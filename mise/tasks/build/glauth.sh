#!/usr/bin/env bash
set -euo pipefail

#MISE description="Build glauth with the compiled-in libsql backend (embedlibsql, CGO)"
#MISE depends=["setup:sources"]
#MISE sources=[".build/glauth/v2/**/*.go", "patches/glauth/*.patch"]
#MISE outputs=[".build/bin/glauth"]

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
mkdir -p "$ROOT/.build/bin"

cd "$ROOT/.build/glauth/v2"
# go-libsql is CGO; tracing-free libsql backend is selected by the embedlibsql tag.
# -s -w strip the symbol table and DWARF; -trimpath drops local filesystem paths.
CGO_ENABLED=1 go build -trimpath -tags embedlibsql -ldflags="-s -w" -o "$ROOT/.build/bin/glauth" .
echo "built $ROOT/.build/bin/glauth"
