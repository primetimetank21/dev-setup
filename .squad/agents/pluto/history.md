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

### Worktree isolation pattern (Issue #56, 2026-04-07)

- `SQUAD_WORKTREES=1` is the recommended env var to enable per-issue git worktree isolation.
- The coordinator creates worktrees at `{repo-parent}/{repo-name}-{issue-number}` so each agent gets a fully isolated working tree.
- This prevents the Sprint 4 race condition where Chip-issue-43 checked out a branch while Chip-issue-41 was mid-commit on the same working tree.
- `SQUAD_WORKTREES=1` is now set by default in `.devcontainer/devcontainer.json` `remoteEnv`.
- Full pattern documented in `.squad/skills/worktree-isolation/SKILL.md` and `CONTRIBUTING.md § "Parallel Agent Work"`.
- PR: https://github.com/primetimetank21/dev-setup/pull/58

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

---

## 2026-04-12 — Issue #64: Append Managed Block to Existing .zshrc/.bashrc

**Branch:** `squad/64-dotfiles-append-managed-block`
**PR:** #65 (open, targeting `develop`)
**Status:** Ready for review

**What I did:**
- Replaced the "skip .zshrc if it exists" behavior with an append-managed-block strategy
- Added `append_managed_block()` helper to `config/dotfiles/install.sh` — uses a marker comment for idempotency
- `.zshrc` block: sets PATH for `$HOME/.local/bin`, inits nvm, sources `.aliases`
- `.bashrc` block: sets PATH for `$HOME/.local/bin`, sources `.aliases` (nvm init omitted — nvm installer handles it)
- Fresh-install (no `.zshrc`) path unchanged — still copies the template
- `--dry-run` support wired into the new helper

**Key decisions:**
- Marker: `# --- dev-setup managed block` — simple `grep -qF` check before every append
- `.bashrc` block is intentionally shorter than `.zshrc` — nvm appends its own init to `.bashrc` during install
- Only append to `.bashrc` if it already exists — no template for `.bashrc`

**Decision record:** `.squad/decisions/inbox/pluto-dotfiles-managed-block.md`

---

## 2026-04-08 — Issue #56: Worktree Isolation for Parallel Agent Work

**Branch:** `squad/56-worktree-isolation`  
**PR:** #58 (open, targeting `develop`)  
**Status:** Ready for review

**What I did:**
1. Added `SQUAD_WORKTREES=1` to `.devcontainer/devcontainer.json` in `remoteEnv` (always-on for Codespaces)
2. Created skill documentation: `.squad/skills/worktree-isolation/SKILL.md`
3. Updated `CONTRIBUTING.md` with § "Parallel Agent Work" section

**Why:** Sprint 4 revealed a critical race condition: Chip-issue-43 ran `git checkout squad/43` while Chip-issue-41 was mid-commit on the shared working tree, resulting in wrong content on wrong branches. PR #51 had to be closed.

**Root cause:** A single git working tree can only have one branch checked out at a time. It is not safe to share between concurrent agents.

**Solution:** With `SQUAD_WORKTREES=1`, the coordinator creates isolated worktrees at `{repo-parent}/{repo-name}-{issue-number}` before handing control to each agent. Branch operations inside one worktree are completely invisible to all others.

**Scope:**
- **Parallel runs:** SQUAD_WORKTREES=1 required (multiple agents on different issues concurrently)
- **Sequential runs:** Not needed — no race condition possible with single agent

**Mid-task incident:** A race condition struck while committing history.md — the commit landed on the wrong branch. Cherry-picked it back to maintain consistency.

**Decision documented:** Merged to squad/decisions.md

**Part of Sprint 5 Round 1:** Coordinated parallel work with Mickey (issue #54) and Donald (issue #57). All agents worked concurrently on separate branches without conflicts.

---

## 2026-04-07 — Issue #108: PowerShell Alias Parity

**Branch:** `squad/108-powershell-alias-parity`
**PR:** #115 → `develop` (merged)
**Status:** ✅ Complete

**What I did:**
- Fixed `gs` alias: updated `Get-GitStatus` body from `git status` to `git status -sb`
- Added 14 new git aliases: `gaa`, `gcm`, `gcb`, `gco`, `gd`, `gds`, `ggsp`, `gp`, `gpf`, `gpl`, `grb`, `grbi`, `grs`, `grss`
- Added 5 GitHub CLI aliases: `ghpr`, `ghprl`, `ghprv`, `ghis`, `ghiv`
- Added 8 dev shortcut aliases: `uvr`, `uvs`, `ni`, `nr`, `nrd`, `nrt`, `py`, `c`
- Added 3 utility aliases: `myip`, `pb`, `h`
- Organized new aliases under `# -- GitHub CLI shortcuts`, `# -- Dev shortcuts`, `# -- Utility` section headers
- Added test group F (6 tests) to `tests/test_windows_setup.ps1`
- Used `Remove-Item -Force Alias:\<name>` guards for all built-in alias conflicts (`gc`, `gl`, `gp`, `grb`, `grs`, `ni`, `h`)

**Key decisions:**
- Shell-only aliases (navigation, ls, tmux, docker, reload) skipped — no PS parity needed
- All functions use `function Name { cmd $args }` pattern for PS 5.1 strict mode compat
- Decision record: `.squad/decisions/inbox/pluto-108-alias-parity.md`

### 2026-04-19 — PR #115 Merged; Issue #108 Closed

PR #115 merged to `develop`. Mickey reviewed and approved — all 30 aliases correct, CI green (4/4), PS 5.x safe, test group F (6 tests) passing. Issue #108 closed manually (GitHub doesn't auto-close on develop merges).

## Sprint 6: PowerShell Aliases (Issue #108)

**PR:** #115  
**Date:** 2026-04-18  

Delivered 30 PowerShell aliases with full git/gh/dev parity, conflict guards for reserved names, $args passthrough on all functions, inline comments, and PS 5.x strict-mode compatibility. High craft level. Issue closed.

