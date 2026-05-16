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
