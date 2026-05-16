#!/usr/bin/env bash
# tests/test_nvm_bootstrap.sh -- Verify nvm/squad-cli bootstrap behavior (#201)
#
# Checks:
#   1. nvm.sh sources nvm correctly (uses \. not just source)
#   2. nvm.sh reads pinned Node version from .tool-versions
#   3. squad-cli.sh emits ERROR (not WARN) when npm is missing

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

pass() { printf '\033[0;32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '\033[0;31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# --- nvm.sh tests ---

NVM_SCRIPT="${REPO_ROOT}/scripts/linux/tools/nvm.sh"

# T1: nvm.sh sources nvm.sh with POSIX-safe dot
# shellcheck disable=SC2016
if grep -q '\\. "\$NVM_DIR/nvm.sh"' "$NVM_SCRIPT"; then
  pass "nvm.sh sources nvm via POSIX-safe dot command"
else
  fail "nvm.sh does not source nvm via POSIX-safe dot command"
fi

# T2: nvm.sh reads pinned Node version from .tool-versions
if grep -q 'read-tool-version.sh.*nodejs' "$NVM_SCRIPT"; then
  pass "nvm.sh reads nodejs version from .tool-versions"
else
  fail "nvm.sh does not read nodejs version from .tool-versions"
fi

# T3: nvm.sh uses pinned version (not --lts)
if grep -q 'nvm install.*PINNED_NODE' "$NVM_SCRIPT" && ! grep -q 'nvm install --lts' "$NVM_SCRIPT"; then
  pass "nvm.sh installs pinned version (not --lts)"
else
  fail "nvm.sh still uses --lts or does not use PINNED_NODE variable"
fi

# --- squad-cli.sh tests ---

SQUAD_SCRIPT="${REPO_ROOT}/scripts/linux/tools/squad-cli.sh"

# T4: squad-cli.sh uses ERROR not WARN for npm missing
if grep -q '\[ERROR\].*npm not found' "$SQUAD_SCRIPT" && ! grep -q '\[WARN\].*npm not found' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh emits ERROR (not WARN) when npm missing"
else
  fail "squad-cli.sh still uses WARN or missing ERROR for npm-not-found"
fi

# T5: squad-cli.sh exits non-zero when npm missing
if grep -q 'exit 1' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh exits non-zero when npm missing"
else
  fail "squad-cli.sh does not exit non-zero"
fi

# --- version-pin enforcement tests ---

# T6: squad-cli.sh reads pinned version from .tool-versions
if grep -q 'read-tool-version.sh.*squad-cli' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh reads squad-cli version from .tool-versions"
else
  fail "squad-cli.sh does not read squad-cli version from .tool-versions"
fi

# T7: squad-cli.sh installs pinned version via npm (not bare latest)
if grep -q 'npm install.*SQUAD_CLI_VERSION' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh installs pinned version via npm"
else
  fail "squad-cli.sh does not pass pinned version to npm install"
fi

COPILOT_SCRIPT="${REPO_ROOT}/scripts/linux/tools/copilot-cli.sh"

# T8: copilot-cli.sh reads pinned version from .tool-versions
if grep -q 'read-tool-version.sh.*copilot-cli' "$COPILOT_SCRIPT"; then
  pass "copilot-cli.sh reads copilot-cli version from .tool-versions"
else
  fail "copilot-cli.sh does not read copilot-cli version from .tool-versions"
fi

# T9: copilot-cli.sh performs version-aware check (not bare binary-exists guard)
if grep -q 'INSTALLED_VERSION' "$COPILOT_SCRIPT" && grep -q 'COPILOT_CLI_VERSION' "$COPILOT_SCRIPT"; then
  pass "copilot-cli.sh performs version-aware idempotency check"
else
  fail "copilot-cli.sh still uses bare binary-exists guard (no version comparison)"
fi

# T10: squad-cli.sh installs from the correct npm package (#255)
# Root cause investigation: 'session persistence may fail' warning was reported
# in e2e runs. Confirmed it originates in @github/copilot-sdk (a transitive dep
# of @bradygaster/squad-cli). Verified absent in 0.9.4. This test ensures the
# correct package name is installed so the fix is not silently reverted.
if grep -q '@bradygaster/squad-cli' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh installs @bradygaster/squad-cli (correct package)"
else
  fail "squad-cli.sh does not install @bradygaster/squad-cli"
fi

# T11: squad-cli.sh already-installed check captures stderr with 2>&1 (#255)
# When squad --version is run, any 'session persistence may fail' warning
# emitted to stderr must appear in the installer log so it is visible in CI.
# The already-installed branch uses: squad --version 2>&1
if grep -q 'squad --version 2>&1' "$SQUAD_SCRIPT"; then
  pass "squad-cli.sh already-installed check captures stderr (2>&1)"
else
  fail "squad-cli.sh already-installed check does not capture stderr -- warnings will be invisible in CI"
fi

# --- Summary ---

echo ""
echo "========================================"
echo "TEST RESULTS"
echo "========================================"
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "All tests passed!"
