#!/usr/bin/env bash
set -euo pipefail

#MISE description="Start sqld (with namespaces) and the Caddy ingress in the background"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
RUN_DIR="$ROOT/.run"
DATA_DIR="$ROOT/.run/sqld/data"
mkdir -p "$RUN_DIR" "$DATA_DIR"

start() { # name cmd...
	local name="$1"
	shift
	local pidfile="$RUN_DIR/$name.pid"
	if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
		echo "$name already running (pid $(cat "$pidfile"))"
		return 0
	fi
	nohup "$@" >"$RUN_DIR/$name.log" 2>&1 &
	echo $! >"$pidfile"
	echo "started $name (pid $(cat "$pidfile")) -> $RUN_DIR/$name.log"
}

wait_port() { # port
	local port="$1"
	for _ in $(seq 1 60); do
		if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
			exec 3>&- 3<&-
			return 0
		fi
		sleep 0.2
	done
	return 1
}

start sqld sqld \
	--enable-namespaces \
	--http-listen-addr "127.0.0.1:${SQLD_HTTP}" \
	--admin-listen-addr "127.0.0.1:${SQLD_ADMIN}" \
	--db-path "$DATA_DIR"

start caddy caddy run --config "$ROOT/deploy/caddy/Caddyfile" --adapter caddyfile

wait_port "${SQLD_HTTP}" && echo "sqld http :${SQLD_HTTP} ready" || echo "WARN: sqld http not ready (see $RUN_DIR/sqld.log)"
wait_port "${SQLD_ADMIN}" && echo "sqld admin :${SQLD_ADMIN} ready" || echo "WARN: sqld admin not ready"
wait_port "${PORT_CADDY}" && echo "caddy :${PORT_CADDY} ready" || echo "WARN: caddy not ready (see $RUN_DIR/caddy.log)"
