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

## Issue #441 Plan Grill (Chip v4-v5.2) -- 2026-05-27 [compressed]

v4 REVISE: GG-7 exe unspecified (false-green on PS5.1-only runner); $TestDrive -> real $HOME
write risk. v5.1 SHIP: C-1/C-2/F-3 resolved; 4 carry-forward LOWs non-blocking; impl-ready.
v5.2 SHIP: JN-1 (Write-PowerShellProfile parameterization) resolved; JN-2 (Write-Warning)
partial (skip counter LOW); all MEDIUMs closed. Key lesson: document input exe -- mock
mechanism correctness doesn't protect against env-fragile setup.

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

## Issue #451 Grill Response -- 2026-05-27T23:12:03-04:00

Revised plan v2 per 3-reviewer grill panel (Mickey/Goofy/Jiminy). Four findings addressed:

- CI gap (Mickey BLOCKING + Goofy #1): validate-ps51 job does not run test_sprint_end_labels_pwsh.ps1.
  Added explicit YAML step (shell: powershell, line 369+) to plan; removed assumption of "no new CI changes."
  Lesson: always audit the CI matrix when adding tests -- "existing jobs run expanded suite" is not a plan,
  it is a wish.
- T7 vagueness (Mickey MAJOR-2): "assert shebang valid" was undefined. Resolved to two concrete assertions:
  no 0x0D bytes (regression invariant) + bytes[0]/[1] == 0x23/0x21 (shebang header intact). Both required
  because the "no CR" check alone does not confirm the Replace call left the header uncorrupted.
- Error message coupling (Mickey MAJOR-1 / Goofy T_C/T_D): T_C/T_D assertion strategy now explicit --
  T_C is exit-code-only (mirrors bash Test C); T_D uses "release:shipped-" substring match (mirrors bash
  Test D). Contract documented in Risk Assessment and Done Criteria. Lesson: "parity keeps both in sync"
  is not a risk mitigation -- it is a description of the coupling.
- Plan path (Jiminy MEDIUM): Plan moved from .squad/decisions/451-vertical-slice.md to
  docs/plans/451-pwsh-parity-gaps.md per PR #441 precedent. .squad/decisions/ is for sprint archives,
  not pre-implementation working plans.

## Issue #451 Grill Response Round 2 -- 2026-05-27T23:47:00-04:00

Revised plan v3 per Round 2 grill panel (Mickey/Goofy/Jiminy).

- Mickey APPROVE (all R1 findings resolved): Done Criteria already covered both
  implementation-phase notes (error-message contract at line 174, TODO removal at line 172).
  No text change required.
- Goofy APPROVE-WITH-MINOR-CAVEATS: $IsWindows PS 5.1 hazard (New-TestEnv line 320).
  Decision: out of scope for #451 (pre-existing code). Filed issue #461. Added
  Out-of-Scope Tracked Item section to plan.
- Jiminy CLEAN (commit trailer cosmetic note): v3 commit uses blank-line-separated
  Co-authored-by trailer per git interpret-trailers convention.

Learnings:
- When a grill surfaces a hazard in pre-existing code outside the slice, prefer filing a
  follow-up issue over expanding slice scope. Keep slices tight.
- Always verify Done Criteria before adding text -- R2 Mickey notes were already addressed
  in v2. Checking first saves unnecessary plan churn.

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

## Learnings

- 2026-05-28T02:38:27-04:00 -- #451/#462: PS sprint-end parity now T1-T7+T_C/T_D (9 pass); validate-ps51 runs it. T7 uses ReadAllBytes: no 0x0D + shebang 0x23/0x21. Surprise: PS5.1 stub capture needs Write-Output and Win32NT guard.
