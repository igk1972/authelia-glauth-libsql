#!/usr/bin/env bash
set -euo pipefail

#MISE description="Run Authelia (libsql storage + sessions) in the background"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
RUN_DIR="$ROOT/.run"
BIN="$ROOT/.build/bin/authelia"
CFG="$ROOT/config/authelia/configuration.yml"
mkdir -p "$RUN_DIR"

# Load secrets from the gitignored secrets.env (created from the example on first run).
# Authelia reads these as AUTHELIA_* env vars, keeping them out of configuration.yml / git.
SECRETS="$ROOT/config/authelia/secrets.env"
[ -f "$SECRETS" ] || cp "$ROOT/config/authelia/secrets.env.example" "$SECRETS"
set -a; . "$SECRETS"; set +a

if [ ! -x "$BIN" ]; then
	echo "authelia binary missing; run: mise run build:authelia" >&2
	exit 1
fi

pidfile="$RUN_DIR/authelia.pid"
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
	echo "authelia already running (pid $(cat "$pidfile"))"
	exit 0
fi

nohup "$BIN" --config "$CFG" >"$RUN_DIR/authelia.log" 2>&1 &
echo $! >"$pidfile"
echo "started authelia (pid $(cat "$pidfile")) -> $RUN_DIR/authelia.log"

for _ in $(seq 1 60); do
	if curl -fsS -k -o /dev/null "https://127.0.0.1:${PORT_AUTHELIA}/api/health" 2>/dev/null; then
		echo "authelia :${PORT_AUTHELIA} ready (https)"
		exit 0
	fi
	sleep 0.3
done
echo "WARN: authelia not ready (see $RUN_DIR/authelia.log)" >&2
