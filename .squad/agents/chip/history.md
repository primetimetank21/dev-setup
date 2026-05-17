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

### Sprint 12 Issue #238: Group FF -- uninstall idempotency + restore coverage- Coordinator pre-assigned **Group FF** in the spawn prompt (post-EE allocation per CONTRIBUTING.md "Group Letter Assignment"). Skipped BB/CC historically; FF is next free after EE (Issue #292 Sprint 11).
- Added 10 scenarios to `tests/test_windows_setup.ps1`:
  - FF-1..FF-3: static-source checks on `scripts/windows/uninstall.ps1` (dotfile list of 5, newest-wins backup selection via Get-ChildItem + Sort-Object LastWriteTime -Descending, Move-Item -Force on both branches)
  - FF-4..FF-5: parity static checks on `scripts/linux/uninstall.sh` (same 5 dotfiles, `ls -t` newest-wins + `[[ -f .bak ]]` fallback)
  - FF-6: functional -- two timestamped .bak.* backups present, newest wins; older preserved for manual recovery
  - FF-7: functional -- legacy .bak fallback restored when no timestamped backup exists
  - FF-8: functional -- second uninstall run is idempotent (size + content unchanged, "No backup found" SKIP marker emitted)
  - FF-9: functional -- managed profile block stripped while user content before/after the block is preserved
  - FF-10: functional -- re-running on a profile with no dev-setup block emits "No dev-setup block in" SKIP and does not rewrite the file
- Functional sandbox pattern (`New-FfSandbox` + `Invoke-UninstallIsolated`): create tmp root + fake HOME + tmp git repo, override `$env:USERPROFILE` / `$env:HOMEDRIVE` / `$env:HOMEPATH` before invoking `powershell -NoProfile -File scripts\windows\uninstall.ps1` in a child process. Push-Location to tmp git repo so the script's `git config --unset-all core.hooksPath` cannot mutate the tester's real config. Restore env + ErrorActionPreference in `finally`.
- **Gotcha (decision-worthy):** PowerShell variables are case-insensitive, so a local `$home = Join-Path $root 'home'` collides with the Constant automatic variable `$HOME` and throws "Cannot overwrite variable HOME because it is read-only or constant." Spent ~10 min debugging the wrong layer (env vars) before realizing the assignment was the cause. Always name the fake HOME local `$fakeHome` (or anything other than `home`). Captured to decisions inbox.
- **Gotcha:** Test harness has `$ErrorActionPreference = "Stop"`. When invoking the child `powershell -File ... 2>$file`, native command stderr (e.g. git config error if `.gitconfig` is malformed) gets wrapped as ErrorRecord and the harness's Stop turns that into a terminating error before our test code can read the ExitCode. Fix: locally set `$ErrorActionPreference = 'Continue'` inside `Invoke-UninstallIsolated` and restore in `finally`.
- **Gotcha:** Sentinel content for `.gitconfig.bak.*` must be valid git-config INI (used `# sentinel: ...` comment lines). Raw garbage strings like `original-new` cause `git config --unset-all core.hooksPath` (which the uninstall script always runs) to error out with "key does not contain a section: original-new" when it reads the now-restored user gitconfig.
- **Gotcha:** `Start-Process -ArgumentList @('-File', $path)` does not quote args containing spaces -- the path `C:\Users\Earl Tankard\...` was split at the space and `powershell` got `-File 'C:\Users\Earl'`. Switched to direct invocation via `& powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>$stderrFile` which uses PowerShell's argument quoting.
- Baseline failures (8: Copilot CLI live check + O-1..O-7 alias overrides) are environmental and pre-existed on develop @ 66930c6. Verified by stash + re-run before adding Group FF.
- No Linux uninstall test file added: `tests/test_linux_setup.sh` does not exist; static-source parity in FF-4/FF-5 catches structural divergence between the two uninstall scripts without needing a separate functional bash harness.
- Diff: +335 lines in `tests/test_windows_setup.ps1`. Pure ASCII (pre-commit clean). All 10 new tests pass locally; tally rose from 119 -> 129 passing (8 skipped, 8 pre-existing failures unchanged).
