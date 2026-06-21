#!/usr/bin/env bash
set -euo pipefail

#MISE description="End-to-end check: log in via Authelia (glauth user) and prove storage + sessions live in libsql"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
A="https://auth.example.com:${PORT_AUTHELIA}"
GLAUTH_URL="http://localhost:${PORT_CADDY}/${NS_GLAUTH}"
AUTH_URL="http://localhost:${PORT_CADDY}/${NS_AUTHELIA}"
# Resolve the portal host to localhost and accept the self-signed cert.
C=(-k --resolve "auth.example.com:${PORT_AUTHELIA}:127.0.0.1")

fail() {
	echo "VERIFY FAILED: $1" >&2
	exit 1
}

count() { # libsql_url sql -> integer
	turso db shell "$1" "$2" 2>/dev/null | grep -oE '[0-9]+' | head -1
}

# 1. glauth directory served from libsql.
users=$(count "$GLAUTH_URL" "SELECT count(*) FROM users;")
echo "glauth users in libsql: ${users:-0}"
[ "${users:-0}" -ge 1 ] || fail "no glauth users in libsql"

# 2. First-factor login (Authelia -> glauth LDAP).
cookie=$(curl -s -i "${C[@]}" -X POST "$A/api/firstfactor" -H 'Content-Type: application/json' \
	-d '{"username":"john","password":"password","keepMeLoggedIn":false,"targetURL":"https://auth.example.com:'"${PORT_AUTHELIA}"'/","requestMethod":"GET"}' |
	grep -i '^Set-Cookie: authelia_session=' | sed -E 's/^[Ss]et-[Cc]ookie: (authelia_session=[^;]+);.*/\1/')
[ -n "$cookie" ] || fail "first-factor login failed (no session cookie)"
echo "login OK (session cookie issued)"

# 3. Session persisted in libsql.
sess=$(count "$AUTH_URL" "SELECT count(*) FROM session;")
echo "sessions in libsql: ${sess:-0}"
[ "${sess:-0}" -ge 1 ] || fail "no session row in libsql"

# 4. Authenticated before restart.
curl -s "${C[@]}" -H "Cookie: $cookie" "$A/api/user/info" | grep -q '"display_name":"John"' ||
	fail "not authenticated before restart"
echo "authenticated before restart"

# 5. Restart ONLY Authelia.
if [ -f "$ROOT/.run/authelia.pid" ]; then
	kill "$(cat "$ROOT/.run/authelia.pid")" 2>/dev/null || true
	rm -f "$ROOT/.run/authelia.pid"
fi
sleep 1
mise run run:authelia >/dev/null

# 6. Still authenticated with the same cookie -> session loaded from libsql.
curl -s "${C[@]}" -H "Cookie: $cookie" "$A/api/user/info" | grep -q '"display_name":"John"' ||
	fail "session did NOT persist across Authelia restart"
echo "authenticated AFTER restart -> session persisted in libsql"

echo
echo "VERIFY OK: glauth directory + Authelia storage + Authelia sessions are all served from libsql."
