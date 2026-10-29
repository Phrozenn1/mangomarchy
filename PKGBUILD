# Maintainer: Kim <kim@omarchy.local>
pkgname=omarchy-mango
pkgver=0.1.0
pkgrel=1
pkgdesc="Omarchy desktop session and Quickshell/IPC integration for MangoWC (mangowm)"
arch=('any')
url="https://github.com/mangowm/mango"
license=('MIT')
depends=(
  'mangowm'
  'ly'
  'wlsunset'
  'wlr-randr'
  'wlopm'
  'python'
  'jq'
  'socat'
)
source=()
sha256sums=()

package() {
  local src_root="${startdir}"

  # Executables
  install -Dm755 "$src_root/bin/omarchy-mango-session" "$pkgdir/usr/bin/omarchy-mango-session"
  install -Dm755 "$src_root/bin/omarchy-mango-bridge" "$pkgdir/usr/bin/omarchy-mango-bridge"
  install -Dm755 "$src_root/bin/omarchy-mango-init" "$pkgdir/usr/bin/omarchy-mango-init"
  install -Dm755 "$src_root/bin/omarchy-mango-dm" "$pkgdir/usr/bin/omarchy-mango-dm"

  # Session-scoped compatibility shims (placed on PATH only inside MangoWC session)
  install -Dm755 "$src_root/lib/bin/hyprctl" "$pkgdir/usr/lib/omarchy-mango/bin/hyprctl"
  install -Dm755 "$src_root/lib/bin/hyprsunset" "$pkgdir/usr/lib/omarchy-mango/bin/hyprsunset"

  # Wayland session entry for SDDM / display managers / uwsm
  install -Dm644 "$src_root/share/wayland-sessions/omarchy-mango.desktop" \
    "$pkgdir/usr/share/wayland-sessions/omarchy-mango.desktop"

  # Default & template configs
  install -dm755 "$pkgdir/usr/share/omarchy-mango"
  cp -r "$src_root/share/config" "$pkgdir/usr/share/omarchy-mango/"
  cp -r "$src_root/share/default" "$pkgdir/usr/share/omarchy-mango/"
  cp -r "$src_root/share/themed" "$pkgdir/usr/share/omarchy-mango/"
  cp -r "$src_root/share/ly" "$pkgdir/usr/share/omarchy-mango/"
}
