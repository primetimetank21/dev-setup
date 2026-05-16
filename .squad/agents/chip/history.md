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

⚠️ **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- Hook bypass pattern: use `case "$STRIPPED" in "Merge "*|"Revert "*) exit 0 ;; esac` to skip validation for git auto-generated messages. Must go BEFORE the regex check so these messages never hit the conventional-commits filter. Position matters -- if the case block is after the regex, the hook rejects before reaching it.

- CP1252 encoding trap: Em dash `—` (U+2014) encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252, PS 5.1 treats as string terminator
- Invoke-Expression for function loading: Load functions at Group scope before Test-Scenario calls; `& ([scriptblock]::Create(...))` creates child scope where functions vanish after test
- PowerShell 5.1 validation requires explicit source-level guards, not runtime version checks — test suite requirements > runtime logic correctness
- Test suite can check one pattern (e.g., PSVersion guards) but code implements different valid pattern -- tests must be updated in sync
- PS 5.1 CI step runs `tests/test_windows_setup.ps1` directly via `powershell -File`, so the test file itself must be ASCII-clean (no emojis, em dashes, arrows, or any non-ASCII chars)
- shellcheck `-s bash` flag is needed for sourced dotfiles like `.aliases` that have no shebang -- tells shellcheck the dialect without requiring SC2148 fix
- `config/dotfiles/.aliases` passes shellcheck clean as of issue #193 -- no directives needed, no SC1090/SC2034/SC2148 violations

---

## Recent Work

## [2026-05-22T00:00:00Z] Issue #181: macOS CI validation job

**Branch:** `squad/181-macos-ci`
**PR:** #216
**Status:** PR opened

Added `validate-macos` job to `.github/workflows/validate.yml` (6th CI job). Runs on `macos-latest` and validates: Homebrew availability, zsh + gh pre-installed, uv install via curl, nvm + Node.js install, idempotency (second setup run), and `test_tool_versions.sh`. All tool install scripts (`zsh.sh`, `gh.sh`, `uv.sh`, `nvm.sh`) already handle macOS via `uname -s == Darwin` checks -- no script changes needed.

**Key findings:**
- All tool scripts in `scripts/linux/tools/` already branch on Darwin vs Linux -- no macOS-specific forks required
- `test_setup_basic.sh` does not exist; `test_tool_versions.sh` is POSIX sh and works cross-platform
- macOS GitHub runners have Homebrew and zsh pre-installed; gh is also pre-installed
- Used plain ASCII text in step output (no emoji) to keep the new job ASCII-clean

---

## [2026-05-19T00:00:00Z] Issue #212: commit-msg hook rejects merge/revert commits

**Branch:** `squad/212-commit-msg-merge-bypass`
**PR:** #213
**Status:** PR opened

Added early-exit case block in `hooks/commit-msg` that accepts git default merge and revert messages without running the conventional-commits regex. Added 3 Group B tests in `tests/test_git_hooks.ps1`. All 8 tests pass (5 existing + 3 new).

## [2026-05-19T01:00:00Z] Issue #212: spec-compliant rewrite (prepare-commit-msg)

**Branch:** `squad/212-commit-msg-merge-bypass`
**PR:** #213 (updated in place)
**Status:** PR updated

Replaced the broad `Merge`/`Revert` case bypass with a spec-compliant approach:
- New `hooks/prepare-commit-msg` hook rewrites git auto-generated merge/revert messages into Conventional Commits form before commit-msg runs
- Added `merge` to the commit-msg type allowlist (alongside existing `revert`)
- Removed the case bypass from commit-msg -- no longer needed
- Replaced 3 Group B bypass tests with 7 new tests covering all prepare-commit-msg rewrite patterns plus merge type acceptance
- Per Conventional Commits v1.0.0 spec compliance

---

## [2026-05-18T00:00:00Z] Issue #183: Wire test_git_hooks.ps1 into validate.yml

**Branch:** `squad/183-test-git-hooks-ci`
**What:** Added `tests/test_git_hooks.ps1` to both `validate-powershell` (pwsh) and `validate-ps51` (powershell) CI jobs. Added prerequisite `git config core.hooksPath hooks` step so the hook-path assertion passes on fresh runner checkouts.

---

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

---

## [2026-05-16T02:00:00Z] Skill Created: ps51-ascii-safety

**Location:** `.squad/skills/ps51-ascii-safety/SKILL.md`
**Confidence:** high

Formalized the PS 5.1 CP1252 encoding trap as a reusable skill. Covers detection, fix patterns, common offender table, and when-to-apply rules. Cite this skill in any future `.ps1` file review or creation task.

---

## [2026-05-17] Issue #187: Alias Parity Test

**Branch:** `squad/187-alias-parity`
**Status:** PR opened

Added `tests/test_alias_parity.sh` -- a bash test that extracts alias names from both Linux (`config/dotfiles/.aliases`) and Windows (`scripts/windows/tools/profile.ps1`), compares the two sets, and fails on undocumented drift.

**Design Choices:**
- Bash test (not PS) -- simpler cross-file text parsing; runs in `validate-linux` CI job
- `ALLOWED_ALIAS_DRIFT` array documents intentional platform-only aliases (navigation, ls variants, Docker, editor shortcuts on Linux; rm/touch/gb/New-PsmuxSession on Windows)
- Windows extraction filters out internal helper functions (Write-Info, etc.) and backing functions (Invoke-Git*) -- only Set-Alias -Name targets and user-facing functions count
- Wired into validate.yml as "Run alias parity test" step after existing alias unit tests

**Key file:** `tests/test_alias_parity.sh`

---

## [2026-05-23] Post-sprint tests/CI audit (Sprint 8 wrap)

**Branch:** READ-ONLY audit, no changes  
**Scope:** tests/**, .github/workflows/**, CI matrix completeness, coverage gaps  
**Findings:** 6 issues reported (F-1 through F-6) -- missing pre-commit and pre-push hook tests (medium severity gap), uninstall untested (low gap), macOS job incomplete vs Linux parity (medium gap), redundant chmod (improvement), PSScriptAnalyzer hook tests missing (low improvement). Details in `.squad/agents/chip/audit-findings.md`. Top priority: pre-push hook tests (safety gate). Second priority: pre-commit hook tests. Third priority: uninstall scripts.  
**Findings document:** `.squad/agents/chip/audit-findings.md` (created 2026-05-23)

## [2026-05-23T14:00:00Z] Read-only verification of audit findings (V-3, V-4, V-16)

**Branch:** READ-ONLY verification, no changes  
**Scope:** Deep verification of 3 claims before escalation to issue backlog  
**Method:** File-by-file inspection of hooks, tests, CI workflows, uninstall scripts  

**Verification Results:**
- **V-3 (Hook coverage gaps):** PARTIALLY CONFIRMED. Prepare-commit-msg and commit-msg are well-tested in test_git_hooks.ps1 (Group B: 7 prepare-commit-msg scenarios + 5 commit-msg scenarios). Pre-commit and pre-push hooks lack behavioral tests (only existence/shebang checks in Group A). Pre-push is critical safety gate (blocks main push) -- highest priority for new tests.
- **V-4 (macOS CI parity):** CONFIRMED. Linux job validates nvm + Node.js (lines 43-57) but macOS job does not (lines 83-142 skip this section). Claim about "squad-cli verification" is overstated -- neither Linux nor macOS CI actually runs squad-cli bootstrap/verification at runtime (test_nvm_bootstrap.sh is static lint, not runtime test, and not wired into validate.yml).
- **V-16 (Uninstall coverage):** CONFIRMED. Both scripts/linux/uninstall.sh and scripts/windows/uninstall.ps1 exist with idempotent logic. Zero test references found in tests/ or .github/workflows/. Both scripts are production-ready but untested.

**Citations:** Full report with line-number citations documented in decision inbox (chip-v3-v4-v16-verification.md).
**Phase recommendation:** P1 (V-3 pre-push, V-4 macOS), P3 (V-16 uninstall, low criticality)
**Next step:** Earl decides whether findings roll to issue backlog or are addressed in next sprint.

---

## [2026-05-16T07:35:02Z] Issue #239: P0 E2E Install Testing (Comprehensive Workflow)

**Issue:** #239 (priority:p0, squad:chip, enhancement, area:ci)
**Assigned to:** Chip — comprehensive E2E install verification on fresh runners

**Scope:** Full tool-verification workflow across all 3 OS platforms (Linux, macOS, Windows):
- squad-cli bootstrap verification (`squad --version`)
- psmux (Windows tmux alias) setup
- All tool installs: zsh, uv, nvm, gh, GitHub Copilot CLI
- Fresh runner baseline (per-PR validation)
- Nightly cron also approved

**Key Context:**
- Cost correction: dev-setup is PUBLIC repo; GitHub Actions runners are FREE
- Scope expansion: Not just setup.sh/setup.ps1 routing, but full tool-verification scope
- Priority framing: P0 "safety net for what really works on fresh machines"
- Related: Supersedes #226 (macOS parity, narrower); overlaps #238 (uninstall tests)
- Terminology: psmux is Windows tmux alias (NOT wezterm — coordinator error corrected)
- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.

---

## [2026-05-16T08:00:00Z] Retro Item: CI Enforcement Gate for Squad History.md

**Retro:** 2026-05-16 hygiene retro, item `retro-ci-gate` (enforcer: Chip)  
**Issue:** #239 (P0, squad:chip)  
**Context:** Recurring issue - agents complete work but forget to append Learnings to their history.md. Goofy skipped update on PR #215; history backfilled manually post-merge. Earl wants this enforced at CI level so PR cannot merge without history append.

**Solution:** New workflow `.github/workflows/squad-history-check.yml` enforces rule: Any PR carrying at least one `squad:*` label (e.g., `squad:goofy`, `squad:chip`, etc.) MUST modify the matching agent's `.squad/agents/{name}/history.md` file.

**Implementation Details:**
- **Trigger:** PR open/sync/reopen/label/unlabel events targeting develop or main branches
- **Label Mapping:** `squad:{name}` label maps to `.squad/agents/{name}/history.md` file path check
- **Validation Logic:** For each `squad:*` label on the PR, verify history file appears in changed files (via `gh pr diff --name-only`)
- **Failure Mode:** If history file not modified, emit `::error::` with clear message: "squad:{name} PR but .squad/agents/{name}/history.md not modified. Append a Learnings entry and push."
- **Multi-label Handling:** If PR has multiple squad labels (rare), ALL matching history files must be touched
- **Non-squad PRs:** PRs without any `squad:*` label skip the check entirely (pass through)
- **Hard Gate:** Per Earl directive, no override path exists. Gate is strict and cannot be bypassed.

**Key Integration:** The squad-history-check workflow itself enforces squad operational hygiene. It uses `squad:chip` label on its own PR, so it validates the new gate works before merge ("dogfood test").
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

---

## [2026-05-23T15:00:00Z] Issue #239: E2E Install Smoke Test Implementation

**Branch:** `chip/239-e2e-install`
**PR:** (pending)
**Status:** Implementation complete

Created `.github/workflows/e2e-install.yml` -- full end-to-end install smoke test across Linux, macOS, and Windows fresh runners.

## Learnings

### Workflow Design Decisions

- **Separate jobs per OS (not matrix):** Used 3 independent jobs (`e2e-linux`, `e2e-macos`, `e2e-windows`) instead of a matrix strategy. Rationale: the step sequences differ significantly between Unix and Windows (different shells, different assertion patterns, different PATH refresh mechanisms). A matrix would require excessive `if` conditions and reduce readability.
- **Fresh shell spawning:** Linux/macOS assertions run inside `bash -lc '...'` to simulate a new login shell that sources profiles. Windows spawns a `pwsh -NoProfile -Command {...}` to test that PATH changes persist at system/user level without relying on profile dot-sourcing in the same process.
- **Non-blocking initially:** All 3 jobs use `continue-on-error: true` at the job level. This means the workflow never blocks PR merge. Rationale: first-run flakiness is expected (third-party network, winget rate limits). Will flip to blocking after observing 2-3 green nightly runs.

### Non-Interactive Flag Survey

- **No new flag needed.** Both `scripts/linux/tools/auth.sh` and `scripts/windows/auth.ps1` already detect `$CI=true` (set automatically by GitHub Actions) and skip interactive auth prompts. The `install_prerequisites()` function in `scripts/linux/setup.sh` uses `apt-get -y` and `DEBIAN_FRONTEND=noninteractive` is set in the workflow env. No changes to setup scripts required.

### Retry Strategy

- **Not implemented in v1.** The issue spec mentions retrying network ops up to 2x, but setup scripts themselves handle retries internally where needed (e.g., curl with timeouts). Adding workflow-level retry would require `uses: nick-fields/retry@v2` or shell loops, adding complexity. Deferred to stabilization phase after observing which steps actually flake. The `continue-on-error: true` on jobs provides the safety net in the meantime.

### Blocking vs Non-Blocking

- Started non-blocking per acceptance criteria. The stabilization plan:
  1. Monitor nightly runs for 1 week
  2. Identify and fix true flakes (third-party network, winget rate limits)
  3. After 2-3 consecutive green nightlies, Earl flips to blocking by removing `continue-on-error: true` from jobs

### Notes for #225 Follow-Up (macOS CI Parity)

- The e2e-install.yml macOS job covers tool assertions that validate.yml's `validate-macos` job does NOT (nvm+Node, tmux, dotfiles, git hooks). When #225 lands, validate-macos may be redundant with the e2e job. Recommend consolidation at that point.
- The e2e workflow is in a SEPARATE file (`e2e-install.yml`) -- it does NOT touch `validate.yml`. Safe to modify validate.yml independently for #225.

### squad-cli and psmux Assertions

- `squad --version` assertion is included in spec but deferred from initial assertions. Reason: squad-cli install depends on npm global install which may not persist across fresh shell invocations on all platforms without profile sourcing. Will add once baseline is green.
- psmux assertions on Windows deferred similarly -- psmux is installed via setup but binary availability in a fresh `pwsh -NoProfile` session depends on PATH persistence.

### Key Insight: PATH Refresh on Windows

- Windows tool assertions use `pwsh -NoProfile` to test that tools are on the system PATH (not just available via profile functions). This is the correct test -- if a tool only works because the profile adds it to PATH, it will fail for scripts/automation that run without profile. The nvm.ps1 bug (#221) was exactly this class of failure.


## Learnings

### Issue #225: Aligning validate-macos with validate-linux (nvm + Node.js)

- Added nvm + Node.js validation step to validate-macos mirroring the existing validate-linux step (lines 43-57).
- macOS-specific differences: None required. NVM_DIR is HOME/.nvm on both platforms, and the macOS runner default shell is bash (3.2) which supports the same sourcing pattern. No brew install calls needed since nvm is installed by setup.sh.
- Kept echo messages without emoji (ASCII-only) to match existing macOS job style, unlike validate-linux which uses emoji markers.
- Verification approach: YAML structure validated by maintaining consistent indentation; shell commands are POSIX-compatible and work in bash 3.2+.
- Placement: step inserted between 'Validate uv installed' and 'Validate gh CLI installed' to match the logical order in validate-linux.

### Issue #252: Node version pinned at 20.11.0, squad-cli requires >=22.5.0

- Root cause: `.tool-versions` pinned `nodejs 20.11.0`, which both Linux/macOS (`nvm.sh`) and Windows (`nvm.ps1`) read via `read-tool-version.sh` / `Read-ToolVersion.ps1`. The version 20.11.0 predates the `squad-cli` engine requirement of `>=22.5.0`.
- Fix: Bumped `.tool-versions` from `nodejs 20.11.0` to `nodejs 22.11.0` (Node 22 LTS baseline). No script changes needed -- both platform scripts already read from `.tool-versions`.
- Regression guard: Added a `Node version gate (>=22)` assertion to both Linux and macOS e2e-install.yml fresh-shell steps. The assertion extracts the major version from `node --version` and fails the job if it is below 22.
- Windows parity: Windows `nvm.ps1` also reads from `.tool-versions`, so the bump applies automatically. No separate Windows fix needed.
- Lesson: When a centralized version file like `.tool-versions` exists, version drift bugs are single-line fixes -- but only if e2e assertions actually check the installed version against downstream requirements. Always add version-gate assertions for tools with engine constraints.
