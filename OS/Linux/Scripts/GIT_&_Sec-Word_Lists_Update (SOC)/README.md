# Purple_GIT_&_Sec-Word_Lists_Update

All‑in‑one maintainer for **cybersecurity wordlists** and **Git repositories**. It updates existing repos (as the repo owner), clones popular wordlist collections, auto‑decompresses archives under `/usr/share/wordlists`, creates a unified `_all-links` hub of symlinks, and (optionally) **deduplicates** Git repos if the same assets are already provided by **APT packages**.

> Built from your uploaded script and packaged for GitHub distribution.  
> **Script file:** `Purple_GIT_&_Sec-Word_Lists_Update.sh`

---

## ✨ Features
- **Interactive TUI** + **CLI flags** for automation.
- **Update ALL git repos** across user/system paths, pulling as the repo owner.
- **Clone key wordlist repos** (SecLists, FuzzDB, PayloadsAllTheThings, etc.), with optional **Assetnote**.
- **Auto‑decompress** `.tar.gz/.tgz` and single `.gz` files within `/usr/share/wordlists`.
- **Zip‑bomb safety**: option to skip `SecLists/Payloads/Zip-Bombs` during extraction.
- **Matryoshka autoclean**: auto‑cleanup of extracted top-level dirs that contained only archives.
- **Unify access** via `/usr/share/wordlists/_all-links` symlinks (dedup names optional).
- **APT bootstrap**: install core tools and prime `rockyou.txt` on APT-based distros.
- **APT‑over‑GIT deduplicate** with report; optionally **apply** removals.

## ✅ Requirements
- Linux (tested on Kali, Ubuntu/Debian).
- `bash`, `git`, `sudo`, `tar`, `gzip`, `find`, `md5sum`.
- For APT bootstrap: `apt-get` available.

## 🚀 Quick Start
See [`docs/QUICKSTART.md`](docs/QUICKSTART.md).

## 📚 Full Usage & Flags
See [`docs/USAGE.md`](docs/USAGE.md). The interactive menu mirrors all flags.

## 🔧 Install (optional helper)
```bash
chmod +x INSTALL.sh
./INSTALL.sh /usr/local/bin
# Now run:
sudo /usr/local/bin/Purple_GIT_&_Sec-Word_Lists_Update.sh
```

## 🧪 Typical Scenarios
### 1) Blue‑team lab refresh
```bash
sudo ./Purple_GIT_&_Sec-Word_Lists_Update.sh --no-menu --apt-bootstrap --include-assetnote
```
### 2) Forensic‑safe preview
```bash
./Purple_GIT_&_Sec-Word_Lists_Update.sh --no-menu --dry-run
```
### 3) Daily maintenance with dedup
```bash
sudo ./Purple_GIT_&_Sec-Word_Lists_Update.sh --no-menu --links-dedup --dedup-prefer-apt --apply
```

## 📝 Logs & Reports
- Run logs: `~/Git_Update_Reports/run_<timestamp>.txt`
- Dedup report: `~/Git_Update_Reports/prefer_apt_over_git_<timestamp>.txt`

## 🛡️ Safety Notes
- Extraction under `/usr/share/wordlists` observes the Zip-bomb skip toggle.
- System-wide scans prune sensitive/system dirs; disable system scan to limit scope.
- **Dry‑run** is available for safe previews.

## 📦 What’s inside this repo package
- `Purple_GIT_&_Sec-Word_Lists_Update.sh` — main script
- `INSTALL.sh` — helper installer
- `docs/QUICKSTART.md`, `docs/USAGE.md`
- `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`
- `.gitignore`, `.editorconfig`
- `.github/workflows/shellcheck.yml`
- `.github/ISSUE_TEMPLATE/bug_report.yml`, `feature_request.yml`

## 🤝 Contributing
See [`CONTRIBUTING.md`](CONTRIBUTING.md). PRs welcome.

## 🔐 Security
See [`SECURITY.md`](SECURITY.md). Use responsibly and within the law.

---

### Credits
Script authored from the provided source; packaging and documentation prepared for repository publication.
