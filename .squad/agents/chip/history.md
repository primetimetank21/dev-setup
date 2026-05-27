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

---

## Recent Work

> Compressed 2026-05-17 per #319. Older entries summarized; full pre-Sprint-11 history at history-archive.md.

## Recent Work (pre-#239 summary)

Full detail in `history-archive.md`. Highlights:

- **2026-04-18** Sprint 7 completion: Issues #121 (git hooks) and #123 (CI triage, PS 5.1 guards).
- **2026-05-04 to 2026-05-14** PR #195 Group K test updates (Windows setup split refactor), PS 5.1 test Groups N, O, P for AllScope aliases + psmux.
- **2026-05-16 to 2026-05-19** Issue #197 non-ASCII test file fix (CP1252 cleanup), `ps51-ascii-safety` skill created, Issue #187 alias parity test, Issue #183 wire test_git_hooks.ps1 into validate.yml, Issue #212 commit-msg merge/revert rewrite (prepare-commit-msg), Issue #181 macOS CI validation, #255 squad-cli session warning, #279 YAML/bash quoting fix revision, #253 e2e-install failure-summary step.
- **2026-05-23** Post-sprint tests/CI audit (Sprint 8 wrap) + read-only verification of V-3 / V-4 / V-16.

Lessons preserved verbatim in Learnings section above (CP1252 encoding, PSVersion guards, hook behavioral testing patterns).

---

## Issue #239 P0 E2E Install Testing (summary)

- **2026-05-16 framing.** P0 enhancement, squad:chip, area:ci. Full tool-verification workflow across Linux/macOS/Windows fresh runners (not just OS routing): squad-cli bootstrap (`squad --version`), psmux (Windows tmux alias), all tool installs (zsh, uv, nvm, gh, GitHub Copilot CLI). Fresh-runner baseline per-PR + nightly cron approved. Cost note: dev-setup is PUBLIC repo (free runners).
- **2026-05-16 -- Retro CI gate (squad-history-check.yml).** Hard gate: any PR carrying `squad:*` label MUST modify matching agent's `.squad/agents/{name}/history.md` (verified via `gh pr diff --name-only`). No override. Dogfood test: workflow's own PR uses `squad:chip` and validates the new gate.
- **2026-05-23 -- E2E implementation.** Created `.github/workflows/e2e-install.yml` with 3 independent jobs (Linux/macOS/Windows), `continue-on-error: true` initially (flip to blocking after 2-3 green nightlies). Fresh-shell assertions: bash -lc on Unix, `pwsh -NoProfile -Command` on Windows. Squad-cli and psmux assertions deferred until PATH-persistence baseline green.

## Learnings (pre-Sprint-12 summary)

- **#239 workflow design choices.** Separate jobs per OS (not matrix) -- step sequences diverge too much (different shells, assertion patterns, PATH refresh). Fresh-shell spawning: `bash -lc` (Unix), `pwsh -NoProfile -Command` (Windows). `continue-on-error: true` initially; flip to blocking after 2-3 green nightlies. No new non-interactive flags needed (`$CI=true` auto-set; auth scripts already detect it; `DEBIAN_FRONTEND=noninteractive`). Retry deferred to stabilization phase. squad-cli + psmux assertions deferred until PATH-persistence baseline green. Key insight: `pwsh -NoProfile` tests system PATH, not profile-added PATH -- correct test for automation (nvm.ps1 #221 bug was exactly this class).
- **#225 macOS validate-linux parity.** Added nvm + Node.js validation step to validate-macos mirroring validate-linux. No macOS-specific differences (NVM_DIR == HOME/.nvm, bash 3.2 supports same sourcing). ASCII-only echo to match existing macOS job style.
- **#252 Node version pinned at 20.11.0, squad-cli needs >=22.5.0.** Bumped `.tool-versions` nodejs to 22.11.0 (Node 22 LTS). Both `nvm.sh` and `nvm.ps1` read via `read-tool-version.sh` / `Read-ToolVersion.ps1` -- single-line fix. Added Node-version-gate assertion (`node --version | major >= 22`) to e2e fresh-shell steps. v2: added `nvm alias default $PINNED_NODE` (fresh `bash -lc` falls back to system Node otherwise -- same root cause as #255). v3: bumped stale test_tool_versions.sh expectation.
- **#224 hook behavioral coverage.** Group X (6 scenarios) in test_windows_setup.ps1: pre-commit ASCII rejection (em-dash bytes 0xE2 0x80 0x94 via `WriteAllBytes`), rogue path rejection, pre-push main hard-reject, develop/feature allow, advisory PSScriptAnalyzer block doesn't fail. Extended test_precommit_hygiene.sh with 5 pre-push scenarios (Tpp1-Tpp5). Decision: extend hygiene.sh rather than new test_git_hooks.sh (one bash file for hook tests). Local-vs-CI gotcha: `sh` not on PATH locally (skips correctly); Git for Windows puts `sh` on PATH on CI runner.

### Sprint 12 Issue #238: Group FF -- uninstall idempotency + restore coverage (compressed)
- 10 new scenarios in `tests/test_windows_setup.ps1`: FF-1..FF-3 static checks on `uninstall.ps1` (dotfile list, newest-wins backup, Move-Item); FF-4..FF-5 Linux `uninstall.sh` parity; FF-6..FF-10 functional sandbox tests (newest-wins backup, legacy fallback, idempotency, block-strip with user content preserved, no-block skip).
- Functional sandbox: `New-FfSandbox` + `Invoke-UninstallIsolated` -- fake HOME via env vars, Push-Location to tmp git repo, restore in `finally`. Use `& powershell -NoProfile -File $path` not `Start-Process` (spaces in path cause arg splitting).
- Gotchas: `$home` local var collides with Constant `$HOME` (use `$fakeHome`); set `$ErrorActionPreference = 'Continue'` in `Invoke-UninstallIsolated` or native stderr wraps as terminating error; sentinel .gitconfig content must be valid INI.
- +335 lines, pure ASCII. Tally: 119 -> 129 passing (8 skipped, 8 pre-existing failures unchanged).

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
