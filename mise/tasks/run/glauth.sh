#!/usr/bin/env bash
set -euo pipefail

#MISE description="Run the embedded-libsql glauth LDAP server in the background"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
RUN_DIR="$ROOT/.run"
BIN="$ROOT/.build/bin/glauth"
CFG="$ROOT/config/glauth/glauth.cfg"
mkdir -p "$RUN_DIR"

if [ ! -x "$BIN" ]; then
	echo "glauth binary missing; run: mise run build:glauth" >&2
	exit 1
fi

pidfile="$RUN_DIR/glauth.pid"
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
	echo "glauth already running (pid $(cat "$pidfile"))"
	exit 0
fi

nohup "$BIN" -c "$CFG" >"$RUN_DIR/glauth.log" 2>&1 &
echo $! >"$pidfile"
echo "started glauth (pid $(cat "$pidfile")) -> $RUN_DIR/glauth.log"

# Wait for the LDAP port.
for _ in $(seq 1 50); do
	if (exec 3<>"/dev/tcp/127.0.0.1/${PORT_GLAUTH_LDAP}") 2>/dev/null; then
		exec 3>&- 3<&-
		echo "glauth ldap :${PORT_GLAUTH_LDAP} ready"
		exit 0
	fi
	sleep 0.2
done
echo "WARN: glauth ldap not ready (see $RUN_DIR/glauth.log)" >&2
