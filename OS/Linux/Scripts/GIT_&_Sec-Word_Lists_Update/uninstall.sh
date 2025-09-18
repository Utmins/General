#!/usr/bin/env bash
set -euo pipefail

read -r -p "[?] Удалить /usr/local/bin/update-wordlists (Y/n)? " ans
ans=${ans:-Y}
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo rm -f /usr/local/bin/update-wordlists
  echo "[+] Удалено."
else
  echo "[i] Пропущено."
fi

echo "[i] Каталог с отчётами $HOME/Git_Update_Reports не трогаем."
