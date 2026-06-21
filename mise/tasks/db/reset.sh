#!/usr/bin/env bash
set -euo pipefail

#MISE description="Wipe sqld data and recreate empty namespaces (destructive)"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"

mise run db:down || true
echo "wiping $ROOT/.run/sqld/data"
rm -rf "$ROOT/.run/sqld/data"
mise run db:up
mise run db:namespaces
echo "reset complete - run 'mise run db:seed' to repopulate glauth"
