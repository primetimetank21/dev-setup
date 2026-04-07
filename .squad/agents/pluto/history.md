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
## 2026-04-07 — Issue #11: Dotfile Templates

**Branch:** `squad/11-dotfile-templates`  
**PR:** targets `dev`

### What I shipped

Created `config/dotfiles/` with:

- `.gitconfig.template` — git defaults with `YOUR_NAME`/`YOUR_EMAIL` placeholders,
  sensible `core`, `pull`, `push`, `merge`, `fetch`, `diff` settings, and common
  aliases (`co`, `br`, `st`, `lg`, `undo`, `unstage`).
- `.editorconfig` — universal editor config: 2-space indent, LF, UTF-8, final
  newline; exceptions for Markdown (trailing whitespace), Makefiles (tabs),
  PowerShell (4 spaces), Python (4 spaces).
- `.npmrc.template` — `save-exact`, `fund=false`, `audit=false`, `loglevel=warn`,
  commented auth token stubs with instructions.
- `install.sh` — idempotent Bash installer with `--dry-run` support. Copies
  `.gitconfig` and `.npmrc` (user-editable), symlinks `.editorconfig`.
  Backs up existing `.gitconfig` before overwriting. Substitutes
  `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_AUTHOR_SIGNING_KEY` via `sed`.
- `README.md` — full documentation of each file, env vars, idempotency, and
  how to add new dotfiles.

### Key decisions

- Copy `.gitconfig`/`.npmrc`, symlink `.editorconfig` — machine-specific vs shared
- Use `sed` not `envsubst` (not universally available)
- Back up existing `.gitconfig` rather than skipping (Codespaces may have stale auto-generated config)
- No `.zshrc` here — that belongs to issue #8

### Decision record

`.squad/decisions/inbox/pluto-dotfiles.md`
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

