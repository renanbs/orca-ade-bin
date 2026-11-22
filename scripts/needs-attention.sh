#!/usr/bin/env bash
# Exit 0 when the package needs a human/agent look: upstream moved past pkgver,
# the AUR is out of sync with the repository, or the last workflow run failed.
# Exit 1 when everything is in order. Used as the Orca automation precheck.
set -euo pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

current=$(sed -n 's/^pkgver=//p' PKGBUILD)
[[ -n $current ]] || { echo 'PKGBUILD has no pkgver'; exit 0; }

latest=$(gh api repos/stablyai/orca/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//')
if [[ -z $latest ]]; then
  echo 'could not read the upstream release'
  exit 0
fi
if [[ $latest != "$current" ]]; then
  echo "upstream ${latest} != pkgver ${current}"
  exit 0
fi

aur=$(curl -fsS 'https://aur.archlinux.org/rpc/v5/info?arg[]=orca-ade-bin' 2>/dev/null |
  jq -r '.results[0].Version // empty')
if [[ -n $aur && ${aur%-*} != "$current" ]]; then
  echo "AUR ${aur} != pkgver ${current}"
  exit 0
fi

last=$(gh run list -R renanbs/orca-ade-bin --limit 1 --json conclusion,displayTitle \
  --jq '.[0] | "\(.conclusion)"' 2>/dev/null || true)
if [[ $last == failure ]]; then
  echo 'last workflow run failed'
  exit 0
fi

exit 1
