#!/bin/bash
# uninstall.sh: Cleanly uninstall Mangomarchy (and legacy omarchy-mango) from the system.

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

PURGE_CONFIG=0
KEEP_CONFIG=0
RESTORE_SDDM=0
ASSUME_YES=0
USER_ONLY=0

usage() {
  cat <<USAGE
Usage: ./uninstall.sh [OPTIONS]

Cleanly uninstall Mangomarchy and legacy omarchy-mango components.

Options:
  --keep-config   Preserve ~/.config/mango/ user configuration (default).
  --purge         Also remove ~/.config/mango/ user configuration directory.
  --with-sddm     Restore SDDM and disable Ly display manager if currently enabled.
  --user-only     Only remove user-space symlinks and hooks (skip sudo system files).
  -y, --yes       Do not prompt for confirmation.
  -h, --help      Show this help message.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE_CONFIG=1; KEEP_CONFIG=0 ;;
    --keep-config) KEEP_CONFIG=1; PURGE_CONFIG=0 ;;
    --with-sddm) RESTORE_SDDM=1 ;;
    --user-only) USER_ONLY=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

confirm() {
  local prompt="$1"
  local default="${2:-N}"
  if (( ASSUME_YES )); then
    return 0
  fi
  read -r -p "$prompt " answer || return 1
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

run_priv() {
  if (( EUID == 0 )); then
    "$@"
  elif [[ -t 0 ]]; then
    sudo "$@"
  elif [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]] && command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    echo "Privileged execution requires interactive terminal or root: $*" >&2
    return 1
  fi
}

echo "=== Mangomarchy Uninstaller ==="

# 1. Stop any running bridge instances
if pgrep -f mangomarchy-bridge >/dev/null 2>&1 || pgrep -f omarchy-mango-bridge >/dev/null 2>&1; then
  echo ":: Stopping running bridge processes..."
  pkill -f mangomarchy-bridge 2>/dev/null || true
  pkill -f omarchy-mango-bridge 2>/dev/null || true
fi

# 2. Check Display Manager status (Ly vs SDDM)
LY_ACTIVE=0
for unit in ly@tty1.service ly@tty2.service ly.service; do
  if systemctl is-enabled "$unit" &>/dev/null; then
    LY_ACTIVE=1
    break
  fi
done

if (( LY_ACTIVE )) && (( ! USER_ONLY )); then
  if (( RESTORE_SDDM )) || confirm ":: Ly is currently enabled as your display manager. Restore SDDM? [Y/n]" "Y"; then
    echo ":: Reverting display manager to SDDM..."
    DM_SCRIPT=$(mktemp /tmp/mangomarchy-dm-revert.XXXXXX.sh)
    cat >"$DM_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail
systemctl disable ly@tty1.service 2>/dev/null || true
systemctl disable ly@tty2.service 2>/dev/null || true
systemctl disable ly.service 2>/dev/null || true
rm -rf /etc/systemd/system/ly@tty1.service.d /etc/systemd/system/ly@tty2.service.d
systemctl enable getty@tty1.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true
systemctl daemon-reload
EOF
    chmod +x "$DM_SCRIPT"
    run_priv "$DM_SCRIPT"
    rm -f "$DM_SCRIPT"
    echo "   SDDM re-enabled."
  fi
fi

# 3. Remove user-space binaries and symlinks (~/.local/bin)
echo ":: Removing user-space binaries from ~/.local/bin..."
for bin_name in \
  mangomarchy-session mangomarchy-bridge mangomarchy-init mangomarchy-dm \
  omarchy-mango-session omarchy-mango-bridge omarchy-mango-init omarchy-mango-dm; do
  target="$HOME/.local/bin/$bin_name"
  if [[ -L "$target" || -f "$target" ]]; then
    rm -f "$target"
    echo "   Removed $target"
  fi
done

# 4. Remove user-space share and state links
echo ":: Removing share and state links..."
for dir_link in \
  "$HOME/.local/share/mangomarchy" \
  "$HOME/.local/share/omarchy-mango" \
  "$HOME/.local/state/omarchy/mangomarchy-lib-bin" \
  "$HOME/.local/state/omarchy/mango-lib-bin"; do
  if [[ -L "$dir_link" || -e "$dir_link" ]]; then
    rm -rf "$dir_link"
    echo "   Removed $dir_link"
  fi
done

# 5. Remove Omarchy theme engine integration & hooks
echo ":: Removing Omarchy theme integration..."
rm -f "$HOME/.config/omarchy/themed/mango-theme.conf.tpl"
rm -f "$HOME/.local/state/omarchy/current/theme/mango-theme.conf"
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/50-mangomarchy-reload.sh"
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/50-mango-reload.sh"
echo "   Removed theme templates and hooks."

# 6. Check and remove Arch packages if installed
if pacman -Q mangomarchy &>/dev/null; then
  if confirm ":: Pacman package 'mangomarchy' is installed. Remove with pacman -R? [Y/n]" "Y"; then
    run_priv pacman -R --noconfirm mangomarchy
  fi
elif pacman -Q omarchy-mango &>/dev/null; then
  if confirm ":: Pacman package 'omarchy-mango' is installed. Remove with pacman -R? [Y/n]" "Y"; then
    run_priv pacman -R --noconfirm omarchy-mango
  fi
fi

# 7. Remove system session files and system-wide binaries if present
if (( ! USER_ONLY )); then
  SYSTEM_FILES=(
    "/usr/share/wayland-sessions/mangomarchy.desktop"
    "/usr/share/wayland-sessions/omarchy-mango.desktop"
    "/usr/bin/mangomarchy-session"
    "/usr/bin/mangomarchy-bridge"
    "/usr/bin/mangomarchy-init"
    "/usr/bin/mangomarchy-dm"
    "/usr/bin/omarchy-mango-session"
    "/usr/bin/omarchy-mango-bridge"
    "/usr/bin/omarchy-mango-init"
    "/usr/bin/omarchy-mango-dm"
    "/usr/share/mangomarchy"
    "/usr/share/omarchy-mango"
    "/usr/lib/mangomarchy"
    "/usr/lib/omarchy-mango"
  )

  FOUND_SYSTEM=()
  for item in "${SYSTEM_FILES[@]}"; do
    [[ -e "$item" ]] && FOUND_SYSTEM+=("$item")
  done

  if (( ${#FOUND_SYSTEM[@]} > 0 )); then
    echo ":: Found system-level files/directories: ${FOUND_SYSTEM[*]}"
    if confirm ":: Remove system-level files (requires sudo)? [Y/n]" "Y"; then
      SYS_SCRIPT=$(mktemp /tmp/mangomarchy-sys-clean.XXXXXX.sh)
      cat >"$SYS_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail
rm -f /usr/share/wayland-sessions/mangomarchy.desktop \
      /usr/share/wayland-sessions/omarchy-mango.desktop \
      /usr/bin/mangomarchy-* \
      /usr/bin/omarchy-mango-*
rm -rf /usr/share/mangomarchy /usr/share/omarchy-mango \
       /usr/lib/mangomarchy /usr/lib/omarchy-mango
EOF
      chmod +x "$SYS_SCRIPT"
      run_priv "$SYS_SCRIPT"
      rm -f "$SYS_SCRIPT"
      echo "   System-level files removed."
    fi
  fi
fi

# 8. Handle ~/.config/mango/
if [[ -d "$HOME/.config/mango" ]]; then
  if (( PURGE_CONFIG )); then
    echo ":: Purging ~/.config/mango/..."
    rm -rf "$HOME/.config/mango"
    echo "   ~/.config/mango removed."
  elif (( ! KEEP_CONFIG )); then
    if confirm ":: Do you want to remove your user configuration in ~/.config/mango/? [y/N]" "N"; then
      rm -rf "$HOME/.config/mango"
      echo "   ~/.config/mango removed."
    else
      echo "   Preserved ~/.config/mango/"
    fi
  else
    echo "   Preserved ~/.config/mango/"
  fi
fi

echo ":: Mangomarchy uninstallation complete."
