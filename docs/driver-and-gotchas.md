# libsql driver and gotchas

## Why go-libsql

The driver is [`go-libsql`](https://github.com/tursodatabase/go-libsql) (CGO), which:

- connects to sqld over Hrana and **preserves the URL path prefix** → path-based
  namespaces via Caddy work (`http://localhost:10000/<ns>`);
- supports interactive `Begin/Commit` transactions, `PRAGMA foreign_keys`, `RETURNING`,
  correct binary round-trip, and `AUTOINCREMENT` (no `INTEGER→float64` bug).

`CGO_ENABLED=1` is mandatory — go-libsql links a native static libsql.

## go-libsql gotchas (and how they are handled)

### 1. Multi-statement `Exec` runs only the first statement

`db.Exec("CREATE TABLE ...; CREATE INDEX ...")` runs only the `CREATE TABLE`.

- **Authelia**: migration runs are split into individual statements (`schemaMigrateExec`
  in the patch), plus a squashed one-statement-per-line schema is used.
- **glauth**: already executes DDL one statement at a time (`CreateSchema`).

### 2. Hrana streams expire while idle (`STREAM_EXPIRED`)

A long-lived `database/sql` pool reuses a connection whose Hrana stream sqld has closed for
inactivity:

```
STREAM_EXPIRED: The stream has expired due to inactivity
```

This surfaced as an intermittent "User not found" / "invalid credentials". The fix is to
recycle connections before the server expires the stream:

```go
db.SetConnMaxIdleTime(2 * time.Second)
db.SetConnMaxLifetime(25 * time.Second)
```

Applied to all three pools: glauth (`basesqlhandler.go`), Authelia storage
(`sql_provider_backend_libsql.go`), Authelia sessions (`session/libsql/provider.go`).

### 3. `otelsql` is incompatible with go-libsql on `Ping`

glauth opens the DB via `otelsql.Open` (an OTEL wrapper), which on go-libsql returns
`driver.ErrSkip` as a fatal `Ping` error ("skip fast-path; continue as if unimplemented").
For the `libsql` driver we open via plain `database/sql` (DB-layer tracing isn't needed
here).

### 4. C-symbol clash between `mattn/go-sqlite3` and go-libsql

Both libraries pull in the SQLite C API symbols → 266 duplicate symbols at link time.
Authelia's local SQLite backend was switched to go-libsql (file mode) so the build contains
only one SQLite-C implementation.

### 5. Session data stored as a BLOB

The shared fasthttp sql provider binds data via `strconv.B2S` (a string), which is risky
for AES-GCM ciphertext. Our `session/libsql` binds `data` as `[]byte` (a `BLOB` column).

### 6. glauth: anonymous Root DSE

Before binding, Authelia performs an anonymous Root DSE search; glauth rejects it by default
and closes the connection. The glauth config enables `anonymousdse = true`.

### 7. A lost response poisons the Hrana stream (`Received a baton that has already been used`)

sqld advances a stream's baton sequence as soon as it accepts a request, before the response
is sent; the client stores the new baton only after reading it from the response. When a
response is cut on the wire (seen on `/v3/cursor` behind Caddy while another pooled
connection runs queries), the client keeps the old baton and every later request on that
connection is refused with HTTP 400 until the pool retires it. sqld logs `Expected baton seq N, received N-1`, Authelia
logs `user not found` / `Unable to save updated user session`, and after three such
failures regulation bans the user.

go-libsql neither reports such connections as bad nor retries, so
`patches/go-libsql/0001-drop-broken-hrana-streams-from-the-pool.patch` makes the driver:

- implement `driver.Validator` / `driver.SessionResetter`, so a connection that hit a
  stream or transport error is closed instead of returned to the pool;
- return `driver.ErrBadConn` (database/sql retries on a fresh connection) when sqld refused
  the request while acquiring the stream — reused/invalid/closed baton, `STREAM_EXPIRED`,
  429 on opening the connection — since nothing was executed;
- return `driver.ErrBadConn` for a transport failure only on a plain `SELECT`; writes keep
  the original error, as they may have run.

Each cut response still leaves one `Expected baton seq` line in the sqld log: the dropped
connection closes its stream with the stale baton.

glauth's SQL backend also ignored `rows.Err()`, so a cut cursor looked like the end of the
table and a lookup returned no user or no group members;
`patches/glauth/0002-propagate-database-errors.patch` returns those errors instead.

## Binary size optimization

Builds use `-trimpath -ldflags="-s -w"` (DWARF and the Go symbol table removed, local paths
trimmed):

| Binary | Without flags | With `-s -w -trimpath` |
|--------|---------------|------------------------|
| authelia | ~79 MB | **~58 MB** |
| glauth | ~63 MB | **~47 MB** |

The remainder (~50 MB) is the embedded **native libsql** (CGO) plus, for Authelia, the
embedded web frontend. Running `strip` on top yields nothing further; it cannot be shrunk
more without breaking CGO linkage. `-s -w -trimpath` is the practical floor here.
