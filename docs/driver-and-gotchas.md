# libsql driver and gotchas

## Why go-libsql, not turso-go

The initial target was `turso-go` (`turso.tech/database/tursogo`, pure Go, beta). Testing
showed its `database/sql` driver is **local-only**:

```
$ sql.Open("turso", "http://localhost:10000/authelia") ; db.Ping()
turso: error: I/O error (open): entity not found
```

i.e. the DSN is treated as a path to a local file; turso-go cannot talk to a remote classic
sqld over Hrana (its remote support is only via its own sync protocol, incompatible with
sqld). So **go-libsql (CGO)** was chosen, which:

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
