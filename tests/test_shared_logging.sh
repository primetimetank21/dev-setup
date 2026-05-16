#!/usr/bin/env bash
# tests/test_shared_logging.sh
# Tests for scripts/linux/lib/log.sh shared logging library.
#
# Usage:
#   bash tests/test_shared_logging.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_LIB="${REPO_ROOT}/scripts/linux/lib/log.sh"

passed=0
failed=0

pass() { printf '\033[0;32m[PASS]\033[0m %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf '\033[0;31m[FAIL]\033[0m %s\n' "$1"; failed=$((failed + 1)); }

# T-1: source log.sh and verify all 4 functions are defined
# shellcheck disable=SC1090
. "$LOG_LIB"

for fn in log_info log_ok log_warn log_error; do
  if type "$fn" 2>/dev/null | grep -q 'function'; then
    pass "T-1: $fn is defined as a function"
  else
    fail "T-1: $fn is NOT defined as a function"
  fi
done

# T-2: each function emits output containing expected prefix
out_info=$(log_info "test message" 2>&1)
out_ok=$(log_ok "test message" 2>&1)
out_warn=$(log_warn "test message" 2>&1)
out_error=$(log_error "test message" 2>&1)

for pair in "log_info:[INFO]:$out_info" "log_ok:[OK]:$out_ok" "log_warn:[WARN]:$out_warn" "log_error:[ERROR]:$out_error"; do
  fn="${pair%%:*}"
  rest="${pair#*:}"
  prefix="${rest%%:*}"
  output="${rest#*:}"
  if printf '%s' "$output" | grep -q "$prefix"; then
    pass "T-2: $fn output contains $prefix"
  else
    fail "T-2: $fn output missing $prefix (got: $output)"
  fi
done

# T-3: warn and error go to stderr
# shellcheck disable=SC2034
stderr_warn=$(log_warn "stderr test" 2>&1 1>/dev/null)
stderr_error=$(log_error "stderr test" 2>&1 1>/dev/null)

if [ -n "$stderr_error" ]; then
  pass "T-3: log_error writes to stderr"
else
  fail "T-3: log_error did not write to stderr"
fi

# log_warn in canonical setup.sh does NOT redirect to stderr (no >&2),
# so we verify it writes to stdout (matching canonical behavior)
stdout_warn=$(log_warn "stdout test" 2>/dev/null)
if [ -n "$stdout_warn" ]; then
  pass "T-3: log_warn writes to stdout (canonical behavior)"
else
  fail "T-3: log_warn did not write to stdout"
fi

# T-4: sourcing twice is idempotent (no errors)
# shellcheck disable=SC1090
. "$LOG_LIB"
if type log_info 2>/dev/null | grep -q 'function'; then
  pass "T-4: idempotent sourcing -- log_info still defined after second source"
else
  fail "T-4: idempotent sourcing failed"
fi

# Results
echo ""
echo "========================================="
printf 'Passed: %d  Failed: %d\n' "$passed" "$failed"
echo "========================================="

if [ "$failed" -gt 0 ]; then
  exit 1
fi
echo "All tests passed!"
exit 0
