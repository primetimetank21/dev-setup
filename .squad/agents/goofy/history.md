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
## 2026-04-08 — Hotfix: $PSScriptRoot for ScriptDir resolution

**Reported by:** Earl Tankard  
**File:** `setup.ps1` line 51

### The Bug
`$MyInvocation.MyCommand.Path` is `$null` in certain PowerShell host environments (e.g., `./` invocation in strict mode, some remote or hosted contexts). This caused:
```
The property 'Path' cannot be found on this object.
```

### The Fix Pattern (memorize this)
Always use `$PSScriptRoot` for directory resolution. It is a PowerShell automatic variable (PS 3.0+) that always contains the directory of the executing script file.

```powershell
# CORRECT: reliable across all invocation contexts
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

# WRONG: null in many host environments
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
```

### Rule
- **Never use** `$MyInvocation.MyCommand.Path` — it's unreliable
- **Always prefer** `$PSScriptRoot` as primary
- **Safe fallback:** `$MyInvocation.MyCommand.Definition` (works in dot-sourced and hosted contexts)
