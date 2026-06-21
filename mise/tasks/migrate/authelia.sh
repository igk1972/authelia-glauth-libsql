#!/usr/bin/env bash
set -euo pipefail

#MISE description="Apply Authelia storage migrations to the libsql authelia namespace"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
BIN="$ROOT/.build/bin/authelia"
CFG="$ROOT/config/authelia/configuration.yml"

# Load secrets from the gitignored secrets.env (created from the example on first run).
# `storage migrate` needs AUTHELIA_STORAGE_ENCRYPTION_KEY; reading it from env keeps
# secrets out of configuration.yml / git.
SECRETS="$ROOT/config/authelia/secrets.env"
[ -f "$SECRETS" ] || cp "$ROOT/config/authelia/secrets.env.example" "$SECRETS"
set -a; . "$SECRETS"; set +a

if [ ! -x "$BIN" ]; then
	echo "authelia binary missing; run: mise run build:authelia" >&2
	exit 1
fi

# `migrate up` exits non-zero with "schema already up to date" when there is nothing
# to do; treat that as success so the task is idempotent.
set +e
out=$("$BIN" storage migrate up --config "$CFG" 2>&1)
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
	echo "$out"
	exit 0
fi

if echo "$out" | grep -qi "already up to date"; then
	echo "Authelia storage schema already up to date"
	exit 0
fi

echo "$out" >&2
exit "$rc"
