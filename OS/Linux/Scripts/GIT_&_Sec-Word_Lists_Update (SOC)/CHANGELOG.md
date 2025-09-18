# Changelog

## v8
- Added toggle **APT bootstrap** — install core tools via `apt` and prime wordlists (e.g., `rockyou.txt`).
- Added toggle **Include assetnote** — optionally clone `assetnote/wordlists` into third‑party wordlists.
- Added CLI flags: `--apt-bootstrap` / `--no-apt-bootstrap`, `--include-assetnote` / `--no-include-assetnote`.
- Kept previous defaults intact (Zip-Bombs OFF by default, etc.).
- **no-CSV build:** removed generation of `wordlists_all_links_list.csv` and `_all-links_list.txt`.
- Hardened CLI args parsing to ignore empty args.
