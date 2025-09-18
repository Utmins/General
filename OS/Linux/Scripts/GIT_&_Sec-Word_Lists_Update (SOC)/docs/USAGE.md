# Usage & Options

The script provides an **interactive menu** and **CLI flags**. Interactive menu toggles mirror CLI flags.

## Menu Options (mirror to flags)
- Toggle **DRY-RUN** — preview actions without changing the system (`--dry-run`).
- Toggle **System-wide scan** — search Git repos across `/` with pruning (`--no-system` to disable system scan).
- Toggle **Cross-filesystems** — follow mount points (`--all-mounts`).
- Toggle **Link all wordlists** — create `/usr/share/wordlists/_all-links` with symlinks to found wordlists (`--link-all` / `--no-link-all`).
- Toggle **Links: only text** — restrict to `.txt`, `.lst`, `.dic`, `.wordlist`, `.json` (`--links-only-txt`).
- Toggle **Links: include archives** — also include archives (`--links-include-archives`).
- Toggle **Links: deduplicate** — avoid duplicate link names (`--links-dedup` / `--no-links-dedup`).
- Toggle **Dedup: prefer APT** — prefer distro packages over Git duplicates (`--dedup-prefer-apt` / `--no-dedup-prefer-apt`).
- Toggle **Apply deletions** — actually remove Git duplicates when dedup is enabled (`--apply` / `--no-apply`).
- Toggle **Autoclean matryoshka** — remove extracted top-level dirs that contain only archives (`--autoclean-matryoshka` / `--no-autoclean-matryoshka`).
- Toggle **Skip Zip-Bombs** — avoid extracting any path under `SecLists/Payloads/Zip-Bombs` (`--skip-zip-bombs`).
- Toggle **APT bootstrap** — install core tooling via apt and prime `rockyou.txt` (`--apt-bootstrap` / `--no-apt-bootstrap`).
- Toggle **Include assetnote** — also clone `assetnote/wordlists` (`--include-assetnote` / `--no-include-assetnote`).
- **Run now** — start with current settings.
- **Quit** — exit without running.

## Key Behaviors
- **Repo updates as owner**: each discovered Git repo is pulled using the repo owner account.
- **Third‑party wordlists** cloned into `/usr/share/wordlists/_3rdparty`.
- **Auto‑decompression** of `.tar.gz/.tgz` and single `.gz` under `/usr/share/wordlists`.
- **Matryoshka autoclean**: if a top-level extracted dir contains only archives, it can be auto‑removed.
- **One-stop link hub**: `_all-links` collects symlinks to wordlists from system paths to simplify tool configs.
- **Dedup APT vs GIT**: generates report and (optionally) removes Git duplicate repos if an APT package provides similar content.
- **Clean logging**: terminal is colorized; logs are ANSI‑stripped and saved to `~/Git_Update_Reports/run_<timestamp>.txt`.

## Example Workflows
- **Blue-team lab refresh**
  ```bash
  sudo ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --apt-bootstrap --include-assetnote
  ```
- **Forensic-safe preview**
  ```bash
  ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --dry-run
  ```
- **Daily maintenance (apply dedup)**
  ```bash
  sudo ./Purple_GIT_&_Sec-Word_Lists_Update_v8.sh --no-menu --links-dedup --dedup-prefer-apt --apply
  ```

## Requirements
- Bash 5+, GNU coreutils, `git`, `sudo`.
- APT-based distro for bootstrap (Kali/Ubuntu/Debian). Non-APT systems will skip bootstrap gracefully.
- Run with `sudo` for system-wide scans, cloning to `/usr/share/wordlists`, and symlink creation.

## Notes
- Zip-bombs in SecLists are skipped if `--skip-zip-bombs` is set.
- The script prunes sensitive/system dirs when scanning `/` and can be limited to user paths by disabling system-wide scan.
