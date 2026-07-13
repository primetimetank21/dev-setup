#!/usr/bin/env bash
# tests/test_delta_installer.sh -- parity tests for git-delta opt-in installer (#466)
#
# Tests:
#   T_delta_in_list        -- delta appears in --list output (opt-in discoverable)
#   T_delta_not_default    -- delta is NOT installed by a default no-arg run
#   T_delta_gitconfig_iso  -- apply_delta_git_config writes core.pager=delta under
#                             an isolated GIT_CONFIG_GLOBAL (does not touch ~/.gitconfig)
#   T_delta_gitconfig_idem -- apply_delta_git_config is idempotent (safe to run twice)
#
# Usage: bash tests/test_delta_installer.sh
# Requires: bash 3.2+ (macOS compatible), git

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
DELTA_SH="${REPO_ROOT}/scripts/linux/tools/delta.sh"
STUB_DIR="${REPO_ROOT}/tests/fixtures/stub-tools/linux"

pass() { printf "${GREEN}PASS${RESET}: %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${RESET}: %s\n" "$1"; FAIL=$((FAIL + 1)); }
# shellcheck disable=SC2329
skip() { printf "${YELLOW}SKIP${RESET}: %s -- %s\n" "$1" "$2"; SKIP=$((SKIP + 1)); }

# Log no-ops -- inherited by subshells; called indirectly by delta.sh when sourced.
# shellcheck disable=SC2329
log_info() { :; }
# shellcheck disable=SC2329
log_ok()   { :; }
# shellcheck disable=SC2329
log_warn() { :; }
# shellcheck disable=SC2329
log_error(){ :; }

# ---------------------------------------------------------------------------
# T_delta_in_list: --list on real tools dir includes 'delta'
# Fails RED when scripts/linux/tools/delta.sh does not exist.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_delta_in_list ---"
list_out="$(bash "$LINUX_SETUP" --list 2>&1)" && list_exit=$? || list_exit=$?
if [ "$list_exit" -ne 0 ]; then
  fail "T_delta_in_list: --list exited $list_exit (expected 0)"
elif echo "$list_out" | grep -qF "delta"; then
  pass "T_delta_in_list: delta appears in --list output (opt-in discoverable)"
else
  fail "T_delta_in_list: delta missing from --list output (is delta.sh in tools/?)"
  echo "  --list output: $list_out"
fi

# ---------------------------------------------------------------------------
# T_delta_not_default: default no-arg run with stub dir does NOT run delta
# Delta is opt-in; it must not appear in defaults.txt.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_delta_not_default ---"
RUN_LOG="$(mktemp)"
export RUN_LOG
bash "$LINUX_SETUP" "--tools-dir=${STUB_DIR}" >/dev/null 2>&1 || true
if grep -qF "delta" "$RUN_LOG" 2>/dev/null; then
  fail "T_delta_not_default: delta ran in a default no-arg install (must be opt-in only)"
else
  pass "T_delta_not_default: delta does NOT run in a default install (correctly opt-in)"
fi
rm -f "$RUN_LOG"
unset RUN_LOG

# ---------------------------------------------------------------------------
# T_delta_gitconfig_iso: apply_delta_git_config writes core.pager=delta under
# an isolated GIT_CONFIG_GLOBAL; real ~/.gitconfig is never touched.
# Fails RED when delta.sh does not exist (function not defined).
# ---------------------------------------------------------------------------
echo ""
echo "--- T_delta_gitconfig_iso ---"
if [ ! -f "$DELTA_SH" ]; then
  fail "T_delta_gitconfig_iso: delta.sh not found at $DELTA_SH -- RED (pre-implementation)"
else
  ISO_CFG="$(mktemp)"
  # Run in a subshell so set -euo pipefail from delta.sh does not affect parent.
  # GIT_CONFIG_GLOBAL is set inside the subshell intentionally; we read via inline
  # env assignment after the subshell exits.
  # shellcheck disable=SC2030
  (
    export GIT_CONFIG_GLOBAL="$ISO_CFG"
    # shellcheck disable=SC1090
    . "$DELTA_SH"
    apply_delta_git_config
  )
  sub_exit=$?
  if [ "$sub_exit" -ne 0 ]; then
    fail "T_delta_gitconfig_iso: apply_delta_git_config subshell exited $sub_exit"
  else
    # shellcheck disable=SC2031
    got_pager="$(GIT_CONFIG_GLOBAL="$ISO_CFG" git config --global --get core.pager 2>/dev/null || true)"
    # shellcheck disable=SC2031
    got_filter="$(GIT_CONFIG_GLOBAL="$ISO_CFG" git config --global --get interactive.diffFilter 2>/dev/null || true)"
    if [ "$got_pager" = "delta" ] && [ "$got_filter" = "delta --color-only" ]; then
      pass "T_delta_gitconfig_iso: core.pager=delta and interactive.diffFilter set under isolated config"
    else
      fail "T_delta_gitconfig_iso: unexpected config values (pager='${got_pager}', filter='${got_filter}')"
    fi
  fi
  rm -f "$ISO_CFG"
fi

# ---------------------------------------------------------------------------
# T_delta_gitconfig_idem: running apply_delta_git_config twice does not error
# (git config --global is naturally idempotent).
# Fails RED when delta.sh does not exist.
# ---------------------------------------------------------------------------
echo ""
echo "--- T_delta_gitconfig_idem ---"
if [ ! -f "$DELTA_SH" ]; then
  fail "T_delta_gitconfig_idem: delta.sh not found -- RED (pre-implementation)"
else
  ISO_CFG2="$(mktemp)"
  # shellcheck disable=SC2030,SC2031
  (
    # shellcheck disable=SC2031
    export GIT_CONFIG_GLOBAL="$ISO_CFG2"
    # shellcheck disable=SC1090
    . "$DELTA_SH"
    apply_delta_git_config  # first run
    apply_delta_git_config  # second run -- must be a no-op / safe
  )
  idem_exit=$?
  if [ "$idem_exit" -ne 0 ]; then
    fail "T_delta_gitconfig_idem: second run of apply_delta_git_config exited $idem_exit"
  else
    # shellcheck disable=SC2031
    got_dark="$(GIT_CONFIG_GLOBAL="$ISO_CFG2" git config --global --get delta.dark 2>/dev/null || true)"
    if [ "$got_dark" = "true" ]; then
      pass "T_delta_gitconfig_idem: idempotent double-run completed; delta.dark=true"
    else
      fail "T_delta_gitconfig_idem: delta.dark unexpected value after double-run: '${got_dark}'"
    fi
  fi
  rm -f "$ISO_CFG2"
fi

# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
