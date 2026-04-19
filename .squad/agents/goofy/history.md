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

### [2026-04-19] Issue #147: PSScriptAnalyzer advisory check in pre-push hook (PR #149)
**Branch:** `squad/147-prepush-psscriptanalyzer`
**Status:** ✅ PR opened

Added PSScriptAnalyzer lint check to `hooks/pre-push` following the existing shellcheck pattern. Advisory only -- prints warnings but never blocks push (exit 0 all paths).

**Implementation:**
- Check if `pwsh` is available before attempting to run PSScriptAnalyzer
- Check if PSScriptAnalyzer module is installed via `Get-Module -ListAvailable`
- Only scan changed `.ps1` files from push diff (`git diff --name-only HEAD~1 HEAD`)
- Use `Write-Warning` to display violations in pwsh
- Silent skip when `pwsh` not found (common on Linux/macOS without PS Core)
- Notice skip when PSScriptAnalyzer module not installed
- Follows POSIX sh -- no bash-isms, no `[[`, no arrays, no `local`

**Key learning:** Hook patterns for optional lint tools should have three-tier graceful degradation: (1) silent skip when tool unavailable, (2) notice skip when dependencies missing, (3) advisory-only output when available. Never block on optional quality checks in pre-push hooks.

### [2026-04-18] Fix PR #130 regressions
- Test-Path Variable:* guard is BROKEN under Set-StrictMode -Version Latest on PS 5.1
- Even with short-circuit -and, strict mode throws VariableIsUndefined on $IsWindows
- CORRECT pattern: PSVersion-based short-circuit (Major -ge 6 -and $IsWindows)
- PSUseSingularNouns: PowerShell cmdlets/functions MUST use singular nouns
- PSUseDeclaredVarsMoreThanAssignments: any assigned var must be used or removed

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

## Sprint 6: Squad CLI Install (Issue #106)

**PR:** #118  
**Date:** 2026-04-18  

Implemented squad-cli global install for Windows and Linux with skip+warn pattern when npm is absent. Established reusable precedent for optional npm-dependent tools. Work shipped as planned. Issue closed.

## Issue #125: Permanently add vim to User PATH after winget install (PR #126)

**Branch:** `squad/fix-ci-vim-path`  
**Date:** 2026-04-18  

**Problem:** winget's `vim.vim` package does not add vim's directory to the system or user PATH. A simple `$env:PATH` session refresh is not enough — vim is unavailable even after opening a new terminal.

**Fix:** After `winget install`, search `C:\Program Files*\Vim\*\vim.exe` (covers both Program Files and Program Files (x86), plus versioned subfolders like `vim91/`). If found, permanently write the directory to the User PATH registry entry via `[System.Environment]::SetEnvironmentVariable('PATH', ..., 'User')`, then refresh the current session PATH.

**Key details:**
- `Get-ChildItem` with wildcard glob finds the versioned install directory
- `Sort-Object -Descending` picks the latest version if multiple exist
- `SetEnvironmentVariable(..., 'User')` persists across new terminal sessions (registry write)
- Session PATH also refreshed immediately so vim works without restart
- PS 5.x compatible: no `$IsWindows`, no `$MyInvocation.MyCommand.Path`, ASCII-only

## [2026-04-18] Fix PR #130 regressions (Issue #132, PR #133)
**Branch:** `squad/fix-pr130-regressions`
**Status:** ✅ Merged to develop

**What I found:** PR #130 introduced two regressions:
1. **PSScriptAnalyzer:** Function `Install-GitHooks` uses plural noun (rule: must be singular `Install-GitHook`)
2. **PSScriptAnalyzer:** Variable `$gitDir` assigned but never used (rule: declare only what's used)
3. **Runtime crash on PS 5.1:** Strict mode rejects `Test-Path Variable:IsWindows -and $IsWindows` pattern because strict mode validates all variables at parse time. Even though `-and` short-circuits at runtime, strict mode throws `VariableIsUndefined` on `$IsWindows` before execution.

**Root cause:** PR #130 reverted guards from approved PSVersion-based pattern (`$PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows`) to the broken `Test-Path Variable:*` pattern.

**What I fixed:**
- Renamed `Install-GitHooks` → `Install-GitHook`
- Removed `$gitDir` assignment
- Restored all PSVersion-based guards in setup.ps1

**Key learning:** PSVersion short-circuit checks are the ONLY safe pattern for PS 5.1 strict mode. The RHS of `-and` is never evaluated when LHS is false, so `$IsWindows` is never accessed on PS 5.x.

**PR #133 merged** by Mickey with --admin flag. Issue #132 closed.

## [2026-04-18] Fix Write-PowerShellProfile sentinel skip logic (Issue #144, PR #145)
**Branch:** `squad/fix-sentinel-update-logic`
**Status:** ✅ Committed, PR opened

**Problem:** Write-PowerShellProfile used "skip if sentinel present" logic. Users who ran setup.ps1 before PRs #141/#142 (psmux aliases) never got the new aliases — `ta`, `tks`, `tls`, `tt` were undefined because the function returned early.

**Fix:** Changed to "strip + re-inject" pattern:
- When BEGIN/END markers found, remove the old managed block entirely with regex
- Fall through to inject the current fresh block (never skip)
- Regex: `(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?`
- Handles both CRLF (Windows) and LF line endings
- Added `Write-Info "Updating PowerShell profile shortcuts..."` when updating existing profile

**Tests added (Group J):**
- J-1: BEGIN marker present in function body
- J-2: END marker present in function body
- J-3: No 'return' after sentinel check (verifies skip removed)
- J-4: Get-Content/Set-Content present (verifies strip logic)

**Key learning:** Sentinel-based idempotency that skips updates breaks incremental feature additions. Always use "strip managed content + re-inject fresh" for configuration blocks that evolve over time.


## [2026-04-19] Sentinel Fix Implementation — PR #145 merged to develop

**Orchestration log:** 2026-04-19T21-19-08Z-goofy-sentinel-fix.md
**Issue:** #144 (child of #138)
**PR:** #145 (`squad/144-sentinel-fix` → `develop`)
**Status:** ✅ Merged

This session delivered the strip+re-inject pattern for Write-PowerShellProfile, replacing the old "skip if sentinel" logic that prevented incremental profile updates.

**Implementation details:**
- Modified Write-PowerShellProfile in scripts/windows/setup.ps1
- Removed early `return` after sentinel check
- Added strip logic with regex that handles both CRLF and LF line endings
- Falls through to inject fresh current block (never skips)
- Write-Info message shown when updating existing profile block

**Test coverage (Group J):**
- J-1: BEGIN marker present in function
- J-2: END marker present in function
- J-3: No 'return' after sentinel (confirms skip logic removed)
- J-4: Get-Content/Set-Content present (confirms strip logic)

**Outcome:**
✅ All 4 Group J tests passing
✅ PR #145 created and pushed
✅ PR awaited Mickey's review (PR #145 approved)
✅ PR merged to develop (5/5 CI green)

**Key learning:** Regex pattern `(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?` is the correct approach for safe, cross-platform stripping of managed config blocks. The `(?s)` flag enables dot-matches-newline, and the `\r?\n?` handles both LF and CRLF line endings.

**Cross-team context:**
- Mickey created issue #144 scope document and reviewed implementation
- PR body referenced #144 correctly (Mickey noted nit: says #138 instead, but issue linkage correct)
- Related to issues #138 (parent: Windows PowerShell aliases), #141/#142 (psmux aliases)

**Decision artifacts merged to decisions.md:**
- goofy-sentinel-fix.md (implementation decision + alternatives)
- mickey-sentinel-fix-scope.md (scope boundaries, risk analysis)
- mickey-pr145-review.md (pattern adoption statement)


## [2026-04-19] Issue #138: Fix Windows PowerShell aliases not fully working (PR #146)
**Branch:** `squad/138-fix-profile-aliases`
**Status:** ✅ PR opened, awaiting Mickey review

**Three fixes implemented:**

1. **Dual-path profile injection** - Write to BOTH PS 5.1 and PS 7+ profile paths explicitly:
   - `~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` (PS 5.1)
   - `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (PS 7+)
   - Each path gets strip+re-inject treatment (no skip on sentinel)
   - Solves: setup in PS 7+ now writes aliases that work in PS 5.1 terminals

2. **Robust alias registration** - Added `-Force -Scope Global` to ALL 44+ `Set-Alias` calls in `$profileContent` heredoc:
   - `-Force` overrides ReadOnly aliases (prevents silent failures)
   - `-Scope Global` ensures aliases persist across scopes
   - Pre-emptive `Remove-Item` lines remain as belt-and-suspenders

3. **Execution policy diagnostic** - Check policy after profile write, warn if `Restricted` or `Undefined`:
   ```powershell
   $execPolicy = Get-ExecutionPolicy -Scope CurrentUser
   if ($execPolicy -eq 'Restricted' -or $execPolicy -eq 'Undefined') {
       Write-Warn "Execution policy is '$execPolicy' -- profile aliases may not load in new terminals."
       Write-Warn "To fix: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
   }
   ```

**Key learning:** `$PROFILE` is version-specific — always write to explicit paths for both PS 5.1 and PS 7+ to ensure cross-version compatibility.

**Related:** Issue #138 (parent), PR #145 (sentinel fix, cause ③)

## 2026-04-19 — Issue #138 Fix Complete: Implementation Session Wrap-up

**Session ID:** issue-138-fix-complete  
**Date:** 2026-04-19T21:59:45Z  

**Implementation Details:**
PR #146 implemented three complementary fixes for Issue #138 (Windows PowerShell aliases):
1. Dual-path profile injection — Write to both PS 5.1 (`WindowsPowerShell`) and PS 7+ (`PowerShell`) paths using explicit `[System.IO.Path]::Combine()`
2. Robust alias registration — Added `-Force -Scope Global` to all 44+ Set-Alias calls in profile content
3. Execution policy diagnostic — Check policy after write, warn if `Restricted` or `Undefined`

**Branch:** `squad/138-fix-profile-aliases`  
**PR:** #146 (merged to develop)  

**Outcome:** Feature fully shipped via PR #148 (develop→main, 10/10 CI green).

**Key Learning:** `$PROFILE` is version-specific — always write to explicit paths for cross-version compatibility. The refactor from `$PROFILE` to explicit `$profilePaths` array solved the root cause of aliases not loading in PS 5.1 terminals even though setup ran in PS 7+.

**Related Issues:** #138 (parent), #144 (sentinel skip), #141/#142 (psmux aliases that triggered discovery)

## [2026-04-19] Issue #147: Fix CI test L-4 failure — PSScriptAnalyzer exit 1 check (PR #149)
**Branch:** `squad/147-prepush-psscriptanalyzer`
**Status:** ✅ Committed and pushed

**Problem:** Test L-4 checks that no line in `hooks/pre-push` contains both `PSScriptAnalyzer` AND `exit 1` (to verify the check is advisory-only). The module availability check used `exit 1` inside a quoted PowerShell command string, which triggered the regex even though the shell never actually exits 1.

**Fix:** Replaced exit-code-based module check with output-based check:
```sh
# BEFORE (exit 1 in string triggered L-4):
if pwsh -NoProfile -Command "if (Get-Module -ListAvailable PSScriptAnalyzer) { exit 0 } else { exit 1 }" 2>/dev/null; then

# AFTER (no exit codes, output-based):
PSANALYZER_AVAIL=$(pwsh -NoProfile -Command "if (Get-Module -ListAvailable -Name 'PSScriptAnalyzer') { 'yes' } else { 'no' }" 2>/dev/null)
if [ "$PSANALYZER_AVAIL" = "yes" ]; then
```

**Result:** L-4 now passes correctly. Behavior is identical — module check still works, PSScriptAnalyzer runs if available, skips with message if not. Zero logic change, purely syntax refactor to satisfy test constraint.

**Key learning:** When tests enforce regex-based line checks, avoid using forbidden patterns even in quoted strings or comments. Output-based checks (`'yes'`/`'no'`) are cleaner than exit-code-based checks when the exit code itself is what's being tested.
