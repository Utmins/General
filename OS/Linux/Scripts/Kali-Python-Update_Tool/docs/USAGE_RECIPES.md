# Usage Recipes & Tips

## Operate in a Virtual Environment
```bash
python3 -m venv .venv
source .venv/bin/activate
./kali_python_update_new.sh --interactive
```

## Audit Without Changing Anything
```bash
./kali_python_update_new.sh --no-bootstrap --interactive
# Review outdated list; quit without confirming updates.
```

## CI/CD-friendly Auto Updates
Use `--auto` inside a controlled environment (e.g., a nightly container job) and pin versions via `pip-tools` for production repos.
