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

## 2026-04-07 — Issue Triage & Priority Assignment

Reviewed and prioritized all 14 open issues. Applied P1/P2/P3 labels. Posted assignment acknowledgments on every issue. #3 (Architecture) is P1 and must ship first — it blocks Donald and Goofy. Dependency order posted as comment on #3.
