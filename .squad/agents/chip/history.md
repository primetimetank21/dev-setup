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

## Issue #441 Plan Grill (Chip v5/v5.2) -- 2026-05-27 [compressed]

v5.1 (Donald H1-H5 + F-4/F-5): SHIP. C-1/C-2/F-3 all resolved. Four non-blocking LOWs (encoding assertion, middle-of-file, skip counter, mockPath identity).

v5.2 (Mickey JN-1/JN-2): SHIP. Parameterization resolved ($HOME temp paths via -Ps51Fallback/-Ps7Fallback + New-Guid + finally). JN-2 partial (skip counter LOW). No destructive writes in GG-2/3/6/7. Implementation-ready: YES for both.

## PR #458 Review -- 2026-05-27 [compressed]

Reviewed PR #458 (feat(profile): #442 v5.2 profile-path fix). Verdict: APPROVED. 136 passed / 8 skipped / 8 pre-existing failures. All 7 GG gates PASS, all 6 AC met. ASCII clean. Stream purity confirmed (Resolve-ProfilePath uses Write-Host). Carry-forward LOWs: NF-1/NF-2/NF-3/NF-4 non-blocking.

## PR #438 Review -- 2026-05-27 [compressed]

Approved PR #438 (sprint-end-labels.ps1 parity). CRLF-strip fix consistent with peer pattern. Three pre-existing parity gaps noted as follow-up.

## 2026-05-27 -- PR #458/#462 Review Cycle [compressed]

- PR #458 re-review: CI 11/11 green; allowlist patch (Invoke-HostQuery:windows, Resolve-ProfilePath:windows) correctly scoped; posted VERIFY OK.
- PR #462 grill-cycle: Goofy revised (scope cleanup + tightened assertions). Both reviewers approved re-review round. Earl final approver.

## 2026-05-28 -- #468 Plan Grill (PR #470, Chip v1)

Grilled Mickey's #468 customizable-install plan v1 from test/parity angle. Verdict: REVISE. Mickey locked out; revision assigned to Goofy or Donald.

**Five blocking findings:**
- B-1: validate-ps51 not mentioned in Done Criteria -- new param() block + $ToolRegistry need PS 5.1 syntax check AND functional test run, not just PS 7+ validate-powershell job.
- B-2: Filename conflict -- Slice 1 names test_setup_list_{linux,pwsh}.* but parity table names test_setup_flags_{linux,pwsh}.*. Two different filenames; implementer has no canonical source.
- B-3: Slices 2-4 have prose-only test plans with no named Test-Scenario / bash function names. Seven parity matrix rows need test-case names before implementation.
- B-4: Backward-compat baseline (Slice 4) is undefined -- no marker list, no snapshot mechanism, no invariant spec. The gate is cosmetic without these.
- B-5: e2e-install.yml never exercises new flags. --list at minimum should be a smoke step on Linux + macOS + Windows e2e jobs.

**Key lesson:** Slice test plans that name test FILES but not test CASES are incomplete for Chip's purposes. A named file with unnamed cases still produces zero contractual obligations for CI coverage.

**Naming convention confirmed:** Bash test files in tests/ carry no platform suffix (test_squad_spawn.sh, not test_squad_spawn_linux.sh). PowerShell parity files use _pwsh suffix (test_sprint_end_labels_pwsh.ps1). The _linux suffix proposed in S1 breaks this.

## 2026-05-28 -- #468 Plan Grill (PR #470, Chip v2)

Re-grilled Goofy's v2. Verdict: REQUEST CHANGES. v1 concerns resolved (named scenarios, PS 5.1 Done Criteria, real validate-ps51 job), but blockers remain for mocked-vs-live install boundaries and regenerable baseline fixture mechanics.

## 2026-05-29 -- #468 Plan v3 Authored (PR #470, Chip v3 owner)

Mickey + Goofy locked out. Authored full v3 rewrite addressing all 6 v2 re-grill findings:

1. **Root entrypoint forwarding** (Duck): Added `setup.sh`/`setup.ps1` to Slice 1 files-touched. Forward `"$@"` and `@PSBoundParameters`. Root-forwarding test scenarios added.
2. **AlwaysRun classification** (Duck): 4th concept introduced. Audit: Linux AlwaysRun = prerequisites + dotfiles + git-hooks; Windows = winget-check + git-hooks. Dotfiles reclassified from DefaultTools -> AlwaysRun on Windows for cross-platform parity.
3. **Windows AvailableTools single source-of-truth** (Duck): Table now says "registered callable installers" for Windows. Per-platform invariant clarified.
4. **Mock/stub harness** (Chip): `--tools-dir` / `-ToolsDir` hidden CLI flag as dispatch seam. Stub tools dir + RUN_LOG marker pattern. Dynamic registry for Windows stubs. Justification table vs alternatives.
5. **Baseline fixture regeneration** (Chip): `make baseline-fixtures` + `--dry-extract-defaults` seam. Baseline-diff test proves order+set without real installs.
6. **Blank CSV token tests** (Donald): Reject empty tokens (exit 1). No trimming. Test scenarios in Slices 2+3.

Key architectural decision: dotfiles moved to AlwaysRun on both platforms. Trade-off: users cannot `--skip=dotfiles`. Acceptable because dotfiles are idempotent infrastructure, not a "tool."
