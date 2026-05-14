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

## Core Context

**Sprints 1–8 Summary (2026-04-07 to 2026-05-04):**

Implemented Windows PowerShell setup, utility alias framework, and architectural refactors:

- **Sprints 1–4:** Root setup.ps1 OS detection, scripts/windows/setup.ps1 core setup, 5 Install-* functions (Git, Uv, Nvm, GhCli, CopilotCli), utility aliases (ta, tt, tls, tks, gpl, ggsls), Remove-Item guards for PS 5.1 AllScope conflicts
- **Sprint 5:** PS 5.1 source-level guards (`Test-Path Variable:IsWindows`), vim PATH refresh after winget, empty catch block pattern (Write-Verbose), UTF-8 em-dash removal
- **Sprint 6:** curl.exe / wget.exe alias bypass, ep alias for profile editor, Remove-Item guard on profile ops
- **Sprint 7:** Git hooks implementation, PS variable guard regressions fixed (reverted to PSVersion pattern)
- **Sprint 8 (Gap Audit):** Refactored monolithic setup.ps1 (451 lines) into 9 per-tool files under tools/ (git, uv, nvm, gh, vim, psmux, copilot, squad-cli, profile); orchestrator reduced to 76 lines; highest-leverage refactor

**Key Patterns Established:**
- Always use `$PSScriptRoot` (not `$MyInvocation.MyCommand.Path` — null in hosted contexts)
- PSVersion-based guards (ONLY safe for PS 5.1 strict mode): `$PSVersionTable.PSVersion.Major -ge 6 -and $IsVariable` — RHS never evaluated on PS 5.x
- AllScope alias override: Must `Remove-Item -Force Alias:\name` before `Set-Alias -Force` (all 11 PS 5.1 conflicts: rm, gc, gl, gcm, gcb, gp, grb, grs, ni, h, ep)
- Strip+re-inject for config blocks: Never skip if sentinel present (breaks incremental updates); always strip old + inject fresh
- Empty catch blocks: Use `Write-Verbose` (satisfies PSScriptAnalyzer PS3109 requirement; provides debug logging without breaking idempotency)
- curl.exe / wget.exe: Always use explicit .exe in PowerShell scripts (bypass alias resolver to real Win32 binary)
- Dot-source tool files in orchestrator: `. "$PSScriptRoot\tools\*.ps1"` with relative paths works correctly via `powershell -File`

**Key Files:**
- `scripts/windows/setup.ps1` — 76-line orchestrator (was 451)
- `scripts/windows/tools/*.ps1` — 9 per-tool files (install functions + Write-PowerShellProfile)
- `tests/test_windows_setup.ps1` — 61 tests, 11 groups (A–L)
- `.squad/agents/goofy/history.md` → split off highest-leverage learnings to this Core Context

**Tech Decisions:**
- winget as sole Windows package manager (covers all required tools)
- npm-dependent tools (squad-cli) skip+warn if npm absent (don't force Node install)
- Dual-profile approach: PS 5.1 (`WindowsPowerShell/`) + PS 7+ (`PowerShell/`) both updated
- Nested Join-Path for PS 5.1: 2-arg syntax only (no array join)

---

## Learnings

- CP1252 encoding trap: Em dash U+2014 encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252; PS 5.1 treats as string terminator — always use ASCII hyphen in literals
- Invoke-Expression for function loading: Load at Group scope before Test-Scenario; `& ([scriptblock]::Create(...))` creates child scope where functions vanish
- PSScriptAnalyzer PS3109: Empty catch blocks forbidden; Write-Verbose satisfies requirement
- PSUseSingularNouns: PowerShell cmdlets/functions MUST use singular nouns (Install-GitHook not Install-GitHooks)
- When refactoring variable names, grep tests for old names — static-analysis tests break silently
- Set-Alias -Force insufficient for AllScope aliases — must Remove-Item first
- Registry SetEnvironmentVariable for PATH persists across terminal sessions: `[System.Environment]::SetEnvironmentVariable('PATH', ..., 'User')`

---

## Recent Work

## [2026-05-14] Issue #197: AllScope Alias Override Verification (Groups N, O, P tests)

**Context:** Earl reported real-world failure on PS 5.1 where setup.ps1 ran but custom aliases didn't work.

**Root Cause:** PS 5.1 built-in aliases (gcm, gc, gl, gp, ni, rm, h, etc.) scoped as AllScope. `Set-Alias -Force` alone cannot override; must explicitly remove first.

**Test Implementation (Chip):**
- Group N: Runtime tests call `Write-PowerShellProfile`, assert both PS 5.1 and PS 7+ profile files exist; verify all 11 AllScope guards present in profile
- Group O: 7 runtime tests execute `Remove-Item -Force 'Alias:\<name>'` then `Set-Alias -Force -Scope Global` for each: gc, gcm, gl, gp, ni, rm, h
- Group P: psmux install (syntax check via AST + Invoke-Expression, skip if present, idempotency via dual-call)

**Key Pattern:**
```powershell
Remove-Item -Force Alias:\<name> -ErrorAction SilentlyContinue
Set-Alias -Name <name> -Value <custom-function> -Force -Scope Global
```

---

## [2026-05-04] Issue #185: Windows Setup Refactor — 451-line monolith → 9 per-tool files (PR #195)

**Status:** ✅ APPROVED, MERGED to develop

Refactored monolithic `scripts/windows/setup.ps1` (451 lines) into per-tool modular structure under `scripts/windows/tools/`, mirroring Linux `scripts/linux/tools/` pattern.

**Orchestrator Changes:**
- Reduced from 451 lines → 76 lines
- Dot-sources each tool file: `. "$PSScriptRoot\tools\git.ps1"`
- Maintains same Main flow, Install-GitHook call

**Created Tool Files:**
- git.ps1, uv.ps1, nvm.ps1, gh.ps1, vim.ps1, psmux.ps1, copilot.ps1, squad-cli.ps1, profile.ps1

**Test Updates (Chip):**
- Updated Group K (K-1 to K-5): AST parser target → `tools/profile.ps1`
- 61/61 tests pass, 5/5 CI green

**Key Learning:** When splitting PowerShell scripts sourced by AST-parsing tests, update test file references to new per-tool file paths. Dot-sourcing with relative paths works correctly when orchestrator invoked via `powershell -File`.

---

## [2026-04-19] Issue #144: Sentinel Fix — Strip+Re-inject Pattern (PR #145)

**Status:** ✅ APPROVED, MERGED to develop

Implemented strip+re-inject for Write-PowerShellProfile, replacing old "skip if sentinel" logic that prevented incremental profile updates.

**Implementation:**
- Regex: `(?s)\r?\n<BEGIN>.*?<END>\r?\n?` handles both LF and CRLF
- No `return` after sentinel check — strips old block, falls through to inject fresh
- `Write-Info "Updating PowerShell profile shortcuts..."` shown on update (not first install)

**Test Coverage (Group J):**
- J-1: BEGIN marker present
- J-2: END marker present
- J-3: No `return` after sentinel (skip logic removed)
- J-4: Get-Content/Set-Content present (strip logic verified)

**Key Learning:** Sentinel-based idempotency that skips entirely breaks incremental feature delivery. Always use "strip managed block + re-inject fresh" for config blocks that evolve. When reviewing regex for profile management, always verify leading/trailing newline anchors handle both LF and CRLF.

---

## [2026-04-18] Issue #132: Regression Fixes from PR #130 (PR #133)

**Status:** ✅ MERGED to develop

Fixed three regressions introduced by PR #130:

1. **PSScriptAnalyzer PS3109:** Function `Install-GitHooks` → `Install-GitHook` (singular noun requirement)
2. **PSScriptAnalyzer:** Removed unused variable `$gitDir`
3. **PS 5.1 Runtime Crash:** Reverted broken `Test-Path Variable:*` guards back to PSVersion-based pattern

**Root Cause:** PR #130 replaced approved PSVersion guards with `Test-Path Variable:*` pattern. Under strict mode on PS 5.1, strict mode validates all variables at parse time; even with short-circuit `-and`, throws `VariableIsUndefined` before execution.

**Correct Pattern:** `$PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows` — RHS never evaluated on PS 5.x.

**Key Learning:** PSVersion-based short-circuit checks are ONLY safe pattern for PS 5.1 strict mode.
