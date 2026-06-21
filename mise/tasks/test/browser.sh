#!/usr/bin/env bash
set -euo pipefail

#MISE description="Browser login test against the live Authelia portal (Playwright, real UI)"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"

cd "$ROOT/tests"
pnpm install
pnpm exec playwright install chromium
PORT_AUTHELIA="${PORT_AUTHELIA}" pnpm exec playwright test
