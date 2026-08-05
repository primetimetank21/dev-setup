#!/usr/bin/env bash
# tests/test_setup_flags.sh -- setup flag tests (#468, #495)
#
# Tests the framework spine: DEFAULT_TOOLS constant, --tools-dir seam,
# --list, --help, root forwarding, baseline-diff.
# WI-2: --only selective install with ORDER PRESERVATION invariant.
# #495 Slice 1: interactive mode guards and backward-compat drift gates.
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
SELECTION_FILE="${STUB_DIR}/selection.txt"

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
  echo "$haystack" | grep -qF -- "$needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  ! echo "$haystack" | grep -qF -- "$needle"
}

# ---------------------------------------------------------------------------
# T_baseline_noarg: no-arg with --tools-dir logs defaults.txt exactly
# ---------------------------------------------------------------------------
echo ""
echo "--- T_baseline_noarg ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha,bravo >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=bravo,alpha >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=delta >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=delta,alpha >/dev/null 2>&1 || true
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
  bash "$ROOT_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha >/dev/null 2>&1 || true
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
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_backward_compat_gate: no-arg run still logs all defaults in order"
else
  fail "T_backward_compat_gate: no-arg run changed (REGRESSION)"
fi
teardown_harness

# ---------------------------------------------------------------------------
# WI-3: --skip selective exclusion
# Stub defaults.txt order: prereqs, alpha, bravo, charlie, dotfiles, git-hook
# Opt-in stubs (in dir but NOT in defaults.txt): delta, uv
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# T_skip_single: --skip=bravo excludes bravo, installs remaining in order
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_single ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --skip=bravo >/dev/null 2>&1 || true
if assert_log_str "$(printf 'prereqs\nalpha\ncharlie\ndotfiles\ngit-hook')"; then
  pass "T_skip_single: --skip=bravo excludes bravo; remaining tools installed in order"
else
  fail "T_skip_single: unexpected run-log"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_skip_multi: --skip=alpha,charlie excludes both, rest in default order
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_multi ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --skip=alpha,charlie >/dev/null 2>&1 || true
if assert_log_str "$(printf 'prereqs\nbravo\ndotfiles\ngit-hook')"; then
  pass "T_skip_multi: --skip=alpha,charlie excludes both; order preserved"
else
  fail "T_skip_multi: unexpected run-log"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_skip_unknown: --skip=bogus exits 1 with helpful message
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_unknown ---"
skip_unk_out="$(bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --skip=bogus 2>&1)" && skip_unk_exit=$? || skip_unk_exit=$?
if [[ $skip_unk_exit -ne 0 ]]; then
  if echo "$skip_unk_out" | grep -qi "unknown\|bogus\|available\|--list"; then
    pass "T_skip_unknown: --skip=bogus exits non-zero with helpful message"
  else
    fail "T_skip_unknown: exits non-zero but message not helpful: $skip_unk_out"
  fi
else
  fail "T_skip_unknown: --skip=bogus exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_skip_empty: --skip= exits 1 (*** EXPECTED RED before WI-3 ARG_SKIP_SET fix ***)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_empty ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--skip=" >/dev/null 2>&1 && skip_empty_exit=0 || skip_empty_exit=$?
if [[ $skip_empty_exit -ne 0 ]]; then
  pass "T_skip_empty: --skip= exits non-zero"
else
  fail "T_skip_empty: --skip= exited 0 (expected non-zero) *** RED until ARG_SKIP_SET fix ***"
fi

# ---------------------------------------------------------------------------
# T_skip_conflict: --only=alpha --skip=bravo exits 1 (mutually exclusive)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_conflict ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha --skip=bravo >/dev/null 2>&1 && skip_conflict_exit=0 || skip_conflict_exit=$?
if [[ $skip_conflict_exit -ne 0 ]]; then
  pass "T_skip_conflict: --only + --skip exits non-zero (mutually exclusive)"
else
  fail "T_skip_conflict: --only + --skip exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_skip_blank_trailing: --skip=alpha, exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_blank_trailing ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--skip=alpha," >/dev/null 2>&1 && sbt_exit=0 || sbt_exit=$?
if [[ $sbt_exit -ne 0 ]]; then
  pass "T_skip_blank_trailing: --skip=alpha, exits non-zero"
else
  fail "T_skip_blank_trailing: --skip=alpha, exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_skip_blank_leading: --skip=,alpha exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_blank_leading ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--skip=,alpha" >/dev/null 2>&1 && sbl_exit=0 || sbl_exit=$?
if [[ $sbl_exit -ne 0 ]]; then
  pass "T_skip_blank_leading: --skip=,alpha exits non-zero"
else
  fail "T_skip_blank_leading: --skip=,alpha exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_skip_blank_consecutive: --skip=alpha,,bravo exits 1
# ---------------------------------------------------------------------------
echo ""
echo "--- T_skip_blank_consecutive ---"
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" "--skip=alpha,,bravo" >/dev/null 2>&1 && sbc_exit=0 || sbc_exit=$?
if [[ $sbc_exit -ne 0 ]]; then
  pass "T_skip_blank_consecutive: --skip=alpha,,bravo exits non-zero"
else
  fail "T_skip_blank_consecutive: --skip=alpha,,bravo exited 0 (expected non-zero)"
fi

# ---------------------------------------------------------------------------
# T_list_plus_only: --list --only=alpha exits 0 (--list takes precedence)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_list_plus_only ---"
setup_harness
lpo_out="$(bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --list --only=alpha 2>&1)" && lpo_exit=$? || lpo_exit=$?
if [[ $lpo_exit -eq 0 ]] && assert_contains "$lpo_out" "alpha" && [[ ! -s "$RUN_LOG" ]]; then
  pass "T_list_plus_only: --list wins over --only (exits 0, list printed, no install)"
else
  fail "T_list_plus_only: --list did not win over --only (exit=$lpo_exit)"
  echo "  Output: $lpo_out"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_list_plus_skip: --list --skip=alpha exits 0 (--list takes precedence)
# ---------------------------------------------------------------------------
echo ""
echo "--- T_list_plus_skip ---"
setup_harness
lps_out="$(bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --list --skip=alpha 2>&1)" && lps_exit=$? || lps_exit=$?
if [[ $lps_exit -eq 0 ]] && assert_contains "$lps_out" "alpha" && [[ ! -s "$RUN_LOG" ]]; then
  pass "T_list_plus_skip: --list wins over --skip (exits 0, list printed, no install)"
else
  fail "T_list_plus_skip: --list did not win over --skip (exit=$lps_exit)"
  echo "  Output: $lps_out"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_no_selection_persistence: prior --only run does NOT poison a later no-arg run
# ---------------------------------------------------------------------------
echo ""
echo "--- T_no_selection_persistence ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --only=alpha >/dev/null 2>&1 || true
teardown_harness
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_no_selection_persistence: no-arg run after --only run installs full defaults"
else
  fail "T_no_selection_persistence: no-arg run after --only run did not produce full defaults"
fi
teardown_harness

# ---------------------------------------------------------------------------
# T_git_hook_skip_path_safe: --skip=git-hook succeeds; git-hook not in run-log
# ---------------------------------------------------------------------------
echo ""
echo "--- T_git_hook_skip_path_safe ---"
setup_harness
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" --skip=git-hook >/dev/null 2>&1 || true
hook_log="$(cat "$RUN_LOG" 2>/dev/null || true)"
if echo "$hook_log" | grep -qF "git-hook"; then
  fail "T_git_hook_skip_path_safe: git-hook appeared in run-log despite being skipped"
elif assert_contains "$hook_log" "prereqs"; then
  pass "T_git_hook_skip_path_safe: --skip=git-hook succeeds; git-hook excluded from run"
else
  fail "T_git_hook_skip_path_safe: unexpected run-log: $hook_log"
fi
teardown_harness

# ---------------------------------------------------------------------------
# #495 Slice 1: interactive guard + backward-compat drift gates
# ---------------------------------------------------------------------------

interactive_fn="$(awk '/^is_interactive\(\)/,/^}/' "$LINUX_SETUP")"

echo ""
echo "--- T_menu_ci_skip ---"
_rc=127
(
  eval "$interactive_fn"
  # shellcheck disable=SC2034
  ARG_NON_INTERACTIVE_SET=0 ARG_ONLY_SET=0 ARG_SKIP_SET=0 ARG_INTERACTIVE_SET=0 ARG_SELECTION_FILE_SET=0
  # shellcheck disable=SC2034
  CI=true GITHUB_ACTIONS='' SETUP_NON_INTERACTIVE=''
  is_interactive
) && _rc=$? || _rc=$?
if [[ $_rc -eq 1 ]]; then
  pass "T_menu_ci_skip: CI suppresses interactive mode"
else
  fail "T_menu_ci_skip: CI did not suppress interactive mode (exit=$_rc)"
fi

echo ""
echo "--- T_menu_tty_skip ---"
_rc=127
(
  eval "$interactive_fn"
  # shellcheck disable=SC2034
  ARG_NON_INTERACTIVE_SET=0 ARG_ONLY_SET=0 ARG_SKIP_SET=0 ARG_INTERACTIVE_SET=0 ARG_SELECTION_FILE_SET=0
  # shellcheck disable=SC2034
  CI='' GITHUB_ACTIONS='' SETUP_NON_INTERACTIVE=''
  is_interactive
) && _rc=$? || _rc=$?
if [[ $_rc -eq 1 ]]; then
  pass "T_menu_tty_skip: redirected test harness suppresses interactive mode"
else
  fail "T_menu_tty_skip: redirected test harness was treated as interactive (exit=$_rc)"
fi

echo ""
echo "--- T_menu_non_interactive_flag ---"
_rc=127
(
  eval "$interactive_fn"
  # shellcheck disable=SC2034
  ARG_NON_INTERACTIVE_SET=1 ARG_ONLY_SET=0 ARG_SKIP_SET=0 ARG_INTERACTIVE_SET=0 ARG_SELECTION_FILE_SET=0
  # shellcheck disable=SC2034
  CI='' GITHUB_ACTIONS='' SETUP_NON_INTERACTIVE=''
  is_interactive
) && _rc=$? || _rc=$?
if [[ $_rc -eq 1 ]]; then
  pass "T_menu_non_interactive_flag: explicit flag suppresses interactive mode"
else
  fail "T_menu_non_interactive_flag: explicit flag did not suppress interactive mode (exit=$_rc)"
fi

echo ""
echo "--- T_menu_only_suppresses_guard ---"
_rc=127
(
  eval "$interactive_fn"
  # shellcheck disable=SC2034
  ARG_NON_INTERACTIVE_SET=0 ARG_ONLY_SET=1 ARG_SKIP_SET=0 ARG_INTERACTIVE_SET=0 ARG_SELECTION_FILE_SET=0
  # shellcheck disable=SC2034
  CI='' GITHUB_ACTIONS='' SETUP_NON_INTERACTIVE=''
  is_interactive
) && _rc=$? || _rc=$?
if [[ $_rc -eq 1 ]]; then
  pass "T_menu_only_suppresses_guard: --only suppresses interactive mode"
else
  fail "T_menu_only_suppresses_guard: --only did not suppress interactive mode (exit=$_rc)"
fi

echo ""
echo "--- T_menu_skip_guards_127 ---"
# Mutation guard: proves exit 127 (missing function) is NOT exit 1.
# The old '! is_interactive' pattern could not distinguish them.
# [[ _rc -eq 1 ]] can -- this test fails if the guard is wrong.
_rc=127
(
  _this_function_does_not_exist_and_exits_127
) && _rc=$? || _rc=$?
if [[ $_rc -eq 127 && $_rc -ne 1 ]]; then
  pass "T_menu_skip_guards_127: exit-127 is distinct from exit-1 (exact-status guard valid)"
else
  fail "T_menu_skip_guards_127: unexpected exit=$_rc from missing-function probe"
fi

echo ""
echo "--- T_menu_selection_file_ci_bypass ---"
_rc=127
(
  eval "$interactive_fn"
  # shellcheck disable=SC2034
  ARG_NON_INTERACTIVE_SET=0 ARG_ONLY_SET=0 ARG_SKIP_SET=0 ARG_INTERACTIVE_SET=1 ARG_SELECTION_FILE_SET=1
  # shellcheck disable=SC2034
  CI=true GITHUB_ACTIONS='' SETUP_NON_INTERACTIVE=''
  is_interactive
) && _rc=$? || _rc=$?
if [[ $_rc -eq 0 ]]; then
  pass "T_menu_selection_file_ci_bypass: --interactive + --selection-file is interactive under CI"
else
  fail "T_menu_selection_file_ci_bypass: bypass failed under CI (exit=$_rc)"
fi

echo ""
echo "--- T_noarg_noninteractive_compat ---"
setup_harness
CI=true bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_noarg_noninteractive_compat: CI no-arg run matches defaults"
else
  fail "T_noarg_noninteractive_compat: CI no-arg run drifted"
fi
teardown_harness

echo ""
echo "--- T_noninteractive_flag_compat ---"
setup_harness
bash "$LINUX_SETUP" --non-interactive "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_noninteractive_flag_compat: --non-interactive run matches defaults"
else
  fail "T_noninteractive_flag_compat: --non-interactive run drifted"
fi
teardown_harness

echo ""
echo "--- T_noninteractive_env_var_compat ---"
setup_harness
SETUP_NON_INTERACTIVE=1 bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_noninteractive_env_var_compat: env-guarded run matches defaults"
else
  fail "T_noninteractive_env_var_compat: env-guarded run drifted"
fi
teardown_harness

echo ""
echo "--- T_menu_mutual_exclusion ---"
bash "$LINUX_SETUP" --interactive --non-interactive >/dev/null 2>&1 && menu_conflict_exit=0 || menu_conflict_exit=$?
if [[ $menu_conflict_exit -ne 0 ]]; then
  pass "T_menu_mutual_exclusion: interactive flags conflict"
else
  fail "T_menu_mutual_exclusion: conflicting flags exited 0"
fi

echo ""
echo "--- T_menu_help_flags_and_no_seam ---"
menu_help="$(bash "$LINUX_SETUP" --help 2>&1)" || true
if assert_contains "$menu_help" "--interactive" && \
   assert_contains "$menu_help" "--non-interactive" && \
   assert_not_contains "$menu_help" "selection-file" && \
   assert_not_contains "$menu_help" "tools-dir"; then
  pass "T_menu_help_flags_and_no_seam: public flags shown; hidden seams absent"
else
  fail "T_menu_help_flags_and_no_seam: help visibility contract failed"
fi

echo ""
echo "--- T_selection_file_passthrough ---"
setup_harness
bash "$LINUX_SETUP" --interactive "--selection-file=${SELECTION_FILE}" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_str "$(printf 'alpha\ndelta')"; then
  pass "T_selection_file_passthrough: selection file resolves in canonical order"
else
  fail "T_selection_file_passthrough: selection file did not control dispatch"
fi
teardown_harness

echo ""
echo "--- T_selection_file_noninteractive_conflict ---"
bash "$LINUX_SETUP" --non-interactive "--selection-file=${SELECTION_FILE}" >/dev/null 2>&1 && seam_conflict_exit=0 || seam_conflict_exit=$?
if [[ $seam_conflict_exit -ne 0 ]]; then
  pass "T_selection_file_noninteractive_conflict: non-interactive rejects selection seam"
else
  fail "T_selection_file_noninteractive_conflict: invalid seam combination exited 0"
fi

echo ""
echo "--- T_menu_only_suppresses_menu ---"
setup_harness
bash "$LINUX_SETUP" --interactive --only=alpha "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_str "alpha"; then
  pass "T_menu_only_suppresses_menu: explicit selection wins"
else
  fail "T_menu_only_suppresses_menu: --interactive changed --only behavior"
fi
teardown_harness

echo ""
echo "--- T_root_interactive_passthrough ---"
setup_harness
bash "$ROOT_SETUP" --interactive "--selection-file=${SELECTION_FILE}" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_str "$(printf 'alpha\ndelta')"; then
  pass "T_root_interactive_passthrough: root forwards interactive selection flags"
else
  fail "T_root_interactive_passthrough: root forwarding failed"
fi
teardown_harness

echo ""
echo "--- T_root_noninteractive_passthrough ---"
setup_harness
bash "$ROOT_SETUP" --non-interactive "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if assert_log_equals "${STUB_DIR}/defaults.txt"; then
  pass "T_root_noninteractive_passthrough: root forwards non-interactive flag"
else
  fail "T_root_noninteractive_passthrough: root forwarding changed defaults"
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
