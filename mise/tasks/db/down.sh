#!/usr/bin/env bash
set -euo pipefail

#MISE description="Stop sqld and Caddy started by db:up"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
RUN_DIR="$ROOT/.run"

stop() { # name
	local name="$1"
	local pidfile="$RUN_DIR/$name.pid"
	if [ -f "$pidfile" ]; then
		local pid
		pid="$(cat "$pidfile")"
		if kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			echo "stopped $name (pid $pid)"
		else
			echo "$name not running (stale pid $pid)"
		fi
		rm -f "$pidfile"
	else
		echo "$name not running"
	fi
}

stop caddy
stop sqld
