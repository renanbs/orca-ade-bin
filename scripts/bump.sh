#!/usr/bin/env bash
# Bump pkgver and every checksum to the newest stable upstream release.
#
# Checksums come from the electron-builder manifests (latest-linux*.yml), which
# carry the sha512 of each published asset. Nothing but ~2 KB of metadata is
# downloaded here: makepkg fetches only the source of the architecture it builds.
#
# Writes .update/changed (true|false) and .update/version so a caller without
# access to $GITHUB_OUTPUT can read the result. Refuses to touch the PKGBUILD
# unless the manifests agree with the release assets GitHub lists.
set -euo pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

upstream='stablyai/orca'
state='.update'

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f PKGBUILD ]] || die 'PKGBUILD not found'
current=$(sed -n 's/^pkgver=//p' PKGBUILD)
[[ -n $current ]] || die 'no pkgver in PKGBUILD'

api_headers=()
[[ -n ${GITHUB_TOKEN:-} ]] && api_headers=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

api=$(curl -fsSL "${api_headers[@]}" \
  "https://api.github.com/repos/${upstream}/releases/latest")
tag=$(jq -r '.tag_name // empty' <<<"$api")
[[ $tag =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] ||
  die "latest release tag is not vX.Y.Z: ${tag:-<none>}"
new=${BASH_REMATCH[1]}

mkdir -p "$state"
printf '%s\n' "$new" >"$state/version"
if [[ $new == "$current" ]]; then
  printf 'false\n' >"$state/changed"
  printf 'up to date: %s\n' "$current"
  exit 0
fi

printf 'bumping %s -> %s\n' "$current" "$new"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
rel="https://github.com/${upstream}/releases/download/v${new}"

curl -fsSL -o "$tmp/x86_64.yml" "${rel}/latest-linux.yml"
curl -fsSL -o "$tmp/aarch64.yml" "${rel}/latest-linux-arm64.yml"
curl -fsSL -o "$tmp/LICENSE" "https://raw.githubusercontent.com/${upstream}/v${new}/LICENSE"
grep -qF 'MIT License' "$tmp/LICENSE" || die 'upstream LICENSE changed shape'

# Pull "<key>: <value>" for the block that names this asset.
yml_field() {  # <file> <asset url> <field>
  awk -v want="$2" -v field="$3" '
    /^  - url:/ { url = $3 }
    $1 == field ":" && url == want { print $2; exit }
  ' "$1"
}
b64_hex() { printf '%s' "$1" | base64 -d | od -An -tx1 | tr -d ' \n'; }
sha() { sha512sum -- "$1" | cut -d' ' -f1; }

checksums=()
for arch in x86_64 aarch64; do
  deb="orca-ide_${new}_$([[ $arch == x86_64 ]] && echo amd64 || echo arm64).deb"
  manifest="$tmp/${arch}.yml"

  # two independent GitHub sources must agree before anything is written
  api_size=$(jq -r --arg n "$deb" '.assets[] | select(.name == $n) | .size' <<<"$api")
  yml_size=$(yml_field "$manifest" "$deb" size)
  [[ -n $api_size && $api_size == "$yml_size" ]] ||
    die "$deb: manifest size ${yml_size:-<none>} != release size ${api_size:-<none>}"

  hex=$(b64_hex "$(yml_field "$manifest" "$deb" sha512)")
  [[ $hex =~ ^[0-9a-f]{128}$ ]] || die "$deb: bad sha512 in manifest"
  checksums+=("$hex")
done

set_field() {  # <name> <value>
  local name=$1 value=$2
  sed -i -E "s|^${name}=\(.*\)\$|${name}=('${value}')|" PKGBUILD
  grep -qxF "${name}=('${value}')" PKGBUILD || die "could not update ${name}"
}

set_field sha512sums "$(sha "$tmp/LICENSE")"
set_field sha512sums_x86_64 "${checksums[0]}"
set_field sha512sums_aarch64 "${checksums[1]}"
sed -i -E "s|^pkgver=.*\$|pkgver=${new}|; s|^pkgrel=.*\$|pkgrel=1|" PKGBUILD
grep -qxF "pkgver=${new}" PKGBUILD || die 'could not update pkgver'

makepkg --printsrcinfo >"$tmp/.SRCINFO"
grep -qE "^[[:space:]]*pkgver = ${new}\$" "$tmp/.SRCINFO" || die '.SRCINFO is stale'
mv "$tmp/.SRCINFO" .SRCINFO

printf 'true\n' >"$state/changed"
printf 'bumped to %s\n' "$new"
