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

### 2026-04-07
- Created 14 GitHub issues for primetimetank21/dev-setup
- Issue breakdown: 1 architecture, 7 tool installs, 3 config, 1 auth, 2 testing/CI
- All issues labeled with `squad` + `squad:{member}` labels
- Created squad labels: squad, squad:mickey, squad:donald, squad:goofy, squad:pluto, squad:chip

### 2026-04-07 — Issue #3: Architecture / OS Detection Entry Point
- Shipped PR #17: `squad/3-os-detection-entry-point` → `develop`
- Created `setup.sh` (Unix entry point) with OS detection via `uname -s` + `/proc/version` (WSL check)
- Created `setup.ps1` (Windows entry point) using PowerShell `$IsWindows` builtin
- Scaffolded full directory structure: `scripts/linux/`, `scripts/linux/tools/`, `scripts/windows/`, `config/dotfiles/`, `.github/workflows/`
- Created idempotent tool stubs for Donald: `zsh.sh`, `uv.sh`, `nvm.sh`, `gh.sh`, `copilot-cli.sh`
- Created scaffold for Goofy: `scripts/windows/setup.ps1`
- Wrote `ARCHITECTURE.md` covering structure, OS detection, naming conventions, team ownership, "how to add a tool" guide
- Decision: WSL is always routed as Linux. Entry points are thin routers only — no tool installation at root level.
- Decision: Tool scripts run via `bash <script>` (not `source`) to keep each isolated in its own subshell.
- Decision: No package-manager abstraction layer — apt/brew per tool script, winget for Windows. Simple beats clever.
- Dropped decision record at `.squad/decisions/mickey-architecture-entry-point.md`
