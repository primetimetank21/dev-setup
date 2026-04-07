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

## 2026-04-07 — Issue #12: CI Workflow for Script Validation

**Branch:** `squad/12-ci-workflow`
**PR:** https://github.com/primetimetank21/dev-setup/pull/20

**What was created:**
- `.github/workflows/validate.yml` with three jobs:
  1. `validate-linux`: Runs `setup.sh` on `ubuntu-latest`, validates zsh, uv, nvm, Node.js, npm, gh CLI are installed and on PATH, then runs setup a second time to confirm idempotency.
  2. `lint-shell-scripts`: Runs shellcheck on `setup.sh`, `scripts/linux/setup.sh`, and all `scripts/linux/tools/*.sh`.
  3. `lint-powershell`: Installs PSScriptAnalyzer and runs `Invoke-ScriptAnalyzer` on `setup.ps1` and `scripts/windows/setup.ps1`.

**Key validation decisions:**
- nvm must be sourced explicitly (`. ~/.nvm/nvm.sh`) — it's a shell function, not a binary
- uv installs to `$HOME/.local/bin` — PATH must be extended before checking
- `DEBIAN_FRONTEND=noninteractive` prevents apt from blocking on prompts
- Each tool validation uses `command -v` and emits ❌/✅ for clear CI output
- Idempotency test is a hard requirement per charter — second run must complete without error

**Environment note:** Shared workspace caused the initial commit to land on a different agent's branch (`squad/15-readme`). Cherry-picked onto `squad/12-ci-workflow` before pushing PR.
