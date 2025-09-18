# config.example.sh — пример файла конфигурации.
# Скопируй как /etc/update-wordlists.conf или source в своей обёртке перед запуском.

# Каталоги и отчёты
REPORT_DIR="$HOME/Git_Update_Reports"
SEARCH_DIRS=("$HOME" "/usr/share/wordlists" "/opt")
PRUNE_DIRS=(/proc /sys /dev /run /boot/efi /lost+found /var/cache /var/tmp /tmp /var/lib/docker /var/lib/containers /var/lib/snapd /snap)
WORDLISTS_DIR="/usr/share/wordlists/_3rdparty"
LINK_TARGET="/usr/share/wordlists/_all-links"

# Флаги по умолчанию
SHOW_MENU=true
DRY_RUN=false
SCAN_SYSTEM=true
CROSS_FS=false
LINK_ALL=true
LINKS_ONLY_TXT=false
LINKS_INCLUDE_ARCH=true
LINKS_DEDUP=true
DEDUP_PREFER_APT=true
APPLY_CHANGES=false
AUTOCLEAN_MATRYOSHKA=true
SKIP_ZIP_BOMBS=true
APT_BOOTSTRAP=false
INCLUDE_ASSETNOTE=true

# Параметры git/timeout
GIT_CLONE_DEPTH=1
GIT_TIMEOUT=300
