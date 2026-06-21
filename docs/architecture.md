# Architecture

A setup in which **Authelia** and **glauth** store all of their data in a single **sqld**
(Turso libSQL) server, over the Hrana protocol via the
[`go-libsql`](https://github.com/tursodatabase/go-libsql) driver. Everything runs natively
through [mise](https://mise.jdx.dev) — no Docker.

## Components

- **glauth** — LDAP server. The directory (users / groups / capabilities) lives in the
  `glauth` namespace in sqld. The libsql backend is **compiled into** the binary (build tag
  `embedlibsql`), avoiding the fragile Go plugin (`.so`) mechanism.
- **Authelia** — authentication portal. Uses glauth as its LDAP backend, and keeps its own
  SQL storage (2FA/TOTP/WebAuthn, OIDC, regulation, identity-verification **and sessions**)
  in the `authelia` namespace in sqld.
- **sqld** — a single instance with `--enable-namespaces`; the `authelia` and `glauth`
  namespaces isolate the two applications' data.
- **Caddy** — path-based ingress to the namespaces (see below).

## Data flow

```
authelia ──http://localhost:10000/authelia──┐
                                            ├─ Caddy :10000 ──Host:<ns>.sqld──> sqld :10001 (--enable-namespaces)
glauth  ──http://localhost:10000/glauth─────┘                                    admin :10002 (namespace mgmt)
```

## The Caddy + namespaces trick

sqld routes a namespace by the subdomain in the `Host` header (`<namespace>.sqld`). To
avoid writing subdomains into `/etc/hosts`, Caddy listens on `:10000`, matches the path
`/<namespace>/<rest>`, strips the prefix and proxies to sqld with
`Host: <namespace>.sqld`:

```caddyfile
:{$PORT_CADDY:10000} {
	@ns path_regexp ns ^/([a-z0-9_-]+)(/.*)?$
	handle @ns {
		rewrite * {re.ns.2}
		reverse_proxy 127.0.0.1:{$SQLD_HTTP:10001} {
			header_up Host {re.ns.1}.sqld
		}
	}
}
```

A libsql client connects to `http://localhost:10000/authelia` or `.../glauth`. go-libsql
preserves the URL path prefix when building Hrana endpoints, so the scheme works (see
[driver-and-gotchas.md](driver-and-gotchas.md)).

## Ports (range 10000–10100)

| Port    | Service           | Note |
|---------|-------------------|------|
| `10000` | Caddy ingress     | entry for libsql clients → namespace by path |
| `10001` | sqld HTTP (Hrana) | `--http-listen-addr 127.0.0.1:10001` |
| `10002` | sqld admin API    | namespace creation (`POST /v1/namespaces/<ns>/create`) |
| `10010` | Authelia portal   | **https**, host `auth.example.com` (TLS required) |
| `10020` | glauth LDAP       | bind/search |

Values are exposed in `[env]` of `mise.toml` (`PORT_CADDY`, `SQLD_HTTP`, `SQLD_ADMIN`,
`PORT_AUTHELIA`, `PORT_GLAUTH_LDAP`).

## Pinned versions

| Component | Version | How it's installed |
|-----------|---------|--------------------|
| Authelia  | `v4.39.20` | clone + patch (`setup:sources`) |
| glauth    | `v2.4.0` | clone + patch (`setup:sources`) |
| sqld      | `libsql-server-v0.24.32` | mise `github:tursodatabase/libsql` |
| Caddy     | `2.11.4` | mise (aqua) |
| Go        | `1.23` | mise (Authelia auto-fetches its own toolchain) |
| node/pnpm | `24` / `11.8.0` | mise (frontend + Playwright) |

## Repository layout

```
mise.toml                  # tools + env (ports, namespaces, tags, paths)
mise/tasks/**/*.sh         # file tasks (#MISE/#USAGE), subdir → group:name
patches/{authelia,glauth}/ # patches only; sources are cloned into .build/ (gitignored)
config/{authelia,glauth}/  # service configs (authelia/secrets.env.example; secrets.env gitignored)
deploy/caddy/Caddyfile     # path-namespace ingress
deploy/authelia/tls/       # self-signed portal cert (gitignored)
seed/glauth.sql            # test users/groups
tests/                     # Playwright browser test
.github/workflows/         # CI: native build -> ghcr images (buildah) + GitHub Release
.build/                    # cloned+patched sources and binaries (gitignored)
.run/                      # pid/log files + sqld data of running services (gitignored)
```

## CI / Release

`.github/workflows/release.yml` builds every target natively (no cross toolchain) and
publishes two multi-arch images to ghcr.io via buildah (no Containerfile) plus the binaries
to a GitHub Release. See [ci.md](ci.md).
