#!/usr/bin/env bash
# tests/test_setup_flags.sh -- WI-1 baseline + WI-2 --only tests (#468)
#
# Tests the framework spine: DEFAULT_TOOLS constant, --tools-dir seam,
# --list, --help, root forwarding, baseline-diff.
# WI-2: --only selective install with ORDER PRESERVATION invariant.
#
# Usage: bash tests/test_setup_flags.sh
# Requires: bash 3.2+ (macOS compatible), GNU diff

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
# WI-2: --only selective install
# Stub defaults.txt order: prereqs, alpha, bravo, charlie, dotfiles, git-hook
# Opt-in stubs (in dir but NOT in defaults.txt): delta, uv
# ---------------------------------------------------------------------------

# Helper: compare run-log content to a literal expected string
assert_log_str() {
  local expected="$1"
  local actual
  actual="$(cat "$RUN_LOG" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  echo "  Expected: |$(echo "$expected" | cat)|"
  echo "  Actual:   |$(echo "$actual"   | cat)|"
  return 1
}

# ---------------------------------------------------------------------------
# T_only_single: --only=alpha installs only alpha
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_single ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha 2>&1 | grep -q . || true
if assert_log_str "alpha"; then
  pass "T_only_single: --only=alpha logs only alpha"
else
  fail "T_only_single: unexpected run-log"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_only_multi: --only=alpha,bravo installs both in DEFAULT order
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_multi ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha,bravo 2>&1 | grep -q . || true
if assert_log_str "$(printf 'alpha\nbravo')"; then
  pass "T_only_multi: --only=alpha,bravo logs alpha then bravo (default order)"
else
  fail "T_only_multi: unexpected run-log (order or content wrong)"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_only_order_preserved: --only=bravo,alpha (reversed) must still install
# alpha BEFORE bravo (DEFAULT_TOOLS order, not input order).
# *** EXPECTED RED before WI-2 fix ***
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_order_preserved ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=bravo,alpha 2>&1 | grep -q . || true
if assert_log_str "$(printf 'alpha\nbravo')"; then
  pass "T_only_order_preserved: reversed input yields default order (alpha then bravo)"
else
  fail "T_only_order_preserved: order NOT preserved (input order used instead of default order)"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_only_optin: --only=delta works (delta is opt-in, not in defaults.txt)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_optin ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=delta 2>&1 | grep -q . || true
if assert_log_str "delta"; then
  pass "T_only_optin: --only=delta (opt-in tool) works"
else
  fail "T_only_optin: opt-in tool not reachable via --only"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_only_optin_order: --only=delta,alpha -> alpha (default) first, delta
# (opt-in) appended after. *** EXPECTED RED before WI-2 fix ***
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_optin_order ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=delta,alpha 2>&1 | grep -q . || true
if assert_log_str "$(printf 'alpha\ndelta')"; then
  pass "T_only_optin_order: default tool (alpha) before opt-in tool (delta)"
else
  fail "T_only_optin_order: opt-in not appended after default-ordered tools"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_only_unknown: --only=bogus exits 1 and prints available tools
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_unknown ---"
only_unk_out="$(bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=bogus 2>&1)" && only_unk_exit=$? || only_unk_exit=$?
if [[ $only_unk_exit -ne 0 ]]; then
  if echo "$only_unk_out" | grep -qi "unknown\|bogus\|available\|--list"; then
    pass "T_only_unknown: --only=bogus exits non-zero with helpful message"
  else
    fail "T_only_unknown: exits non-zero but message not helpful: $only_unk_out"
  fi
else
  fail "T_only_unknown: --only=bogus exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_only_empty: --only= exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_empty ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only= 2>&1 | grep -q . || true && only_empty_exit=$? || only_empty_exit=$?
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--only=" >/dev/null 2>&1 && only_empty_exit=0 || only_empty_exit=$?
if [[ $only_empty_exit -ne 0 ]]; then
  pass "T_only_empty: --only= exits non-zero"
else
  fail "T_only_empty: --only= exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_only_blank_trailing: --only=alpha, exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_blank_trailing ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--only=alpha," >/dev/null 2>&1 && bt_exit=0 || bt_exit=$?
if [[ $bt_exit -ne 0 ]]; then
  pass "T_only_blank_trailing: --only=alpha, exits non-zero"
else
  fail "T_only_blank_trailing: --only=alpha, exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_only_blank_leading: --only=,alpha exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_blank_leading ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--only=,alpha" >/dev/null 2>&1 && bl_exit=0 || bl_exit=$?
if [[ $bl_exit -ne 0 ]]; then
  pass "T_only_blank_leading: --only=,alpha exits non-zero"
else
  fail "T_only_blank_leading: --only=,alpha exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_only_blank_consecutive: --only=alpha,,bravo exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_blank_consecutive ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--only=alpha,,bravo" >/dev/null 2>&1 && bc_exit=0 || bc_exit=$?
if [[ $bc_exit -ne 0 ]]; then
  pass "T_only_blank_consecutive: --only=alpha,,bravo exits non-zero"
else
  fail "T_only_blank_consecutive: --only=alpha,,bravo exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_only_copilot_alias: --list output includes copilot-cli (real tools dir)
# This confirms the real DEFAULT_TOOLS/tools/ expose copilot-cli as selectable
# ---------------------------------------------------------------------------
echo ""
echo "--- T_only_copilot_alias ---"
copilot_list="$(bash "$LINUX_SETUP" --list 2>&1)" && copilot_list_exit=$? || copilot_list_exit=$?
if [[ $copilot_list_exit -eq 0 ]]; then
  if assert_contains "$copilot_list" "copilot-cli"; then
    pass "T_only_copilot_alias: --list includes copilot-cli in real tools dir"
  else
    fail "T_only_copilot_alias: --list missing copilot-cli (check tools/copilot-cli.sh)"
    echo "  List output: $copilot_list"
  fi
else
  fail "T_only_copilot_alias: --list exited $copilot_list_exit"
fi

# ---------------------------------------------------------------------------
# T_root_only: root setup.sh --only=alpha --tools-dir=... installs only alpha
# ---------------------------------------------------------------------------
echo ""
echo "--- T_root_only ---"
if [[ -f "$ROOT_SETUP" ]]; then
  setup_harness
  bash "$ROOT_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha 2>&1 | grep -q . || true
  if assert_log_str "alpha"; then
    pass "T_root_only: root setup.sh --only=alpha forwards and installs only alpha"
  else
    fail "T_root_only: root --only=alpha did not produce expected log"
  fi
  teardown_harness
else
  skip "T_root_only" "root setup.sh not found"
fi

# ---------------------------------------------------------------------------
# T_backward_compat_gate: no-arg run still produces full defaults (WI-2 gate)
# Redundant with T_baseline_noarg but documents the WI-2 non-regression contract.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_backward_compat_gate ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" 2>&1 | grep -q . || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_backward_compat_gate: no-arg run still logs all defaults in order"
else
  fail "T_backward_compat_gate: no-arg run changed (REGRESSION)"
fi
teardown_harness

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
