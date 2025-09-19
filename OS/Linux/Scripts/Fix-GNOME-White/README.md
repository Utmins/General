# fix-gnome-white.sh — GNOME белые окна/артефакты: быстрый фикс

Полный, автономный скрипт для временного решения проблем «белых/прозрачных» окон и артефактов рендеринга в приложениях GNOME (Nautilus, Settings, Extensions, Disks, System Monitor, Terminal и др.).
Скрипт создаёт **локальные .desktop-овверрайды**, **обёртки для бинарей** и **переопределение D‑Bus сервиса** GNOME Shell Extensions, добавляя безопасные переменные окружения рендеринга:

```
LIBGL_ALWAYS_SOFTWARE=1
GSK_RENDERER=cairo
```

> Идея: принудительно переключить рендеринг на программный/CAIRO, обойти баги драйверов/рендереров (особенно на виртуалках), не ломая системные пакеты и без root‑модификаций в /usr.

---

## Быстрый старт

```bash
chmod +x fix-gnome-white.sh
./fix-gnome-white.sh
# После — перелогиниться (или на Xorg: Alt+F2 → r)
```

**Откат:**

```bash
./fix-gnome-white.sh --restore
# Рекомендуется перелогиниться
```

---

## Что именно делает скрипт

1. **Патчит .desktop-файлы (user‑override):**
   - Копирует из `/usr/share/applications` в `~/.local/share/applications` для:
     - `org.gnome.Nautilus.desktop`
     - `org.gnome.Settings.desktop`
     - `org.gnome.Extensions.desktop`
     - `org.gnome.DiskUtility.desktop`
     - `org.gnome.SystemMonitor.desktop`
     - `org.gnome.Terminal.desktop`
   - В секции `Exec=` дописывает `env LIBGL_ALWAYS_SOFTWARE=1 GSK_RENDERER=cairo …`
   - Принудительно ставит `DBusActivatable=false` (уменьшает влияние D‑Bus‑активации на запуск через локальный override).
   - Создаёт резервную копию `*.desktop.bak` для быстрого отката.

2. **Создаёт user‑wrappers (обёртки) в `~/.local/bin/` для:**
   - `nautilus`, `gnome-control-center`, `gnome-extensions-app`
   - Обёртка экспортирует переменные окружения и затем вызывает настоящий бинарь из `/usr/bin/…`.

3. **Переопределяет D‑Bus сервис GNOME Shell Extensions (user scope):**
   - Копирует `/usr/share/dbus-1/services/org.gnome.Shell.Extensions.service` → `~/.local/share/dbus-1/services/…`
   - Подменяет `Exec=` на запуск под теми же переменными окружения.
   - Вызывает `systemctl --user daemon-reload` (по возможности).

4. **Обновляет кэши desktop‑базы и shell‑PATH (hash -r)**

**Ничего в /usr не модифицируется**: всё в вашем home‑префиксе. Поэтому _sudo не нужен_ и риск минимален.

---

## Использование

### Запуск
- **Применить фикс (режим по умолчанию):**
  ```bash
  ./fix-gnome-white.sh
  ```
  Вы увидите отчёт вида:
  - `✔ Patched .desktop: …`
  - `✔ Wrapped bin: …`
  - `✔ Patched D-Bus service: …`
  - В конце: `✅ Patch complete. Re-login or (Xorg) Alt+F2 → r.`

- **Откат всех изменений:**
  ```bash
  ./fix-gnome-white.sh --restore
  ```
  Вернёт исходные `.desktop`, удалит обёртки и пользовательский D‑Bus override.

### Параметры
- `--restore` — отменить все изменения и обновить кэши.

### Требования
- GNOME‑окружение;
- Пользовательский доступ к домашнему каталогу;
- Утилиты: `update-desktop-database` (обычно присутствует в системах с desktop‑окружением).

---

## Типовые кейсы и советы

- **VirtualBox/KVM/VMware:** на виртуалках артефакты появляются чаще из‑за особенностей 3D‑акселерации — программный рендеринг через CAIRO часто стабилен.
- **Snap/Flatpak‑приложения:** скрипт правит только системные `.desktop` и бинарники из `/usr/bin`. Для контейнерных пакетов правила аналогичны (можно вручную создать .desktop override в `~/.local/share/applications` и прописать `Exec=env … flatpak run …`).
- **Wayland vs Xorg:** на Xorg можно быстро «перезапустить shell» (`Alt+F2 → r`). На Wayland полноценный эффект даёт перелогин.

---

## Безопасность и откат

- Все изменения — **только в $HOME**:
  - `~/.local/share/applications/*.desktop` (+ резервные `*.bak`)
  - `~/.local/bin/*` (обёртки)
  - `~/.local/share/dbus-1/services/org.gnome.Shell.Extensions.service`
- Скрипт **не требует sudo** и не затрагивает системные файлы.
- Откат одной командой: `--restore`.

---

## Ограничения

- Если дистрибутив не содержит описанных `.desktop`/бинарей, вы получите уведомления `✗ … not found` — это **нормально**.
- Обновления системы могут добавить новые `.desktop` — просто запустите скрипт снова.
- Некоторым приложениям нужны собственные overrides (особенно контейнерным форматам).

---

## Проверено

- GNOME 42+ (Ubuntu, Debian, Kali, Fedora — в т.ч. на виртуалках).
- Сообщайте результаты для вашей системы через Issues/PR‑ы.

---

## Контрольная сумма

- `fix-gnome-white.sh` (SHA256): `ac5d6b57c6b2dd53966d006f7c97609ecf1aad1dfb2625e46c8dc8d7269d779e`

---

## Лицензия

Проект распространяется по лицензии MIT (см. `LICENSE`).

---

## Источник скрипта

Содержимое скрипта включено в репозиторий как `fix-gnome-white.sh`. Подробности по логике см. комментарии внутри файла.
