#!/usr/bin/env bash
# Build the package, install it and prove the CLI runs before anything is
# published. Runs as an unprivileged user; sudo must be passwordless.
set -euo pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

pkgver=$(sed -n 's/^pkgver=//p' PKGBUILD)

makepkg --nocolor --noconfirm --syncdeps --cleanbuild --clean
pkg=$(makepkg --packagelist)
[[ -f $pkg ]] || { echo "error: $pkg was not built" >&2; exit 1; }

sudo pacman --noconfirm -U "$pkg"

# The upstream shim hands off to $ORCA_CLI_COMMAND when a session sets it, which
# would report the version of whatever Orca is already installed.
ver=$(env -u ORCA_CLI_COMMAND -u ORCA_CLI_HANDOFF orca-ide --version)
[[ $ver == "$pkgver" ]] ||
  { printf 'error: orca-ide --version printed %s, expected %s\n' "$ver" "$pkgver" >&2; exit 1; }
printf 'verified orca-ide %s\n' "$ver"
