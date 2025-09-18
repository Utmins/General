# Quick Start

```bash
# 1) Make executable and run (interactive menu)
chmod +x Purple_GIT_&_Sec-Word_Lists_Update_v8.sh
sudo ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh

# 2) Non-interactive common scenarios
# Update repos + clone 3rd-party + auto-decompress + link-all + dedup (APT preferred)
sudo ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --links-dedup --dedup-prefer-apt --apply

# With APT bootstrap and Assetnote lists
sudo ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --apt-bootstrap --include-assetnote

# Dry-run to preview actions
./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --dry-run
```
