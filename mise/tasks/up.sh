#!/usr/bin/env bash
set -euo pipefail

#MISE description="Build and start the full stack: sqld + caddy + glauth + authelia, all data in libsql"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"

mise run setup:tls
mise run build:glauth
mise run build:authelia
mise run db:up
mise run db:namespaces
mise run migrate:authelia
mise run db:seed
mise run run:glauth
mise run run:authelia

echo
echo "Stack is up:"
echo "  Authelia portal  : http://127.0.0.1:${PORT_AUTHELIA}"
echo "  glauth LDAP      : ldap://127.0.0.1:${PORT_GLAUTH_LDAP}"
echo "  sqld (via Caddy) : http://127.0.0.1:${PORT_CADDY}/{${NS_AUTHELIA},${NS_GLAUTH}}"
echo
echo "Run 'mise run verify' for an end-to-end check."
