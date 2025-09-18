#!/bin/bash
# update_git_and_wordlists_pentest.sh
# Pentest-oriented build of Purple_GIT_&_Sec-Word_Lists_Update (no-CSV)
# - Focused on web/content discovery & injection payload lists used in pentesting

set -euo pipefail

# ===== Colors (TTY only) =====
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_INFO=$'\033[36m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'
else
  C_RESET=""; C_OK=""; C_INFO=""; C_WARN=""; C_ERR=""
fi

# ===== Logging =====
REPORT_DIR="$HOME/Git_Update_Reports"
TS="$(date +%Y-%m-%d_%H-%M-%S)"
RUN_LOG="$REPORT_DIR/run_${TS}.txt"
mkdir -p "$REPORT_DIR"

# ===== Defaults =====
SHOW_MENU=true
DRY_RUN=false
SCAN_SYSTEM=true
CROSS_FS=false
LINK_ALL=true
LINKS_ONLY_TXT=false
LINKS_INCLUDE_ARCH=true
LINKS_DEDUP=true
DEDUP_PREFER_APT=true
APPLY_CHANGES=true
AUTOCLEAN_MATRYOSHKA=true
SKIP_ZIP_BOMBS=false
APT_BOOTSTRAP=false
INCLUDE_ASSETNOTE=true   # Pentest flavor: include Assetnote by default

# ===== CLI flags =====
for arg in "$@"; do
  [[ -z "$arg" ]] && continue
  case "$arg" in
    --no-menu) SHOW_MENU=false ;;
    --dry-run) DRY_RUN=true ;;
    --no-system) SCAN_SYSTEM=false ;;
    --all-mounts) CROSS_FS=true ;;
    --link-all) LINK_ALL=true ;;
    --no-link-all) LINK_ALL=false ;;
    --links-only-txt) LINKS_ONLY_TXT=true ;;
    --links-include-archives) LINKS_INCLUDE_ARCH=true ;;
    --links-dedup) LINKS_DEDUP=true ;;
    --no-links-dedup) LINKS_DEDUP=false ;;
    --dedup-prefer-apt) DEDUP_PREFER_APT=true ;;
    --no-dedup-prefer-apt) DEDUP_PREFER_APT=false ;;
    --apply) APPLY_CHANGES=true ;;
    --no-apply) APPLY_CHANGES=false ;;
    --autoclean-matryoshka) AUTOCLEAN_MATRYOSHKA=true ;;
    --no-autoclean-matryoshka) AUTOCLEAN_MATRYOSHKA=false ;;
    --skip-zip-bombs) SKIP_ZIP_BOMBS=true ;;
    --apt-bootstrap) APT_BOOTSTRAP=true ;;
    --no-apt-bootstrap) APT_BOOTSTRAP=false ;;
    --include-assetnote) INCLUDE_ASSETNOTE=true ;;
    --no-include-assetnote) INCLUDE_ASSETNOTE=false ;;
    -h|--help) sed -n '1,240p' "$0"; exit 0 ;;
    *) echo "${C_WARN}[i] Unknown flag: $arg${C_RESET}" ;;
  esac
done

# ===== Config =====
SEARCH_DIRS=("$HOME" "/usr/share/wordlists" "/opt")
PRUNE_DIRS=(/proc /sys /dev /run /boot/efi /lost+found /var/cache /var/tmp /tmp /var/lib/docker /var/lib/containers /var/lib/snapd /snap)

# Pentest-focused wordlist/payload repos
declare -A WORDLIST_REPOS=(
  # Core pentest lists
  ["SecLists"]="https://github.com/danielmiessler/SecLists.git"
  ["PayloadsAllTheThings"]="https://github.com/swisskyrepo/PayloadsAllTheThings.git"
  ["FuzzDB"]="https://github.com/fuzzdb-project/fuzzdb.git"

  # Focused payload sets (payloadbox)
  ["SQLi-Payloads"]="https://github.com/payloadbox/sql-injection-payload-list.git"
  ["XSS-Payloads"]="https://github.com/payloadbox/xss-payload-list.git"
  #["LFI-Payloads"]="https://github.com/payloadbox/lfi-payload-list.git"
  #["SSRF-Payloads"]="https://github.com/payloadbox/ssrf-payload-list.git"
  ["SSTI-Payloads"]="https://github.com/payloadbox/ssti-payloads.git"
  ["XXE-Payloads"]="https://github.com/payloadbox/xxe-injection-payload-list.git"
  #["Path-Traversal-Payloads"]="https://github.com/payloadbox/path-traversal-lfi-wordlist.git"

  # Discovery / content wordlists
  ["Probable-Wordlists"]="https://github.com/berzerk0/Probable-Wordlists.git"
  ["DirBuster-Wordlists"]="https://github.com/daviddias/node-dirbuster.git"
  # Assetnote (toggleable below)
)

# ===== Helpers =====
onoff(){ [[ "$1" == true ]] && printf "ON " || printf "OFF"; }
printf_cfg_line(){ printf "  [%-3s] %-26s — %s\n" "$(onoff "$1")" "$2" "$3"; }
tty_clear(){ [[ -t 1 ]] && printf '\033[H\033[2J\033[3J'; }

norm_name() {
  local s="${1,,}"; local orig="$s"
  s="${s##*/}"; s="${s%.git}"; s="${s// /-}"; s="${s//_/ -}"
  s="${s//wordlists/}"; s="${s//wordlist/}"; s="${s//-lists/}"; s="${s//-list/}"
  s="${s//payloads/}"; s="${s//dirbuster/dirb}"
  s="${s//[^a-z0-9.+-]/-}"; s="${s//--*/-}"; s="${s##-}"; s="${s%%-}"
  [[ -n "$s" ]] || s="$orig"; echo "$s"
}

map_git_to_apt() {
  case "$1" in
    node-dirbuster|dirbuster) echo "dirb" ;;
    seclists) echo "seclists" ;;
    fuzzdb) echo "fuzzdb" ;;
    amass) echo "amass" ;;
    gobuster) echo "gobuster" ;;
    wfuzz) echo "wfuzz" ;;
    feroxbuster) echo "feroxbuster" ;;
    nikto) echo "nikto" ;;
    dnsrecon) echo "dnsrecon" ;;
    dnsenum) echo "dnsenum" ;;
    dnsmap) echo "dnsmap" ;;
    hashcat) echo "hashcat" ;;
    john) echo "john" ;;
    cewl) echo "cewl" ;;
    payloadsallthethings|assetnote-wordlists|assetnote) echo "" ;;
    *) echo "" ;;
  esac
}

is_zipbomb_path() {
  case "$1" in
    *"/SecLists/Payloads/Zip-Bombs/"*|*"/seclists/payloads/zip-bombs/"*) return 0;;
    *) return 1;;
  esac
}

contains_only_archives() {
  local d="$1"
  [[ -d "$d" ]] || return 1
  if sudo find "$d" -mindepth 1 -type d -print -quit 2>/dev/null | grep -q .; then
    return 1
  fi
  if ! sudo find "$d" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | grep -q .; then
    return 1
  fi
  if sudo find "$d" -mindepth 1 -maxdepth 1 -type f ! -iregex '.*\.\(tar\.gz\|tgz\|zip\|7z\|rar\|gz\)$' -print -quit 2>/dev/null | grep -q .; then
    return 1
  fi
  return 0
}

tar_topdir(){ tar -tzf "$1" 2>/dev/null | head -1 | cut -d/ -f1; }
is_recursive_tar(){
  local listing; listing="$(tar -tzf "$1" 2>/dev/null)" || return 1
  local nested_count; nested_count="$(echo "$listing" | grep -E '\.(tar\.gz|tgz)$' | wc -l | tr -d ' ')"
  local files_count; files_count="$(echo "$listing" | grep -v '/$' | wc -l | tr -d ' ')"
  [[ "$nested_count" == "1" && "$files_count" == "1" ]]
}

run_git_pull() {
  local repo="$1" owner output
  owner="$(stat -c %U "$repo" 2>/dev/null || echo root)"
  if sudo -u "$owner" git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    echo "    → pulling as ${owner} …"
    if $DRY_RUN; then
      echo "    ${C_INFO}[DRY-RUN] git -C \"$repo\" pull --rebase --autostash --ff-only${C_RESET}"
      return
    fi
    if output="$(sudo -u "$owner" git -C "$repo" pull --rebase --autostash --ff-only 2>&1)"; then
      [[ "$output" == *"Already up to date."* ]] && echo "    ${C_INFO}Already up to date${C_RESET}" || echo "    ${C_OK}Updated${C_RESET}"
    else
      echo "    ${C_WARN}Non-fast-forward or other issue${C_RESET}"
    fi
  else
    echo "    ${C_WARN}No remote (origin) — skipping${C_RESET}"
  fi
}

scan_dir_for_repos(){
  local base="$1"; [[ -d "$base" ]] || return 0
  echo ""; echo ">>> Checking directory: $base"
  while IFS= read -r -d '' gitdir; do
    local repo_dir; repo_dir="$(dirname "$gitdir")"
    echo ""; echo "[*] Repository: $repo_dir"
    run_git_pull "$repo_dir"
  done < <(sudo find "$base" -type d -name ".git" -print0 2>/dev/null)
}

link_all_wordlists() {
  local TARGET="/usr/share/wordlists/_all-links"
  echo ""; echo ">>> Linking all wordlists into: $TARGET"
  $DRY_RUN || sudo mkdir -p "$TARGET"

  local base_pred='
    -ipath "*/seclists/*" -o
    -ipath "*/payloadsallthethings/*" -o
    -ipath "*/fuzzdb/*" -o
    -ipath "*/dirb/wordlists/*" -o
    -ipath "*/dirbuster/*" -o
    -ipath "*/dirsearch/db/*" -o
    -ipath "*/wfuzz/wordlist/*" -o
    -ipath "*/feroxbuster/wordlists/*" -o
    -ipath "*/gobuster/*" -o
    -ipath "*/ffuf/*" -o
    -ipath "*/sqlmap/data/*" -o
    -ipath "*/metasploit-framework/data/wordlists/*" -o
    -ipath "*/nmap/nselib/data/*" -o
    -ipath "*/amass/wordlists/*" -o
    -ipath "*/dnsenum/*" -o
    -ipath "*/dnsmap/*" -o
    -ipath "*/dnsrecon/*" -o
    -ipath "*/nikto/*" -o
    -ipath "*/hashcat/*" -o
    -ipath "*/john/*" -o
    -iname "*wordlist*" -o
    -iname "*wordlists*" -o
    -iname "rockyou*"
  '

  local ext_pred=""
  if $LINKS_ONLY_TXT; then
    ext_pred+=' -iname "*.txt" -o -iname "*.lst" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.json" '
  fi
  if $LINKS_INCLUDE_ARCH; then
    [[ -n "$ext_pred" ]] && ext_pred+=" -o "
    ext_pred+=' -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" '
  fi
  if ! $LINKS_ONLY_TXT && ! $LINKS_INCLUDE_ARCH; then
    ext_pred=' -iname "*.txt" -o -iname "*.lst" -o -iname "*.dic" -o -iname "*.wordlist" -o -iname "*.json" -o -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" '
  fi

  local LINKED=0
  while IFS= read -r -d '' f; do
    local link_name rel base ext hash target_now
    if $LINKS_DEDUP; then
      base="$(basename "$f")"
      ext="${base##*.}"
      if [[ "$base" == "$ext" ]]; then ext=""; else ext=".$ext"; base="${base%$ext}"; fi
      link_name="${base}${ext}"
      if [[ -e "$TARGET/$link_name" && ! -L "$TARGET/$link_name" ]]; then
        hash="$(echo -n "$f" | md5sum | cut -c1-8)"
        link_name="${base}_${hash}${ext}"
      elif [[ -L "$TARGET/$link_name" ]]; then
        target_now="$(readlink -f "$TARGET/$link_name" || true)"
        [[ "$target_now" != "$f" ]] && { hash="$(echo -n "$f" | md5sum | cut -c1-8)"; link_name="${base}_${hash}${ext}"; }
      fi
    else
      rel="${f#/usr/share/}"; rel="${rel#/opt/}"
      link_name="$(echo "$rel" | tr '/ ' '__')"
    fi

    if $DRY_RUN; then
      echo "  ${C_INFO}[DRY-RUN] ln -s \"$f\" \"$TARGET/$link_name\"${C_RESET}"
    else
      sudo ln -sfn "$f" "$TARGET/$link_name" && ((LINKED++))
    fi
  done < <(
    eval sudo find /usr/share /opt/wordlists -type f \( $base_pred \) -a \( $ext_pred \) \
      ! -path "/usr/share/wordlists/_all-links/*" -print0 2>/dev/null
  )

  echo ">>> Linked files: $LINKED"
}

final_dup_report() {
  local report="$1"; shift
  echo "" | tee -a "$report"
  echo "=== Duplicate report (APT vs GIT) ===" | tee -a "$report"
  echo "Timestamp: $(date)" | tee -a "$report"
  declare -A APT_PKGS=() APT_IDX=()
  while IFS=$'\t' read -r pkg ver; do
    [[ -n "$pkg" ]] && APT_PKGS["$pkg"]="$ver"
  done < <(dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null || true)
  for p in "${!APT_PKGS[@]}"; do n="$(norm_name "$p")"; [[ -n "$n" && -z "${APT_IDX[$n]:-}" ]] && APT_IDX["$n"]="$p"; done
  declare -A GIT_REPOS=()
  collect_git_in(){ local base="$1"; [[ -d "$base" ]] || return 0
    while IFS= read -r -d '' g; do repo="${g%/.git}"; url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"; GIT_REPOS["$repo"]="$url"; done < <(find "$base" -type d -name .git -print0 2>/dev/null)
  }
  for r in "${SEARCH_DIRS[@]}"; do collect_git_in "$r"; done
  if $SCAN_SYSTEM; then
    XDEV=(); $CROSS_FS || XDEV=(-xdev)
    PRUNE_EXPR=(); for p in "${PRUNE_DIRS[@]}"; do PRUNE_EXPR+=( -path "$p" -prune -o ); done
    while IFS= read -r -d '' g; do repo="${g%/.git}"; url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"; GIT_REPOS["$repo"]="$url"; done < <(find / "${XDEV[@]}" \( "${PRUNE_EXPR[@]}" -name .git -type d -print0 \) 2>/dev/null)
  fi
  local dups=0
  for repo in "${!GIT_REPOS[@]}"; do
    url="${GIT_REPOS[$repo]}"; base="$(norm_name "${url:-$repo}")"; mapped="$(map_git_to_apt "$base")"; cand="$mapped"
    [[ -z "$cand" && -n "$base" ]] && cand="${APT_IDX[$base]:-}"
    if [[ -n "$cand" && -n "${APT_PKGS[$cand]:-}" ]]; then
      ((dups++)); apt_ver="${APT_PKGS[$cand]}"
      git_hash="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '-')"
      git_date="$(git -C "$repo" log -1 --date=short --format='%cd' 2>/dev/null || echo '-')"
      echo "" | tee -a "$report"
      echo "$((dups)). ${cand^}" | tee -a "$report"
      echo "   APT version: $apt_ver" | tee -a "$report"
      echo "   GIT version: commit $git_hash ($git_date)" | tee -a "$report"
      echo "   Path: $repo" | tee -a "$report"
      echo "   Recommended: keep APT, remove GIT" | tee -a "$report"
    fi
  done
  [[ $dups -eq 0 ]] && echo "No APT↔GIT duplicates detected." | tee -a "$report"
}

dedup_prefer_apt() {
  echo ""; echo ">>> Dedup: prefer APT over GIT"
  local REPORT="$REPORT_DIR/prefer_apt_over_git_${TS}.txt"
  : > "$REPORT"
  declare -A APT_PKGS=() APT_IDX=()
  while IFS=$'\t' read -r pkg ver; do [[ -n "$pkg" ]] && APT_PKGS["$pkg"]="$ver"; done < <(dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null || true)
  for p in "${!APT_PKGS[@]}"; do n="$(norm_name "$p")"; [[ -n "$n" && -z "${APT_IDX[$n]:-}" ]] && APT_IDX["$n"]="$p"; done
  declare -A GIT_REPOS=()
  collect_git_in(){ local base="$1"; [[ -d "$base" ]] || return 0
    while IFS= read -r -d '' g; do repo="${g%/.git}"; url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"; GIT_REPOS["$repo"]="$url"; done < <(find "$base" -type d -name .git -print0 2>/dev/null)
  }
  for r in "${SEARCH_DIRS[@]}"; do collect_git_in "$r"; done
  if $SCAN_SYSTEM; then
    XDEV=(); $CROSS_FS || XDEV=(-xdev)
    PRUNE_EXPR=(); for p in "${PRUNE_DIRS[@]}"; do PRUNE_EXPR+=( -path "$p" -prune -o ); done
    while IFS= read -r -d '' g; do repo="${g%/.git}"; url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"; GIT_REPOS["$repo"]="$url"; done < <(find / "${XDEV[@]}" \( "${PRUNE_EXPR[@]}" -name .git -type d -print0 \) 2>/dev/null)
  fi

  local -a to_remove=()
  local dups=0 keepers=0
  {
    echo "Report: prefer APT over GIT  $(date)"
    echo "Mode: $([ "$APPLY_CHANGES" = true ] && echo APPLY || echo DRY-RUN)"
    echo; echo "== Duplicates (APT preferred) =="
  } >> "$REPORT"

  for repo in "${!GIT_REPOS[@]}"; do
    url="${GIT_REPOS[$repo]}"; base="$(norm_name "${url:-$repo}")"; mapped="$(map_git_to_apt "$base")"; cand="$mapped"
    [[ -z "$cand" && -n "$base" ]] && cand="${APT_IDX[$base]:-}"
    if [[ -n "$cand" && -n "${APT_PKGS[$cand]:-}" ]]; then
      ((dups++))
      echo "- GIT: $repo  (origin: ${url:-none})" >> "$REPORT"
      echo "  APT: $cand  version: ${APT_PKGS[$cand]}" >> "$REPORT"
      echo "  Action: KEEP APT, REMOVE GIT" >> "$REPORT"; echo >> "$REPORT"
      to_remove+=("$repo")
    else
      ((keepers++))
    fi
  done

  {
    echo; echo "== Summary =="
    echo "APT packages: ${#APT_PKGS[@]}"
    echo "GIT repos:    ${#GIT_REPOS[@]}"
    echo "Duplicates (apt>git): $dups"
    echo "Git keepers (no apt): $keepers"
  } >> "$REPORT"

  final_dup_report "$REPORT"
  echo "${C_INFO}Dedup report saved to:${C_RESET} $REPORT"

  if $APPLY_CHANGES; then
    echo "${C_WARN}[APPLY] Removing ${#to_remove[@]} git duplicates…${C_RESET}"
    for repo in "${to_remove[@]}"; do
      echo " - rm -rf '$repo'"
      $DRY_RUN || rm -rf --one-file-system -- "$repo" || echo "${C_ERR}! Failed:${C_RESET} $repo"
      parent="$(dirname "$repo")"; $DRY_RUN || rmdir "$parent" 2>/dev/null || true
    done
    echo "${C_OK}Done.${C_RESET}"
  else
    echo "${C_INFO}[DRY-RUN] No removals. Use --apply with --dedup-prefer-apt to delete git duplicates.${C_RESET}"
  fi

  echo "${C_INFO}Run log saved to:${C_RESET} $RUN_LOG"
}

apt_bootstrap() {
  echo ""; echo ">>> APT bootstrap (tools + prime wordlists)"
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "${C_WARN}[i] apt-get is not available on this system — skipping bootstrap.${C_RESET}"
    return 0
  fi
  local -a CORE_PKGS=(
    seclists dirb wfuzz feroxbuster gobuster ffuf amass
    nikto dnsrecon dnsenum dnsmap hashcat john cewl
    nmap wordlists
  )
  local -a TO_INSTALL=()
  for p in "${CORE_PKGS[@]}"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then TO_INSTALL+=("$p"); fi
  done
  if ((${#TO_INSTALL[@]})); then
    if $DRY_RUN; then
      echo "  ${C_INFO}[DRY-RUN] apt-get update && apt-get install -y ${TO_INSTALL[*]}${C_RESET}"
    else
      echo "  [+] Installing: ${TO_INSTALL[*]}"
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${TO_INSTALL[@]}" || true
    fi
  else
    echo "  ${C_INFO}All core packages already present${C_RESET}"
  fi
  local ry="/usr/share/wordlists/rockyou.txt"
  local rygz="/usr/share/wordlists/rockyou.txt.gz"
  if [[ ! -f "$ry" && -f "$rygz" ]]; then
    if $DRY_RUN; then
      echo "  ${C_INFO}[DRY-RUN] gunzip -c \"$rygz\" > \"$ry\"${C_RESET}"
    else
      echo "  [+] Decompressing rockyou.txt.gz"
      sudo bash -c "gunzip -c \"$rygz\" > \"$ry\"" || true
    fi
  fi
}

print_config(){
  echo; echo "Current configuration:"
  printf_cfg_line "$DRY_RUN"               "DRY-RUN mode"               "'dry run' mode - commands are shown but not executed"
  printf_cfg_line "$SCAN_SYSTEM"           "System-wide scan"           "Search Git repos in the whole filesystem (pruned dirs)"
  printf_cfg_line "$CROSS_FS"              "Cross-filesystems"          "Follow mounts to other filesystems (NFS, USB, etc.)"
  printf_cfg_line "$LINK_ALL"              "Link all wordlists"         "Create one shared folder '_all-links' with all dictionaries (symlinks) to all found wordlists"
  printf_cfg_line "$LINKS_ONLY_TXT"        "Links: only text"           "Only .txt, .lst, .dic and similar text files will be included in symlinks"
  printf_cfg_line "$LINKS_INCLUDE_ARCH"    "Links: include archives"    "Also add archives (.gz, .zip, .tar.gz, etc.) to symlinks"
  printf_cfg_line "$LINKS_DEDUP"           "Links: deduplicate names"   "Remove duplicate file names in symlinks"
  printf_cfg_line "$DEDUP_PREFER_APT"      "Dedup: prefer APT over GIT" "If there is a duplicate dictionary both via apt and via git, leave the apt version"
  printf_cfg_line "$APPLY_CHANGES"         "Apply deletions (Dedup)"    "Actually remove GIT duplicates (otherwise just list)"
  printf_cfg_line "$AUTOCLEAN_MATRYOSHKA"  "Autoclean matryoshka"       "After extracting, delete top-level dir that contains only archives"
  printf_cfg_line "$SKIP_ZIP_BOMBS"        "Skip Zip-Bombs"             "Do not extract anything under SecLists/Payloads/Zip-Bombs"
  printf_cfg_line "$APT_BOOTSTRAP"         "APT bootstrap"              "Install via apt + prime wordlists (e.g., rockyou.txt)"
  printf_cfg_line "$INCLUDE_ASSETNOTE"     "Include assetnote"          "Add assetnote/wordlists to clones"
  echo
}

menu(){
  while true; do
    tty_clear
    echo "=== Update Git & Wordlists — Pentest Edition ==="
    print_config
    cat <<MENU
Choose an option:
  1) Toggle DRY-RUN                  — Switch dry-run mode on/off
  2) Toggle System-wide scan         — Enable/disable scan under /
  3) Toggle Cross-filesystems        — Enable/disable crossing mounts
  4) Toggle Link all wordlists       — Enable/disable symlink collection
  5) Toggle Links: only text         — Restrict symlinks to text files only
  6) Toggle Links: include archives  — Add archives to symlink collection
  7) Toggle Links: deduplicate       — Avoid duplicate names in _all-links
  8) Toggle Dedup: prefer APT        — Keep APT when APT & GIT both exist
  9) Toggle Apply deletions          — Delete GIT duplicates (with Dedup)
  a) Toggle Autoclean matryoshka     — Remove extracted dirs that contain only archives
  z) Toggle Skip Zip-Bombs           — Don't extract SecLists Zip-Bombs
  b) Toggle APT bootstrap            — Install via apt + prime symlinks
  n) Toggle Include assetnote        — Add assetnote/wordlists to clones
  r) Run now                         — Execute with current settings
  q) Quit                            — Exit without running
MENU
    read -rp "Select: " ans
    case "$ans" in
      1) DRY_RUN=$([[ $DRY_RUN == true ]] && echo false || echo true) ;;
      2) SCAN_SYSTEM=$([[ $SCAN_SYSTEM == true ]] && echo false || echo true) ;;
      3) CROSS_FS=$([[ $CROSS_FS == true ]] && echo false || echo true) ;;
      4) LINK_ALL=$([[ $LINK_ALL == true ]] && echo false || echo true) ;;
      5) LINKS_ONLY_TXT=$([[ $LINKS_ONLY_TXT == true ]] && echo false || echo true) ;;
      6) LINKS_INCLUDE_ARCH=$([[ $LINKS_INCLUDE_ARCH == true ]] && echo false || echo true) ;;
      7) LINKS_DEDUP=$([[ $LINKS_DEDUP == true ]] && echo false || echo true) ;;
      8) DEDUP_PREFER_APT=$([[ $DEDUP_PREFER_APT == true ]] && echo false || echo true) ;;
      9) APPLY_CHANGES=$([[ $APPLY_CHANGES == true ]] && echo false || echo true) ;;
      a|A) AUTOCLEAN_MATRYOSHKA=$([[ $AUTOCLEAN_MATRYOSHKA == true ]] && echo false || echo true) ;;
      z|Z) SKIP_ZIP_BOMBS=$([[ $SKIP_ZIP_BOMBS == true ]] && echo false || echo true) ;;
      b|B) APT_BOOTSTRAP=$([[ $APT_BOOTSTRAP == true ]] && echo false || echo true) ;;
      n|N) INCLUDE_ASSETNOTE=$([[ $INCLUDE_ASSETNOTE == true ]] && echo false || echo true) ;;
      r|R) break ;;
      q|Q) echo "Bye!"; exit 0 ;;
      *) echo "Unknown choice"; sleep 0.5 ;;
    esac
  done
}

echo "${C_INFO}Run date: $(date)${C_RESET}"
echo "${C_INFO}Run log will be saved to:${C_RESET} $RUN_LOG"

$SHOW_MENU && menu

# Apply Include Assetnote choice
if $INCLUDE_ASSETNOTE; then
  WORDLIST_REPOS["assetnote-wordlists"]="https://github.com/assetnote/wordlists.git"
fi

# Start logging after the menu
exec > >(tee >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "$RUN_LOG")) 2>&1

log_only(){ printf "%s\n" "$*" | sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "$RUN_LOG"; }

echo "${C_INFO}Starting with selected options...${C_RESET}"
$DRY_RUN && echo "${C_INFO}[i] DRY-RUN enabled — no changes will be made${C_RESET}"

# 0) APT bootstrap
if $APT_BOOTSTRAP; then apt_bootstrap; fi

# 1) Update git repos
for d in "${SEARCH_DIRS[@]}"; do scan_dir_for_repos "$d"; done
if $SCAN_SYSTEM; then
  echo ""; echo ">>> System-wide scan under / (with pruning)"
  echo "    Pruned: ${PRUNE_DIRS[*]}"
  PRUNE_EXPR=(); for p in "${PRUNE_DIRS[@]}"; do PRUNE_EXPR+=( -path "$p" -prune -o ); done
  XDEV_FLAG=(); $CROSS_FS || XDEV_FLAG=( -xdev )
  while IFS= read -r -d '' gitdir; do
    repo_dir="$(dirname "$gitdir")"
    echo ""; echo "[*] Repository: $repo_dir"
    run_git_pull "$repo_dir"
  done < <(sudo find / "${XDEV_FLAG[@]}" \( "${PRUNE_EXPR[@]}" -name .git -type d -print0 \) 2>/dev/null)
fi

# 2) Clone/update pentest wordlists
WORDLISTS_DIR="/usr/share/wordlists/_3rdparty"
echo ""; echo ">>> Target directory for extra wordlists: $WORDLISTS_DIR"
$DRY_RUN || sudo mkdir -p "$WORDLISTS_DIR"
for NAME in "${!WORDLIST_REPOS[@]}"; do
  DEST="$WORDLISTS_DIR/$NAME"
  if [[ -d "$DEST/.git" ]]; then
    echo ""; echo "[*] Updating $NAME..."
    if $DRY_RUN; then
      echo "    ${C_INFO}[DRY-RUN] git -C \"$DEST\" pull --rebase --autostash --ff-only${C_RESET}"
    else
      if output="$(sudo git -C "$DEST" pull --rebase --autostash --ff-only 2>&1)"; then
        [[ "$output" == *"Already up to date."* ]] && echo "    ${C_INFO}Already up to date${C_RESET}" || echo "    ${C_OK}Updated${C_RESET}"
      else
        echo "    ${C_WARN}Non-fast-forward or other issue${C_RESET}"
      fi
    fi
  else
    echo ""; echo "[+] Cloning $NAME..."
    if $DRY_RUN; then
      echo "    ${C_INFO}[DRY-RUN] git clone ${WORDLIST_REPOS[$NAME]} \"$DEST\"${C_RESET}"
    else
      sudo git clone --depth 1 "${WORDLIST_REPOS[$NAME]}" "$DEST" || echo "${C_WARN}Clone failed: $NAME${C_RESET}"
    fi
  fi
done

# 3) Auto-decompress (same as base)
echo ""; echo ">>> Auto-decompressing archives under /usr/share/wordlists ..."
declare -A __SEEN_TAR=()
declare -A __SEEN_GZ=()
DECOMP_ROOTS=("/usr/share/wordlists")
for ROOT in "${DECOMP_ROOTS[@]}"; do
  [[ -d "$ROOT" ]] || continue
  echo ">> Scanning: $ROOT"
  \
while IFS= read -r -d '' tgz; do
    rp="$(readlink -f "$tgz" 2>/dev/null || echo "$tgz")"
    if [[ -n "${__SEEN_TAR[$rp]:-}" ]]; then
      continue
    fi
    __SEEN_TAR[$rp]=1
    if $SKIP_ZIP_BOMBS && is_zipbomb_path "$tgz"; then
      log_only "  [=] Skipping Zip-Bombs path: $tgz"
      continue
    fi
    if [[ ! -f "$tgz" ]]; then
      log_only "  [=] Skipped (gone after cleanup): $tgz"
      continue
    fi
    if is_recursive_tar "$tgz"; then
      log_only "  [=] Skipping recursive archive (matryoshka candidate): $tgz"
      continue
    fi
    if $DRY_RUN; then
      echo "  ${C_INFO}[DRY-RUN] tar -xzf \"$tgz\" in place${C_RESET}"
    else
      dir="$(dirname "$tgz")"; base="$(basename "$tgz")"
      if [[ ! -d "$dir" ]]; then
        log_only "  [=] Skipped (parent removed): $tgz"
        continue
      fi
      echo "  [*] Extracting tar: $tgz"
      top="$(tar_topdir "$tgz")"
      sudo bash -c "cd \"$dir\" && tar -xzf \"$base\""
      if $AUTOCLEAN_MATRYOSHKA && [[ -n "$top" && -d "$dir/$top" ]]; then
        if contains_only_archives "$dir/$top"; then
          echo "  [-] Autoclean matryoshka (only archives inside): $dir/$top"
          sudo rm -rf --one-file-system -- "$dir/$top"
        fi
      fi
    fi
  done < <(sudo find "$ROOT" -type f \( -iname "*.tar.gz" -o -iname "*.tgz" \) -print0 2>/dev/null)

  while IFS= read -r -d '' gz; do
    rp="$(readlink -f "$gz" 2>/dev/null || echo "$gz")"
    if [[ -n "${__SEEN_GZ[$rp]:-}" ]]; then
      continue
    fi
    __SEEN_GZ[$rp]=1
    out="${gz%.gz}"
    [[ -d "$out" ]] && continue
    [[ -f "$out" ]] && continue
    if $DRY_RUN; then
      echo "  ${C_INFO}[DRY-RUN] gunzip -c \"$gz\" > \"$out\"${C_RESET}"
    else
      if sudo bash -c "gunzip -c \"$gz\" > \"$out\" 2>/dev/null"; then
        echo "  [+] Decompressing: $gz -> $out"
      fi
    fi
  done < <(sudo find "$ROOT" -type f -iname "*.gz" ! -iname "*.tar.gz" -print0 2>/dev/null)
done

# 4) Link-all
$LINK_ALL && link_all_wordlists

# 5) Dedup
if $DEDUP_PREFER_APT; then
  dedup_prefer_apt
else
  echo "${C_INFO}Run log saved to:${C_RESET} $RUN_LOG"
fi

echo ""; echo "${C_OK}=== All done. ===${C_RESET}"
echo "${C_INFO}Run log saved to:${C_RESET} $RUN_LOG"
