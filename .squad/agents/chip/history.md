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

**Sprints 1–7 Summary (2026-04-07 to 2026-05-04):**

Established CI/CD validation framework and cross-platform test coverage infrastructure:

- **Sprints 1–4:** Linux/Windows CI workflows, shellcheck (shell scripts), PSScriptAnalyzer (PowerShell)
- **Sprint 5:** Windows PowerShell regression test suite (15 tests, Groups A–D); idempotency test framework
- **Sprint 6:** PS 5.1 dual-runtime validation (`Parser::ParseFile` syntax checks, PSScriptAnalyzer on windows-latest); git hooks testing
- **Sprint 7:** Git hooks tests (commit-msg validation, branch guard); PS variable guard fixes via Test-Path guards (later reverted to PSVersion pattern)
- **Sprint 8:** Group K, N, O, P test updates for split Windows setup architecture and AllScope alias override verification

**Key Patterns Established:**
- `shell: powershell` = PS 5.1; `shell: pwsh` = PS 7+ (critical distinction)
- `Join-Path` nested 2-arg syntax for PS 5.1 compatibility (no array join)
- PSScriptAnalyzer rule naming: `PSUseBOMForUnicodeEncodedFile` for non-ASCII content
- Test framework: `Test-Scenario` wrapper for PASS/FAIL reporting, random temp files for CI isolation
- ASCII-only in all test literals (UTF-8 em-dash, smart quotes cause CP1252 encoding traps on PS 5.1)
- Conditional skip pattern: `Get-Command -ErrorAction SilentlyContinue` outside test block, call `Write-Skip` if found

**Key Files:**
- `.github/workflows/validate.yml` — 5 jobs: lint-ps, validate-ps (PS 7+), validate-ps51 (PS 5.1), lint-shell, validate-linux
- `tests/test_windows_setup.ps1` — 61 tests across 11 groups (A–L); Groups A–B verify functions, C–D integration, E vim, F aliases, G squad-cli, J sentinel, K profile paths, L PSScriptAnalyzer hook
- `tests/test_idempotency.sh` — Linux idempotency baseline

**Tech Debt:**
- Test file assertions must track actual implementation patterns; static-analysis tests break silently when code refactors

---

## Learnings

- CP1252 encoding trap: Em dash `—` (U+2014) encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252, PS 5.1 treats as string terminator
- Invoke-Expression for function loading: Load functions at Group scope before Test-Scenario calls; `& ([scriptblock]::Create(...))` creates child scope where functions vanish after test
- PowerShell 5.1 validation requires explicit source-level guards, not runtime version checks — test suite requirements > runtime logic correctness
- Test suite can check one pattern (e.g., PSVersion guards) but code implements different valid pattern -- tests must be updated in sync
- PS 5.1 CI step runs `tests/test_windows_setup.ps1` directly via `powershell -File`, so the test file itself must be ASCII-clean (no emojis, em dashes, arrows, or any non-ASCII chars)

---

## Recent Work

## [2026-05-16T01:30:00Z] Issue #197: Non-ASCII Test File Fix (CP1252 Encoding Cleanup)

**Branch:** `squad/197-ps51-compat-fix`  
**Status:** ✅ COMPLETE — file fully ASCII-clean, committed & pushed

Removed 14 non-ASCII characters from `tests/test_windows_setup.ps1` to resolve CP1252 encoding trap on PS 5.1:

**Characters Replaced:**
- 8 emoji test markers (`✓`, `✗`, `⚠`, etc.) → `[PASS]`, `[FAIL]`, `[SKIP]` text tags
- 4 em dashes (U+2014) in comments → ` - ` (space-hyphen-space)
- 2 arrows (U+2192) in comments → `->` (ASCII hyphen-greater-than)

**Why:** PS 5.1 reads files as CP1252 by default. UTF-8 byte sequences for non-ASCII chars produce bytes that CP1252 misinterprets as string terminators or control chars, causing `ParserError: TerminatorExpectedAtEndOfString`.

**Outcome:** Test file now passes PS 5.1 validation. All 61 tests validated under both PS 5.1 and PS 7+.

**Key Decisions Captured:**
1. ASCII-only rule for test files (chip-test-ascii-rule.md)
2. CP1252 string-literal encoding rule with Invoke-Expression pattern for cross-group tool loading (chip-ps51-tests.md)
3. Conditional skip pattern for binary-dependent tests (P-2 psmux test)

---

## [2026-05-14] Issue #197: PS 5.1 Test Groups N, O, P for AllScope Aliases & Psmux

**Branch:** `squad/197-ps51-compat-fix`  
**Status:** Tests implemented (PR pending)

Added three new test groups validating PS 5.1 AllScope alias override behavior and psmux installation:

**Group N (PS 5.1 Profile Write):** Runtime tests call `Write-PowerShellProfile` and assert both profile files exist (PS 5.1: `WindowsPowerShell`, PS 7+: `PowerShell`); source-level checks verify BEGIN/END markers and `Remove-Item -Force Alias:\` guards for all 11 AllScope-conflicting aliases.

**Group O (PS 5.1 Alias Override):** 7 runtime tests execute `Remove-Item -Force 'Alias:\<name>'` then `Set-Alias -Force -Scope Global` for each of: gc, gcm, gl, gp, ni, rm, h. Verifies pattern works without error.

**Group P (psmux Install):** P-1 uses AST parser for syntax check + Invoke-Expression to load psmux.ps1, confirms `Install-Psmux` callable; P-2 conditionally runs if psmux absent (skip if binary found), captures output, asserts warning; P-3 calls `Install-Psmux` twice for idempotency.

**CI Step Added:** `Test PS 5.1 profile write` in validate-ps51 job: dot-sources profile.ps1, calls `Write-PowerShellProfile`, asserts PS 5.1 profile exists.

**Key Patterns:**
- AllScope alias guards: All 11 PS 5.1 conflicting aliases require `Remove-Item -Force Alias:\<name>` before `Set-Alias`
- Conditional skip: Check binary existence outside test block, call `Write-Skip` if found, `Test-Scenario` if not

---

## [2026-05-04] PR #195 Group K Test Updates: Windows Setup Split Refactor

**PR:** #195 (refactor Windows setup into per-tool files)  
**Status:** ✅ MERGED to develop

Updated all 5 Group K tests (K-1 through K-5) to track new file locations after Goofy split monolithic `scripts/windows/setup.ps1` into per-tool files under `scripts/windows/tools/`:

**Changes:**
- K-1, K-2, K-4, K-5: Updated AST parser target from `setup.ps1` → `tools/profile.ps1` (where `Write-PowerShellProfile` now lives)
- K-3: Updated heredoc extraction to read from `profile.ps1`
- All 5 tests verified passing, 61/61 tests passing overall, 5/5 CI green

**Key Learning:** When code is refactored into separate modules, AST-based tests must track the actual file containing the function being tested — not just the top-level orchestrator. Group K tests verify profile management logic, so they reference the dedicated `profile.ps1` tool file where `Write-PowerShellProfile` lives.

---

## [2026-04-18] Sprint 7 Completion: Issues #121 (git hooks), #123 (CI triage)

**Session:** Full autonomous execution  
**Status:** ✅ All work merged to develop

**Issue #121 — git hooks implementation (PR #130):**
- `hooks/commit-msg` — Conventional Commits validation (hard reject, exit 1)
- `hooks/pre-push` — Branch protection (block direct push to main) + shellcheck on changed .sh files
- Tests: Group A (hook config, files exist, shebangs valid); Group B (commit-msg validation)

**Issue #123 — CI triage & PS 5.1 compat (PR #130):**
- 5 historical CI failures on main branch: Stale, superseded by PR #126 (em-dash removal)
- Pre-existing develop failure: Root setup.ps1 using PSVersionTable checks instead of Test-Path Variable:* guards
- Fix: Replaced all version checks with Test-Path Variable:* guards (pattern: `Test-Path Variable:IsWindows -and $IsWindows`)

**Key Learning:** PowerShell 5.1 validation requires explicit source-level guards, not runtime version checks. Always check if newer PR superseded earlier CI failures (stale artifacts common in shared repos).

**Outcome:** Main and develop branches both green. All Sprint 7 CI issues resolved.
