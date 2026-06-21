#!/usr/bin/env bash
set -euo pipefail

#MISE description="Clone Authelia and glauth at pinned tags into .build/ and apply local patches"

#USAGE flag "--reset" help="Re-clone from scratch, discarding any local changes in .build/"

ROOT="${MISE_PROJECT_ROOT:-$PWD}"
BUILD="$ROOT/.build"
mkdir -p "$BUILD"

clone() { # name url tag [extra git clone args...]
	local name="$1" url="$2" tag="$3"
	shift 3
	local dir="$BUILD/$name"
	if [ "${usage_reset:-false}" = "true" ] && [ -d "$dir" ]; then
		echo "removing $dir"
		rm -rf "$dir"
	fi
	if [ ! -d "$dir/.git" ]; then
		echo "cloning $name @ $tag"
		git clone --depth 1 --branch "$tag" "$@" "$url" "$dir"
	else
		echo "$name present ($(git -C "$dir" describe --tags --always 2>/dev/null || echo '?'))"
	fi
}

apply_patches() { # name
	local name="$1"
	local dir="$BUILD/$name"
	local pdir="$ROOT/patches/$name"
	shopt -s nullglob
	local patches=("$pdir"/*.patch)
	shopt -u nullglob
	if [ ${#patches[@]} -eq 0 ]; then
		echo "no patches for $name"
		return 0
	fi
	for p in "${patches[@]}"; do
		if git -C "$dir" apply --reverse --check "$p" 2>/dev/null; then
			echo "already applied $(basename "$p")"
		elif git -C "$dir" apply --check "$p" 2>/dev/null; then
			git -C "$dir" apply "$p"
			echo "applied $(basename "$p")"
		else
			echo "FAILED to apply $(basename "$p")"
			return 1
		fi
	done
}

# keys.go is a generated file: authelia-gen builds it via reflection over the config
# struct koanf tags. Rather than hand-patching it, regenerate it after patching — the
# patch adds the LibSQL struct fields, and the generator then emits the matching
# storage.libsql.* / session.libsql.* keys. Keeps the patch robust across upgrades.
regen_authelia_keys() {
	local dir="$BUILD/authelia"
	echo "regenerating internal/configuration/schema/keys.go (authelia-gen)"
	go -C "$dir" run ./cmd/authelia-gen code keys
}

clone authelia https://github.com/authelia/authelia.git "$AUTHELIA_TAG"
clone glauth https://github.com/glauth/glauth.git "$GLAUTH_TAG" --recurse-submodules

apply_patches authelia
regen_authelia_keys
apply_patches glauth
