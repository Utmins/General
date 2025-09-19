#!/usr/bin/env bash
set -euo pipefail

# ================== Options ==================
MODE="interactive"   # interactive | auto
USE_BREAK="auto"     # auto | never (для fallback без pip-review)
# bootstrap: auto-установка python/pip/pipx и наборов установщиков
BOOTSTRAP="yes"
for arg in "${@:-}"; do
  case "$arg" in
    --auto) MODE="auto" ;;
    --interactive) MODE="interactive" ;;
    --no-break) USE_BREAK="never" ;;
    --no-bootstrap) BOOTSTRAP="no" ;;
    *) echo "Usage: $0 [--auto|--interactive] [--no-break] [--no-bootstrap]"; exit 1 ;;
  esac
done

# ================== Colors ==================
if command -v tput >/dev/null 2>&1 && [ -n "${TERM-}" ] && [ "$(tput colors || echo 0)" -ge 8 ]; then
  BOLD="$(tput bold)"; RESET="$(tput sgr0)"
  GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; BLUE="$(tput setaf 4)"
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; RED=""; BLUE=""
fi

echo -e "${BOLD}${BLUE}==> Kali Python/Pip updater (with toolchain bootstrap)${RESET}"

# ================== Helpers ==================
need_sudo() { [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; }
run_apt() {
  if command -v apt-get >/dev/null 2>&1; then
    if need_sudo; then sudo apt-get update -y; sudo apt-get install -y "$@"
    else apt-get update -y; apt-get install -y "$@"
    fi
    return 0
  fi
  return 1
}
ensure_path_for_pipx() {
  case ":${PATH}:" in *":${HOME}/.local/bin:"*) : ;; *)
    export PATH="${HOME}/.local/bin:${PATH}";; esac
  local SHELL_RC=""
  if [ -n "${BASH_VERSION-}" ]; then SHELL_RC="${HOME}/.bashrc"
  elif [ -n "${ZSH_VERSION-}" ]; then SHELL_RC="${HOME}/.zshrc"; fi
  if [ -n "${SHELL_RC}" ] && [ -w "${SHELL_RC}" ]; then
    grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${SHELL_RC}" || \
      printf '\n# Added by kali_python_update.sh\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${SHELL_RC}"
  fi
  hash -r || true
}

install_python_stack_if_missing() {
  # python3 / pip3 / venv
  local need_py="no" need_pip="no"
  command -v python3 >/dev/null 2>&1 || need_py="yes"
  python3 -m pip --version >/dev/null 2>&1 || need_pip="yes"

  if [ "$need_py" = "yes" ] || [ "$need_pip" = "yes" ]; then
    echo -e "${YELLOW}Устанавливаю python3/python3-pip/python3-venv через APT...${RESET}"
    run_apt python3 python3-pip python3-venv || { echo -e "${RED}Не удалось установить python3/pip3/venv.${RESET}"; exit 1; }
  fi
}

install_pipx_if_missing() {
  if command -v pipx >/dev/null 2>&1; then
    echo -e "${GREEN}pipx уже установлен: $(pipx --version)${RESET}"
    ensure_path_for_pipx
    return 0
  fi
  echo -e "${YELLOW}pipx не найден — устанавливаю...${RESET}"
  if run_apt pipx python3-venv python3-pip; then
    :
  else
    # Fallback на pip --user
    python3 -m pip install --user -U pipx || { echo -e "${RED}Не удалось установить pipx.${RESET}"; exit 1; }
  fi
  ensure_path_for_pipx
  pipx ensurepath || true
  ensure_path_for_pipx
  command -v pipx >/dev/null 2>&1 || { echo -e "${RED}pipx всё ещё не в PATH.${RESET}"; exit 1; }
}

pipx_install_or_upgrade() {
  # $1=package, $2(optional)=--spec (например, uv) или версия
  local pkg="$1"; shift || true
  if pipx list 2>/dev/null | grep -qiE "^\s*package ${pkg} "; then
    echo -e "${BLUE}Обновляю ${pkg} через pipx...${RESET}"
    pipx upgrade "${pkg}" || pipx install --force "${pkg}" "$@" || true
  else
    echo -e "${BLUE}Устанавливаю ${pkg} через pipx...${RESET}"
    pipx install "${pkg}" "$@" || true
  fi
}

# ================== Python / pip base ==================
if [ "$BOOTSTRAP" = "yes" ]; then install_python_stack_if_missing; fi

PY_BIN=""
if command -v python3 >/dev/null 2>&1; then PY_BIN="python3"
elif command -v python  >/dev/null 2>&1; then PY_BIN="python"
else
  echo -e "${RED}Python не найден. Установите: sudo apt update && sudo apt install -y python3 python3-pip${RESET}"
  exit 1
fi
PY_VER="$($PY_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
echo -e "${GREEN}Использую: ${PY_BIN} ${PY_VER}${RESET}"

if ! $PY_BIN -m pip --version >/dev/null 2>&1; then
  if [ "$BOOTSTRAP" = "yes" ]; then
    echo -e "${YELLOW}pip не найден — ставлю python3-pip...${RESET}"
    run_apt python3-pip || { echo -e "${RED}Не удалось установить pip.${RESET}"; exit 1; }
  else
    echo -e "${RED}pip не найден. Завершаю.${RESET}"; exit 1
  fi
fi
echo -e "${GREEN}$($PY_BIN -m pip --version)${RESET}"

# ================== Show APT python3-* ==================
echo -e "\n${BOLD}${BLUE}==> APT-пакеты python3-* (установленные)${RESET}"
if command -v dpkg-query >/dev/null 2>&1; then
  APT_LIST=$(dpkg-query -W -f='${Package}\t${Version}\n' 'python3-*' 2>/dev/null | sort || true)
  [ -n "$APT_LIST" ] && echo "$APT_LIST" | sed 's/^/  /' || echo "  (нет установленных python3-* через apt)"
else
  echo "  dpkg-query недоступен."
fi

# ================== venv / PEP668 ==================
IN_VENV="$($PY_BIN - <<'PY'
import sys
print("yes" if (getattr(sys,"base_prefix",sys.prefix)!=sys.prefix) or hasattr(sys,"real_prefix") else "no")
PY
)"
PEP668="no"
if [ "$IN_VENV" = "no" ] && ls /usr/lib/python*/EXTERNALLY-MANAGED >/dev/null 2>&1; then PEP668="yes"; fi
[ "$IN_VENV" = "yes" ] && echo -e "${YELLOW}Обнаружено venv: операции затронут только текущее окружение.${RESET}"
[ "$PEP668" = "yes" ] && echo -e "${YELLOW}PEP 668 активен (externally managed).${RESET}"

# ================== Bootstrap toolchain (pipx + common installers) ==================
if [ "$BOOTSTRAP" = "yes" ]; then
  install_pipx_if_missing
  # Часто используемые установщики/менеджеры Python-пакетов и CLI:
  pipx_install_or_upgrade pip-review         # авто- и интерактивные апдейты pip-пакетов
  pipx_install_or_upgrade pipenv             # менеджер окружений/зависимостей
  pipx_install_or_upgrade poetry             # менеджер зависимостей/пакетов
  pipx_install_or_upgrade virtualenv         # альтернативный venv-менеджер
  pipx_install_or_upgrade pip-tools          # pip-compile/pip-sync
  # uv — быстрый установщик/менеджер (если не в репо — pipx подтянет с PyPI)
  pipx_install_or_upgrade uv
  ensure_path_for_pipx
fi

# ================== Preferred path: pip-review via pipx ==================
if command -v pip-review >/dev/null 2>&1; then
  echo -e "\n${BOLD}${BLUE}==> Найден pip-review. Использую его.${RESET}"
  echo -e "${GREEN}Список устаревших (локально видимых pip-пакетов):${RESET}"
  pip-review --local || true

  if [ "$MODE" = "auto" ]; then
    echo -e "\n${BOLD}${BLUE}==> Авто-обновление через pip-review --auto${RESET}"
    pip-review --auto || true
  else
    echo -e "\n${BOLD}${BLUE}==> Интерактивное обновление (pip-review --interactive)${RESET}"
    pip-review --interactive || true
  fi

  echo -e "\n${BOLD}${BLUE}==> Готово (pip-review).${RESET}"
  echo "Подсказки:"
  echo "  • Системные python3-* обновляй через: sudo apt update && sudo apt upgrade"
  exit 0
fi

# ================== Fallback path (без pip-review) ==================
echo -e "\n${YELLOW}pip-review недоступен. Переход к fallback-режиму (чистый pip).${RESET}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

$PY_BIN - <<'PY' > "$TMPDIR/pkg_map.tsv"
import pathlib
try:
    from importlib import metadata as im
except Exception:
    import importlib_metadata as im
for dist in im.distributions():
    name = dist.metadata.get('Name','UNKNOWN').strip()
    version = getattr(dist,'version','UNKNOWN').strip()
    base = pathlib.Path(dist.locate_file(''))
    installer = 'unknown'
    for f in (dist.files or []):
        p = pathlib.Path(f)
        if p.name == 'INSTALLER' and '.dist-info' in str(p):
            try:
                installer = (dist.locate_file(p)).read_text(encoding='utf-8', errors='ignore').strip().lower() or 'unknown'
            except Exception:
                installer = 'unknown'
            break
    print("\t".join((name, version, str(base), installer)))
PY

PIP_LIST_FILE="$TMPDIR/pip_names.txt"
APT_STYLE_FILE="$TMPDIR/apt_style_names.txt"

awk -F'\t' -v in_venv="$IN_VENV" '
{
  name=$1; ver=$2; loc=$3; inst=tolower($4);
  l=tolower(loc);
  is_usr_local = index(l,"/usr/local/")==1
  is_usr_lib_dist = match(l, "^/usr/lib/python[0-9.]+/dist-packages")>0
  is_user_site = index(l,"/.local/")>0
  pip_managed = (inst=="pip" || is_usr_local || is_user_site || in_venv=="yes") && name!="UNKNOWN"
  apt_managed = (!pip_managed && is_usr_lib_dist)
  if (pip_managed) print name >> "'"$PIP_LIST_FILE"'";
  else if (apt_managed) print name"\t"ver"\t"loc"\t"inst >> "'"$APT_STYLE_FILE"'";
}
' "$TMPDIR/pkg_map.tsv"

echo -e "\n${BOLD}${BLUE}==> Pip-управляемые пакеты (кандидаты на обновление)${RESET}"
[ -s "$PIP_LIST_FILE" ] && sort -u "$PIP_LIST_FILE" | sed 's/^/  - /' || echo "  (не найдено)"

echo -e "\n${BOLD}${BLUE}==> Системные (apt-стиль) пакеты в dist-packages (не трогаем pip-ом)${RESET}"
[ -s "$APT_STYLE_FILE" ] && column -t -s$'\t' "$APT_STYLE_FILE" | sed 's/^/  /' || echo "  (не обнаружены)"

# Настройка флага break для PEP668
PIP_EXTRA=()
if [ "$PEP668" = "yes" ] && [ "$IN_VENV" = "no" ] && [ "$USE_BREAK" != "never" ]; then
  echo -e "${YELLOW}Добавляю --break-system-packages для pip-команд (PEP 668).${RESET}"
  PIP_EXTRA+=(--break-system-packages)
elif [ "$PEP668" = "yes" ] && [ "$USE_BREAK" = "never" ]; then
  echo -e "${YELLOW}PEP 668 активен, но --break-system-packages отключён (--no-break). Возможны ошибки.${RESET}"
fi

if [ -s "$PIP_LIST_FILE" ]; then
  echo -e "\n${BOLD}${BLUE}==> Проверяю устаревшие среди pip-пакетов (fallback)${RESET}"
  "$PY_BIN" -m pip list --outdated --format=json "${PIP_EXTRA[@]}" > "$TMPDIR/outdated.json" || true
  $PY_BIN - <<'PY' "$TMPDIR/outdated.json" "$PIP_LIST_FILE" > "$TMPDIR/outdated_pip_names.txt"
import json, re, sys
def norm(s): return re.sub(r'[-_]+','', s).lower()
data = json.load(open(sys.argv[1]))
targets = {line.strip() for line in open(sys.argv[2]) if line.strip()}
tgt_norm = {norm(x) for x in targets}
sel = []
for item in data:
    name = item.get("name") or item.get("project") or ""
    if norm(name) in tgt_norm:
        sel.append(name)
for n in sorted(set(sel), key=str.lower):
    print(n)
PY

  if [ -s "$TMPDIR/outdated_pip_names.txt" ]; then
    echo -e "${YELLOW}Устаревшие pip-пакеты:${RESET}"
    sed 's/^/  - /' "$TMPDIR/outdated_pip_names.txt"

    echo -e "\n${BOLD}${BLUE}==> Обновляю pip-пакеты по одному (only-if-needed)${RESET}"
    while IFS= read -r pkg; do
      [ -z "$pkg" ] && continue
      echo -e "${GREEN}--> $pkg${RESET}"
      "$PY_BIN" -m pip install -U --upgrade-strategy only-if-needed "${PIP_EXTRA[@]}" "$pkg" || \
        echo -e "${RED}   Не удалось обновить $pkg.${RESET}"
    done < "$TMPDIR/outdated_pip_names.txt"
  else
    echo "  Все pip-пакеты уже актуальны."
  fi
else
  echo -e "\n${YELLOW}pip-пакеты не обнаружены — обновлять нечего.${RESET}"
fi

echo -e "\n${BOLD}${BLUE}==> Готово.${RESET}"
echo "Подсказки:"
echo "  • Системные python3-* — через APT: sudo apt update && sudo apt upgrade"
echo "  • В следующий раз можно отключить авто-установку тулчейна флагом: --no-bootstrap"