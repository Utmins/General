# Update Wordlists — Pentest Edition

Автоматизированный bash-скрипт для обновления, клонирования и управления словарями (wordlists) и payload-наборами,
используемыми при пентесте (web/content discovery, brute-force, SQLi/XSS/SSTI и т.д.).

---

## 🚀 Возможности
- Обновление всех локальных Git-репозиториев (git pull).
- Клонирование и обновление популярных wordlist-репозиториев: SecLists, PayloadsAllTheThings, FuzzDB, payloadbox-наборы, Probable-Wordlists, DirBuster и опционально Assetnote.
- Автоматическая распаковка архивов (.tar.gz, .gz).
- Создание единого каталога со ссылками на все словари (`/usr/share/wordlists/_all-links`).
- Дедупликация дубликатов между APT и Git (APT предпочитается).
- APT bootstrap (установка core-пакетов: seclists, dirb, wfuzz, gobuster, nikto и др.).
- Ведение логов и отчётов в `~/Git_Update_Reports/`.

---

## ⚙️ Установка
```bash
git clone <your-repo-url>
cd <your-repo>
chmod +x bin/update-wordlists.sh
```

Опционально установка в систему:
```bash
sudo ./install.sh
```

Удаление:
```bash
sudo ./uninstall.sh
```

---

## 📖 Использование
Запуск с меню:
```bash
sudo ./bin/update-wordlists.sh
```

Запуск без меню:
```bash
sudo ./bin/update-wordlists.sh --no-menu --dry-run
```

---

## 🔑 Ключи командной строки

### Основные
- `--no-menu` — пропустить меню, сразу запуск.
- `--dry-run` — показать команды, не выполнять.
- `--no-system` — не сканировать всю систему, только стандартные каталоги.
- `--all-mounts` — разрешить пересечение файловых систем (по умолчанию выключено).

### Линковка словарей
- `--link-all` / `--no-link-all` — включить/отключить создание `_all-links`.
- `--links-only-txt` — включить только текстовые файлы (.txt, .lst, .dic, .json).
- `--links-include-archives` — включить архивы (.gz, .zip, .tar.gz).
- `--links-dedup` / `--no-links-dedup` — включить/выключить дедупликацию имён.

### Дедупликация
- `--dedup-prefer-apt` / `--no-dedup-prefer-apt` — при дубликатах предпочитать apt.
- `--apply` / `--no-apply` — применять удаление Git-дубликатов или только писать отчёт.

### Архивация и безопасность
- `--autoclean-matryoshka` / `--no-autoclean-matryoshka` — удалять пустые каталоги, содержащие только архивы.
- `--skip-zip-bombs` — пропускать zip-бомбы из SecLists.

### Дополнительно
- `--apt-bootstrap` — установка core-пакетов через apt-get.
- `--include-assetnote` / `--no-include-assetnote` — включить/выключить assetnote wordlists.

### Помощь
- `-h` или `--help` — показать начало файла (с описанием).

---

## 📂 Каталоги
- **/usr/share/wordlists/_3rdparty** — сюда клонируются сторонние репозитории.
- **/usr/share/wordlists/_all-links** — единый каталог ссылок на все найденные словари.
- **~/Git_Update_Reports/** — логи и отчёты (`run_YYYY-MM-DD_HH-MM-SS.txt`, отчёты дедупликации).

---

## 📝 Примеры

Dry-run без сканирования всей системы:
```bash
./bin/update-wordlists.sh --dry-run --no-system
```

Полный запуск с APT bootstrap и assetnote:
```bash
sudo ./bin/update-wordlists.sh --apt-bootstrap --include-assetnote
```

---

## ⚠️ Важно
- Всегда проверяй сначала с `--dry-run`.
- Перед `--apply` убедись в содержимом отчётов.
- Используй на свой страх и риск: скрипт делает `rm -rf` при дедупликации.

---

## 📜 Лицензия
MIT — см. файл `LICENSE`.
