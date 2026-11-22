#!/usr/bin/env bash
# Push PKGBUILD + .SRCINFO to the AUR package base, on top of its existing
# history. No-op when AUR_SSH_PRIVATE_KEY is absent, so the repo also works without
# AUR publishing configured.
set -euo pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if [[ -z ${AUR_SSH_PRIVATE_KEY:-} ]]; then
  echo '::notice::AUR_SSH_PRIVATE_KEY is not set; skipping the AUR push'
  exit 0
fi

pkgbase=$(sed -n 's/^pkgbase=//p' PKGBUILD)
[[ -n $pkgbase ]] || pkgbase=$(sed -n 's/^pkgname=//p' PKGBUILD)
pkgver=$(sed -n 's/^pkgver=//p' PKGBUILD)
[[ -n $pkgbase && -n $pkgver ]] || { echo 'error: cannot read pkgbase/pkgver' >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" >"$tmp/id"
chmod 600 "$tmp/id"
export GIT_SSH_COMMAND="ssh -i $tmp/id -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$tmp/known_hosts"

# Prove the key is accepted before blaming the package base for a failed clone.
bash scripts/check-aur.sh "$tmp/id"

# Cloning keeps the AUR history intact; force-pushing a single commit does not.
# AUR hands out an empty repository for any name that does not exist yet, so a
# clone alone proves nothing about the base.
git clone --quiet "ssh://aur@aur.archlinux.org/${pkgbase}.git" "$tmp/aur"
git -C "$tmp/aur" rev-parse --verify -q HEAD >/dev/null ||
  { echo "error: ${pkgbase} has no history on the AUR; submit the base at https://aur.archlinux.org/submit/ first" >&2; exit 1; }

install -m644 PKGBUILD .SRCINFO "$tmp/aur/"
git -C "$tmp/aur" add PKGBUILD .SRCINFO
if git -C "$tmp/aur" diff --cached --quiet; then
  echo "AUR already at ${pkgver}"
  exit 0
fi

git -C "$tmp/aur" -c user.name='aur-updater' -c user.email='aur-updater@localhost' \
  commit --quiet -m "update to ${pkgver}"
git -C "$tmp/aur" push --quiet origin master
echo "published ${pkgbase} ${pkgver} to the AUR"
