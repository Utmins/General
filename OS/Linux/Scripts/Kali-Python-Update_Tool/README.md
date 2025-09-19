# Kali Python/Pip Updater — with Toolchain Bootstrap

> One-command upkeep for your Python toolchain on Kali (and Debian/Ubuntu-like).  
> Installs `python3`, `pip`, `pipx`, and common dependency managers on demand, then updates your user-managed Python packages safely.

---

## ✨ Key Features

- **Bootstrap everything** you usually need for Python workflows:
  - Installs missing `python3`, `python3-pip`, `python3-venv` via APT.
  - Installs/configures **pipx** and ensures `~/.local/bin` is on your PATH.
  - Installs or upgrades **pip-review**, **pipenv**, **poetry**, **virtualenv**, **pip-tools**, **uv** using `pipx`.
- **Two modes** of package updating:
  - `--interactive` (default): review and choose updates with `pip-review --interactive`.
  - `--auto`: fire-and-forget updates with `pip-review --auto`.
- **Smart fallback** when `pip-review` is unavailable:
  - Enumerates Python distributions, separates **APT-managed** vs **pip-managed**.
  - Updates only **pip-managed** packages, **ignoring APT-managed** (`dist-packages`) to prevent conflicts.
  - **PEP 668 aware** — adds `--break-system-packages` only when needed and only if allowed.
- **Visibility of system state**:
  - Prints installed `python3-*` APT packages (via `dpkg-query`) for quick inspection.
  - Detects if you are in a virtualenv, explains what the update will affect.

---

## 📦 Files in this repository

- `kali_python_update_new.sh` — main script (as provided; preserved verbatim).
- `kali_python_update.sh` — convenience alias (same content).
- `README.md` — this detailed documentation.
- `README_catalog.md` — short catalog summary for higher-level directory readme.
- `CHANGELOG.md` — release notes.
- `LICENSE` — MIT license.
- `docs/QUICKSTART.md` — 60‑second start.
- `docs/FAQ.md` — frequent questions & troubleshooting.
- `docs/USAGE_RECIPES.md` — common workflows, tips, and examples.

Checksums:
```text
kali_python_update_new.sh  b0e444318e81c8231c898959f6cb317032ba61583730b4a6c84010cd7bd6b119
kali_python_update.sh      b0e444318e81c8231c898959f6cb317032ba61583730b4a6c84010cd7bd6b119
```

---

## 🔧 Requirements

- Kali Linux / Debian / Ubuntu (APT-based).
- Network access for initial bootstrap (unless everything is already installed).
- A user shell with write access to `~/.local/bin` and your shell rc (`.bashrc` or `.zshrc`).

---

## 🚀 Quick Start

```bash
chmod +x ./kali_python_update_new.sh
./kali_python_update_new.sh            # interactive by default
./kali_python_update_new.sh --auto     # non-interactive
```

> Tip: run with `--no-bootstrap` if you *only* want to update packages without installing any tooling.

---

## 🧭 CLI Options & Behavior (exhaustive)

```
Usage: ./kali_python_update_new.sh [--auto|--interactive] [--no-break] [--no-bootstrap]
```

### `--auto`  
Runs updates without prompts using `pip-review --auto` if available.  
If `pip-review` is missing, the fallback uses `pip` to update only user/venv-managed packages.

### `--interactive` *(default)*  
Launches `pip-review --interactive` so you can select which packages to update. Helpful when you want granular control.

### `--no-break`  
On systems with **PEP 668** (Externally Managed Environments) *outside* a virtualenv, pip operations may require `--break-system-packages`.
- With default settings, the script will **add** `--break-system-packages` **only when required**.
- With `--no-break`, the script will **not** add it, and pip may refuse to install/update. This is safer but may result in **errors**.

### `--no-bootstrap`  
Skips initial checks/installs for `python3`, `pip`, `pipx`, and the curated toolchain list. The script then attempts to proceed with whatever is already present.

---

## 🔍 How it Works (deep dive)

1. **Bootstrap (optional, default ON)**
   - Ensures `python3`, `python3-pip`, `python3-venv` via APT.
   - Installs `pipx` (APT preferred, pip fallback), places `~/.local/bin` on PATH, persists to `~/.bashrc` or `~/.zshrc`.
   - Installs or updates via `pipx`: `pip-review`, `pipenv`, `poetry`, `virtualenv`, `pip-tools`, `uv`.
2. **Primary path: `pip-review` (preferred)**
   - Prints outdated list (`pip-review --local`).
   - Runs `--interactive` or `--auto` as selected.
3. **Fallback path (no `pip-review`)**
   - Enumerates installed dists via `importlib.metadata`.
   - Classifies packages into **pip-managed** (user-site, `/usr/local`, inside venv) vs **APT-managed** (`/usr/lib/pythonX/dist-packages`).
   - Queries outdated **only** for pip-managed and upgrades them one by one with safer `--upgrade-strategy only-if-needed`.
   - Adds `--break-system-packages` **only** if PEP 668 applies *and* you didn’t disable it.
4. **Safety**
   - Never tries to pip‑update packages that are clearly APT-managed.
   - Advises using APT for `python3-*` when appropriate.

---

## 🧪 Usage Scenarios (recipes)

- **Daily maintenance (no prompts):**
  ```bash
  ./kali_python_update_new.sh --auto
  ```
- **Granular control:**
  ```bash
  ./kali_python_update_new.sh --interactive
  ```
- **Within a virtualenv (project‑local updates):**
  ```bash
  python3 -m venv .venv && source .venv/bin/activate
  ./kali_python_update_new.sh --interactive
  ```
- **Audit only (no bootstrap, just see outdated list):**
  ```bash
  ./kali_python_update_new.sh --no-bootstrap --interactive
  ```

---

## 🆘 Troubleshooting

- **`pipx: command not found` after install**  
  Open a new shell or run `source ~/.bashrc` (or `~/.zshrc`). The script also attempts to set PATH automatically.
- **APT errors (repo/lock)**  
  Ensure no other APT process runs; retry `sudo apt-get update`.
- **`pip` refuses due to PEP 668**  
  Re-run without `--no-break` or operate inside a virtual environment to avoid system site-packages.
- **Corporate proxy**  
  Export:
  ```bash
  export HTTP_PROXY=http://user:pass@proxy:port
  export HTTPS_PROXY=$HTTP_PROXY
  ```

---

## 🧰 Related Tools Installed (via `pipx`)

- **pip-review** — audit/update user-installed packages quickly (`--local`, `--auto`, `--interactive`).
- **pipenv** — virtualenv + lockfile workflow.
- **poetry** — modern dependency/packaging manager.
- **virtualenv** — create isolated environments (alternative to built-in `venv`).
- **pip-tools** — `pip-compile` & `pip-sync` for reproducible `requirements.txt` flows.
- **uv** — extremely fast Python package manager/installer.

---

## 🔐 Security Note

This script **never** performs system-wide destructive actions. It prefers user-space updates and avoids touching APT-managed dists. For system Python upgrades, use APT (`sudo apt update && sudo apt upgrade`).

---

## 📄 License

MIT — see [LICENSE](./LICENSE).

---

## 🙋 FAQ & Extended Guides

See [`docs/FAQ.md`](./docs/FAQ.md) and [`docs/USAGE_RECIPES.md`](./docs/USAGE_RECIPES.md). For a super‑short start, see [`docs/QUICKSTART.md`](./docs/QUICKSTART.md).
