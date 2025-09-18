# Update Wordlists — Pentest Edition

Автоматизированный bash-скрипт для обновления/клонирования/управления словарями (wordlists) и payload-наборами,
используемыми в пентесте: web/content discovery, brute-force, SQLi/XSS/SSTI/XXE и пр.

**Основной скрипт:** `bin/update-wordlists.sh` (идентичен файлу `bin/GIT_&_Sec-Word_Lists_Update.sh` — сохранён без изменений).

---

## ✨ Возможности

- Обновление всех локальных Git-репозиториев (`git pull`) в заданных директориях и (опционально) по всей системе.
- Клонирование/обновление популярных репозиториев словарей: **SecLists**, **PayloadsAllTheThings**, **FuzzDB**, payloadbox-наборы (SQLi, XSS, SSTI, XXE), **Probable‑Wordlists**, **DirBuster**; опционально — **assetnote/wordlists**.
- Автоматическая распаковка архивов (`.tar.gz`, `.tgz`, `.gz`) в `/usr/share/wordlists`.
- Создание единого каталога ссылок на словари — `/usr/share/wordlists/_all-links` (с опциями фильтрации и дедупликации имён).
- Дедупликация APT ↔ GIT: предпочтение системных пакетов (`seclists`, `fuzzdb`, `dirb` и др.) над дубликатами из Git (с отчётом и, при желании, удалением Git-копий).
- APT bootstrap (опционально): установка core-пакетов (seclists, dirb, wfuzz, gobuster, ffuf, amass, nikto, john, hashcat, cewl, nmap/wordlists и др.) и распаковка `rockyou.txt`.
- Подробное логирование и отчёты в `~/Git_Update_Reports/`.

---

## 🔧 Требования

- Linux с bash (>=4), `git`, `sudo` (для установки/записи в системные каталоги).
- Для `--apt-bootstrap` — Debian/Ubuntu (наличие `apt-get`). На иных дистрибутивах шаг пропускается.
- Доступ на запись в `/usr/share/wordlists` (обычно через `sudo`).

---

## 📦 Установка

```bash
git clone <your-repo-url>
cd <your-repo>
chmod +x bin/update-wordlists.sh
```

Опциональная системная установка:
```bash
sudo ./install.sh
# после этого:
sudo update-wordlists --no-menu --dry-run
```

Удаление:
```bash
sudo ./uninstall.sh
```

---

## ▶️ Запуск

С меню (интерактивный режим):
```bash
sudo ./bin/update-wordlists.sh
```

Без меню (неинтерактивный режим, полезно для cron/CI):
```bash
sudo ./bin/update-wordlists.sh --no-menu --dry-run --no-system
```

Логи/отчёты: `~/Git_Update_Reports/run_YYYY-MM-DD_HH-MM-SS.txt` и файлы отчётов дедупликации.

---

## 🔑 Ключи командной строки (CLI)

> Ниже — полный список флагов, поддерживаемых скриптом. Все они отражаются в переменных окружения,
> дальше влияют на выполняемые шаги. Любой флаг можно указать в любой комбинации.

### Базовые
- `--no-menu` — запуск без меню (неинтерактивно).
- `--dry-run` — *просушка*: команды печатаются как `[DRY-RUN] ...`, но **не выполняются**.
- `--no-system` — не сканировать всю систему (`/`), только каталоги из `SEARCH_DIRS`.
- `--all-mounts` — разрешить пересечение различных ФС при системном сканировании (иначе `-xdev`).

### Линковка словарей в `_all-links`
- `--link-all` / `--no-link-all` — включить/выключить создание коллекции ссылок `/usr/share/wordlists/_all-links`.
- `--links-only-txt` — включать в коллекцию **только текстовые** форматы (`.txt`, `.lst`, `.dic`, `.wordlist`, `.json`).
- `--links-include-archives` — включать также архивы (`.gz`, `.zip`, `.tar.gz`, `.tgz`, `.xz`).
- `--links-dedup` / `--no-links-dedup` — дедупликация имён (если имя уже занято, добавляется короткий хеш).

### Дедупликация APT ↔ GIT
- `--dedup-prefer-apt` / `--no-dedup-prefer-apt` — когда *один и тот же набор* встречается и в APT, и в Git, предпочесть APT.
- `--apply` / `--no-apply` — **фактически удалить** найденные Git-дубликаты (`rm -rf`) или только сформировать подробный отчёт.

### Архивы / безопасность
- `--autoclean-matryoshka` / `--no-autoclean-matryoshka` — если после распаковки верхняя папка содержит **только архивы**, удалить её.
- `--skip-zip-bombs` — пропускать путь `SecLists/Payloads/Zip-Bombs` при распаковке (защита от zip-бомб).

### Дополнительные
- `--apt-bootstrap` / `--no-apt-bootstrap` — установить через APT базовые утилиты и распаковать `rockyou.txt`.
- `--include-assetnote` / `--no-include-assetnote` — включить/отключить `assetnote/wordlists` в списке репозиториев.
- `-h` | `--help` — показать шапку скрипта (первая ~240 строк), краткую справку.

---

## 🎛️ Опции меню ⇄ переменные ⇄ эффект

При запуске без флагов скрипт показывает меню. Каждый пункт **переключает булеву переменную** и влияет на дальнейшие шаги:

| Пункт меню | Переменная | Эффект |
|---|---|---|
| 1) Toggle DRY-RUN | `DRY_RUN` | Отладочный прогон без изменений: печатаются команды, но не выполняются. |
| 2) Toggle System-wide scan | `SCAN_SYSTEM` | Сканировать ли `/` на предмет Git-репозиториев (с исключениями `PRUNE_DIRS`). |
| 3) Toggle Cross-filesystems | `CROSS_FS` | Пересекать ли другие ФС при find (иначе используется `-xdev`). |
| 4) Toggle Link all wordlists | `LINK_ALL` | Создавать коллекцию ссылок `_all-links`. |
| 5) Toggle Links: only text | `LINKS_ONLY_TXT` | Ограничить `_all-links` только текстовыми форматами. |
| 6) Toggle Links: include archives | `LINKS_INCLUDE_ARCH` | Добавлять в `_all-links` архивы. |
| 7) Toggle Links: deduplicate | `LINKS_DEDUP` | Включить дедупликацию имён ссылок. |
| 8) Toggle Dedup: prefer APT | `DEDUP_PREFER_APT` | Предпочитать APT‑пакеты над Git‑дубликатами. |
| 9) Toggle Apply deletions | `APPLY_CHANGES` | Фактически удалять Git‑дубли при дедупликации. |
| a) Toggle Autoclean matryoshka | `AUTOCLEAN_MATRYOSHKA` | Удалять «матрёшки» (верхнюю пустую папку с одними архивами). |
| z) Toggle Skip Zip-Bombs | `SKIP_ZIP_BOMBS` | Пропускать распаковку в известных каталогах zip‑бомб. |
| b) Toggle APT bootstrap | `APT_BOOTSTRAP` | Установить core‑пакеты через APT и разжать rockyou. |
| n) Toggle Include assetnote | `INCLUDE_ASSETNOTE` | Добавить `assetnote/wordlists` в список репозиториев. |
| r) Run now | — | Выполнить все шаги с текущими настройками. |
| q) Quit | — | Выйти без выполнения. |

---

## 🧭 Шаги выполнения (pipeline)

0. *(опционально)* `apt_bootstrap` — установка core‑пакетов и `rockyou.txt` (если `APT_BOOTSTRAP=true`).  
1. Обновление Git‑репозиториев в `SEARCH_DIRS` (`git pull --rebase --autostash --ff-only`).  
2. *(опционально)* **System‑wide scan** — поиск и обновление всех репозиториев под `/` (исключая `PRUNE_DIRS`; `CROSS_FS` определяет `-xdev`).  
3. Клонирование/обновление **WORDLIST_REPOS** в `/usr/share/wordlists/_3rdparty`.  
4. Авто‑распаковка `.tar.gz/.tgz` и `.gz` под `/usr/share/wordlists` (с проверками zip‑бомб, «матрёшек» и др.).  
5. *(опционально)* Создание коллекции ссылок `_all-links` с фильтрами и дедупликацией.  
6. *(опционально)* Дедупликация APT ↔ GIT: формирование отчёта и, если разрешено, удаление Git‑дубликатов.  
7. Запись логов/отчётов, итоговые сообщения.

---

## 📁 Пути и файлы

- **SEARCH_DIRS**: `"$HOME" "/usr/share/wordlists" "/opt"` — где искать `.git` локально.  
- **PRUNE_DIRS**: исключаемые пути при сканировании `/`: `/proc`, `/sys`, `/dev`, `/run`, `/boot/efi`, `/lost+found`, `/var/cache`, `/var/tmp`, `/tmp`, `/var/lib/docker`, `/var/lib/containers`, `/var/lib/snapd`, `/snap` и др.  
- **WORDLISTS_DIR**: `/usr/share/wordlists/_3rdparty` — сюда клонируются внешние наборы.  
- **_all-links**: `/usr/share/wordlists/_all-links` — коллекция ссылок на все найденные словари.  
- **REPORT_DIR**: `~/Git_Update_Reports/` — все логи и отчёты.  

---

## 🧪 Примеры запуска

Минимальный dry‑run только по домашнему каталогу:
```bash
./bin/update-wordlists.sh --dry-run --no-system --no-menu
```

Полная пробежка с установкой APT‑пакетов и assetnote:
```bash
sudo ./bin/update-wordlists.sh --no-menu --apt-bootstrap --include-assetnote
```

Создать только коллекцию текстовых словарей:
```bash
sudo ./bin/update-wordlists.sh --no-menu --link-all --links-only-txt --no-links-dedup
```

Провести дедупликацию без удаления (только отчёт):
```bash
sudo ./bin/update-wordlists.sh --no-menu --dedup-prefer-apt --no-apply
```

Применить удаление Git‑дубликатов после проверки отчёта:
```bash
sudo ./bin/update-wordlists.sh --no-menu --dedup-prefer-apt --apply
```

---

## 🛡️ Безопасность и рекомендации

- **Всегда** начинай с `--dry-run`, чтобы увидеть, что будет сделано.  
- Перед `--apply` внимательно смотри отчёты дедупликации.  
- Для распаковки включай `--skip-zip-bombs`, чтобы не распаковать zip‑бомбу.  
- Для сетевых/внешних дисков включай `--all-mounts` только при необходимости.  
- Системные каталоги изменяются через `sudo` — храни бэкапы критичных данных.

---

## 🩺 Troubleshooting (частые проблемы)

**1) `apt-get` отсутствует, дистрибутив не Debian/Ubuntu**  
Скрипт корректно пропустит шаг `--apt-bootstrap`. Установи нужные пакеты своим пакетным менеджером.

**2) `git pull` → `Non-fast-forward` / локальные изменения**  
Скрипт вызывает `git pull --rebase --autostash --ff-only`. Если pull не смержился — репозиторий пропускается с предупреждением. Разберись вручную.

**3) Нет прав в `/usr/share/wordlists`**  
Запускай команду через `sudo` или измени путь назначения в конфиге/в самом скрипте.

**4) CI падает на shellcheck**  
Предупреждения shellcheck не блокируют CI (пример конфигурации допускает предупреждения). Исправь по возможности.

**5) Zip-бомбы в SecLists**  
Флаг `--skip-zip-bombs` (в меню пункт `z`) пропустит подозрительные пути распаковки.

---

## 🧩 FAQ

**Q:** Можно ли управлять конфигом из файла?  
**A:** Да, см. `conf/config.example.sh` — скопируй его как свой конфиг и запускай скрипт с нужными флагами. (В данном репозитории мы не модифицируем исходный скрипт, чтобы сохранить его 1:1.)

**Q:** Есть ли планировщик/cron?  
**A:** Да, пример: `@weekly root /usr/local/bin/update-wordlists --no-menu >> /var/log/update-wordlists.log 2>&1`

**Q:** Где смотреть отчёты?  
**A:** В `~/Git_Update_Reports/` — там хранится общий run‑лог и подробные отчёты дедупликации.

---

## 🧱 Структура репозитория

```
.
├─ .github/
│  └─ workflows/
│     └─ ci.yml
├─ bin/
│  ├─ update-wordlists.sh
│  └─ GIT_&_Sec-Word_Lists_Update.sh   # идентичный оригинал
├─ conf/
│  └─ config.example.sh
├─ docs/
│  ├─ INSTALL.md
│  └─ USAGE.md
├─ tests/
│  └─ smoke_test.sh
├─ .editorconfig
├─ .gitignore
├─ CONTRIBUTING.md
├─ CHANGELOG.md
├─ LICENSE
├─ Makefile
├─ README.md
├─ uninstall.sh
└─ install.sh
```

---

## 📜 Лицензия
MIT — см. `LICENSE`.
