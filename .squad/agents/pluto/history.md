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

## Work Log

### 2026-04-07 — Issue #10: Dev Container and Codespace post-create setup

**Branch:** `squad/10-devcontainer`
**PR:** https://github.com/primetimetank21/dev-setup/pull/21
**Status:** PR open, pending review

**What I did:**
- Created `.devcontainer/devcontainer.json` using `mcr.microsoft.com/devcontainers/base:ubuntu`
- `postCreateCommand` set to `bash setup.sh` — routes to `scripts/linux/setup.sh` on Linux
- Pre-installed 10 VS Code extensions: Copilot, Copilot Chat, ShellCheck, shell-format, bash-ide, PowerShell, EditorConfig, GitLens, PR GitHub, GitHub Actions
- Default terminal set to zsh (installed by setup.sh)
- Devcontainer features: git and github-cli (gh available before postCreate so Copilot CLI install works)
- `DEBIAN_FRONTEND=noninteractive` set in both `containerEnv` and `remoteEnv` to suppress apt prompts
- Created `.devcontainer/README.md` with full documentation: how to open in VS Code and Codespaces, what postCreate does, extensions table, settings table, customization guide

**Key decisions:**
- Used `github-cli` as a devcontainer feature (not just relying on setup.sh) so `gh` is available during postCreate for Copilot CLI install
- `editor.rulers: [100]` matches the project's 100-char line width convention
- `shellcheck.run: "onType"` for immediate feedback on shell scripts
