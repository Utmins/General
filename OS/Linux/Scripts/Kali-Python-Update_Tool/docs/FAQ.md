# FAQ / Troubleshooting

**Q: Will this break system Python packages?**  
A: No. The script detects APT-managed dists (`/usr/lib/pythonX/dist-packages`) and does not update them with `pip`.

**Q: I saw `PEP 668` warnings. What now?**  
A: Either allow the script to add `--break-system-packages` (default) or activate a virtualenv to avoid system site-packages.

**Q: Where does `pipx` install apps?**  
A: Into isolated environments under `~/.local/pipx/venvs`, with shims in `~/.local/bin`.

**Q: Can I use this on non-Kali Debian/Ubuntu?**  
A: Yes, as long as APT is present. It also runs fine inside WSL (Ubuntu/Kali).

**Q: How to revert an upgrade?**  
A: Use your project lockfile (`poetry.lock`/`Pipfile.lock`) or reinstall a specific version:
```bash
pip install <pkg>==<version> --upgrade --force-reinstall
```
