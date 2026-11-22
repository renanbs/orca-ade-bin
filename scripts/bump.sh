#!/usr/bin/env bash
# Bump pkgver and every checksum to the newest stable upstream release.
#
# Writes .update/changed (true|false) and .update/version so a caller without
# access to $GITHUB_OUTPUT can read the result. Refuses to touch the PKGBUILD
# unless each new source downloads intact.
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

tag=$(curl -fsSL "${api_headers[@]}" \
  "https://api.github.com/repos/${upstream}/releases/latest" |
  jq -r '.tag_name // empty')
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

curl -fsSL -o "$tmp/amd64.deb" "${rel}/orca-ide_${new}_amd64.deb"
curl -fsSL -o "$tmp/arm64.deb" "${rel}/orca-ide_${new}_arm64.deb"
curl -fsSL -o "$tmp/LICENSE" "https://raw.githubusercontent.com/${upstream}/v${new}/LICENSE"

# A truncated body or an HTML error page must never reach the checksums.
for deb in amd64.deb arm64.deb; do
  bsdtar -tf "$tmp/$deb" 2>/dev/null | grep -qxF 'data.tar.xz' ||
    die "$deb is not a .deb archive"
done
grep -qF 'MIT License' "$tmp/LICENSE" || die 'upstream LICENSE changed shape'

sha() { sha256sum -- "$1" | cut -d' ' -f1; }

set_field() {
  local name=$1 value=$2
  sed -i -E "s|^${name}=\(.*\)\$|${name}=('${value}')|" PKGBUILD
  grep -qxF "${name}=('${value}')" PKGBUILD || die "could not update ${name}"
}

set_field sha256sums "$(sha "$tmp/LICENSE")"
set_field sha256sums_x86_64 "$(sha "$tmp/amd64.deb")"
set_field sha256sums_aarch64 "$(sha "$tmp/arm64.deb")"
sed -i -E "s|^pkgver=.*\$|pkgver=${new}|; s|^pkgrel=.*\$|pkgrel=1|" PKGBUILD
grep -qxF "pkgver=${new}" PKGBUILD || die 'could not update pkgver'

makepkg --printsrcinfo >"$tmp/.SRCINFO"
grep -qE "^[[:space:]]*pkgver = ${new}\$" "$tmp/.SRCINFO" || die '.SRCINFO is stale'
mv "$tmp/.SRCINFO" .SRCINFO

printf 'true\n' >"$state/changed"
printf 'bumped to %s\n' "$new"
