#!/usr/bin/env bash
set -euo pipefail

#MISE description="Generate a self-signed TLS cert for the Authelia portal (auth.example.com)"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
DIR="$ROOT/deploy/authelia/tls"
mkdir -p "$DIR"

if [ -f "$DIR/cert.pem" ] && [ -f "$DIR/key.pem" ]; then
	echo "TLS cert already present"
	exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$DIR/key.pem" -out "$DIR/cert.pem" -days 3650 \
	-subj "/CN=auth.example.com" \
	-addext "subjectAltName=DNS:auth.example.com,DNS:*.example.com,DNS:localhost,IP:127.0.0.1"

echo "generated $DIR/{cert,key}.pem"
