# authelia + glauth + sqld (all storage via libsql)

**Authelia** and **glauth** keep *all of their data* in a single **sqld**
(Turso libSQL) server, over the Hrana protocol via the `go-libsql` driver. Everything runs
natively through [mise](https://mise.jdx.dev) — no Docker.

- **glauth** — LDAP directory in the `glauth` namespace (libsql backend compiled in, `embedlibsql`).
- **Authelia** — portal; glauth as the LDAP backend, its own storage (2FA/OIDC/regulation
  **and sessions**) in the `authelia` namespace.
- **sqld** (`--enable-namespaces`) + **Caddy** — path-based namespace routing, no `/etc/hosts`.

## Quick start

```sh
mise run setup:tools     # go, caddy, sqld, node, pnpm
mise run setup:sources   # clone authelia/glauth at pinned tags + apply patches
mise run up              # cert + build (incl. frontend) + start the stack
mise run verify          # SQL level: login + data/sessions in libsql + restart
mise run test:browser    # browser login through the real portal (Playwright)
mise run down            # stop the stack
```

Test users (`seed/glauth.sql`), password is `password`: `john` (admins), `jane` (users).
Portal: `https://auth.example.com:10010` (self-signed TLS cert, see docs).

## Documentation

- [docs/architecture.md](docs/architecture.md) — components, ports, data flow, the
  Caddy+namespaces trick, pinned versions, repository layout.
- [docs/driver-and-gotchas.md](docs/driver-and-gotchas.md) — why go-libsql (not
  turso-go), the gotchas (multi-statement, `STREAM_EXPIRED`, otelsql, symbol clash, Root
  DSE), binary size optimization.
- [docs/patches.md](docs/patches.md) — exactly what is patched in Authelia and glauth, the
  frontend build, idempotency.
- [docs/usage.md](docs/usage.md) — mise task reference, lifecycle, verification
  (SQL/browser/manual).
- [docs/limitations.md](docs/limitations.md) — deliberate limitations.
