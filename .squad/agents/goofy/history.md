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
## PS 5.x Automatic Variable Pattern (`$IsLinux` / `$IsMacOS` / `$IsWindows`)

`$IsLinux`, `$IsMacOS`, and `$IsWindows` are **PS 6+ only**. Referencing them directly on PS 5.x under `Set-StrictMode -Version Latest` causes a hard error:
```
The variable '$IsLinux' cannot be retrieved because it has not been set.
```

**Safe pattern for PS 5.1 compatibility:**
```powershell
$isWin = ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) -or
          ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')
$isLin = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$isMac = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
```

Key facts:
- `$PSVersionTable.PSVersion.Major` has existed since PS 2 — always safe to read
- `$env:OS` is `Windows_NT` on all Windows versions in PS 5.x
- Short-circuit `$PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux` means the RHS is never evaluated on PS 5.x, so no strict-mode error

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

## 2026-04-13 -- Issue #107: feat(windows): install vim via winget (PR #112)

**Branch:** `squad/107-install-vim-winget`

Added `Install-Vim` to `scripts/windows/setup.ps1` and Group E tests to `tests/test_windows_setup.ps1`.

### Learnings

- **winget package ID for vim:** `vim.vim` (use `winget install --id vim.vim`)
- **PS 5.1 compat patterns confirmed:**
  - No `$MyInvocation.MyCommand.Path` -- always use `$PSScriptRoot`
  - No unguarded `$IsLinux` / `$IsMacOS` / `$IsWindows` -- must be wrapped with `$PSVersionTable.PSVersion.Major -ge 6 -and $IsX`
  - Verified by E-4 and E-5 tests
- **Test file location:** `tests/test_windows_setup.ps1`
  - Existing Groups A-D cover PSScriptRoot, PS 5.x guards, profile idempotency, Copilot CLI
  - Group E (added this issue) covers Install-Vim function existence, Main call, winget ID, and compat checks
- **Install position:** `Install-Vim` inserted after `Install-GhCli` and before `Install-CopilotCli` in Main, ensuring vim is available for any vim-based workflows during Copilot CLI setup

## 2026-04-18 -- Issue #106: feat(setup): install squad-cli globally (PR #118)

**Branch:** `squad/106-squad-cli-install`

Added `squad-cli` (`@bradygaster/squad-cli`) global install to both Windows and Linux setup scripts.

### Windows (`scripts/windows/setup.ps1`)
- New `Install-SquadCli` function following `Install-CopilotCli` pattern
- PS 5.x safe: uses `$PSScriptRoot`, no unguarded PS 6+ auto-vars
- Skips with `[WARN]` if npm is not found (does NOT force-install Node)
- Called from `Main` after `Install-CopilotCli`

### Linux (`scripts/linux/tools/squad-cli.sh`)
- New tool script following existing `run_tool` / tool-script pattern
- Skips with `[WARN]` if npm not found
- Called from `main()` in `scripts/linux/setup.sh` after `copilot-cli`

### Tests (`tests/test_windows_setup.ps1` - Group G)
- G-1: `Install-SquadCli` function exists
- G-2: `Install-SquadCli` is called from `Main`
- G-3: npm availability check with skip+warn pattern
- G-4: No `$MyInvocation.MyCommand.Path` (PS 5.x compat)

### Design decision
If npm/Node.js is not present, skip with `[WARN]`. Do not force-install Node -- matches team decision in decisions.md.
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
