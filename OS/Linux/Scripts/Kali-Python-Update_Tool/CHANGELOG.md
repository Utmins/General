# Changelog

## [2025-09-19] v1.0.0
- Initial public release of **Kali Python/Pip Updater** with toolchain bootstrap.
- Includes automatic detection/installation of python3, pip/pipx, and a curated set of Python package managers (pip-review, pipenv, poetry, virtualenv, pip-tools, uv).
- Supports `--auto` (non-interactive) and `--interactive` (guided) modes.
- Safe fallback when `pip-review` is unavailable: use pure `pip` with PEP 668 awareness.
- Adds PATH for `pipx` to shell profile when needed.
