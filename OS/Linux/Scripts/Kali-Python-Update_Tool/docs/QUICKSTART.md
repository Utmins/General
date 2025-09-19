# Quick Start

1. Make the script executable and run it:
   ```bash
   chmod +x ./kali_python_update_new.sh
   ./kali_python_update_new.sh
   ```

2. Prefer non-interactive maintenance?
   ```bash
   ./kali_python_update_new.sh --auto
   ```

3. Already have everything installed and just want updates?
   ```bash
   ./kali_python_update_new.sh --no-bootstrap --interactive
   ```

Notes:
- On first run, the script may add `~/.local/bin` to your PATH and install `pipx`.
- Use a virtualenv to keep project dependencies isolated.
