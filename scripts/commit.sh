#!/usr/bin/env bash
# Commit the regenerated package files and push them back to this repository.
set -euo pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
version=${1:?usage: commit.sh <version>}

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add PKGBUILD .SRCINFO
git commit -m "update to ${version} [skip ci]"
git push
