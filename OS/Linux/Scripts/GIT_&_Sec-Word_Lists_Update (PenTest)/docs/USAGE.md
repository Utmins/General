# USAGE

## Запуск
```bash
sudo ./bin/update-wordlists.sh           # меню
sudo ./bin/update-wordlists.sh --no-menu # без меню
```

## Ключи
См. полный список в README.md (раздел «Ключи командной строки»).

## Примеры
- Только dry-run и без системного сканирования:
```bash
./bin/update-wordlists.sh --dry-run --no-system --no-menu
```

- Установка через APT и assetnote-словарей:
```bash
sudo ./bin/update-wordlists.sh --no-menu --apt-bootstrap --include-assetnote
```
