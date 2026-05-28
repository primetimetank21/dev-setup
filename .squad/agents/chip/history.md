# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup -- A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent -- safe to run multiple times

## Core Context

**Sprints 1-7 Summary (2026-04-07 to 2026-05-04):**

Established CI/CD validation framework and cross-platform test coverage infrastructure:

- **Sprints 1-4:** Linux/Windows CI workflows, shellcheck (shell scripts), PSScriptAnalyzer (PowerShell)
- **Sprint 5:** Windows PowerShell regression test suite (15 tests, Groups A-D); idempotency test framework
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
- `.github/workflows/validate.yml` -- 5 jobs: lint-ps, validate-ps (PS 7+), validate-ps51 (PS 5.1), lint-shell, validate-linux
- `tests/test_windows_setup.ps1` -- 61 tests across 11 groups (A-L); Groups A-B verify functions, C-D integration, E vim, F aliases, G squad-cli, J sentinel, K profile paths, L PSScriptAnalyzer hook
- `tests/test_idempotency.sh` -- Linux idempotency baseline

**Tech Debt:**
- Test file assertions must track actual implementation patterns; static-analysis tests break silently when code refactors

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- Hook bypass pattern: use `case "$STRIPPED" in "Merge "*|"Revert "*) exit 0 ;; esac` to skip validation for git auto-generated messages. Must go BEFORE the regex check so these messages never hit the conventional-commits filter. Position matters -- if the case block is after the regex, the hook rejects before reaching it.

- CP1252 encoding trap: Em dash `--` (U+2014) encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252, PS 5.1 treats as string terminator
- Invoke-Expression for function loading: Load functions at Group scope before Test-Scenario calls; `& ([scriptblock]::Create(...))` creates child scope where functions vanish after test
- PowerShell 5.1 validation requires explicit source-level guards, not runtime version checks -- test suite requirements > runtime logic correctness
- Test suite can check one pattern (e.g., PSVersion guards) but code implements different valid pattern -- tests must be updated in sync
- PS 5.1 CI step runs `tests/test_windows_setup.ps1` directly via `powershell -File`, so the test file itself must be ASCII-clean (no emojis, em dashes, arrows, or any non-ASCII chars)
- shellcheck `-s bash` flag is needed for sourced dotfiles like `.aliases` that have no shebang -- tells shellcheck the dialect without requiring SC2148 fix
- `config/dotfiles/.aliases` passes shellcheck clean as of issue #193 -- no directives needed, no SC1090/SC2034/SC2148 violations
- Issue #424: when wiring `tests/test_precommit_hygiene.sh` into `validate.yml`, set `git config --global init.defaultBranch master` before the hook-path step. The test creates `main` later; runners whose `git init` default is already `main` make that scenario fail before the hook is exercised.
- Issue #441/#442 (v5.2): `tests/test_alias_parity.sh` scrapes ALL PowerShell `function` declarations from `profile.ps1` and treats them as aliases. Any new Windows-only PS helper function (e.g. `Invoke-HostQuery`, `Resolve-ProfilePath`) will appear as undocumented drift. Fix: add to `ALLOWED_ALIAS_DRIFT` with `windows` platform tag, OR add the function name to the exclusion grep in `extract_windows_aliases`. The allowlist is the right choice for user-visible helpers; the exclusion grep is right for purely internal plumbing. Future PS helpers added in Windows-only paths will trigger this test until one of those two options is applied.

---

## Recent Work

> Compressed 2026-05-17 per #319. Older entries summarized; full pre-Sprint-11 history at history-archive.md.

## Recent Work (pre-#239 summary)

**Full detail in `history-archive.md`.** Sprints 9-17 archived. Key learnings: CP1252 encoding, PSVersion guards, hook behavioral testing patterns, e2e-install gate, group X hook tests, group FF uninstall sandbox.

## Issue #441 Plan Grill (Chip v4) -- 2026-05-27 [compressed]

Grilled v4 (Jiminy revision). Verdict: REVISE. Two MEDIUMs: (1) GG-7 exe spec missing --
if engineer uses 'pwsh' on PS5.1-only runner, false green via not-installed early-exit;
fix: specify 'powershell'. (2) $TestDrive (Pester-only) in GG-1/4/5 with no temp-file
pattern -- destructive writes to real $HOME in CI; fix: $env:TEMP + New-Guid + finally.
Two LOWs: C-2/C-3 skip-as-pass; BeforeEach reference. Impl-ready: NO. Key lesson: document
the input exe -- mock mechanism correctness doesn't protect against env-fragile setup.

## Issue #441 Plan Grill (Chip v5) -- 2026-05-27

Grilled plan #441 v5.1 (Donald revision -- H1-H5 + F-4/F-5 patches). Verdict: SHIP.

**C-1/C-2/F-3 status:**
- C-1 (GG-7 exe spec): RESOLVED -- GG-7 Input now says '$HostExe = 'powershell'' with rationale
  about 'pwsh' masking the not-installed early-exit on PS5.1-only runners.
- C-2 (TestDrive -> real temp path): RESOLVED -- Section 5 documents Join-Path $env:TEMP +
  New-Guid + finally cleanup for GG-1/GG-4/GG-5; $ps51Fallback/$ps7Fallback overrides stated
  in GG-4 row; $TestDrive removed entirely.
- F-3 (LASTEXITCODE reset positioning): RESOLVED -- Section 5 says "Before each redefinition,
  reset $global:LASTEXITCODE = 0"; ordering is explicitly before mock redefinition.

**Regression check (H1-H5, F-4, F-5):** All HOLD. Algorithm correct. BeforeEach reference
fixed (now says "not a BeforeEach block -- Test-Scenario has none").

**New LOWs (non-blocking):**
- NF-1: H1 has no encoding assertion in GG-4 (ASCII encoding on Set-Content not verified).
- NF-2: F-4 middle-of-file case not exercised (GG-4 doesn't specify content after the block).
- NF-3: NF-3v4 carry-forward -- C-2/C-3 skip-as-pass; Write-Host not Write-Skip; still LOW.
- NF-4: GG-1 $mockPath identity implicit (row says 'OneDrive path'; temp path only in Section 5).

**Implementation-ready: YES.** No MEDIUM+ concerns open. Four LOWs acceptable for vertical slice.
Engineer can implement GG-1..GG-7 straight from v5.1 without false-green or destructive-path risk.

## Issue #441 Plan Grill (Chip v5.2) -- 2026-05-27

Grilled plan #441 v5.2 (Mickey revision -- JN-1/JN-2 patch). Verdict: SHIP.

**JN-1 (parameterization):** RESOLVED. `Write-PowerShellProfile` now accepts
`-Ps51Fallback`/`-Ps7Fallback` params with $HOME-derived defaults. Parameters feed both
`Resolve-ProfilePath` fallback args AND `$legacyPaths` (orphan-strip targets). GG-1/4/5
all pass both params with temp paths. Temp path pattern (`Join-Path $env:TEMP
"gg-test-441-$(New-Guid)"`) explicit in Section 5 header + GG-4 row. `finally` cleanup
documented. No disk writes to real $HOME. Mechanism sound.

**GG-2/3/6/7 destructive write risk: NO.** Section 5 explicitly marks GG-1/4/5 as
"write to disk" tests. GG-2/6/7 test Resolve-ProfilePath return values (no disk writes).
GG-3 tests dedup logic in isolation (`$profilePaths.Count -eq 1` from Sort-Object
expression -- not callable via Write-PowerShellProfile from test scope).

**JN-2 (Write-Warning + [SKIPPED] tag):** PARTIAL. Visibility resolved -- warning stream
visible, [SKIPPED] grep-able in CI logs, D2 preserved. Skip counter gap remains: Write-Warning
does not call Write-Skip (harness skip-counter function); C-2/C-3 on PS7+ still do not
increment TestsSkipped. LOW residual.

**Implementation-ready: YES.** GG-3 invocation target (dedup in isolation) mildly ambiguous
(LOW). GG-1 $mockPath + GG-4 $oneDrivePath not explicitly stated as temp paths (LOW -- CI
failure reveals, not silent destruction).

**New finding (NF-4-v5.2, LOW):** Resolved-path write target in GG-1/GG-4 (mock return
value) not redirected to temp by -Ps51Fallback/-Ps7Fallback. Write loop writes to
$profilePaths entries = mock return values. On CI, no real OneDrive dir -> test failure
(observable); not silent destruction. One sentence in GG-1/4 Input cells would close.

**Carry-forward LOWs:** NF-1 (encoding assertion), NF-2 (F-4 middle-of-file), NF-3/JN-2
(skip counter), NF-4 (resolved-path identity). None blocking.

## PR #458 Review -- 2026-05-27T20:09:59-04:00

Reviewed PR #458 (feat(profile): #442 v5.2 profile-path fix -- host-queried PROFILE + legacy cleanup). Verdict: APPROVED (comment; GitHub blocked self-approve on Copilot-authored PRs).

**Tests run locally (PS 5.1):** 136 passed / 8 skipped / 8 failed. All 7 GG gates PASS. The 8 failures are pre-existing (D-4 live Copilot, O-1..O-7 alias override).

**All 6 acceptance criteria met:**
- AC-1: GG-1 confirms block written to mock OneDrive path (not hardcoded)
- AC-2: GG-4 dual-orphan legacy cleanup strips both fallback files
- AC-3: uninstall.ps1 inlines resolver + unions resolved+legacy paths
- AC-4: [INFO] Resolved ... path emitted in GG-1/3/4/5/6 output
- AC-5: Group GG (7 tests) mocks Invoke-HostQuery
- AC-6: C-2/C-3 have Write-Warning '[SKIPPED]...' + return guards

**ASCII check:** All 3 touched .ps1 files clean (profile.ps1, uninstall.ps1, test_windows_setup.ps1).

**Stream purity:** Resolve-ProfilePath (value-returning) uses Write-Host directly for all 4 log calls -- consistent with the lesson captured in pluto/history.md. GG-2/GG-7 empirically confirm no stream pollution ($result == fallback path only).

**Carry-forward LOWs (non-blocking, accepted in v5.2 grill):** NF-1 (GG-4 no encoding assertion), NF-2 (middle-of-file strip), NF-3/JN-2 (skip counter gap), NF-4 (resolved-path write identity).

## Learnings

**OneDrive/KFM profile path testing pattern:** Mock Invoke-HostQuery at script scope (not inside Test-Scenario) to override the host-query seam. Pass temp paths via -Ps51Fallback/-Ps7Fallback to Write-PowerShellProfile. Reset $global:LASTEXITCODE = 0 before each mock definition to prevent GG-7's native-command exit-1 from contaminating subsequent success-path tests. Seed idempotency test files with pre-existing content -- the strip regex requires a preceding \r?\n before BEGIN marker (position-0 blocks not a production scenario but break GG-5 if file starts empty).

**Self-approve blocked on Copilot-authored PRs:** GitHub blocks 'addPullRequestReview' approve action when the reviewer is the same bot identity as the PR author. Use --comment with a clear APPROVED verdict header instead. Flag this to coordinator for routing -- Earl or a human reviewer must click Approve in the GitHub UI.

**PowerShell parity-gap test patterns (Issue #451 research):** Three gaps identified in test_sprint_end_labels_pwsh.ps1 vs. bash peer test_sprint_end_labels.ps1: (1) Missing --release-label alone validation (Test C), (2) Bad --release-label prefix validation (Test D), (3) No CRLF-in-launcher regression test (T7). Bash peer has Tests A-G (7 total); PowerShell needs T1-T7 + T_C + T_D (9 total) for parity. T7 requires binary byte inspection via `[System.IO.File]::ReadAllBytes()` (not Get-Content, which applies encoding), asserting no 0x0D (CR) bytes in launcher shim. Test isolation uses existing New-TestEnv fixture with minimal state. Effort: T_C/T_D simple (~5 min each, no setup), T7 more involved (~20 min, careful encoding handling). Key risk: T7's byte-level assertion must avoid encoding transforms; use ASCII-only Write-AsciiFile pattern (established in chip/history.md PS51-safety notes).

## PR #438 Review -- 2026-05-27

- Reviewed PR #438 (feat/scripts: sprint-end-labels.ps1 PowerShell parity) under domain-aligned reviewer model (PR #445). Single-file change: tests/test_sprint_end_labels_pwsh.ps1. Verdict: APPROVE. Fix strips CRLF from bash launcher here-string before ASCII write -- consistent with peer test pattern (lines 209, 264 of test_sprint_end_labels.ps1). Three pre-existing parity gaps noted as follow-up items.

## 2026-05-27 -- PR #458 Review (In Flight)

- Reviewing PR #458 (v5.2 profile-path fix, closes #441/#442). Focus: acceptance criteria, test coverage (136 passed, 8 pre-existing baseline failures). Pluto's implementation on branch squad/442-profile-path-impl delivered Invoke-HostQuery, Resolve-ProfilePath, Write-PowerShellProfile parameterization, legacy cleanup, uninstall resolver integration. Mickey reviewing architecture/cross-cutting in parallel.
- 2026-05-27 -- #442/#458 re-review -- CI 11/11 green; allowlist patch (Invoke-HostQuery:windows, Resolve-ProfilePath:windows) correctly scoped with :windows suffix and #441/#442 reference; all 6 AC met; posted VERIFY OK comment per co-author lockout protocol.

## 2026-05-27 -- Grill Ceremony: Issue #451 Vertical Slice Plan (v1->v3)

- **Plan author role:** Authored vertical slice plan for PowerShell test parity gaps (T_C, T_D, T7 + CI YAML step). v1 received 4 blocking/major findings; revised to v2 (all findings resolved); revised to v3 (added out-of-scope tracking for $IsWindows caveat, filed #461).
- **Grill panel feedback (v1->v2->v3):** Mickey R1 REVISE (CI gap, PS 5.1 coverage, error-msg coupling, T7 vagueness); Goofy R1 REVISE ($IsWindows fragility); Jiminy R1 DIRTY (plan location); Mickey R2 APPROVE (all 4 blockers resolved); Goofy R2 APPROVE-W/-CAVEATS (caveat tracked); Jiminy R2 CLEAN; Mickey R3 APPROVE (R2 conditions tracked); Goofy R3 APPROVE (scope boundary sound); Jiminy R4 CLEAN (trailers verified).
- **Trailer fix:** Commits 461befc + b274cebe had Co-authored-by concatenated to body (no blank line); fixed via doc rebase to 72b80bb + 18f170a; verified via `git interpret-trailers --parse`.
- **Implementation ready:** YES. Plan v3 at docs/plans/451-pwsh-parity-gaps.md with all acceptance criteria documented. Draft PR #462 opened. Follow-up #461 filed for PS 5.1 defensiveness (out-of-scope).

