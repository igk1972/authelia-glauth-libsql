# CI / Release (GitHub Actions)

`.github/workflows/release.yml` builds the patched Authelia + glauth (libsql) and publishes:

- two **multi-arch container images** to GitHub Container Registry (ghcr.io), built with
  **buildah** commands (no Containerfile);
- the **binaries** to a GitHub Release.

## Triggers

- `push` of a `v*` git tag → full run, including the Release job.
- `workflow_dispatch` → manual run; images are still published, the Release job is skipped
  (it is gated on a tag).

## Targets & runners

The build is **native per target** (`CGO_ENABLED=1`; go-libsql links a prebuilt static
`libsql.a`), so each architecture builds on its own runner — no cross toolchain, no QEMU:

| Target | Runner |
|--------|--------|
| `linux/amd64`  | `ubuntu-24.04` |
| `linux/arm64`  | `ubuntu-24.04-arm` |
| `darwin/arm64` | `macos-14` |

Lightweight jobs (`meta` / `manifest` / `release`) run on `ubuntu-slim`. Container images are
**linux only** (amd64 + arm64); macOS produces a binary only — `darwin/amd64` has no
go-libsql prebuilt (see [limitations.md](limitations.md)).

## Jobs

- **meta** — reads the upstream pins (`AUTHELIA_TAG`, `GLAUTH_TAG`) from `mise.toml` and
  exposes the image versions.
- **build** (matrix ×3) — `mise run setup:sources` → `build:frontend` → `build:authelia` →
  `build:glauth`; uploads the binaries as artifacts; on linux also builds and pushes the
  per-arch images with `buildah`.
- **manifest** — stitches the per-arch images into one multi-arch manifest list per
  component (`buildah manifest`).
- **release** — (tag only) downloads the binaries, writes `SHA256SUMS`, and uploads
  everything to the GitHub Release.

## Images (ghcr.io)

Tagged with the **upstream** version + `-libsql` (no `latest`); the base image is
`gcr.io/distroless/cc-debian13` (glibc ≥ the build runner's, plus `libgcc_s.so.1` /
`libstdc++` — the CGO go-libsql binaries load these at runtime; no shell). Config is mounted
at runtime, not baked in.

- `ghcr.io/<owner>/authelia:<authelia-version>-libsql` (e.g. `4.39.20-libsql`)
- `ghcr.io/<owner>/glauth:<glauth-version>-libsql` (e.g. `2.4.0-libsql`)

Each is a manifest list covering `linux/amd64` + `linux/arm64`.

## Release assets

For both components, per target (`linux/amd64`, `linux/arm64`, `darwin/arm64`):

- `authelia-<authelia-version>-libsql-<os>-<arch>`
- `glauth-<glauth-version>-libsql-<os>-<arch>`
- `SHA256SUMS`

## Versioning

Image/binary versions come from the upstream pins in `mise.toml`, **not** from the git tag —
the git tag only triggers the run and names the Release. Bumping a component's image is a
matter of bumping `AUTHELIA_TAG` / `GLAUTH_TAG`.
