# Usage

Everything runs natively through [mise](https://mise.jdx.dev). Task files live in
`mise/tasks/**/*.sh` (subdir → `group:name`; mise strips the `.sh`).

## Lifecycle

```sh
mise run setup:tools     # install go, caddy, sqld, node, pnpm
mise run setup:sources   # clone authelia@tag, glauth@tag, apply patches, regen keys.go
mise run up              # cert + build (incl. frontend) + start the whole stack
mise run verify          # SQL-level e2e
mise run test:browser    # browser login through the real portal (Playwright)
mise run down            # stop the stack
mise run clean           # + remove binaries, pids and logs (--all: also sources and sqld data)
```

## Task reference

| Task | What it does |
|------|--------------|
| `setup:tools` | `mise install` + print toolchain versions |
| `setup:sources [--reset]` | clone Authelia/glauth at tags into `.build/` (glauth without submodules) + apply patches + regenerate Authelia `keys.go` (authelia-gen) |
| `setup:tls` | self-signed cert for `auth.example.com` into `deploy/authelia/tls/` |
| `build:frontend` | build the Authelia web frontend (Vite) into `public_html` |
| `build:glauth` | build glauth (`-tags embedlibsql`, CGO, `-s -w -trimpath`) |
| `build:authelia` | build Authelia (CGO, `-s -w -trimpath`); depends on `setup:sources`, `build:frontend` |
| `db:up` / `db:down` | start/stop sqld + Caddy (background, pid in `.run/`) |
| `db:namespaces` | create the `authelia`, `glauth` namespaces via the admin API |
| `db:seed` | load `seed/glauth.sql` into the `glauth` namespace |
| `db:reset` | wipe sqld data and recreate empty namespaces |
| `migrate:authelia` | run Authelia migrations into the `authelia` namespace (idempotent) |
| `run:glauth` / `run:authelia` | start the services (background, pid in `.run/`) |
| `up` / `down` | start / stop the whole stack |
| `verify` | SQL-level e2e (see below) |
| `test:browser` | Playwright login through the real portal UI |
| `clean [--all]` | stop + remove binaries, pids and logs (with `--all`, also sources and sqld data) |

Test glauth users (`seed/glauth.sql`), password is `password`: `john` (group `admins`),
`jane` (group `users`).

## Secrets

Authelia's secrets — `session.secret`, `storage.encryption_key`,
`identity_validation.reset_password.jwt_secret`, and the LDAP bind password — are **not** in
`configuration.yml`. They live in `config/authelia/secrets.env` (gitignored) and are read by
Authelia as `AUTHELIA_*` env vars. `run:authelia` and `migrate:authelia` load this file,
creating it from `config/authelia/secrets.env.example` on first run, so the stack works out
of the box locally. The placeholder values are for local use only — replace them before any
real use.

## CI / Release

Tagged builds publish multi-arch images to ghcr.io and binaries to a GitHub Release via
`.github/workflows/release.yml`. See [ci.md](ci.md).

## Verification

### `mise run verify` (SQL level)

1. glauth users exist in libsql;
2. `POST /api/firstfactor` (`john`/`password`) issues a session cookie (Authelia → glauth LDAP);
3. a session row appears in libsql;
4. `/api/user/info` is authenticated;
5. restarting **only** Authelia → still authenticated with the same cookie
   (proves the session is in libsql, not in-memory).

### `mise run test:browser` (browser)

Authelia requires an `https` `authelia_url`, so the portal is served over TLS with a
self-signed cert for `auth.example.com`. The Playwright test (`tests/`) maps
`auth.example.com → 127.0.0.1` at the browser level (`--host-resolver-rules`) and ignores
the cert — no `/etc/hosts`. The test logs in as `john/password` through the real UI
(`#username-textfield` / `#password-textfield` / `#sign-in-button`) and asserts
`#authenticated-stage`.

### Manual

```sh
# glauth directory in libsql
turso db shell http://localhost:10000/glauth "SELECT name, uidnumber FROM users;"

# Authelia storage in libsql (tables, migration, sessions)
turso db shell http://localhost:10000/authelia "SELECT name FROM sqlite_master WHERE type='table';"
turso db shell http://localhost:10000/authelia "SELECT count(*) FROM session;"

# LDAP bind directly
ldapsearch -x -H ldap://127.0.0.1:10020 -D 'cn=john,dc=glauth,dc=com' -w password \
  -b 'dc=glauth,dc=com' '(cn=jane)'

# portal (https, self-signed cert)
curl -k --resolve auth.example.com:10010:127.0.0.1 https://auth.example.com:10010/api/health
```
