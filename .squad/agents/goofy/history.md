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

⚠️ **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- CP1252 encoding trap: Em dash U+2014 encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252; PS 5.1 treats as string terminator — always use ASCII hyphen in literals
- Invoke-Expression for function loading: Load at Group scope before Test-Scenario; `& ([scriptblock]::Create(...))` creates child scope where functions vanish
- PSScriptAnalyzer PS3109: Empty catch blocks forbidden; Write-Verbose satisfies requirement
- PSUseSingularNouns: PowerShell cmdlets/functions MUST use singular nouns (Install-GitHook not Install-GitHooks)
- When refactoring variable names, grep tests for old names — static-analysis tests break silently
- Set-Alias -Force insufficient for AllScope aliases — must Remove-Item first
- Registry SetEnvironmentVariable for PATH persists across terminal sessions: `[System.Environment]::SetEnvironmentVariable('PATH', ..., 'User')`
- Em dash fix pattern (PR #198): When PS 5.1 CI fails with TerminatorExpectedAtEndOfString, scan ALL .ps1 files on the branch for non-ASCII (bytes > 0x7F). Replace em dashes and other non-ASCII with ASCII equivalents in both comments and string literals. Use a byte-level scan (not just grep) to catch multi-byte UTF-8 sequences.

---

## Recent Work

## [2026-05-16T01:30:00Z] Issue #197 & #198: Em-Dash Fix & ASCII-Only Enforcement

**Branch:** `squad/184-gitconfig-editor-fix` (PR #198)  
**Status:** ✅ COMPLETE — CI green

Fixed CP1252 encoding violations causing PS 5.1 parse errors on PR #198:

**Files Modified:**
- `scripts/windows/tools/profile.ps1` — 2 em dashes → ` - `
- `scripts/windows/tools/psmux.ps1` — 2 em dashes → ` - `

**Total:** 4 em dashes replaced with ASCII equivalents

**Outcome:** CI checks went green after fix. Formalized ASCII-only rule in decisions.md via Goofy decision (goofy-em-dash-fix.md, goofy-ps51-impl.md).

**Key Decisions Captured:**
1. All `.ps1` files MUST be ASCII-only (U+0000–U+007F)
2. Psmux unavailable via winget #179 → skip-with-warning pattern implemented
3. Profile.ps1 diagnostics added (dir path, file exists, exec policy checks) to surface real failure cause on Earl's PS 5.1 machine

---

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

## [2026-05-16T18:30:00Z] Issue #226: Assert winget exit code after installs

**Branch:** `squad/226-winget-exit-check`
**Status:** PR open -- awaiting Doc review

**Bug Pattern:** `winget install` (and `npm install -g`, powershell IEX installs) can return
non-zero on real failures while the script silently continued. 7 install sites all lacked
any exit-code check.

**Fix Applied:**
- Added `Assert-LastExit` helper to `scripts/windows/lib/logging.ps1`
- `Assert-LastExit -ToolName <name> -AllowedExitCodes @(0, -1978335189)` called immediately
  after each install command in all 7 sites
- Winget ALREADY_INSTALLED code 0x8A15002B (= -1978335189 signed int32) treated as success
- PS function mocks in tests P-2/P-3 updated to set `$global:LASTEXITCODE = 0` explicitly
  (PS functions do not set LASTEXITCODE; leaving it unset would be racy)
- 9 new Group X tests added (X-1 through X-9)

**7 Install Sites Fixed:**
1. `tools/git.ps1` -- winget Git.Git
2. `tools/gh.ps1` -- winget GitHub.cli
3. `tools/vim.ps1` -- winget vim.vim
4. `tools/psmux.ps1` -- winget marlocarlo.psmux
5. `tools/copilot.ps1` -- winget GitHub.Copilot
6. `tools/uv.ps1` -- powershell IEX (astral.sh install script)
7. `tools/squad-cli.ps1` -- npm install -g

**Key Learnings:**
- PowerShell functions do NOT set `$LASTEXITCODE`; only native external commands do.
  Test mocks that override winget with a PS function MUST explicitly set
  `$global:LASTEXITCODE = 0` to avoid racy behavior.
- Winget ALREADY_INSTALLED = 0x8A15002B = -1978335189 (signed int32). Always include in
  AllowedExitCodes for winget calls.
- `Assert-LastExit` must be called BEFORE any subsequent PS commands that might change
  `$LASTEXITCODE` (i.e., before `Refresh-SessionPath` even though PS functions don't
  affect it -- defense in depth).
- `[Parameter(Mandatory)]` on the helper's ToolName param satisfies PSUseSingularNouns
  and PSReviewUnusedParameter rules without extra suppressions.

---


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

#### Issue #179 -- Fix psmux winget package ID
- **PR:** #204 -- `fix(windows): use correct psmux winget id (closes #179)`
- **Branch:** `squad/179-psmux-winget-id` from `develop`
- **What:** Replaced skip-with-warning hack with real winget install using correct ID `marlocarlo.psmux`. Removed stale NOTE comment and dead nicowillis/psmux URL.
- **Key finding:** Correct winget ID is `marlocarlo.psmux` (confirmed 2026-05-15). Real upstream repo: `psmux/psmux`.
- **Tests:** All psmux groups (H, I, P) pass. ASCII safety verified.

## Learnings

### Issue #180 - Windows dotfiles installer (2026-05-16)
- Created `scripts/windows/tools/dotfiles.ps1` with `Install-Dotfiles` function
- Pattern: copy with .bak backup (no symlinks on Windows -- avoids admin/developer mode requirement)
- File mappings: .editorconfig, .gitconfig.template->.gitconfig, .npmrc.template->.npmrc, .vimrc->_vimrc
- Windows uses `_vimrc` convention (underscore prefix) unlike Linux `.vimrc`
- Placed Install-Dotfiles after Install-SquadCli and before Write-PowerShellProfile in setup chain
- Tests in Group Q of test_windows_setup.ps1 using temp USERPROFILE override

### Issue #251 -- Session PATH not refreshed after winget installs (2026-05-17)
- **PR:** fix(windows): refresh session PATH after winget installs (#251)
- **Branch:** `goofy/251-windows-nvm-path` from `develop`
- **Bug:** `winget install nvm` succeeded but the running PowerShell session kept its original PATH snapshot. `nvm install` then failed because `nvm.exe` was not on PATH. Same pattern affected git, gh, vim, copilot, psmux.
- **Fix:** Extracted `Refresh-SessionPath` from `nvm.ps1` into shared `scripts/windows/lib/path.ps1`. Sourced it in the orchestrator and all 6 winget-based tool scripts. Added `Refresh-SessionPath` call after every `winget install` that is followed by usage of the just-installed binary. Replaced vim.ps1's inline PATH rebuild with the shared function.
- **Pattern:** Any time a tool modifies the system/user PATH (winget, manual registry write), call `Refresh-SessionPath` before the next `Get-Command` or binary invocation in the same session.
- **Key learning:** Windows PowerShell snapshots `$env:Path` at process start. Registry changes from installers are invisible until you explicitly re-read `[System.Environment]::GetEnvironmentVariable('Path', 'Machine')` and `'User'` and assign back to `$env:Path`. This is a shared-lib concern, not per-tool -- extract once, source everywhere.
- **v2 fix:** squad-cli.ps1 also needed `Refresh-SessionPath` (defensive) -- it runs after nvm.ps1 in the orchestrator and the npm/node junction may not be on PATH for its invocation scope. tests/test_windows_setup.ps1 Group P strip regex needed to handle the new path.ps1 dot-source added to psmux.ps1 (IEX makes `$PSScriptRoot` empty, so relative dot-sources fail).

### Issue #190 - Pin tool versions via .tool-versions (2026-05-16)
- PR: #215 -- `feat(setup): pin tool versions via .tool-versions file`
- Branch: `squad/190-tool-versions` from `develop`
- **What:** Added `.tool-versions` at repo root pinning nodejs 20.11.0, nvm 0.39.7, uv 0.4.18, copilot-cli 0.0.339. Added POSIX `scripts/lib/read-tool-version.sh` parser and PowerShell `scripts/lib/Read-ToolVersion.ps1` (`Get-ToolVersion` function). Updated 4 install scripts to read from `.tool-versions` instead of fetching latest.
- **Tests:** Group R (R-1 through R-4) all pass; bash tests in `test_tool_versions.sh`. ASCII safety verified on all .ps1 files (per ps51-runtime-file-encoding skill).
- **Docs:** README "Version Pinning" section, CHANGELOG under [Unreleased].
- **Key pattern:** `.tool-versions` format is one `tool version` line per row, `#`-prefixed comments allowed. POSIX parser uses `awk` to find the matching row; PowerShell parser uses `Get-Content | Where-Object`.

### Issue #201 - nvm LTS auto-install + squad-cli bootstrap (2026-05-16)
- PR: #218 -- `feat(setup): auto-install Node LTS via nvm`
- Branch: `squad/201-nvm-bootstrap` from `develop`
- **What:** After nvm installs, auto-run `nvm install <version>` and `nvm use <version>` using pinned nodejs version from `.tool-versions`. Refresh PATH so node/npm are usable in the same session. Changed squad-cli npm-missing from silent WARN to hard ERROR with actionable hints.
- **Key findings:** Windows PATH refresh requires re-reading Machine+User registry (session-only entries lost). nvm-windows writes active Node dir to user PATH on `nvm use`. Linux uses `\. "$NVM_DIR/nvm.sh"` (POSIX dot, not `source`) to load nvm into current shell. Idempotency: skip if node --version matches pinned version.
- **Tests:** Groups S (S-1 to S-4) and T (T-1 to T-3) in test_windows_setup.ps1; test_nvm_bootstrap.sh for Linux side.
- **Related to #190:** Reads pinned nodejs version via `Get-ToolVersion -Name 'nodejs'` (PS) and `read-tool-version.sh nodejs` (bash) -- both from `.tool-versions` file added in #190.

### Issue #186 -- Shared logging helpers (2026-05-16)
- PR: #219 -- `refactor(scripts): extract shared logging helpers to lib/`
- Branch: `squad/186-shared-logging` from `develop`
- What: Extracted log_info/log_ok/log_warn/log_error into scripts/linux/lib/log.sh and Write-Info/Write-Ok/Write-Warn/Write-Err into scripts/windows/lib/logging.ps1. Updated 8 shell callers + 11 PS callers to source from lib. Removed duplicate definitions.
- Key findings: Shell tool scripts had drift -- some only defined 2-3 of 4 log functions (gh.sh had only log_info/log_ok, squad-cli.sh missing log_warn). PS uninstall.ps1 uses Write-Host format (not Write-Output) so was left alone. Tests using Invoke-Expression need logging lib pre-loaded and dot-source line stripped since $PSScriptRoot resolves to test dir.
- Tests: tests/test_shared_logging.sh + Group V (V-1 to V-3) in test_windows_setup.ps1

### Post-sprint Windows/PS audit (2026-05-16)
- Lens: windows / powershell / ps 5.1 compat
- 10 findings reported: 1 high-severity bug (nvm.ps1 path resolution), 1 medium (tool error handling), 8 low/improvements
- 2 pass validations: AllScope alias guards complete, ASCII-only check clean
- Coordinator can prioritize F-1 (path bug in PR #218), F-4 (error handling), F-2 (encoding consistency) for next sprint

## [2026-05-17] Verification of Audit Findings (Read-Only Deep Dive)
- **Status:** COMPLETED — 5/5 findings verified; V-1 confirmed P0 bug, V-7 & V-11 & V-15 confirmed P2 refactoring gaps, V-13 confirmed P1 error handling gap
- **Method:** Systematic file inspection + citations to exact locations; compared against ps51-runtime-file-encoding skill
- **Report:** .squad/agents/goofy/VERIFICATION_REPORT.md (13KB, detailed analysis per finding)
- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.

### Retro Action: PR Template with Hygiene Checklist (2026-05-17)
- **Retro:** 2026-05-16 hygiene retro, action item `retro-pr-template`
- **Context:** Recurring sprint hygiene gaps — agents forget to update history.md, drain decisions inbox, capture skills, verify ASCII-only compliance in PS files. Root cause: No visible checklist at PR authoring time. Goofy owned this action item as closure on #215 miss (forgot to update history.md when Chip merged PR #215 tool-versions feature).
- **Solution:** Created `.github/pull_request_template.md` with 8-item hygiene checklist:
  1. Updated `.squad/agents/{name}/history.md` with Learnings entry
  2. Decisions inbox drained (or N/A)
  3. Skill captured for new pattern (or N/A)
  4. ASCII-only enforcement for PS/YAML files (em dashes, curly quotes, smart apostrophes break PS 5.1 CP1252)
  5. Conventional Commits format on all commits
  6. Co-authored-by Copilot trailer on all commits
  7. Branch forked from develop (prevents `squad/*` ancestry bleed)
  8. No rogue files outside canonical `.squad/` paths
- **Design:** HTML-comment-wrapped guidance in template prevents render clutter in PR body but remains visible in editor. Combined with Jiminy's CI gate (separate PR), provides both human-readable confirmation AND automated enforcement.
- **Key Pattern:** Hygiene checklist goes BEFORE first PR body is authored (visible during composition), creates friction against skipping items. This is why appending to history.md in this very commit proves the pattern works — if Goofy had skipped it, the template itself would fail its own checklist.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

## Learnings -- Issue #221 (nvm.ps1 lib path off-by-one)
- **Date:** 2026-05-16
- **Bug:** `nvm.ps1` used one `Split-Path -Parent` from `` (landing in `scripts\windows\lib\`) but `Read-ToolVersion.ps1` lives in `scripts\lib\` (two levels up from `scripts\windows\tools\`).
- **Fix:** Changed to two-level `Split-Path` and added a `Test-Path` assertion so the failure is immediate and descriptive instead of a cryptic dot-source error.
- **Spot-check:** Verified `uv.ps1` and `copilot.ps1` do NOT reference `Read-ToolVersion.ps1` -- no contagion.
- **Pattern:** When tool scripts under `scripts\windows\tools\` need shared libs, the path is always `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent | Join-Path -ChildPath 'lib'`. Add a guard assertion every time.
- **Test:** Added Group W (W-1 through W-3) in `test_windows_setup.ps1` verifying path resolution, runtime assertion presence, and two-level Split-Path usage.
### PR #245 Revision - Missing e2e assertions for squad/psmux/tmux (2026-05-17)
- **Context:** Chip authored PR #245 (branch `chip/239-e2e-install`). Mickey's review flagged missing assertions per Issue #239 acceptance criteria. Per squad governance, a DIFFERENT agent must revise a rejected PR -- Goofy assigned.
- **What was missing:** squad CLI assertion on Linux/macOS; squad, psmux, and tmux assertions on Windows. Also no post-idempotency re-assertions for these tools.
- **What was added:**
  - Linux fresh-shell: `squad --version` with explicit failure message
  - macOS fresh-shell: `squad --version` with explicit failure message
  - Windows fresh-shell: `Assert-Command 'squad' '--version'`, `Assert-Command 'psmux' '--version'`, `Assert-Command 'tmux' '--version'`
  - Post-idempotency assertion steps for all three platforms (verifies tools survive a second setup run)
- **Decision on `|| true` vs hard fail:** Hard fail chosen. squad-cli is a required tool per acceptance criteria. Silent `|| true` would mask real install failures. The error message explicitly names the npm package so CI logs point directly at root cause.
- **Why any agent could do this:** The changes are YAML workflow edits (no PS 5.1 compat concerns, no complex cross-platform logic). Selected per "different agent revises" rule, not technical necessity.

### PR #257 v3 fix (2026-05-18)
- v3 fix -- Add-NvmWindowsPaths defensive injection (winget->registry timing race); fixed 2 stale PS 5.1 tests (R-1 nodejs version, T-3 PATH refresh location).
- v4 fix -- Refresh-SessionPath now MERGES registry into existing $env:Path instead of replacing. Old behavior wiped GH Actions tool-cache Node injection. Skill doc updated. Test T-3c added.
- v5 fix -- Root cause: winget returns before the inner nvm-setup.exe installer finishes writing files/registry. Replaced Add-NvmWindowsPaths with Wait-ForNvmInstall (polling helper, 90s timeout, 5 candidate paths). Kept v4 Refresh-SessionPath merge fix intact. Updated test T-3b, skill doc (Gotcha 2), CHANGELOG.
- v6 fix -- v5 90s timeout was 10s too short (installer took ~100s in CI run 25970591039). v5 candidate paths also missed actual install location (registry update proved installer succeeded but none of 5 paths matched). v6 uses Refresh-SessionPath + Get-Command nvm as primary detection (path-agnostic), expanded candidate list (7 dirs including C:\nvm, C:\nvm-windows) as fallback, 180s default timeout, and diagnostic dump on timeout failure.
- v8 fix -- Earl chose portable download approach. winget install was racy (3 different timings in CI: 24s, 100s, >180s). Replaced Wait-ForNvmInstall with Install-NvmPortable + Set-NvmEnvironment. Downloads nvm-noinstall.zip from GitHub releases, extracts to %USERPROFILE%\nvm (standard nvm-windows portable location). Sets NVM_HOME/NVM_SYMLINK at User scope so subsequent shells work too. Deterministic, no installer race.

## 2026-05-16 -- Sprint R: Winget Exit Code Assertion

**PR:** #268 (fix(scripts/windows): assert winget exit code)
**Branch:** `squad/226-winget-exit-check`
**Status:** MERGED to develop

### What I did

- Added Assert-LastExit helper to scripts/windows/lib/logging.ps1:
  - Signature: `Assert-LastExit [int[]]$AllowedExitCodes = @(0)`
  - Validates $LASTEXITCODE is in the allowed set; exits 1 with clear error message if not
  - PS 5.1 compatible: uses -notcontains (not ternary or null-conditional)
- Patched 7 install sites with Assert-LastExit calls after each winget/npm invocation:
  - tools/git.ps1: winget Git.Git
  - tools/gh.ps1: winget GitHub.cli
  - tools/vim.ps1: winget vim.vim
  - tools/psmux.ps1: winget marlocarlo.psmux
  - tools/copilot.ps1: winget GitHub.Copilot
  - tools/uv.ps1: IEX (uses @(0) only, no winget)
  - tools/squad-cli.ps1: npm install -g
- Added AllowedExitCodes parameter to handle winget-specific codes (e.g., -1978335189 = ALREADY_INSTALLED)
- Added test X-9 to verify that simulated winget failure (exit 99) propagates correctly
- Updated mock P-2 and P-3 to explicitly set $global:LASTEXITCODE = 0 (PS functions don't set it)

### Key learnings

- Winget idempotence: code -1978335189 means tool already installed. Must include in allowed list
  to avoid false failures on re-run. This is winget-specific; npm uses standard 0.
- PS function return codes: PowerShell functions do not automatically set $LASTEXITCODE.
  Callers must check it explicitly after native binary invocation. Tests using mocks
  must set $global:LASTEXITCODE explicitly before assertion.
- Error propagation: Assert-LastExit centralizes the pattern, preventing silent failures.
  Every external tool invocation should be followed by validation.
- Group letter coordination: This PR also created Group X, but collision with #267 Group X
  was resolved by merging #268 first and having #267 rebase to Group Y.
  Lesson: Coordinator should pre-assign group letters in spawn prompts.
2026-05-16 -- #234 ASCII encoding hygiene

---

## [2026-05-17] Sprint S -- Issue #255: Silent version drift bug (tool-version-pins)

**Branch:** `squad/255-tool-version-pins`
**Status:** PR open -- awaiting CI and Mickey review

### Background

Doc's fact-check + coordinator audit revealed a P1 silent-drift bug: all three tool
installers (squad-cli, copilot-cli, gh) used bare `command -v X; then exit 0` guards
with no version in the install command. Any cached binary on CI runners prevented
upgrade; `.tool-versions` bumps had no effect.

Earl approved expanding #255 from "investigate Linux warning" to "fix all three tools
cross-platform."

### What I did

**`.tool-versions`**
- Added `squad-cli 0.9.4` pin
- Added `gh 2.92.0` pin
- `copilot-cli 0.0.339` unchanged

**`scripts/linux/tools/squad-cli.sh`**
- Reads `SQUAD_CLI_VERSION` from `.tool-versions`
- Detects installed version via `squad --version 2>&1 | grep -oE '...' | head -1`
- Version-aware branch: skip / upgrade / fresh-install
- npm install pinned: `@bradygaster/squad-cli@${SQUAD_CLI_VERSION}`

**`scripts/windows/tools/squad-cli.ps1`**
- Dot-sources `Read-ToolVersion.ps1`; reads `SquadCliVersion`
- Detects installed version via regex on `squad --version 2>&1`
- Version-aware branch mirroring Linux logic
- npm install pinned: `@bradygaster/squad-cli@$SquadCliVersion`

**`scripts/linux/tools/copilot-cli.sh`**
- Rewrote: uses `command -v copilot` + version extraction (not `~/.local/bin/copilot` path check)
- Installs via `npm install -g @githubnext/github-copilot-cli@${COPILOT_CLI_VERSION}`
- Gracefully skips if npm not available (warns)

**`scripts/windows/tools/copilot.ps1`**
- Reads `CopilotCliVersion` from `.tool-versions`
- Detects installed version; passes `--version $CopilotCliVersion` to winget
- Fallback to latest if winget refuses the version (CONSTRAINT documented in header)

**`scripts/linux/tools/gh.sh`**
- Linux: tarball download from GitHub releases (reliable cross-distro version pin)
  - `https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz`
  - Extracts to `~/.local/bin/gh`; arch detection (amd64/arm64)
- macOS: brew install/upgrade (WARN if installed version differs; brew cannot pin)

**`scripts/windows/tools/gh.ps1`**
- Passes `--version $GhVersion` to winget so cached runners cannot drift

### Tests added

- `tests/test_nvm_bootstrap.sh` T6-T9: static checks for version-reading and version-aware idempotency
- `tests/test_windows_setup.ps1` Group DD (DD-1 to DD-5): Windows version-pin validation

### Skill

- `.squad/skills/tool-version-pin/SKILL.md`: documents the anti-pattern + canonical solution

### Key decisions

- Used npm install (not `gh.io/copilot-install` pipe) for copilot-cli.sh to guarantee
  version pinning. The `gh.io/copilot-install` script may not honor `COPILOT_CLI_VERSION`
  env var and installing via named npm package is explicit and verifiable.
- Used tarball for Linux gh install; avoids apt package-suffix guessing across distros.
- Added winget fallback for copilot.ps1; winget catalog IDs for GitHub.Copilot may use
  a different version scheme than the npm package. Documented in script header + CONTRIBUTING.
- Group DD chosen for test group (BB/CC pre-assigned to other Sprint S agents).

### Constraints documented

- macOS/brew cannot pin gh version -- logs WARN, accepts latest
- winget `GitHub.Copilot` version ID may differ from semver in .tool-versions
  (which is the npm @githubnext/github-copilot-cli version); fallback to latest on mismatch

---

## [2026-05-18] Sprint S Revision -- PR #282: Fix copilot package name + pin (BLOCKER P0)

**Branch:** `squad/255-tool-version-pins`
**Status:** Revised -- force-pushed to PR #282

### Context

Doc's fact-check on PR #282 found a P0 BLOCKER: `@githubnext/github-copilot-cli@0.0.339`
does not exist on npm. The package publishes versions 0.1.0-0.1.36 only.
The version `0.0.339` was a stale carry-over from the old `curl gh.io/copilot-install | bash`
opaque installer, which used its own internal versioning unrelated to any npm package.

### Package research

Two npm packages exist in the "copilot CLI" space:
- `@githubnext/github-copilot-cli` -- legacy, deprecated, frozen at 0.1.36
  Description: "A CLI experience for letting GitHub Copilot help you on the command line."
- `@github/copilot` -- modern, active, current at 1.0.48
  Description: "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal."

**Winner: `@github/copilot@1.0.48`**

Rationale:
1. The legacy package is explicitly deprecated and frozen -- 0.1.36 is its final version.
2. The modern package is actively maintained and matches the current product branding.
3. The original install mechanism (curl gh.io/copilot-install) installed a standalone copilot
   binary -- NOT from @githubnext/github-copilot-cli. That version number was never a valid
   npm version for either package. Using @github/copilot@1.0.48 is the clean reset.
4. Verified: `npm view "@github/copilot@1.0.48" version` returns `1.0.48` -- package exists.

### Windows: switched from winget to npm

The old Windows approach used `winget install --id GitHub.Copilot`. Research showed this
installs the GitHub Copilot for Visual Studio extension, NOT the CLI. It is the wrong package.
Switching to `npm install -g "@github/copilot@$CopilotCliVersion"` unifies behavior with
Linux and installs the actual copilot binary.

P2 fix is moot: the winget fallback path (which had the misleading Write-Ok) was eliminated
entirely. The npm path has no fallback -- it either installs at the pinned version or fails.
Write-Ok now reports the pinned version explicitly: "GitHub Copilot CLI installed at $version".

### Changes made

**`.tool-versions`:** `copilot-cli 0.0.339` -> `copilot-cli 1.0.48`
**`README.md`:** updated example `.tool-versions` block to match
**`CHANGELOG.md`:** updated copilot-cli entry to describe correct package + reason for correction
**`scripts/linux/tools/copilot-cli.sh`:** `@githubnext/github-copilot-cli` -> `@github/copilot` (3 locations: header comment, log_warn message, npm install line)
**`scripts/windows/tools/copilot.ps1`:** full rewrite -- winget -> npm, correct package, clean header, no fallback path, Assert-LastExit preserved
**`tests/test_windows_setup.ps1`:**
- Group D test: now asserts `npm install -g` + `@github/copilot` (not winget)
- X-5: wingetScripts array reduced from 5 to 4 (copilot removed)
- X-8: same reduction
- Skip/throw messages updated to reference npm

### Lessons learned (retro pointer)

Validate npm package names AND version existence BEFORE committing a pin sweep:
  `npm view "@pkgname@version" version`
must return the version number (not an error) before the pin is committed.
The version `0.0.339` was never verifiable -- it was copied from curl installer internal
state without checking whether it corresponded to a real npm package version.
Add this check to `.squad/skills/tool-version-pin/SKILL.md` validation steps.


---

## [2026-05-18] Sprint T -- Issue #230: Move auth.ps1 under tools/ (Wave 1)

**Branch:** `squad/230-auth-to-tools`
**Status:** PR open

### Background

After PR #195's per-tool refactor, `scripts/windows/auth.ps1` was the lone
top-level installer left at `scripts/windows/`. Issue #230 (P2 chore) called
for relocating it under `tools/` to match the established layout.

### What I did

- `git mv scripts/windows/auth.ps1 scripts/windows/tools/auth.ps1` (git
  reports 96% similarity, rename history preserved).
- Updated the dot-source path inside `auth.ps1` from
  `\lib\logging.ps1` to `\..\lib\logging.ps1`
  to match the pattern used by every other `tools/*.ps1` script. Also
  updated the file's header comment to reflect the new path. No logic
  changes; `Invoke-GhAuth` body is byte-identical.
- `scripts/windows/setup.ps1` line 34: updated dot-source from
  `\auth.ps1` to `\tools\auth.ps1`.
- `tests/test_windows_setup.ps1` line 1195 (Group S setup): added
  `tools` segment to `Join-Path` chain.
- CHANGELOG.md: added an `[Unreleased]` `### Changed` entry.

### Files I did NOT touch

- **ARCHITECTURE.md** -- no auth.ps1 reference present anyway, and Mickey
  owns the file in concurrent worktree #229. Confirmed clean grep.
- **CHANGELOG.md line 76** -- historical entry under 0.8.0 ("Windows
  GitHub auth step via scripts/windows/auth.ps1 (closes #191)") is a
  historically accurate description of the original add and must remain
  pinned to the path at the time. New `[Unreleased]` entry documents
  the move.
- **auth.ps1 function body** -- the four `& gh ...` `0`
  read-without-reset sites flagged in the pwsh-lastexitcode SKILL are
  out of scope for this issue. Wave 2 (#292) handles that hardening.

### Verification

- `Test-Path scripts/windows/tools/auth.ps1` -> True
- `Test-Path scripts/windows/auth.ps1` -> False
- PowerShell parser: all three modified files parse cleanly
- Dot-source from new location succeeds; `Invoke-GhAuth` function defined
- Full `tests/test_windows_setup.ps1` run: Group S 3/3 PASS; 114 total
  PASS, 8 baseline FAIL (Group O alias / live Copilot) -- identical to
  `develop` baseline, unrelated to this change

### Wave 2 queued

- **#292** -- harden the 4 `0` sites in `auth.ps1` plus
  any in `setup.ps1` (per pwsh-lastexitcode SKILL). Next task.

