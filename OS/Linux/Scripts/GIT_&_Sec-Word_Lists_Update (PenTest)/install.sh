#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$ROOT_DIR/bin/update-wordlists.sh"

if [[ ! -f "$BIN_SRC" ]]; then
  echo "Не найден $BIN_SRC"
  exit 1
fi

echo "[+] Копирую скрипт в /usr/local/bin/update-wordlists"
sudo cp "$BIN_SRC" /usr/local/bin/update-wordlists
sudo chmod +x /usr/local/bin/update-wordlists

echo "[+] Создаю каталог отчётов: $HOME/Git_Update_Reports"
mkdir -p "$HOME/Git_Update_Reports"

echo "[i] Готово. Запуск: sudo update-wordlists --no-menu --dry-run"
