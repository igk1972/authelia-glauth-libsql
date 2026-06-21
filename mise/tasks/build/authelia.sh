#!/usr/bin/env bash
set -euo pipefail

#MISE description="Build patched Authelia with the libsql storage and session backends (CGO)"
#MISE depends=["setup:sources", "build:frontend"]
#MISE sources=[".build/authelia/internal/**/*.go", ".build/authelia/internal/server/public_html/**/*", "patches/authelia/*.patch"]
#MISE outputs=[".build/bin/authelia"]

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
mkdir -p "$ROOT/.build/bin"

cd "$ROOT/.build/authelia"
# go-libsql is CGO. Authelia's go.mod pins a newer Go toolchain, auto-fetched by `go`.
# -s -w strip the symbol table and DWARF; -trimpath drops local filesystem paths.
CGO_ENABLED=1 go build -trimpath -ldflags="-s -w" -o "$ROOT/.build/bin/authelia" ./cmd/authelia
echo "built $ROOT/.build/bin/authelia"
