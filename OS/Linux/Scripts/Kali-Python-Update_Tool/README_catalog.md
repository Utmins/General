# Kali Python/Pip Updater — Catalog Summary

A bootstrap-and-update helper for Python on Kali/Debian/Ubuntu. Installs `python3`, `pip`, `pipx`, and popular managers (pip-review, pipenv, poetry, virtualenv, pip-tools, uv), then updates user-managed packages safely.

**Usage:**
```bash
./kali_python_update_new.sh            # interactive (default)
./kali_python_update_new.sh --auto     # non-interactive
```

**Highlights:** PEP 668 aware, avoids touching APT-managed dists, adds PATH for pipx automatically, detailed logs and safety checks.
