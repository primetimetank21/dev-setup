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

---

### 2026-04-07 — Issue #14: Idempotency test suite

**Branch:** `squad/14-idempotency-tests`
**PR:** [#26](https://github.com/primetimetank21/dev-setup/pull/26)

**What I did:**
- Created `tests/test_idempotency.sh` — a self-contained idempotency test suite
- Created `tests/README.md` — documents each test, usage, and known limitations
- Verified bash syntax with `bash -n`
- Opened PR #26 targeting `develop`

**What the tests cover:**
1. All 5 tool scripts exist in `scripts/linux/tools/`
2. Tool PATH verification: zsh, uv (~/.local/bin), nvm (sourced), node, npm, gh
3. Each tool script re-run detects existing install (asserts "already installed" output + exit 0)
4. `/etc/shells` has no duplicate zsh entries
5. `~/.zshrc` has no duplicate NVM_DIR, .local/bin, or nvm.sh source lines
6. Full `setup.sh` second-run completes without error

**Key decisions:**
- `uv` requires `~/.local/bin` on PATH in non-login shells — test prepends it explicitly
- `nvm` is a shell function, not a binary — test sources `$NVM_DIR/nvm.sh` before checking
- `copilot-cli.sh` exits 0 with a warning when `gh` is not authenticated — test treats this as acceptable idempotent behavior
- PR #20 (CI workflow) is not merged yet; test suite can be wired into CI once it lands
## 2026-04-07 — Issue #12: CI Workflow for Script Validation

**Branch:** `squad/12-ci-workflow`
**PR:** https://github.com/primetimetank21/dev-setup/pull/20

**What was created:**
- `.github/workflows/validate.yml` with three jobs:
  1. `validate-linux`: Runs `setup.sh` on `ubuntu-latest`, validates zsh, uv, nvm, Node.js, npm, gh CLI are installed and on PATH, then runs setup a second time to confirm idempotency.
  2. `lint-shell-scripts`: Runs shellcheck on `setup.sh`, `scripts/linux/setup.sh`, and all `scripts/linux/tools/*.sh`.
  3. `lint-powershell`: Installs PSScriptAnalyzer and runs `Invoke-ScriptAnalyzer` on `setup.ps1` and `scripts/windows/setup.ps1`.

**Key validation decisions:**
- nvm must be sourced explicitly (`. ~/.nvm/nvm.sh`) — it's a shell function, not a binary
- uv installs to `$HOME/.local/bin` — PATH must be extended before checking
- `DEBIAN_FRONTEND=noninteractive` prevents apt from blocking on prompts
- Each tool validation uses `command -v` and emits ❌/✅ for clear CI output
- Idempotency test is a hard requirement per charter — second run must complete without error

**Environment note:** Shared workspace caused the initial commit to land on a different agent's branch (`squad/15-readme`). Cherry-picked onto `squad/12-ci-workflow` before pushing PR.

---

### 2026-04-07 — Issue #41: Remove-CustomItem multi-argument regression test

**Branch:** `squad/41-remove-customitem-test`
**PR:** [#52](https://github.com/primetimetank21/dev-setup/pull/52)

**What I built:**
- Created `tests/test_remove_custom_item.ps1` — PowerShell regression test for Sprint 3 bug
- Added `validate-powershell` job to `.github/workflows/validate.yml` running on `windows-latest`

**Test coverage:**
1. **Correct behavior:** `[string[]]$Path` array parameter accepts multiple arguments, deletes all files
2. **Regression guard:** `[string]$Path` scalar parameter silently drops second argument (proves test catches the bug)
3. **Single file:** Array parameter works with single file argument

**Key patterns:**
- Test file creates temp files in current directory (not `/tmp`) for cross-platform compatibility
- Defines both CORRECT and BROKEN function versions to prove the test catches regressions
- Uses `Test-Scenario` wrapper for consistent PASS/FAIL reporting
- Random file names avoid collision in shared CI environment
- Exits 0 on all pass, 1 on any failure for CI integration

**Environment note:** Shared workspace caused initial commit to land on wrong branch (`squad/43-tmux-test-coverage`). Cherry-picked to correct branch before PR creation.

---

### 2026-04-13 — Issue #102, #103: Windows PowerShell Regression Test Suite (PR #104)

**Branch:** `squad/102-windows-ps-regression-tests`  
**PR:** [#104](https://github.com/primetimetank21/dev-setup/pull/104)  
**Status:** ✅ MERGED

**What I built:**
- Created `tests/test_windows_setup.ps1` — comprehensive Windows PowerShell setup test suite
- 15 tests organized in 4 groups:
  - **Group A (4 tests):** Function existence & parameter validation for Install-* functions
  - **Group B (4 tests):** Installation behavior and idempotency verification
  - **Group C (3 tests):** Error handling and edge cases
  - **Group D (4 tests):** Integration scenarios across multiple tools

**Technical issues fixed:**
1. **Unicode encoding** — Properly configured UTF-8 encoding for script output and test assertions
2. **Where-Object .Count bug** — Fixed array counting logic for detecting PSAvoidUsingEmptyCatchBlock violations in target scripts

**Key test patterns:**
- Each test validates both success and graceful failure modes
- Idempotency assertions: re-running install functions should not error
- Tests coordinate with goofy-lint-fix to fix lint violations blocking PR
- Random file names avoid collisions in shared CI environment

**Cross-agent coordination:**
- Opened PR #104, which triggered Mickey's review (discovered PSAvoidUsingEmptyCatchBlock lint violation)
- Goofy then fixed the lint violation in scripts/windows/setup.ps1
- PR #104 merged after lint fix (all 4 CI checks passed)
- Issues #102 and #103 closed by this merge

**Outcome:** Windows setup now has regression test baseline (15 tests), enabling confidence in future PowerShell setup changes.

---

### 2026-04-18 — Issue #109: CI PS 5.1 validation path on GitHub Actions

**Branch:** `squad/109-ci-ps51-validation`
**PR:** [#116](https://github.com/primetimetank21/dev-setup/pull/116)

**What I built:**
- Added `validate-ps51` job to `.github/workflows/validate.yml`
- Runs on `windows-latest` with `shell: powershell` to force PS 5.1
- 5 steps: version check, syntax parse of both `.ps1` files, PSScriptAnalyzer lint under PS 5.1, and test suite execution

**What's validated:**
1. PS 5.1 version confirmed on runner
2. `scripts/windows/setup.ps1` — syntax check via `Parser::ParseFile`
3. `setup.ps1` (root) — syntax check via `Parser::ParseFile`
4. Both scripts linted by PSScriptAnalyzer under PS 5.1
5. `tests/test_windows_setup.ps1` executed under native PS 5.1

**Key decisions:**
- `shell: powershell` = PS 5.1; `shell: pwsh` = PS 7+ — this is the critical distinction
- Added root `setup.ps1` to validation (not just `scripts/windows/setup.ps1`) for full coverage
- PSScriptAnalyzer installed at runtime since it's not pre-installed on Windows runners
- Cannot test actual winget installs on CI runner — syntax and lint only for install functions

**Outcome:** PowerShell scripts are now validated under the same PS 5.1 runtime that real Windows users have.

## Sprint 6: PS 5.1 CI Validation (Issue #109)

**PR:** #116  
**Date:** 2026-04-18  

Designed and implemented PS 5.1 validation job using `windows-latest` runner with Windows PowerShell 5.1. Used `shell: powershell` to invoke native PS 5.1, Parser::ParseFile for syntax validation, and PSScriptAnalyzer for linting. Dual-runtime coverage now active (PS 7+ and PS 5.1). Issue closed.

---

### 2026-04-18 — Hotfix: CI em-dash + vim PATH (Issues #123, #107)

**Branch:** `squad/fix-ci-vim-path`
**PR:** [#126](https://github.com/primetimetank21/dev-setup/pull/126)

**What I fixed:**
1. **CI failure (PSUseBOMForUnicodeEncodedFile):** Replaced UTF-8 em-dash (U+2014) on line 63 of root `setup.ps1` with ASCII `--`. This non-ASCII byte triggered PSScriptAnalyzer's `PSUseBOMForUnicodeEncodedFile` rule, breaking both `Lint PowerShell Scripts` and `Validate PowerShell 5.1 Compatibility` CI jobs. Verified zero non-ASCII bytes remain.
2. **Vim not on PATH after install:** Added `$env:PATH` refresh in `Install-Vim` (`scripts/windows/setup.ps1`) after `winget install`. Reads Machine + User PATH from the registry so vim is available immediately without restarting the terminal. Added fallback warning if vim still not found on PATH.

**Key decisions:**
- Used `[System.Environment]::GetEnvironmentVariable('PATH', 'Machine')` — works on PS 5.1+ (no PS6+ auto-vars)
- Fallback `Write-Warn` keeps user informed without failing the setup

