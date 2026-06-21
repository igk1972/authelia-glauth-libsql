# Upstream patches

The Authelia and glauth sources are cloned at pinned tags into `.build/` (gitignored). The
repository keeps **patches only** — `setup:sources` clones and applies them.
`setup:sources --reset` re-clones from scratch and re-applies the patches (idempotent:
already-applied patches are skipped).

## glauth — `patches/glauth/0001-embed-libsql-backend.patch`

- `v2/pkg/embed/libsql.go` — `SqlBackend` implementation for libsql (driver `libsql`,
  prepare symbol `?`, reuses the SQLite DDL with the upstream `TYEXT`→`TEXT` typo fixed),
  `NewLibsqlHandler`.
- `v2/pkg/server/embed_libsql.go` — `NewEmbed` under the `embedlibsql` build tag; edit to
  `embed_noembed.go` (adds `embedlibsql` to the excluding build constraint).
- `v2/pkg/plugins/basesqlhandler.go` — for the `libsql` driver, open via plain
  `database/sql` (bypassing `otelsql`, which is incompatible with go-libsql) + pool tuning
  (`ConnMaxIdleTime`/`ConnMaxLifetime`).
- `go.mod`/`go.sum` — the `github.com/tursodatabase/go-libsql` dependency.

Build: `go build -tags embedlibsql` (CGO). Config: `datastore = "embed"`,
`database = "http://localhost:10000/glauth"`, `anonymousdse = true`.

glauth is cloned **without submodules**: its plugin submodules (`glauth-{sqlite,mysql,
postgres,pam}`) use SSH URLs and are unused by the `embedlibsql` build (`go.work` uses only
`./v2`, and the main module neither requires nor imports them), so `setup:sources` skips
them — CI runners have no SSH key to `git@github.com`.

## Authelia — `patches/authelia/0001-libsql-storage-and-sessions.patch`

### libsql storage backend

- `internal/configuration/schema/storage.go` — `StorageLibSQL{URL, AuthToken}` + a field on `Storage`.
- `internal/configuration/validator/storage.go` — `validateLibSQLConfiguration` branch + inclusion in the "exactly one backend" count.
- `internal/storage/const.go` — `providerLibSQL = "libsql"`.
- `internal/storage/sql_provider_backend_libsql.go` — `NewLibSQLProvider`: a wrapper over
  `NewSQLProvider(config, providerLibSQL, "libsql", dsn)` reusing the SQLite dialect,
  `querySQLiteSelectExistingTables`, and pool tuning; `sqlx.BindDriver("libsql", QUESTION)`.
- `internal/storage/sql_provider.go` — `case config.Storage.LibSQL != nil` branch in `NewProvider`.
- `internal/storage/sql_provider_schema.go` — libsql added to `truncate` (like sqlite) and
  `schemaMigrateExec` (splits multi-statement migrations per statement for libsql).
- `internal/storage/migrations/libsql/V0001.Initial_Schema.{up,down}.sql` — a **squashed**
  final schema (equivalent to sqlite V0001..V0024), dumped from a real sqlite; fresh-install
  only (the historical UDF/PRAGMA/rebuild migrations are not replayed).
- `internal/storage/sql_provider_backend_sqlite.go` — the local SQLite backend switched to
  go-libsql (file mode) to drop `mattn/go-sqlite3` from the build (C-symbol clash).

### sessions in libsql

- `internal/session/libsql/provider.go` — a fasthttp `session.Provider` over go-libsql:
  table `session(id, data BLOB, last_active, expiration)`, upsert, GC; `data` is bound as
  `[]byte`.
- `internal/configuration/schema/session.go` — `SessionLibSQL{URL, AuthToken, Table}` + a field on `Session`.
- `internal/configuration/validator/session.go` — validation (url required, default table).
- `internal/session/provider_config.go` — `case config.LibSQL != nil` branch in
  `NewSessionProvider` with a **mandatory** `NewEncryptingSerializer(config.Secret)`
  (sessions are AES-GCM-encrypted before storage).

### Generated config keys (`keys.go`)

`internal/configuration/schema/keys.go` (the list of valid configuration keys) is a
**generated** file: `authelia-gen` builds it via reflection over the config struct koanf
tags. Rather than patching it by hand, `setup:sources` regenerates it after applying the
patches (`go run ./cmd/authelia-gen code keys`) — the patch adds the `LibSQL` struct fields,
and the generator then emits the matching `storage.libsql.*` / `session.libsql.*` keys. This
keeps the patch robust across Authelia upgrades.

## Authelia web frontend (outside the patches)

The frontend (React/Vite) is built as a separate step, `build:frontend` (pnpm); Vite emits
the assets directly into `internal/server/public_html` (its `outDir`), from which Go embeds
them (`//go:embed`). These are **generated** assets, so they are not part of the patch.
Vite's `emptyOutDir` wipes `public_html/api` (the swagger template Authelia loads at
startup) — it is restored from the git checkout after the build.

## Idempotency

`apply_patches` in `setup:sources` first tries `git apply --reverse --check` (already
applied → skip), then `git apply --check` (apply). Re-runs are safe.
