# orca-ade-bin

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
cd orca-ade-bin
makepkg -si
```

Or, once published:

```sh
yay -S orca-ade-bin
```

## Automated updates

`.github/workflows/update.yml` runs hourly and:

1. asks the GitHub API for the newest stable release of `stablyai/orca`;
2. on a new `vX.Y.Z`, reads the electron-builder manifests (`latest-linux.yml`,
   `latest-linux-arm64.yml`) for the sha512 of both `.deb` assets, cross-checks
   their sizes against the release API, and downloads only the license before
   rewriting `pkgver`, resetting `pkgrel` and refreshing every checksum
   (`scripts/bump.sh`);
3. builds with `makepkg` and proves the result by installing it and checking
   `orca-ide --version` against `pkgver` (`scripts/build.sh`);
4. pushes to the AUR when `AUR_SSH_PRIVATE_KEY` exists (`scripts/publish-aur.sh`);
5. commits `PKGBUILD` + `.SRCINFO` here.

The AUR push runs before the commit on purpose: if it fails, this repository
stays on the old version and the next hourly run retries. Both steps are
idempotent, so a failed commit after a successful AUR push only repeats the push
(which reports the version is already there) and commits.

Nothing is committed or published when any step fails, so a restructured
upstream asset or a moved CLI shim stops the pipeline instead of shipping a
broken package.

Hourly is deliberate: upstream publishes several releases per day, so a daily
run would sit behind most of the time. A run without a new version downloads
nothing; on a real bump only the source of the architecture being built is
fetched, by `makepkg` itself.

### AUR publishing

Add an SSH key whose AUR account owns the package base as the repository secret
`AUR_SSH_PRIVATE_KEY`. Without it the workflow still commits to this repository and
skips the AUR push.

Since 2026-11 the AUR takes submissions over git: the first push to a package
name creates the base, so no web form is involved. The script proves the key is
accepted, then either creates the base or commits on top of its history.

Every push run also probes the secret with `scripts/check-aur.sh`, non-fatally,
so a rotated or revoked key shows up as an annotation long before the next
release needs it.

The base is `orca-ade-bin` because upstream's `orca-ide` name collides with GNOME
Orca and the existing `orca-ide-bin` base belongs to another maintainer.
`provides=orca-ide` plus the `conflicts` list keep every Orca repackaging in the
AUR mutually exclusive.

## License

This repository's packaging files are licensed under 0BSD (see `LICENSE`). The
packaged software is MIT, see `/usr/share/licenses/orca-ade-bin/LICENSE`.

## Limitations

CI builds `x86_64` only. The `aarch64` source, checksum and `.SRCINFO` are
maintained but not built by the workflow.
