# Sec-Word_Lists_Inventory

Инструмент инвентаризации словарей и пейлоад-наборов на Linux-хосте. Сканирует базовые директории (по умолчанию `/usr/share/wordlists`, `/usr/share/seclists`, `/usr/share/wordlists/_3rdparty`), собирает метаданные и, при необходимости, вычисляет устойчивый «отпечаток» источника (fingerprint) по содержимому файлов. Поддерживает фильтрацию по дате, дедупликацию источников с одинаковыми именами, многопоточность и вывод в CSV/JSON.

> Скрипт основан на файле `Sec-Word_Lists_Inventory.sh` (эта версия прилагается в репозитории).

---

## Возможности

- **Два режима работы**:
  - `light` — быстрый (отпечаток по списку файлов/размерам/mtime).
  - `full` — точный (отпечаток по хешам всех файлов).
- **Фильтр свежести**: `--since=YYYY-MM-DD` — в отчёт попадают только источники, изменённые не ранее указанной даты (UTC).
- **Дедупликация по имени каталога**: `--dedup-name=system|thirdparty|none`.
- **Гибкая конфигурация корней**: `--roots=/a,/b` + `--exclude=tmp,backup`.
- **Параллельная обработка**: `--parallel N` для ускорения «full»-режима.
- **Несколько форматов отчёта**: `--out-format=csv|json|both`.
- **Невмешивающийся dry-run**: `--dry-run` (ничего не записывает на диск).
- **Отчёт о статусе**: `New | Updated | No Changes | Removed`.

## Требования

Linux-платформа со стандартными утилитами:
`bash`, `find`, `xargs`, `sha256sum`, `stat`, `awk`, `sort`, `tail`, `date`, `du`, `mkdir`, `mktemp`.

> Минимально проверенная среда: Kali/Ubuntu/Debian.

## Установка

```bash
# Клонируйте ваш репозиторий и сделайте скрипт исполняемым
chmod +x Sec-Word_Lists_Inventory.sh
```

## Быстрый старт

```bash
# Интерактивное меню (предлагает light/full)
./Sec-Word_Lists_Inventory.sh

# Неблокирующие запуски
./Sec-Word_Lists_Inventory.sh --mode=light
./Sec-Word_Lists_Inventory.sh --mode=full

# Изменить каталог отчётов
./Sec-Word_Lists_Inventory.sh --mode=light --out-dir "$HOME/Git_Update_Reports"

# Сканировать другие корни, исключив некоторые подпапки
./Sec-Word_Lists_Inventory.sh --mode=full --roots="/opt/lists,/data/seclists" --exclude="tmp,backup"

# Порог свежести и формат JSON
./Sec-Word_Lists_Inventory.sh --mode=light --since=2025-05-01 --out-format=json
```

## Переменные окружения (по умолчанию)

| Переменная | Значение по умолчанию | Описание |
|---|---|---|
| `OUT_DIR` | `$HOME/Git_Update_Reports` | Куда писать отчёты |
| `LOG_LEVEL` | `info` | `error|warn|info|debug|trace` |
| `MAX_DEPTH` | `2` | Глубина обхода `find` |
| `MIN_FILES_PER_SOURCE` | `1` | Минимум файлов, чтобы каталог считался «источником» |
| `PARALLEL` | `4` | Кол-во воркеров в «full»-режиме |
| `OUT_FORMAT` | `csv` | `csv|json|both` |

> Все опции CLI перекрывают значения из окружения.

## Опции CLI

```
--mode=light|full         Выбор режима (без меню)
--out-dir=PATH            Каталог для отчётов (по умолчанию $HOME/Git_Update_Reports)
--log-level=error|warn|info|debug|trace
--roots=/a,/b             Список корней через запятую
--exclude=pat1,pat2       Исключить каталоги, содержащие подстроки
--max-depth=N             Глубина обхода find (по умолчанию 2)
--min-files=N             Минимум файлов на источник (по умолчанию 1)
--parallel=N              Параллельные воркеры («full»; по умолчанию 4)
--dedup-name=system|thirdparty|none
--since=YYYY-MM-DD        Включить источники с LatestChangeISO >= since
--out-format=csv|json|both
--dry-run                 Ничего не записывать; только показать предполагаемые действия
-h|--help                 Показать справку
```

### Семантика `--since`
Опция является **фильтром вывода**. В итоговом отчёте будут только каталоги, у которых `LatestChangeISO >= since`. Сравнения статуса (`Updated/No Changes`) выполняются **в рамках фильтра**, т.е. учитываются только попавшие в текущую выборку.

### Дедупликация `--dedup-name`
При совпадении имён каталогов:
- `system` — предпочитает пути внутри `/usr/share/seclists`,
- `thirdparty` — предпочитает пути внутри `/_3rdparty/`,
- `none` — отключить дедупликацию (оставить первый встретившийся).

## Структура выходных файлов

По умолчанию создаются файлы:
- `wordlists_inventory_light.csv`
- `wordlists_inventory_full.csv`

Если указан `--out-format=json|both`, дополнительно создаются:
- `wordlists_inventory_light.json`
- `wordlists_inventory_full.json`

### CSV-схема

| Колонка | Пример | Описание |
|---|---|---|
| `SourceName` | `SecLists` | Имя каталога-источника (`basename`) |
| `SourcePath` | `/usr/share/seclists` | Абсолютный путь |
| `FileCount` | `4525` | Кол-во файлов, отнесённых к источнику |
| `TotalSizeBytes` | `123456789` | Общий объём (`du -sb --apparent-size`) |
| `LatestChangeISO` | `2025-09-18T14:03:33Z` | Самая свежая `mtime` файла в источнике (UTC) |
| `ScanTimeISO` | `2025-09-19T06:12:00Z` | Время сканирования (UTC) |
| `Status` | `New/Updated/No Changes/Removed` | Статус источника относительно предыдущего отчёта |
| `Fingerprint` | `sha256…` | Сводный отпечаток директории |

### JSON-схема
Каждый элемент массива содержит поля, идентичные колонкам CSV.

## Примеры использования

- **Быстрый аудит системных списков**:
  ```bash
  ./Sec-Word_Lists_Inventory.sh --mode=light --roots="/usr/share/wordlists,/usr/share/seclists"
  ```
- **Точный контроль изменений третьих источников**:
  ```bash
  ./Sec-Word_Lists_Inventory.sh --mode=full --roots="$HOME/wordlists/_3rdparty" --dedup-name=thirdparty --parallel=8
  ```
- **Фиксация только свежих обновлений** (после 1 августа 2025):
  ```bash
  ./Sec-Word_Lists_Inventory.sh --mode=light --since=2025-08-01 --out-format=both
  ```

## Логи и уровни подробности

Указываются через `--log-level` или `LOG_LEVEL`. При `debug/trace` скрипт печатает диагностическую информацию о параметрах запуска и количестве найденных кандидатов.

## Производительность

- В «full»-режиме стоимость вычислений пропорциональна количеству и размеру файлов (читаются и хешируются все файлы). Увеличивайте `--parallel` для SSD/многоядерных систем.
- Ограничивайте глубину `--max-depth`, исключайте мусорные каталоги через `--exclude`.

## Типичные проблемы и решения

- **`/usr/bin/xargs: warning: options --max-args and --replace/-I/-i are mutually exclusive`** — не мешает работе, предупреждение от `xargs` в некоторых окружениях. В текущей версии скрипта конкурирующие флаги не используются.
- **`/usr/bin/xargs: sh: Permission denied`** — проверьте права на исполняемые файлы/точки монтирования, запустите под пользователем с доступом к каталогам.
- **`/usr/bin/xargs: sh: No such file or directory`** — установите пакет `dash`/`bash` и убедитесь, что `/bin/sh` существует.
- **Пустой отчёт** — проверьте `--roots`, `--exclude`, `--max-depth` и `MIN_FILES_PER_SOURCE`.

## Выходные коды

- `0` — успех
- `1` — неверный выбор меню
- `2` — ошибка параметров CLI
- `>0` — прочие ошибки исполнения (см. trap-лог в stderr)

## Лицензия

MIT (см. `LICENSE`).

---

© 2025-09-19 Pavel K. / Contributors
