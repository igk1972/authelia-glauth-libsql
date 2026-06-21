#!/usr/bin/env bash
set -euo pipefail

#MISE description="Create the sqld namespaces (authelia, glauth) via the admin API"

ADMIN="http://127.0.0.1:${SQLD_ADMIN}"

create_ns() { # namespace
	local ns="$1"
	local code
	code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$ADMIN/v1/namespaces/$ns/create" \
		-H 'Content-Type: application/json' --data '{}')
	case "$code" in
	200 | 201) echo "namespace '$ns' created" ;;
	400 | 409) echo "namespace '$ns' already exists (HTTP $code)" ;;
	*)
		echo "namespace '$ns' create failed (HTTP $code):"
		curl -s -X POST "$ADMIN/v1/namespaces/$ns/create" -H 'Content-Type: application/json' --data '{}'
		echo
		return 1
		;;
	esac
}

create_ns "$NS_AUTHELIA"
create_ns "$NS_GLAUTH"
