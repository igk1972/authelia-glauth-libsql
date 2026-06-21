#!/usr/bin/env bash
set -euo pipefail

#MISE description="Stop the whole stack (authelia, glauth, caddy, sqld)"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
RUN_DIR="$ROOT/.run"

for name in authelia glauth caddy sqld; do
	pf="$RUN_DIR/$name.pid"
	if [ -f "$pf" ]; then
		pid="$(cat "$pf")"
		if kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			echo "stopped $name ($pid)"
		else
			echo "$name not running (stale pid)"
		fi
		rm -f "$pf"
	else
		echo "$name not running"
	fi
done
