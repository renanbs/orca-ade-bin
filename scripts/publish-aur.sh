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

# The AUR has taken submissions over git since 2026-11: a push to a name with no
# history creates the package base, so there is no web form in this path. An
# existing base is cloned so its history and co-maintainers survive.
git -c advice.defaultBranchName=false -c init.defaultBranch=master \
  clone --quiet "ssh://aur@aur.archlinux.org/${pkgbase}.git" "$tmp/aur"

install -m644 PKGBUILD .SRCINFO "$tmp/aur/"
git -C "$tmp/aur" add PKGBUILD .SRCINFO
if git -C "$tmp/aur" rev-parse --verify -q HEAD >/dev/null; then
  if git -C "$tmp/aur" diff --cached --quiet; then
    echo "${pkgbase} is already at ${pkgver}"
    exit 0
  fi
  message="update to ${pkgver}"
else
  message="initial upload: ${pkgver}"
fi

git -C "$tmp/aur" -c user.name='aur-updater' -c user.email='aur-updater@localhost' \
  commit --quiet -m "$message"
git -C "$tmp/aur" push --quiet origin HEAD:master
echo "published ${pkgbase} ${pkgver} to the AUR"
