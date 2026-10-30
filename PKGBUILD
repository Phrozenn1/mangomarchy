# Maintainer: Kim <kim@omarchy.local>
pkgname=mangomarchy
pkgver=0.1.0
pkgrel=1
pkgdesc="Omarchy desktop session and Quickshell/IPC integration for MangoWC (mangomarchy)"
arch=('any')
url="https://github.com/mangowm/mango"
license=('MIT')
provides=('omarchy-mango')
conflicts=('omarchy-mango')
replaces=('omarchy-mango')
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
  install -Dm755 "$src_root/bin/mangomarchy-session" "$pkgdir/usr/bin/mangomarchy-session"
  install -Dm755 "$src_root/bin/mangomarchy-bridge" "$pkgdir/usr/bin/mangomarchy-bridge"
  install -Dm755 "$src_root/bin/mangomarchy-init" "$pkgdir/usr/bin/mangomarchy-init"
  install -Dm755 "$src_root/bin/mangomarchy-dm" "$pkgdir/usr/bin/mangomarchy-dm"

  # Backward compatibility symlinks in /usr/bin
  ln -snf mangomarchy-session "$pkgdir/usr/bin/omarchy-mango-session"
  ln -snf mangomarchy-bridge "$pkgdir/usr/bin/omarchy-mango-bridge"
  ln -snf mangomarchy-init "$pkgdir/usr/bin/omarchy-mango-init"
  ln -snf mangomarchy-dm "$pkgdir/usr/bin/omarchy-mango-dm"

  # Session-scoped compatibility shims (placed on PATH only inside MangoWC session)
  install -Dm755 "$src_root/lib/bin/hyprctl" "$pkgdir/usr/lib/mangomarchy/bin/hyprctl"
  install -Dm755 "$src_root/lib/bin/hyprsunset" "$pkgdir/usr/lib/mangomarchy/bin/hyprsunset"

  # Wayland session entry for SDDM / display managers / uwsm
  install -Dm644 "$src_root/share/wayland-sessions/mangomarchy.desktop" \
    "$pkgdir/usr/share/wayland-sessions/mangomarchy.desktop"

  # Default & template configs
  install -dm755 "$pkgdir/usr/share/mangomarchy"
  cp -r "$src_root/share/config" "$pkgdir/usr/share/mangomarchy/"
  cp -r "$src_root/share/default" "$pkgdir/usr/share/mangomarchy/"
  cp -r "$src_root/share/themed" "$pkgdir/usr/share/mangomarchy/"
  cp -r "$src_root/share/ly" "$pkgdir/usr/share/mangomarchy/"
}
