#!/usr/bin/env bash
set -euo pipefail
SCRIPT_NAME="Purple_GIT_&_Sec-Word_Lists_Update.sh"
TARGET="${1:-/usr/local/bin}"
echo "[+] Installing $SCRIPT_NAME to $TARGET (sudo may be required)"
sudo install -m 0755 "$SCRIPT_NAME" "$TARGET/$SCRIPT_NAME"
echo "[✓] Installed: $TARGET/$SCRIPT_NAME"
echo "Tip: add an alias, e.g., alias pgwu='sudo $TARGET/$SCRIPT_NAME'"
