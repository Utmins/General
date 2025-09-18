# Contributing

Thanks for your interest in contributing!

## Quick Start
- Run `shellcheck` locally before committing.
- Keep the script POSIX-ish where possible; bash features are fine (script requires bash).
- Avoid hardcoding paths — prefer variables and checks.
- Document new flags in **README.md**.

## Workflow
1. Fork the repo and create your branch from `main`.
2. Make your changes with clear commit messages.
3. Run style and lint checks.
4. Open a PR with a description, motivation, and testing notes.

## Coding Standards
- `set -euo pipefail`
- Functions: lower_snake_case
- User output must be clear and colorized only when TTY is detected.
- Log files **must not** contain ANSI escapes.

## Testing
- Dry-run mode must be supported for any destructive action.
- Test on Kali/Ubuntu; ensure graceful behavior on non-APT distros.
