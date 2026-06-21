#!/usr/bin/env bash
set -euo pipefail

#MISE description="Build the Authelia web frontend (pnpm + Vite) into the embedded public_html"
#MISE depends=["setup:sources"]
#MISE sources=[".build/authelia/web/src/**/*", ".build/authelia/web/package.json", ".build/authelia/web/index.html"]
# The "static" dir only exists after a real Vite build (the cloned placeholder lacks it),
# so it reliably marks the frontend as built.
#MISE outputs=[".build/authelia/internal/server/public_html/static"]

ROOT="${MISE_PROJECT_ROOT:-$PWD}"

cd "$ROOT/.build/authelia/web"
pnpm install --frozen-lockfile
# Vite is configured (outDir) to emit into ../internal/server/public_html.
pnpm build

# Vite's emptyOutDir wipes the committed public_html/api swagger template, which
# Authelia loads at startup; restore it from the upstream checkout.
git -C "$ROOT/.build/authelia" checkout -- internal/server/public_html/api

echo "frontend built into internal/server/public_html"
