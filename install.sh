#!/bin/bash
# install.sh: Install omarchy-mango (either in user-space + system session or via PKGBUILD)

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

MODE="user"
INSTALL_DEPS=1
USE_LY=0
for arg in "$@"; do
  case "$arg" in
    --pkg) MODE="pkg" ;;
    --user) MODE="user" ;;
    --with-ly) USE_LY=1 ;;
    --no-deps) INSTALL_DEPS=0 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--user | --pkg] [--with-ly] [--no-deps]

Options:
  --user     Link scripts into ~/.local/bin, initialize ~/.config/mango and
             Omarchy theme templates, and optionally install the Wayland session
             desktop entry (default).
  --pkg      Build and install the Arch Linux package using makepkg -si.
  --with-ly  Also configure and enable 'ly' as the login display manager.
  --no-deps  Skip checking/installing mangowm and companion packages via pacman.
USAGE
      exit 0
      ;;
  esac
done

chmod +x "$REPO_ROOT/bin/"* "$REPO_ROOT/lib/bin/"*

if (( INSTALL_DEPS )); then
  DEPS=(mangowm wlsunset wlr-randr wlopm socat jq python)
  MISSING=()
  for dep in "${DEPS[@]}"; do
    pacman -Q "$dep" &>/dev/null || MISSING+=("$dep")
  done
  if (( ${#MISSING[@]} > 0 )); then
    echo ":: Installing missing dependencies: ${MISSING[*]}"
    if command -v omarchy-pkg-add >/dev/null 2>&1; then
      omarchy-pkg-add "${MISSING[@]}"
    else
      sudo pacman -S --needed "${MISSING[@]}"
    fi
  fi
fi

if [[ $MODE == "pkg" ]]; then
  echo ":: Building and installing omarchy-mango Arch package..."
  (cd "$REPO_ROOT" && makepkg -si --needed)
  omarchy-mango-init --ensure
  echo ":: Done! Select 'Omarchy (MangoWC)' at login or run 'omarchy-mango-session'."
  exit 0
fi

echo ":: Linking omarchy-mango binaries into ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
for bin_file in "$REPO_ROOT/bin/"*; do
  ln -snf "$bin_file" "$HOME/.local/bin/$(basename "$bin_file")"
done

echo ":: Initializing ~/.config/mango and Omarchy theme templates..."
"$REPO_ROOT/bin/omarchy-mango-init" --ensure

if (( USE_LY )); then
  "$REPO_ROOT/bin/omarchy-mango-dm" use-ly
elif [[ -d /usr/share/wayland-sessions ]] && [[ ! -f /usr/share/wayland-sessions/omarchy-mango.desktop ]]; then
  echo ":: Installing /usr/share/wayland-sessions/omarchy-mango.desktop (requires sudo)..."
  sudo install -Dm644 "$REPO_ROOT/share/wayland-sessions/omarchy-mango.desktop" \
    /usr/share/wayland-sessions/omarchy-mango.desktop || true
fi

echo ":: omarchy-mango setup complete!"
echo "   - Configs: ~/.config/mango/config.conf"
echo "   - Theme template: ~/.config/omarchy/themed/mango-theme.conf.tpl"
echo "   - Run 'omarchy-mango-session' or select 'Omarchy (MangoWC)' in your display manager."
