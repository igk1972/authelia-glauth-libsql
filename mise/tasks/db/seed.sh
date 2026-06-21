#!/usr/bin/env bash
set -euo pipefail

#MISE description="Seed the glauth directory (users/groups) into the glauth namespace"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
URL="http://localhost:${PORT_CADDY}/${NS_GLAUTH}"

# seed/glauth.sql is self-contained (schema IF NOT EXISTS + reset + insert).
# turso's shell executes the multi-statement file (go-libsql's Exec would not).
turso db shell "$URL" <"$ROOT/seed/glauth.sql"
echo "seeded glauth directory -> $URL"
