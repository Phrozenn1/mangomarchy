#!/bin/bash
# install.sh: Install mangomarchy (either in user-space + system session or via PKGBUILD)

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
  echo ":: Building and installing mangomarchy Arch package..."
  (cd "$REPO_ROOT" && makepkg -si --needed)
  mangomarchy-init --ensure
  echo ":: Done! Select 'Mangomarchy' at login or run 'mangomarchy-session'."
  exit 0
fi

echo ":: Linking mangomarchy binaries into ~/.local/bin..."
mkdir -p "$HOME/.local/bin"

# Remove legacy omarchy-mango symlinks from ~/.local/bin
rm -f "$HOME/.local/bin/omarchy-mango-bridge" \
      "$HOME/.local/bin/omarchy-mango-dm" \
      "$HOME/.local/bin/omarchy-mango-init" \
      "$HOME/.local/bin/omarchy-mango-session"

for bin_file in "$REPO_ROOT/bin/"*; do
  name=$(basename "$bin_file")
  ln -snf "$bin_file" "$HOME/.local/bin/$name"
  # Also maintain backward compatibility links
  legacy_name="${name/mangomarchy/omarchy-mango}"
  if [[ "$legacy_name" != "$name" ]]; then
    ln -snf "$bin_file" "$HOME/.local/bin/$legacy_name"
  fi
done

echo ":: Initializing ~/.config/mango and Omarchy theme templates..."
"$REPO_ROOT/bin/mangomarchy-init" --ensure

# Install user-space Wayland session entry
mkdir -p "$HOME/.local/share/wayland-sessions"
install -Dm644 "$REPO_ROOT/share/wayland-sessions/mangomarchy.desktop" "$HOME/.local/share/wayland-sessions/mangomarchy.desktop"
rm -f "$HOME/.local/share/wayland-sessions/omarchy-mango.desktop"

if (( USE_LY )); then
  "$REPO_ROOT/bin/mangomarchy-dm" use-ly
elif (( EUID == 0 )) && [[ -d /usr/share/wayland-sessions ]]; then
  install -Dm644 "$REPO_ROOT/share/wayland-sessions/mangomarchy.desktop" /usr/share/wayland-sessions/mangomarchy.desktop
  rm -f /usr/share/wayland-sessions/omarchy-mango.desktop
fi

echo ":: mangomarchy setup complete!"
echo "   - Configs: ~/.config/mango/config.conf"
echo "   - Theme template: ~/.config/omarchy/themed/mango-theme.conf.tpl"
echo "   - Run 'mangomarchy-session' or select 'Mangomarchy' in your display manager."
