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

### 2026-04-08: gh 2.x+ built-in promotion breaks extension install (PR #63 revised)

`gh 2.89.0` promotes `gh copilot` to a **built-in command**. This breaks two earlier patterns:

- `gh extension list | grep -q "gh-copilot"` — misses built-ins (only lists extensions)
- `gh alias list | grep copilot` — misses built-ins (only lists aliases)
- `gh extension install github/gh-copilot` — fails with `"copilot" matches the name of a built-in command` (stdout, not stderr)

**Correct idempotency check:** `gh copilot --help &>/dev/null 2>&1` — succeeds whether copilot is a built-in, extension, or alias. Version-agnostic.

**Correct install failure handling:** Use `set +e` to capture stdout+stderr from `gh extension install`, then grep for the "built-in" error string and exit 0 gracefully. Never let a version-gated "already built-in" failure propagate as a setup error.

**Rule:** Never use `gh extension list` or `gh alias list` as the sole idempotency gate for gh subcommands — probe the actual command with `--help` instead.

### 2026-04-08: Bug fix — gh alias conflict blocks copilot-cli extension install

`gh extension install` silently fails (stdout, not stderr) when an existing gh alias matches the extension's command name. For `gh-copilot`, this means any stale `copilot` alias from a prior partial install blocks reinstall entirely.

Fix pattern: guard with `gh alias list | grep -q "^copilot"` and delete before installing. Applied to `scripts/linux/tools/copilot-cli.sh` on branch `squad/fix-copilot-cli-alias-conflict`, PR #63.

Also: never use `$(gh copilot --version)` in a post-install check — if the alias conflict exists, that subshell triggers the same error and leaks it into log output. Use `gh extension list | grep -q "gh-copilot"` or a plain success string instead.

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
### 2026-04-08: Issue #57 — Removed ps.tar.gz binary artifact and updated .gitignore

Cleaned up the 69MB PowerShell/.NET SDK DLL archive (`ps.tar.gz`) that was accidentally committed in Sprint 1:

- Removed file from git tracking via `git rm ps.tar.gz`
- Updated `.gitignore` to prevent future binary artifact commits: added `*.tar.gz`, `*.zip`, `*.dll`, `*.exe`
- Created branch `squad/57-remove-ps-tar-gz` from `develop`
- Committed with proper trailer: `chore: remove ps.tar.gz binary artifact and update .gitignore (#57)`
- Pushed to origin and opened PR #59

This reduces repo size and prevents accidental commits of compiled binaries. Note: git history rewrite skipped per issue spec (nice-to-have only).
PR: #59 (open, targeting `develop`)
