#!/usr/bin/env bash
# tests/test_lazygit_installer.sh -- parity tests for lazygit opt-in installer (#467)
#
# Tests:
#   T_lazygit_in_list      -- lazygit appears in --list output (opt-in discoverable)
#   T_lazygit_not_default  -- lazygit is NOT installed by a default no-arg run
#   T_lazygit_version_pin  -- .tool-versions contains a lazygit pin
#   T_lazygit_optin_stub   -- --only=lazygit with stub dir runs only lazygit
#
# Usage: bash tests/test_lazygit_installer.sh
# Requires: bash 3.2+ (macOS compatible)

set -uo pipefail

PASS=0
FAIL=0
SKIP=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LINUX_SETUP="${REPO_ROOT}/scripts/linux/setup.sh"
TOOL_VERSIONS="${REPO_ROOT}/.tool-versions"
STUB_DIR="${REPO_ROOT}/tests/fixtures/stub-tools/linux"

pass() { printf "${GREEN}PASS${RESET}: %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${RESET}: %s\n" "$1"; FAIL=$((FAIL + 1)); }
# shellcheck disable=SC2329
skip() { printf "${YELLOW}SKIP${RESET}: %s -- %s\n" "$1" "$2"; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------------------
# T_lazygit_in_list: --list on real tools dir includes 'lazygit'
# Fails RED when scripts/linux/tools/lazygit.sh does not exist.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_lazygit_in_list ---"
list_out="$(bash "$LINUX_SETUP" --list 2>&1)" && list_exit=$? || list_exit=$?
if [ "$list_exit" -ne 0 ]; then
  fail "T_lazygit_in_list: --list exited $list_exit (expected 0)"
elif echo "$list_out" | grep -qF "lazygit"; then
  pass "T_lazygit_in_list: lazygit appears in --list output (opt-in discoverable)"
else
  fail "T_lazygit_in_list: lazygit missing from --list output (is lazygit.sh in tools/?)"
  echo "  --list output: $list_out"
fi

# ---------------------------------------------------------------------------
# T_lazygit_not_default: default no-arg run with stub dir does NOT run lazygit
# lazygit is opt-in; it must not appear in defaults.txt.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_lazygit_not_default ---"
RUN_LOG="$(mktemp)"
export RUN_LOG
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if grep -qF "lazygit" "$RUN_LOG" 2>/dev/null; then
  fail "T_lazygit_not_default: lazygit ran in a default no-arg install (must be opt-in only)"
else
  pass "T_lazygit_not_default: lazygit does NOT run in a default install (correctly opt-in)"
fi
rm -f "$RUN_LOG"
unset RUN_LOG

# ---------------------------------------------------------------------------
# T_lazygit_version_pin: .tool-versions contains a lazygit entry
# Fails RED before lazygit is added to .tool-versions.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_lazygit_version_pin ---"
if grep -qE '^lazygit[[:space:]]' "$TOOL_VERSIONS" 2>/dev/null; then
  ver="$(grep -E '^lazygit[[:space:]]' "$TOOL_VERSIONS" | awk '{print $2}')"
  pass "T_lazygit_version_pin: lazygit pinned at ${ver} in .tool-versions"
else
  fail "T_lazygit_version_pin: lazygit not found in .tool-versions -- RED (pre-implementation)"
fi

# ---------------------------------------------------------------------------
# T_lazygit_optin_stub: --only=lazygit with stub dir runs only lazygit
# Fails RED when tests/fixtures/stub-tools/linux/lazygit.sh does not exist.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_lazygit_optin_stub ---"
RUN_LOG2="$(mktemp)"
export RUN_LOG
RUN_LOG="$RUN_LOG2"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=lazygit 2>&1 | grep -q . || true
if grep -qF "lazygit" "$RUN_LOG2" 2>/dev/null; then
  actual="$(cat "$RUN_LOG2")"
  if [ "$actual" = "lazygit" ]; then
    pass "T_lazygit_optin_stub: --only=lazygit runs only lazygit via stub"
  else
    fail "T_lazygit_optin_stub: --only=lazygit ran unexpected tools: ${actual}"
  fi
else
  fail "T_lazygit_optin_stub: --only=lazygit did not run lazygit (stub missing or tool unregistered)"
fi
rm -f "$RUN_LOG2"
unset RUN_LOG

# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
