# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup — A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent — safe to run multiple times

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-07: Issues #1, #4, #5, #6, #7, #9 — Core Linux/macOS setup scripts implemented

Implemented the full installer suite on branch `squad/1-linux-core-setup` (based on Mickey's `squad/3-os-detection-entry-point`):

- `scripts/linux/setup.sh` — orchestrator: platform detection, apt/brew prerequisites, runs all tools, hooks dotfiles
- `scripts/linux/tools/zsh.sh` — installs zsh via apt/brew, sets as default shell (idempotent `$SHELL` check)
- `scripts/linux/tools/uv.sh` — installs uv via official installer, exports `~/.local/bin` to PATH
- `scripts/linux/tools/nvm.sh` — fetches latest nvm release tag from GitHub API, installs, sources in session, installs Node LTS
- `scripts/linux/tools/gh.sh` — uses GitHub's official apt keyring on Linux; brew on macOS
- `scripts/linux/tools/copilot-cli.sh` — installs `gh-copilot` extension; gracefully skips if gh not installed or not authenticated

All scripts: `set -euo pipefail`, idempotency guard at top, consistent log helpers.
WSL treated as Linux throughout — no special-casing needed beyond what Mickey already handles in root `setup.sh`.
