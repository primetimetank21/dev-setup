#!/usr/bin/env bash
# tests/test_setup_flags.sh -- WI-1 baseline + --list/--help tests (#468)
#
# Tests the framework spine: DEFAULT_TOOLS constant, --tools-dir seam,
# --list, --help, root forwarding, baseline-diff.
#
# Usage: bash tests/test_setup_flags.sh
# Requires: bash 4+ (mapfile), GNU diff

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
ROOT_SETUP="${REPO_ROOT}/setup.sh"
STUB_DIR="${REPO_ROOT}/tests/fixtures/stub-tools/linux"

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${RESET}: $1 -- $2"; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------------------
# Harness helpers
# ---------------------------------------------------------------------------
setup_harness() {
  RUN_LOG="$(mktemp)"
  export RUN_LOG
}

teardown_harness() {
  rm -f "${RUN_LOG:-}"
  unset RUN_LOG
}

assert_log_equals() {
  local expected_file="$1"
  if diff "$RUN_LOG" "$expected_file" >/dev/null 2>&1; then
    return 0
  fi
  echo "  Run-log mismatch:"
  diff "$expected_file" "$RUN_LOG" || true
  return 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  echo "$haystack" | grep -qF "$needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  ! echo "$haystack" | grep -qF "$needle"
}

# ---------------------------------------------------------------------------
# T_baseline_noarg: no-arg with --tools-dir logs defaults.txt exactly
# ---------------------------------------------------------------------------
echo ""
echo "--- T_baseline_noarg ---"
setup_harness
if bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" 2>&1 | grep -q .; then : ; fi
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_baseline_noarg: no-arg run logs exactly defaults.txt order"
else
  fail "T_baseline_noarg: run-log does not match defaults.txt"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_baseline_real_defaults: fixture matches live DEFAULT_TOOLS array
# ---------------------------------------------------------------------------
echo ""
echo "--- T_baseline_real_defaults ---"
if command -v bash >/dev/null 2>&1; then
  if bash "${REPO_ROOT}/scripts/dev/regenerate-baseline-fixtures.sh" --check 2>&1; then
    pass "T_baseline_real_defaults: fixture matches DEFAULT_TOOLS in source"
  else
    fail "T_baseline_real_defaults: DEFAULT_TOOLS array drifted from fixture"
  fi
else
  skip "T_baseline_real_defaults" "bash not available"
fi

# ---------------------------------------------------------------------------
# T_list_output: --list prints AvailableTools, exit 0
# ---------------------------------------------------------------------------
echo ""
echo "--- T_list_output ---"
list_out="$(bash "$LINUX_SETUP" --list "--tools-dir=${STUB_DIR}" 2>&1)" && list_exit=$? || list_exit=$?
if [[ $list_exit -eq 0 ]]; then
  if assert_contains "$list_out" "alpha" && assert_contains "$list_out" "delta"; then
    pass "T_list_output: --list exits 0 and contains available tools"
  else
    fail "T_list_output: --list output missing expected tool names"
    echo "  Output: $list_out"
  fi
else
  fail "T_list_output: --list exited $list_exit (expected 0)"
fi

# ---------------------------------------------------------------------------
# T_list_no_install: --list with --tools-dir produces no RUN_LOG entries
# ---------------------------------------------------------------------------
echo ""
echo "--- T_list_no_install ---"
setup_harness
bash "$LINUX_SETUP" --list "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if [[ ! -s "$RUN_LOG" ]]; then
  pass "T_list_no_install: --list produced no run-log entries"
else
  fail "T_list_no_install: --list wrote to run-log (should not install)"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_help_output: --help prints usage containing flag names, exit 0
# ---------------------------------------------------------------------------
echo ""
echo "--- T_help_output ---"
help_out="$(bash "$LINUX_SETUP" --help 2>&1)" && help_exit=$? || help_exit=$?
if [[ $help_exit -eq 0 ]]; then
  if assert_contains "$help_out" "--list" && \
     assert_contains "$help_out" "--only" && \
     assert_contains "$help_out" "--skip"; then
    pass "T_help_output: --help exits 0 and mentions --list, --only, --skip"
  else
    fail "T_help_output: --help output missing expected flags"
    echo "  Output: $help_out"
  fi
else
  fail "T_help_output: --help exited $help_exit (expected 0)"
fi

# ---------------------------------------------------------------------------
# T_help_no_toolsdir: --help does NOT mention tools-dir (hidden seam)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_help_no_toolsdir ---"
help_out2="$(bash "$LINUX_SETUP" --help 2>&1)" || true
if assert_not_contains "$help_out2" "tools-dir"; then
  pass "T_help_no_toolsdir: --help does not expose hidden --tools-dir flag"
else
  fail "T_help_no_toolsdir: --help mentions tools-dir (must remain hidden)"
fi

# ---------------------------------------------------------------------------
# T_unknown_arg: unknown flag exits 1 with error message
# ---------------------------------------------------------------------------
echo ""
echo "--- T_unknown_arg ---"
bash "$LINUX_SETUP" --foobar >/dev/null 2>&1 && unk_exit=$? || unk_exit=$?
if [[ $unk_exit -ne 0 ]]; then
  pass "T_unknown_arg: unknown flag exits non-zero"
else
  fail "T_unknown_arg: unknown flag exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_root_list: root setup.sh --list exits 0
# ---------------------------------------------------------------------------
echo ""
echo "--- T_root_list ---"
if [[ -f "$ROOT_SETUP" ]]; then
  root_list_out="$(bash "$ROOT_SETUP" --list "--tools-dir=${STUB_DIR}" 2>&1)" && root_exit=$? || root_exit=$?
  if [[ $root_exit -eq 0 ]] && assert_contains "$root_list_out" "alpha"; then
    pass "T_root_list: root setup.sh --list forwards correctly"
  else
    fail "T_root_list: root setup.sh --list failed (exit=$root_exit)"
    echo "  Output: $root_list_out"
  fi
else
  skip "T_root_list" "root setup.sh not found"
fi

# ---------------------------------------------------------------------------
# T_root_help: root setup.sh --help exits 0
# ---------------------------------------------------------------------------
echo ""
echo "--- T_root_help ---"
if [[ -f "$ROOT_SETUP" ]]; then
  bash "$ROOT_SETUP" --help >/dev/null 2>&1 && rh_exit=$? || rh_exit=$?
  if [[ $rh_exit -eq 0 ]]; then
    pass "T_root_help: root setup.sh --help exits 0"
  else
    fail "T_root_help: root setup.sh --help exited $rh_exit"
  fi
else
  skip "T_root_help" "root setup.sh not found"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "TEST RESULTS (test_setup_flags.sh)"
echo "========================================"
echo -e "${GREEN}Passed:${RESET}  $PASS"
echo -e "${YELLOW}Skipped:${RESET} $SKIP"
echo -e "${RED}Failed:${RESET}  $FAIL"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
