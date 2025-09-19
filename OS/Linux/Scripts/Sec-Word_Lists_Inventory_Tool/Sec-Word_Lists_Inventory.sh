#!/usr/bin/env bash
# Sec-Word_Lists_Inventory.sh — финальная версия
# Поддерживает: --mode=light|full, --out-dir, --log-level, --roots, --exclude, --max-depth,
#               --min-files, --parallel, --dedup-name, --since, --out-format, --dry-run
#
# Поведение --since:
#   если указано, в итоговый отчёт попадают только каталоги, чей LatestChangeISO >= since.
#   Это поведение фильтра вывода (а не "удаление" из prev CSV): если вы хотите, чтобы
#   сравнения (Updated/No Changes) выполнялись только в рамках фильтра — это реализовано.
set -Eeuo pipefail
LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Trap for error diagnostics
trap 'ec=$?; echo "[ERR] line:${LINENO} cmd:${BASH_COMMAND} ec:${ec}" >&2' ERR

# ===== defaults =====
OUT_DIR="${OUT_DIR:-$HOME/Git_Update_Reports}"
LOG_LEVEL="${LOG_LEVEL:-info}"    # error|warn|info|debug|trace
ROOTS=( "/usr/share/wordlists" "/usr/share/seclists" "/usr/share/wordlists/_3rdparty" )
MAX_DEPTH="${MAX_DEPTH:-2}"
MIN_FILES_PER_SOURCE="${MIN_FILES_PER_SOURCE:-1}"
PARALLEL="${PARALLEL:-4}"
OUT_FORMAT="${OUT_FORMAT:-csv}"   # csv|json
DRY_RUN=false
EXCLUDE_PATTERNS=()               # array
DEDUPE_MODE="none"                # system|thirdparty|none
SINCE_ISO=""

LIGHT_REPORT="${OUT_DIR}/wordlists_inventory_light.csv"
FULL_REPORT="${OUT_DIR}/wordlists_inventory_full.csv"

# ===== logging =====
_log_level_num(){
  case "${1:-info}" in
    error) echo 0 ;;
    warn)  echo 1 ;;
    info)  echo 2 ;;
    debug) echo 3 ;;
    trace) echo 4 ;;
    *)     echo 2 ;;
  esac
}
LOG_LEVEL_NUM="$(_log_level_num "$LOG_LEVEL")"
log(){ local lvl="$1"; shift||true; local n="$(_log_level_num "$lvl")"; (( n<=LOG_LEVEL_NUM )) && printf '[%s] %s\n' "$lvl" "$*" >&2 || true; }

usage(){
  cat <<'USAGE'
Usage:
  Sec-Word_Lists_Inventory.sh [options]

Options:
  --mode=light|full         non-interactive mode
  --out-dir=PATH            output directory (default $HOME/Git_Update_Reports)
  --log-level=error|warn|info|debug|trace
  --roots=/a,/b             comma-separated roots to search
  --exclude=pat1,pat2       exclude directories matching these substrings
  --max-depth=N             find maxdepth (default 2)
  --min-files=N             minimum files to consider a source (default 1)
  --parallel=N              parallel workers for full mode (default 4)
  --dedup-name=system|thirdparty|none
  --since=YYYY-MM-DD        include only sources with LatestChangeISO >= since
  --out-format=csv|json     write csv and optionally json (default csv)
  --dry-run                 don't write files; show actions only
  -h|--help
If --mode not provided, interactive menu will be shown.
USAGE
}

# ===== CLI =====
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode) MODE="${2:-}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    -o|--out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --out-dir=*) OUT_DIR="${1#*=}"; shift ;;
    -l|--log-level) LOG_LEVEL="${2:-}"; LOG_LEVEL_NUM="$(_log_level_num "$LOG_LEVEL")"; shift 2 ;;
    --log-level=*) LOG_LEVEL="${1#*=}"; LOG_LEVEL_NUM="$(_log_level_num "$LOG_LEVEL")"; shift ;;
    --roots=*) IFS=',' read -r -a ROOTS <<< "${1#*=}"; shift ;;
    --exclude=*) IFS=',' read -r -a EXCLUDE_PATTERNS <<< "${1#*=}"; shift ;;
    --max-depth=*) MAX_DEPTH="${1#*=}"; shift ;;
    --min-files=*) MIN_FILES_PER_SOURCE="${1#*=}"; shift ;;
    --parallel=*) PARALLEL="${1#*=}"; shift ;;
    --dedup-name=*) DEDUPE_MODE="${1#*=}"; shift ;;
    --since=*) SINCE_ISO="${1#*=}"; shift ;;
    --out-format=*) OUT_FORMAT="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    *) shift ;;
  esac
done

LIGHT_REPORT="${OUT_DIR}/wordlists_inventory_light.csv"
FULL_REPORT="${OUT_DIR}/wordlists_inventory_full.csv"
LOG_LEVEL_NUM="$(_log_level_num "$LOG_LEVEL")"

log debug "LOG_LEVEL=$LOG_LEVEL"
log debug "OUT_DIR=$OUT_DIR"
log debug "ROOTS=(${ROOTS[*]})"
log debug "MAX_DEPTH=$MAX_DEPTH"
log debug "MIN_FILES_PER_SOURCE=$MIN_FILES_PER_SOURCE"
log debug "PARALLEL=$PARALLEL"
log debug "DEDUPE_MODE=$DEDUPE_MODE"
log debug "EXCLUDE=(${EXCLUDE_PATTERNS[*]})"
log debug "SINCE=$SINCE_ISO"
log debug "OUT_FORMAT=$OUT_FORMAT"
log debug "DRY_RUN=$DRY_RUN"

# ===== helpers =====
ensure_dir(){ local d; d="$(/usr/bin/dirname -- "$1")"; /usr/bin/mkdir -p -- "$d"; }
now_iso(){ /usr/bin/date -u '+%Y-%m-%dT%H:%M:%SZ'; }
iso_to_epoch(){ /usr/bin/date -u -d "$1" '+%s' 2>/dev/null || echo 0; }
csv_escape(){ local s="${1:-}"; s="${s//\"/\"\"}"; printf '"%s"' "$s"; }

# ===== load prev fingerprints (no subshell) =====
load_prev_fingerprints(){ # $1 = PREV_CSV
  declare -gA prev_fp; prev_fp=()
  local csv="$1"
  [[ -s "$csv" ]] || { log debug "Нет предыдущего отчёта: $csv"; return 0; }

  local line path fp
  # tail through process substitution to avoid subshell on the while
  while IFS= read -r line; do
    path="$(printf '%s\n' "$line" | cut -d',' -f2)"
    fp="$(  printf '%s\n' "$line" | cut -d',' -f8)"
    path="${path%\"}"; path="${path#\"}"; path="${path//\"\"/\"}"
    fp="${fp%\"}";     fp="${fp#\"}";     fp="${fp//\"\"/\"}"
    [[ -n "$path" ]] && prev_fp["$path"]="$fp"
  done < <(tail -n +2 -- "$csv")
  log debug "Загружено предыдущих отпечатков: ${#prev_fp[@]}"
}

# ===== exclude check =====
is_excluded(){
  local p="$1"
  local pat
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    [[ -n "$pat" ]] && [[ "$p" == *"$pat"* ]] && return 0
  done
  return 1
}

# ===== find helpers =====
dir_has_wordlists(){
  local base="$1"
  /usr/bin/find "$base" -type f \( \
    -iname "*.txt" -o -iname "*.lst" -o -iname "*.list" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.words" -o -iname "*.cfg" -o \
    -iname "*.7z" -o -iname "*.zip" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.xz" -o -iname "*.gz" \
  \) -quit >/dev/null 2>&1
}

discover_candidates(){
  declare -A seen=()
  local r d
  for r in "${ROOTS[@]}"; do
    [[ -d "$r" ]] || { log debug "Пропуск корня (нет каталога): $r"; continue; }
    # root itself
    if ! is_excluded "$r" && dir_has_wordlists "$r"; then seen["$r"]=1; fi
    # subdirs up to MAX_DEPTH
    while IFS= read -r d; do
      [[ -d "$d" ]] || continue
      is_excluded "$d" && continue
      dir_has_wordlists "$d" && seen["$d"]=1
    done < <(/usr/bin/find "$r" -mindepth 1 -maxdepth "$MAX_DEPTH" -type d -print 2>/dev/null)
  done
  for d in "${!seen[@]}"; do printf '%s\0' "$d"; done
}

# ===== fingerprints =====
fingerprint_fast(){
  local base="$1"
  /usr/bin/find "$base" -type f \( \
    -iname "*.txt" -o -iname "*.lst" -o -iname "*.list" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.words" -o -iname "*.cfg" -o \
    -iname "*.7z" -o -iname "*.zip" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.xz" -o -iname "*.gz" \
  \) -printf '%P\t%s\t%T@\n' 2>/dev/null \
  | /usr/bin/sort | /usr/bin/sha256sum | /usr/bin/awk '{print $1}'
}

fingerprint_slow(){
  local base="$1" out_manifest; out_manifest="$(/usr/bin/mktemp -t wl_manifest.XXXXXX)"

  # Собираем файлы и считаем по каждому: hash  rel  size  mtime
  /usr/bin/find "$base" -type f \( \
    -iname "*.txt" -o -iname "*.lst" -o -iname "*.list" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.words" -o -iname "*.cfg" -o \
    -iname "*.7z" -o -iname "*.zip" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.xz" -o -iname "*.gz" \
  \) -print0 2>/dev/null \
  | /usr/bin/xargs -0 -r -P "${PARALLEL}" -I {} /bin/sh -c '
      f="$1"; base="$2"
      # относительный путь
      case "$f" in
        "$base"/*) rel="${f#"$base"/}" ;;
        *)         rel="$f" ;;
      esac
      h=$(/usr/bin/sha256sum -- "$f" 2>/dev/null | /usr/bin/awk "{print \$1}")
      s=$(/usr/bin/stat -c "%s" -- "$f" 2>/dev/null || echo 0)
      m=$(/usr/bin/stat -c "%Y" -- "$f" 2>/dev/null || echo 0)
      /usr/bin/printf "%s\t%s\t%s\t%s\n" "$h" "$rel" "$s" "$m"
    ' _ {} "$base" >> "$out_manifest"

  # Если удалось нагенерить строки — сворачиваем в один хэш
  if [[ -s "$out_manifest" ]]; then
    /usr/bin/sort "$out_manifest" | /usr/bin/sha256sum | /usr/bin/awk '{print $1}'
  fi
  /usr/bin/rm -f -- "$out_manifest"
}

calc_dir_metrics_and_fingerprint(){
  local src_dir="$1" mode="$2"
  # list files
  mapfile -d '' files < <(
    /usr/bin/find "$src_dir" -type f \( \
      -iname "*.txt" -o -iname "*.lst" -o -iname "*.list" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.words" -o -iname "*.cfg" -o \
      -iname "*.7z" -o -iname "*.zip" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.xz" -o -iname "*.gz" \
    \) -print0 2>/dev/null
  )
  local file_count="${#files[@]}"
  (( file_count < MIN_FILES_PER_SOURCE )) && { echo "SKIP"; return; }

  local total_size; total_size="$(/usr/bin/du -sb --apparent-size -- "$src_dir" 2>/dev/null | /usr/bin/awk '{print $1}')" || total_size=0

  local latest_epoch="0"
  if (( file_count > 0 )); then
    latest_epoch="$(
      printf '%s\0' "${files[@]}" \
      | /usr/bin/xargs -0 /usr/bin/stat -c '%Y' 2>/dev/null \
      | /usr/bin/sort -n | /usr/bin/tail -1
    )"
    latest_epoch="${latest_epoch:-0}"
  fi
  local latest_iso=""
  [[ "$latest_epoch" != "0" ]] && latest_iso="$(/usr/bin/date -u -d "@$latest_epoch" '+%Y-%m-%dT%H:%M:%SZ')"

  # since filter: if set, skip sources with latest_epoch < since_epoch
  if [[ -n "$SINCE_ISO" ]]; then
    local since_epoch; since_epoch="$(iso_to_epoch "$SINCE_ISO")"
    if [[ -z "$latest_epoch" ]] || (( latest_epoch < since_epoch )); then
      echo "SKIP_SINCE"
      return
    fi
  fi

  local fp
  if [[ "$mode" == "full" ]]; then fp="$(fingerprint_slow "$src_dir")"; else fp="$(fingerprint_fast "$src_dir")"; fi

  local source_name; source_name="$(/usr/bin/basename "$src_dir")"
  printf '%s|%s|%s|%s|%s|%s\n' "$source_name" "$src_dir" "$file_count" "$total_size" "$latest_iso" "$fp"
}

# ===== dedupe helper =====
# inputs: an array of paths; produce list filtered by dedupe mode
dedupe_paths_by_name(){
  local -n _in=$1
  declare -A best
  local p name
  for p in "${_in[@]}"; do
    name="$(/usr/bin/basename "$p")"
    if [[ -z "${best[$name]+x}" ]]; then
      best["$name"]="$p"
    else
      case "$DEDUPE_MODE" in
        system)
          # prefer /usr/share/seclists
          if [[ "${best[$name]}" == /usr/share/seclists/* ]]; then
            : # keep existing
          elif [[ "$p" == /usr/share/seclists/* ]]; then
            best["$name"]="$p"
          fi
          ;;
        thirdparty)
          if [[ "${best[$name]}" == */_3rdparty/* ]]; then
            : # keep existing
          elif [[ "$p" == */_3rdparty/* ]]; then
            best["$name"]="$p"
          fi
          ;;
        *)
          # none: keep first
          ;;
      esac
    fi
  done
  # output
  local out=()
  for name in "${!best[@]}"; do out+=("${best[$name]}"); done
  printf '%s\0' "${out[@]}"
}

# ===== main run mode =====
run_mode(){
  local MODE="$1"
  local REPORT PREV_CSV TMP_REPORT JSON_REPORT
  if [[ "$MODE" == "full" ]]; then REPORT="$FULL_REPORT"; else REPORT="$LIGHT_REPORT"; fi
  PREV_CSV="$REPORT"
  JSON_REPORT="${REPORT%.csv}.json"
  TMP_REPORT="$(/usr/bin/mktemp -t wl_report.XXXXXX.csv)"

  ensure_dir "$REPORT"
  local SCAN_TIME_ISO; SCAN_TIME_ISO="$(now_iso)"

  # load prev fingerprints
  load_prev_fingerprints "$PREV_CSV"
  declare -A seen_now=()

  # gather candidates safely
  local -a candidates=()
  mapfile -d '' candidates < <(discover_candidates) || true
  log debug "Кандидатов найдено: ${#candidates[@]}"

  # apply dedupe if requested
  if [[ "$DEDUPE_MODE" != "none" && ${#candidates[@]} -gt 0 ]]; then
    mapfile -d '' -t tmp < <(dedupe_paths_by_name candidates)
    candidates=("${tmp[@]}")
    log debug "Кандидатов после dedupe: ${#candidates[@]}"
  fi

  # if no candidates
  if (( ${#candidates[@]} == 0 )); then
    if [[ -s "$PREV_CSV" ]]; then
      log warn "Кандидатов 0 — оставляю предыдущий отчёт как есть: $PREV_CSV"
      if [[ "$DRY_RUN" == "true" ]]; then
        log info "[dry-run] Would keep existing: $PREV_CSV"
        return 0
      else
        /usr/bin/tail -n 4 -- "$PREV_CSV" || true
        return 0
      fi
    else
      # no prev and none found => write header only (unless dry-run)
      echo "SourceName,SourcePath,FileCount,TotalSizeBytes,LatestChangeISO,ScanTimeISO,Status,Fingerprint" > "$TMP_REPORT"
      if [[ "$DRY_RUN" == "true" ]]; then
        log info "[dry-run] Would write header to $REPORT"
        /usr/bin/rm -f -- "$TMP_REPORT"
        return 0
      else
        /usr/bin/mv -f -- "$TMP_REPORT" "$REPORT"
        /usr/bin/chmod 0644 -- "$REPORT"
        /usr/bin/tail -n 4 -- "$REPORT" || true
        log info "Строк записано (включая заголовок): $(/usr/bin/wc -l < "$REPORT")"
        log info "Готово: $REPORT"
        return 0
      fi
    fi
  fi

  # have candidates -> create header
  echo "SourceName,SourcePath,FileCount,TotalSizeBytes,LatestChangeISO,ScanTimeISO,Status,Fingerprint" > "$TMP_REPORT"

  local dir line NAME PATH FILES TOTAL_SIZE LATEST_ISO FP STATUS
  for dir in ${candidates[@]+"${candidates[@]}"}; do
    [[ -d "$dir" ]] || continue
    line="$(calc_dir_metrics_and_fingerprint "$dir" "$MODE")" || line="SKIP"
    [[ "$line" == "SKIP" ]] && continue
    [[ "$line" == "SKIP_SINCE" ]] && continue
    IFS='|' read -r NAME PATH FILES TOTAL_SIZE LATEST_ISO FP <<< "$line"

    STATUS="No Changes"
    if [[ -n "$FP" ]]; then
      if [[ -z "${prev_fp["$PATH"]+x}" ]]; then
        STATUS="New"
      else
        [[ "${prev_fp["$PATH"]}" == "$FP" ]] && STATUS="No Changes" || STATUS="Updated"
      fi
    fi

    seen_now["$PATH"]=1
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "$(csv_escape "$NAME")" \
      "$(csv_escape "$PATH")" \
      "$(csv_escape "$FILES")" \
      "$(csv_escape "$TOTAL_SIZE")" \
      "$(csv_escape "$LATEST_ISO")" \
      "$(csv_escape "$SCAN_TIME_ISO")" \
      "$(csv_escape "$STATUS")" \
      "$(csv_escape "$FP")" \
      >> "$TMP_REPORT"
  done

  # Removed entries from prev that aren't seen now (but only if not filtered by --since)
  local old_path base
  for old_path in "${!prev_fp[@]}"; do
    if [[ -z "${seen_now["$old_path"]+x}" ]]; then
      # if since filter is set and old_path's latest change is before since, we still may want to report Removed
      base="$(/usr/bin/basename "$old_path")"
      printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(csv_escape "$base")" \
        "$(csv_escape "$old_path")" \
        "" "" "" \
        "$(csv_escape "$SCAN_TIME_ISO")" \
        "$(csv_escape "Removed")" \
        "$(csv_escape "${prev_fp["$old_path"]}")" \
        >> "$TMP_REPORT"
    fi
  done

  # write out (or dry-run)
  if [[ "$DRY_RUN" == "true" ]]; then
    log info "[dry-run] Would write $TMP_REPORT -> $REPORT"
    /usr/bin/rm -f -- "$TMP_REPORT"
  else
    /usr/bin/mv -f -- "$TMP_REPORT" "$REPORT"
    /usr/bin/chmod 0644 -- "$REPORT"
    log info "Строк записано (включая заголовок): $(/usr/bin/wc -l < "$REPORT")"
    /usr/bin/tail -n 4 -- "$REPORT" || true
  fi

  # JSON output if requested
  if [[ "$OUT_FORMAT" == "json" || "$OUT_FORMAT" == "both" ]]; then
    JSON_REPORT="${REPORT%.csv}.json"
    log debug "Building JSON: $JSON_REPORT"
    # simple conversion (do not rely on heavy quoting since CSV already escaped)
    awk -F',' 'NR>1{
      gsub(/(^"|"$)/,"",$0);
      # naive split respecting CSV quoting already removed
      name=$1; path=$2; files=$3; size=$4; latest=$5; scan=$6; status=$7; fp=$8;
      # remove surrounding quotes if present
      for(i=1;i<=8;i++){ gsub(/^"|"$/,"",$i) }
      printf "%s{\"SourceName\":\"%s\",\"SourcePath\":\"%s\",\"FileCount\":%s,\"TotalSizeBytes\":%s,\"LatestChangeISO\":\"%s\",\"ScanTimeISO\":\"%s\",\"Status\":\"%s\",\"Fingerprint\":\"%s\"}\n",(NR==2?"[":","),$1,$2,$3,$4,$5,$6,$7,$8
    } END{ if (NR>1) print "]" }' "$REPORT" > "$JSON_REPORT" 2>/dev/null || {
      log warn "JSON conversion failed; file left untouched"
    }
  fi

  log info "Готово: $REPORT"
}

# ===== menu =====
show_menu(){
  echo
  echo "Выберите режим анализа:"
  echo "  1) Light (быстро, по метаданным) -> ${LIGHT_REPORT}"
  echo "  2) Full  (медленно, по содержимому) -> ${FULL_REPORT}"
  echo "  q) Выход без запуска"
  echo -n "Ваш выбор [1/2/q]: "
}

main(){
  ensure_dir "$LIGHT_REPORT"
  ensure_dir "$FULL_REPORT"

  if [[ -n "${MODE:-}" ]]; then
    case "$MODE" in
      light|full) run_mode "$MODE"; exit 0 ;;
      *) echo "ERR: Некорректный --mode: $MODE" >&2; exit 2 ;;
    esac
  fi

  show_menu
  read -r choice
  case "$choice" in
    1) run_mode light ;;
    2) run_mode full ;;
    q|Q) echo "Отменено."; exit 0 ;;
    *) echo "Неверный выбор. Повторите запуск."; exit 1 ;;
  esac
}

main
