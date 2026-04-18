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

### End-of-session cleanup workflow (2026-04-12)

When finishing a multi-agent session with uncommitted changes on merged feature branches:

1. **Stash changes** on the feature branch: `git stash`
2. **Checkout develop** and **pull latest**: `git checkout develop && git pull origin develop`
3. **Pop the stash**: `git stash pop` (reapply changes to develop)
4. **Commit and push** to develop with appropriate co-authored-by trailer
5. **Delete merged local branches**: `git branch -d <branch>` (or `-D` if needed)
6. **Delete remote branches**: `git push origin --delete <branch>` (safe to ignore "not exists" errors)
7. **Verify clean state**: `git branch -a` and `git status`

This ensures uncommitted work on merged branches doesn't get lost, and keeps the local repo clean.

## 2026-04-07 — Issue #2: Windows core setup script

**Branch:** `squad/2-windows-setup` (based on `squad/3-os-detection-entry-point`)

Implemented `scripts/windows/setup.ps1` — the core Windows installer. Filled in Mickey's stub with five idempotent `Install-*` functions:

- `Install-GitBash` — Git for Windows via winget (`Git.Git`); ships Git Bash as the unix-shell equivalent
- `Install-Uv` — uv Python package manager via official `irm https://astral.sh/uv/install.ps1 | iex`
- `Install-Nvm` — nvm-windows via winget (`CoreyButler.NVMforWindows`); reloads PATH post-install
- `Install-GhCli` — GitHub CLI via winget (`GitHub.cli`)
- `Install-CopilotCli` — `gh extension install github/gh-copilot`; gracefully skips if gh not authenticated

Also added `Write-Err` helper and `Test-WingetAvailable` guard (exits 1 with helpful message if winget absent).

**Decision:** winget as sole package manager — it's built into Windows 10 1709+ and covers all required tools cleanly.

**Note:** Multi-agent environment required use of `git worktree` to isolate changes from concurrent branch checkouts.

## 2026-04-12 — Issue #75: Add vim to system prerequisites (PR #77)

**Branch:** `squad/75-add-vim-prerequisite` (merged, deleted)

`install_prerequisites()` in `scripts/linux/setup.sh` was missing `vim` from the `apt-get install -y` list. Aliases `vb` (edit `~/.bashrc`) and `vz` (edit `~/.zshrc`) invoke `vim` directly — without it present, both aliases fail on fresh Devcontainer builds with "command not found".

**Fix:** Added `vim` to the `apt-get install -y` line in `install_prerequisites()`.

```bash
sudo apt-get install -y curl git build-essential vim
```

**PR #77** reviewed by Mickey, CI 4/4 green, squash-merged to `develop`. Branch deleted.

---

### 2026-04-13 — Issue #102: Fix PSAvoidUsingEmptyCatchBlock in scripts/windows/setup.ps1

**Branch:** `squad/102-windows-ps-regression-tests`  
**Commit:** `7f80b5f`  
**Status:** ✅ MERGED (as part of PR #104)

**What I fixed:**
- Empty catch block in `scripts/windows/setup.ps1` (line for `Install-CopilotCli` error handling)
- PSScriptAnalyzer rule PS3109 requires at least one *statement* in catch blocks (comments alone are insufficient)

**Before:**
```powershell
catch {
    # Silently continue if extension already exists or not available
}
```

**After:**
```powershell
catch {
    Write-Verbose "GitHub Copilot CLI extension not available or already installed"
}
```

**Technical insight:**
- PSScriptAnalyzer enforces non-empty catch bodies at AST level — comments are not counted as statements
- Write-Verbose is ideal for this pattern: provides logging for debugging without breaking idempotency
- This violation was discovered during chip-write-tests PR review (mickey-review-104)

**Cross-agent coordination:**
- Chip's PR #104 triggered lint failure
- Mickey reviewed and identified the blocking issue
- I fixed the violation on the same branch
- PR #104 then passed all CI checks and was merged

**Outcome:** PSScriptAnalyzer now passes on scripts/windows/setup.ps1. Windows setup lint baseline established.
