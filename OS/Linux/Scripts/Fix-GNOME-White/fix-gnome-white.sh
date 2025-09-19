#!/usr/bin/env bash
set -euo pipefail

DESKTOP_APPS=(
  org.gnome.Nautilus.desktop
  org.gnome.Settings.desktop
  org.gnome.Extensions.desktop
  org.gnome.DiskUtility.desktop
  org.gnome.SystemMonitor.desktop
  org.gnome.Terminal.desktop
)

WRAP_BINS=( nautilus gnome-control-center gnome-extensions-app )

DBUS_ID="org.gnome.Shell.Extensions"
DBUS_SYS="/usr/share/dbus-1/services/${DBUS_ID}.service"
DBUS_USR="$HOME/.local/share/dbus-1/services/${DBUS_ID}.service"

SRC_DIR="/usr/share/applications"
DST_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"
ENVVARS="LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo"

mkdir -p "$DST_DIR" "$BIN_DIR"

patch_desktop() {
  local base="$1"
  local src="$SRC_DIR/$base"
  local dst="$DST_DIR/$base"
  local bak="$dst.bak"
  [[ -f "$src" ]] || { echo "✗ .desktop not found: $base"; return 0; }
  cp -f "$src" "$dst"
  cp -f "$src" "$bak"
  sed -i -E "/^Exec=/ { /LIBGL_ALWAYS_SOFTWARE=1/! s|^Exec=|Exec=env $ENVVARS | }" "$dst"
  if grep -q '^DBusActivatable=' "$dst"; then
    sed -i 's/^DBusActivatable=.*/DBusActivatable=false/' "$dst"
  else
    echo 'DBusActivatable=false' >> "$dst"
  fi
  echo "✔ Patched .desktop: $base"
}

restore_desktop() {
  local base="$1"
  local dst="$DST_DIR/$base"
  local bak="$dst.bak"
  if [[ -f "$bak" ]]; then
    mv -f "$bak" "$dst"
    echo "↩ Restored .desktop: $base"
  else
    [[ -f "$dst" ]] && rm -f "$dst"
    echo "ℹ Removed local .desktop override: $base"
  fi
}

wrap_bin() {
  local bin="$1"
  local target="/usr/bin/$bin"
  local wrap="$BIN_DIR/$bin"
  [[ -x "$target" ]] || { echo "✗ Binary not found: $target"; return 0; }
  cat > "$wrap" <<WRAP
#!/bin/bash
export $ENVVARS
exec "$target" "\$@"
WRAP
  chmod +x "$wrap"
  echo "✔ Wrapped bin: $wrap -> $target"
}

unwrap_bin() {
  local bin="$1"
  local wrap="$BIN_DIR/$bin"
  [[ -f "$wrap" ]] && { rm -f "$wrap"; echo "↩ Removed wrapper: $wrap"; } || echo "ℹ No wrapper: $wrap"
}

patch_dbus() {
  [[ -f "$DBUS_SYS" ]] || { echo "✗ No D-Bus service: $DBUS_SYS"; return 0; }
  mkdir -p "$(dirname "$DBUS_USR")"
  cp -f "$DBUS_SYS" "$DBUS_USR"
  local CMD
  CMD="$(sed -n 's/^Exec=//p' "$DBUS_SYS")"
  sed -i "s|^Exec=.*|Exec=/bin/sh -c 'export $ENVVARS; exec ${CMD} \"\\\$@\"'|" "$DBUS_USR"
  systemctl --user daemon-reload || true
  echo "✔ Patched D-Bus service: $DBUS_USR"
}

restore_dbus() {
  [[ -f "$DBUS_USR" ]] && { rm -f "$DBUS_USR"; systemctl --user daemon-reload || true; echo "↩ Removed D-Bus override"; } || echo "ℹ No D-Bus override"
}

update_caches() {
  update-desktop-database "$DST_DIR" >/dev/null 2>&1 || true
  hash -r || true
}

case "${1:-}" in
  --restore)
    for f in "${DESKTOP_APPS[@]}"; do restore_desktop "$f"; done
    for b in "${WRAP_BINS[@]}"; do unwrap_bin "$b"; done
    restore_dbus
    update_caches
    echo "↩ Restore complete. Re-login recommended."
    ;;
  "")
    for f in "${DESKTOP_APPS[@]}"; do patch_desktop "$f"; done
    for b in "${WRAP_BINS[@]}"; do wrap_bin "$b"; done
    patch_dbus
    update_caches
    echo "✅ Patch complete. Re-login or (Xorg) Alt+F2 → r."
    ;;
  *) echo "Usage: $0 [--restore]"; exit 1 ;;
esac