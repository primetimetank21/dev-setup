## Chip -- Tests/CI Audit (Post-Sprint 8)

### Summary

Sprint 8 wrapped with 22 PRs (17 go:yes closed), comprehensive test coverage across 21 Windows test groups (A-V), and a 6-job CI matrix. This read-only audit identifies 6 actionable gaps: missing pre-commit and pre-push hook tests, incomplete macOS coverage, untested uninstall scripts, redundant chmod in macOS CI, and ASCII validation gaps in new code.

### Findings

#### F-1: Missing pre-commit hook behavioral tests
- **Severity:** medium
- **Category:** gap
- **Where:** tests/test_git_hooks.ps1 (Group A, lines 72-87)
- **What:** Group A verifies hook files exist and have shebangs, but does NOT test pre-commit hook behavior. The hook runs `shellcheck` on staged .sh files, but there are zero tests for this functionality.
- **Why it matters:** If pre-commit hook logic breaks (e.g., shellcheck invocation fails silently, or grep for .sh files regresses), the breakage lands in develop undetected. Pre-commit is a first-line gatekeeper.
- **Suggested action:** Add Group B-2 (or new Group C) tests: (1) Test pre-commit hook accepts empty staged file list and exits 0. (2) Test pre-commit hook detects a .sh file and attempts shellcheck. (3) Test pre-commit hook skips if shellcheck absent. (4) Test pre-commit hook exits non-zero on shellcheck failure.

#### F-2: Missing pre-push hook behavioral tests
- **Severity:** medium
- **Category:** gap
- **Where:** tests/test_git_hooks.ps1 (Group A checks file existence only)
- **What:** pre-push hook has three behaviors: (1) block direct push to main, (2) run shellcheck on changed .sh files, (3) run PSScriptAnalyzer on changed .ps1 files (advisory). Zero tests verify any of these work.
- **Why it matters:** Pre-push is a critical guardrail against main branch direct pushes. If the guard silently fails, users bypass the rule. Shellcheck and PSScriptAnalyzer linting is advisory but should not crash.
- **Suggested action:** Add pre-push hook test group (before summary): (1) Mock git diff to simulate push to main, verify exit 1 is raised. (2) Mock changed .sh file, verify shellcheck is invoked (or skipped if absent). (3) Mock changed .ps1 file, verify PSScriptAnalyzer is optional (advisory-only, no exit 1).

#### F-3: Uninstall scripts have zero test coverage
- **Severity:** low
- **Category:** gap
- **Where:** scripts/linux/uninstall.sh, scripts/windows/uninstall.ps1
- **What:** Uninstall scripts exist but are completely untested. No tests verify uninstall removes files, cleans up dotfiles, or leaves the system in a known state.
- **Why it matters:** Uninstall is a destructive operation. Without tests, breakage isn't caught until a user reports "uninstall left garbage behind" or "uninstall deleted too much."
- **Suggested action:** Create tests/test_uninstall.sh (Linux) and tests/test_uninstall.ps1 (Windows) verifying: (1) Script exits 0 on success. (2) Key profile files are removed/backed up. (3) Alias functions are de-registered. (4) Idempotency: running uninstall twice is safe.

#### F-4: macOS CI job makes redundant chmod calls
- **Severity:** low
- **Category:** improvement
- **Where:** .github/workflows/validate.yml lines 92 (macOS job)
- **What:** The step "Make scripts executable" runs `chmod +x setup.sh scripts/linux/setup.sh scripts/linux/tools/*.sh`. Since setup.sh is the dispatcher (routes to scripts/linux/setup.sh internally), the explicit `chmod +x scripts/linux/setup.sh` is redundant -- setup.sh handles it.
- **Why it matters:** Redundant chmod adds noise to CI logs and makes debugging harder. Each step should have a clear, non-overlapping purpose.
- **Suggested action:** Change macOS job chmod to: `chmod +x setup.sh scripts/linux/tools/*.sh` (remove explicit scripts/linux/setup.sh). Document that scripts/linux/setup.sh is executed indirectly via setup.sh dispatcher.

#### F-5: macOS job missing nvm and squad-cli verification (parity with Linux)
- **Severity:** medium
- **Category:** gap
- **Where:** .github/workflows/validate.yml lines 83-142 (validate-macos job)
- **What:** validate-linux job includes tests for: (1) nvm and Node.js install, (2) squad-cli bootstrap. validate-macos job does NOT verify either. It only validates zsh, uv, and gh. On macOS, nvm and squad-cli are also required, but no CI verification confirms they're installed.
- **Why it matters:** If squad-cli install breaks on macOS (e.g., npm path issue, nvm load failure), it won't be caught in CI. Users will discover it in the real world.
- **Suggested action:** Add to validate-macos job after "Validate gh CLI installed" step: (1) Verify nvm is installed (source ~/.nvm/nvm.sh, check nvm --version works). (2) Verify Node.js is on PATH and matches pinned version from .tool-versions. (3) Verify squad-cli is available after npm install. Consider running test_nvm_bootstrap.sh on macOS (already written for Linux).

#### F-6: CI matrix missing explicit PSScriptAnalyzer hook tests
- **Severity:** low
- **Category:** improvement
- **Where:** .github/workflows/validate.yml, validate.yml jobs overall
- **What:** Pre-push hook has optional PSScriptAnalyzer linting on changed .ps1 files, but the CI does NOT validate this code path works. PSScriptAnalyzer is installed in validate-ps51, but the pre-push hook's PSScriptAnalyzer invocation (lines 30-46 of hooks/pre-push) is untested.
- **Why it matters:** If the pre-push PSScriptAnalyzer logic breaks (e.g., the pwsh command path fails, module install regresses), the advisory lint is silently skipped without the developer knowing.
- **Suggested action:** Extend pre-push hook tests to verify: (1) If pwsh is present and PSScriptAnalyzer module is installed, the hook attempts to run it on changed .ps1 files. (2) If PSScriptAnalyzer is absent, the hook gracefully skips with an informational message (no exit 1). This is advisory-only, not a blocker.

### Recommended issue priorities (your top 3)

1. **F-2: Missing pre-push hook tests** -- Pre-push is a critical safety gate (blocks main branch). If the gate is broken in CI, it will fail silently. HIGH impact, medium effort (4-5 test scenarios). Start here to ensure branch protection works.

2. **F-1: Missing pre-commit hook tests** -- Pre-commit is the first line of defense. While less critical than pre-push, shellcheck breakage on .sh files is a quick regression that should be caught early.

3. **F-3: Uninstall script testing** -- Lowest urgency (cleanup operation, not on critical path), but also the easiest to address (2-3 basic tests verifying file removal and idempotency). Good for backlog after more urgent hooks tests.

---

**Audit Date:** 2026-05-23  
**Sprint:** 8 (post-close)  
**Reviewer:** Chip (Tester)  
**Scope:** Tests/CI matrix/coverage gaps only  
**Changes:** None (read-only audit)
