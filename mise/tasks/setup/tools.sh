#!/usr/bin/env bash
set -euo pipefail

#MISE description="Install the pinned toolchain (go, caddy, sqld) and print versions"

mise install

echo "--- toolchain ---"
echo "go:    $(go version 2>/dev/null || echo MISSING)"
echo "caddy: $(caddy version 2>/dev/null | head -1 || echo MISSING)"
echo "sqld:  $(sqld --version 2>/dev/null || echo MISSING)"
echo "turso: $(turso --version 2>/dev/null || echo 'MISSING (optional)')"
