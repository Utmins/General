#!/usr/bin/env bash
set -euo pipefail
chmod +x bin/update-wordlists.sh
# Пробный запуск: должен завершиться 0 и напечатать конфиг/меню или действия
./bin/update-wordlists.sh --dry-run --no-system --no-menu
echo "SMOKE OK"
