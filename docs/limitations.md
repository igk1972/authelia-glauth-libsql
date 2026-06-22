# Limitations

Below are the deliberate simplifications and their reasons.

- **Fresh-install only.** A squashed final libsql schema is used; the historical chain of
  Authelia's sqlite migrations (Go UDFs `BIN2B64`, `PRAGMA foreign_keys` toggling, table
  rebuilds) is not replayed. Upgrading an existing database is not supported.
- **sqld without authentication.** Runs on trusted localhost with no JWT
  (`--auth-jwt-key`). For production: enable an Ed25519 JWT on sqld and present a token from
  each client — Authelia via the `storage.libsql.auth_token` / `session.libsql.auth_token`
  config fields, glauth via the `GLAUTH_LIBSQL_AUTH_TOKEN` env var (appended to the DSN as
  `authToken=`). Both paths are already wired.
- **Sessions without Redis.** Authelia sessions are persisted in libsql (rather than
  in-memory/Redis), which was the goal; Redis HA scenarios were not considered.
- **Placeholder secrets and self-signed TLS.** Authelia's secrets live in
  `config/authelia/secrets.env` (gitignored, copied from `secrets.env.example`) and are read
  as `AUTHELIA_*` env vars; those placeholder values and the `deploy/authelia/tls/` cert are
  for local use only. Replace before any real use.
- **Version not injected into the binary.** The build does not pass
  `-ldflags -X ...Version`, so Authelia reports its version as `untagged-unknown` (visible
  in the `migrations` table). Cosmetic; easy to add tag injection.
- **CGO + platforms.** go-libsql requires `CGO_ENABLED=1` and ships prebuilt static libs for
  `linux/amd64`, `linux/arm64` and `darwin/arm64` only — there is no `darwin/amd64` prebuilt
  in this version, so Intel macs are unsupported. No pure-Go option for a remote sqld existed
  at the time of writing.
- **Downstream patches.** The "sessions in storage/libsql" approach and reusing the sqlite
  backend via go-libsql are downstream changes, not intended for upstream as-is.
- **Binary size.** ~47–58 MB due to the embedded native libsql (+ the web frontend for
  Authelia); it cannot be made smaller without breaking CGO linkage.
