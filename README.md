# `omarchy-mango` — Omarchy for MangoWC (`mangowm`)

`omarchy-mango` brings the **MangoWC** (`extra/mangowm`) Wayland compositor to [Omarchy](https://omarchy.org/) as a non-invasive, first-class session alongside Hyprland—preserving Omarchy's Quickshell desktop (`omarchy-shell`), dynamic theme engine (`omarchy theme set`), screenshots/recordings (`omasnap` & `omarchy-capture-*`), and keybindings without modifying any files in `/usr/share/omarchy/`.

## How It Works

1. **`omarchy-mango-bridge` (MangoWC $\leftrightarrow$ Hyprland IPC Bridge):**
   - `Quickshell.Hyprland` (used by `omarchy-shell` for bar workspaces, monitor geometry, overlay scaling, and notifications) communicates via `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock` and `.socket2.sock`.
   - `omarchy-mango-bridge` translates MangoWC's `mmsg` JSON queries (`get all-monitors`, `get all-clients`, `get all-tags`, `get keyboardlayout`) and real-time event streams (`watch ...`) into Hyprland's exact socket protocol, and maps Omarchy's workspace dispatches back to `mmsg` commands.
2. **Session-Scoped `hyprctl` & `hyprsunset` Shims (`lib/bin/`):**
   - Placed on `PATH` only inside the MangoWC session (and delegating to `/usr/bin/hyprctl` if called in Hyprland), allowing `omasnap`, `omarchy-capture-region`, `omarchy-launch-or-focus`, `omarchy-hyprland-workspace-layout-toggle`, and Nightlight (`wlsunset`) to work seamlessly.
3. **Live Theme Synchronization (`mango-theme.conf.tpl`):**
   - Installed into `~/.config/omarchy/themed/mango-theme.conf.tpl` with a `theme-set` hook (`~/.config/omarchy/hooks/theme-set.d/50-mango-reload.sh`), so `omarchy theme set <theme>` updates MangoWC border colors and reloads `mango` on the fly.

## Quick Start

### Option 1: User-Space + Session Install (Recommended for Development)
```bash
./install.sh
```

### Option 2: Arch Linux Package (`PKGBUILD`)
```bash
./install.sh --pkg
# or: makepkg -si && omarchy-mango-init
```

### Switching the Login Display Manager to `ly`
Omarchy's default SDDM configuration auto-logs into Hyprland (`omarchy.desktop`). To switch to the minimalist **Ly** TUI display manager so you can choose between **Omarchy (MangoWC)** and **Omarchy (Hyprland uwsm)** at login:
```bash
omarchy-mango-dm use-ly
```
To check status or switch back to SDDM at any time:
```bash
omarchy-mango-dm status
omarchy-mango-dm use-sddm
```

## Customization

Your user configurations live in `~/.config/mango/`:
- `~/.config/mango/config.conf` — Root config entry point
- `~/.config/mango/monitors.conf` — Monitor rules (`monitorrule=...`)
- `~/.config/mango/input.conf` — Keyboard repeat rate, trackpad settings
- `~/.config/mango/looknfeel.conf` — Gaps, borders, corner radius, blur, animations
- `~/.config/mango/bindings.conf` — Custom keybindings (`bind=MOD,key,action,arg`)

Validate your configuration at any time with:
```bash
mango -c ~/.config/mango/config.conf -p
```
