# INSTALL

## Требования
- Linux, bash (>=4), git, sudo
- Для `--apt-bootstrap` — Debian/Ubuntu (`apt-get`)

## Быстрый старт (локально)
```bash
chmod +x bin/update-wordlists.sh
sudo ./bin/update-wordlists.sh --no-menu --dry-run
```

## Установка в систему (опционально)
```bash
sudo ./install.sh
sudo update-wordlists --no-menu --dry-run
```

## Удаление
```bash
sudo ./uninstall.sh
```

## Примечания
- По умолчанию словари и ссылки размещаются под `/usr/share/wordlists`.
- Логи и отчёты — в `~/Git_Update_Reports/`.
