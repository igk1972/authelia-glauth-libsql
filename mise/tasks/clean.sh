#!/usr/bin/env bash
set -euo pipefail

#MISE description="Stop the stack and remove built binaries and runtime state (keeps cloned sources)"

#USAGE flag "--all" help="Also remove cloned upstream sources (.build/authelia, .build/glauth) and sqld data"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"

mise run down || true

echo "removing built binaries and runtime state (pids, logs)"
rm -rf "$ROOT/.build/bin"
rm -f "$ROOT/.run"/*.pid "$ROOT/.run"/*.log

if [ "${usage_all:-false}" = "true" ]; then
	echo "removing cloned sources and sqld data"
	rm -rf "$ROOT/.build/authelia" "$ROOT/.build/glauth" "$ROOT/.run/sqld"
fi

echo "clean complete"
