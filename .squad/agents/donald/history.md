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

### 2026-04-07: Issue #13 — auth.sh re-implemented from develop (PR #25 was lost)

Previous PR #25 was closed because its base branch (`squad/1-linux-core-setup`) had been merged and deleted.
Re-implemented from `develop` on branch `squad/13-auth-prompt`.

- `scripts/linux/tools/auth.sh` — new file: checks `gh auth status`, prompts interactively, skips gracefully in CI/Codespaces/non-interactive
- `scripts/linux/setup.sh` — added `run_tool "auth"` between `run_tool "gh"` and `run_tool "copilot-cli"`

Idempotent: exits 0 immediately if already authenticated. Copilot CLI install (which follows) needs auth to work.
PR: #24 (open, targeting `develop`)

### 2026-04-07: Issue #13 — GitHub auth prompt step added to setup

Implemented `scripts/linux/tools/auth.sh` on branch `squad/13-auth-prompt` (based on `squad/1-linux-core-setup`):

- Checks `gh auth status` — exits 0 immediately if already authenticated (prints username)
- Detects non-interactive environments via `CI`, `CODESPACES`, and TTY check — skips gracefully with guidance message
- In interactive environments: launches `gh auth login` and confirms result
- `scripts/linux/setup.sh` updated to call `run_tool "auth"` between `run_tool "gh"` and `run_tool "copilot-cli"`

This ensures copilot-cli install always has an authenticated gh CLI available.
PR: #25 (open, targeting `squad/1-linux-core-setup`)

---

## 2026-04-08 — Issue #57: Remove ps.tar.gz Binary Artifact

**Branch:** `squad/57-remove-ps-tar-gz`  
**PR:** #59 (open, targeting `develop`)  
**Status:** Ready for review

**What I did:**
- Removed `ps.tar.gz` (69MB compiled PowerShell/.NET SDK DLLs) from working tree
- Updated `.gitignore` to prevent future accidental commits

**Why:** Binary artifact; no runtime purpose in a setup scripts repository. Adds significant bloat. Currently tracked in git; now prevented via .gitignore.

**Future consideration:** Optional git history cleanup with `git-filter-repo` or `bfg` (cost/benefit analysis deferred)

**Part of Sprint 5 Round 1:** Coordinated parallel work with Mickey (issue #54) and Pluto (issue #56). All agents worked concurrently on separate branches without conflicts.
