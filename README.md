# orca-ide-bin

Arch Linux package for [Orca](https://onorca.dev/), repackaged from the upstream
Debian build.

The `.deb` already ships a complete Electron runtime under `/opt/Orca`, so the
package does not depend on `extra/electronNN`: native modules, Node ABI and the
CLI launcher always match the release they came from. `chrome-sandbox` is setuid
as upstream's `postinst` does, and `/usr/bin/orca-ide` is the upstream CLI shim.

Dependencies mirror the Debian `Depends` field; `xorg-server-xvfb`, `xdotool`,
`xclip` and `python-gobject` are what Orca uses to drive GUIs for agents.

## Install

```sh
git clone <this repo>
cd orca-ide-bin
makepkg -si
```

Or, once published:

```sh
yay -S orca-ide-bin
```

## Automated updates

`.github/workflows/update.yml` runs hourly and:

1. asks the GitHub API for the newest stable release of `stablyai/orca`;
2. on a new `vX.Y.Z`, downloads both `.deb` assets and the license, then
   rewrites `pkgver`, resets `pkgrel` and refreshes every checksum
   (`scripts/bump.sh`);
3. builds with `makepkg` and proves the result by installing it and checking
   `orca-ide --version` against `pkgver` (`scripts/build.sh`);
4. commits `PKGBUILD` + `.SRCINFO`;
5. pushes to the AUR when `AUR_SSH_KEY` exists (`scripts/publish-aur.sh`).

Nothing is committed or published when any step fails, so a restructured
upstream asset or a moved CLI shim stops the pipeline instead of shipping a
broken package.

Hourly is deliberate: upstream publishes several releases per day, so a daily
run would sit behind most of the time. A run without a new version only makes
one API call; the ~210 MB asset download happens only on a real bump.

### AUR publishing

Add an SSH key whose AUR account owns the package base as the repository secret
`AUR_SSH_KEY`. Without it the workflow still commits to this repository and
skips the AUR push.

The AUR package base `orca-ide-bin` already belongs to another maintainer. To
publish under your own name, rename `pkgname` in `PKGBUILD` (and regenerate
`.SRCINFO`) to a free base such as `orca-ade-bin`; `provides`/`conflicts` keep it
mutually exclusive with the other Orca packages.

## Limitations

CI builds `x86_64` only. The `aarch64` source, checksum and `.SRCINFO` are
maintained but not built by the workflow.
