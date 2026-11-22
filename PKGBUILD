# Maintainer: Renan BS <renan.biegel@gmail.com>
pkgname=orca-ade-bin
pkgver=1.4.269
pkgrel=1
pkgdesc='Next-gen IDE for parallel agentic development'
arch=('x86_64' 'aarch64')
url='https://onorca.dev/'
license=('MIT')
depends=(
  'alsa-lib' 'at-spi2-core' 'cairo' 'dbus' 'expat' 'gcc-libs' 'glib2'
  'glibc' 'gtk3' 'hicolor-icon-theme' 'libcups' 'libnotify' 'libsecret'
  'libx11' 'libxcb' 'libxcomposite' 'libxdamage' 'libxext' 'libxfixes'
  'libxkbcommon' 'libxrandr' 'libxss' 'libxtst' 'mesa' 'nspr' 'nss' 'pango'
  'python' 'python-gobject' 'systemd-libs' 'util-linux-libs' 'xclip'
  'xdg-utils' 'xdotool' 'xorg-server-xvfb'
)
optdepends=(
  'libappindicator-gtk3: system tray indicator'
  'vulkan-icd-loader: Vulkan backend for GPU-backed features'
)
makedepends=('libarchive')
provides=("orca-ide=${pkgver}")
conflicts=('orca-ide' 'orca-ide-bin' 'onorca-bin' 'stably-orca' 'stably-orca-bin' 'stably-orca-git')
options=('!strip' '!debug')

# Upstream ships a self-contained Electron runtime in /opt/Orca, so the package
# never depends on an extra/electronNN version and native modules always match.
_upstream='https://github.com/stablyai/orca'
_debrel="${_upstream}/releases/download/v${pkgver}"
source=("LICENSE-${pkgver}::https://raw.githubusercontent.com/stablyai/orca/v${pkgver}/LICENSE")
source_x86_64=("${_debrel}/orca-ide_${pkgver}_amd64.deb")
source_aarch64=("${_debrel}/orca-ide_${pkgver}_arm64.deb")
sha256sums=('ff1b611f80580d49f4b97e93a97b24eb050b0671b26b8afe16341fab699112f3')
sha256sums_x86_64=('c3ed00c4320ce6186a0d601923df47945a130a6691774a54333f08ecfa9e51a6')
sha256sums_aarch64=('3675a822c4e2b47c8cf460d6bae633b6c893714399f6561689ef84f7d28827d4')

_debname() {
  case $CARCH in
    x86_64)  echo "orca-ide_${pkgver}_amd64.deb" ;;
    aarch64) echo "orca-ide_${pkgver}_arm64.deb" ;;
    *) return 1 ;;
  esac
}

prepare() {
  # The .deb is an ar archive; unpack only the payload, not Debian metadata.
  bsdtar --no-same-owner -xf "$(_debname)" data.tar.xz
}

check() {
  local list entry
  list=$(bsdtar -tf data.tar.xz)
  for entry in \
    ./opt/Orca/orca-ide \
    ./opt/Orca/chrome-sandbox \
    ./opt/Orca/resources/app.asar \
    ./opt/Orca/resources/bin/orca-ide \
    ./usr/share/applications/orca-ide.desktop \
    ./usr/share/icons/hicolor/512x512/apps/orca-ide.png
  do
    grep -qxF -- "$entry" <<<"$list" || {
      echo "upstream layout changed: ${entry} is gone" >&2
      return 1
    }
  done
  # The launcher must use the bundled runtime, not a system Electron.
  bsdtar -xOf data.tar.xz ./usr/share/applications/orca-ide.desktop |
    grep -qF 'Exec=/opt/Orca/orca-ide'
}

package() {
  bsdtar --no-same-owner -xf data.tar.xz -C "$pkgdir"

  # Upstream postinst: the CLI shim resolves the app from its own path, so the
  # symlink is all it needs; chrome-sandbox stays setuid for hosts without
  # unprivileged user namespaces.
  chmod 4755 "$pkgdir/opt/Orca/chrome-sandbox"
  install -d "$pkgdir/usr/bin"
  ln -s /opt/Orca/resources/bin/orca-ide "$pkgdir/usr/bin/orca-ide"

  install -Dm644 "LICENSE-${pkgver}" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  # Debian changelog; upstream's release notes live on GitHub.
  rm -rf "$pkgdir/usr/share/doc"
}
