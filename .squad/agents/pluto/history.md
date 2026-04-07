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
