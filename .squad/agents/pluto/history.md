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

## Session: 2026-04-07 — Issue #8 Shell Aliases

**Branch:** `squad/8-shell-aliases`
**PR:** #22 — [Config] Shell shortcuts and aliases
**Status:** PR open, base `develop`

### What was done
- Created `config/dotfiles/.aliases` with aliases grouped by category: navigation, ls, git, gh CLI, docker (optional), utility, and dev shortcuts
- Created `config/dotfiles/.zshrc.template` — a minimal template for `$HOME/.zshrc` that sets up PATH for `uv` and `nvm`, and sources `~/.aliases`
- Created `config/dotfiles/install.sh` by porting from `squad/11-dotfile-templates` and extending it to:
  - Symlink `.aliases` → `$HOME/.aliases`
  - Copy `.zshrc.template` → `$HOME/.zshrc` only if no `.zshrc` exists (never overwrites)

### Design decisions
- `.aliases` is symlinked (not copied) so repo updates propagate instantly
- `.zshrc.template` is copied only on first install — it's the user's file to own
- Docker aliases are marked as optional in comments
- No hardcoded paths — all use `$HOME`, `$NVM_DIR`

