#!/usr/bin/env bash
# tests/test_spawn_prompt_lint.sh
# Tests for scripts/lint-spawn-prompt.sh (Issue #414)
#
# Covers:
#   A. All 6 markers present -- exits 0 with OK message
#   B. One marker missing -- exits 1 and names the missing marker
#   C. All markers missing -- exits 1 and lists all 6
#   D. File not found -- exits 1 with error message
#   E. Unknown argument -- exits 1
#
# Usage:
#   bash tests/test_spawn_prompt_lint.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LINT_SCRIPT="${REPO_ROOT}/scripts/lint-spawn-prompt.sh"

passed=0
failed=0

pass() { printf '\033[0;32m[PASS]\033[0m %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf '\033[0;31m[FAIL]\033[0m %s\n' "$1"; failed=$((failed + 1)); }

TMPDIR_BASE="${REPO_ROOT}/tests/.tmp_lint_prompt_$$"
mkdir -p "$TMPDIR_BASE"
# shellcheck disable=SC2329
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# Reusable full hygiene tail block (ASCII only)
FULL_TAIL='
### Hygiene Tail -- MANDATORY (do not omit any item)

**1. CWD-pin -- before every file write**
Run and PASS before touching any file.

**2. base=develop discipline**
Every gh pr create MUST pass --base develop explicitly.

**3. ASCII discipline -- after every file write**
0 non-ASCII bytes in every committed file.

**4. history.md pre-size-check -- before every append**
Check size before appending.

**5. Worktree-remove-FIRST cleanup -- after PR merges**
From the MAIN checkout, harvest then remove worktree.

**6. Hygiene tail completion**
Append history.md entry when done.
'

# ---------------------------------------------------------------------------
# Test A: All 6 present -- exits 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Test A: all 6 present ==="

printf '%s\n%s' "Spawn chip for issue 77." "$FULL_TAIL" > "${TMPDIR_BASE}/all6.md"
output="$(bash "$LINT_SCRIPT" --file "${TMPDIR_BASE}/all6.md" 2>&1)" && code=0 || code=$?

if [ "$code" -ne 0 ]; then
    fail "A: expected exit 0, got $code; output: $output"
elif ! printf '%s' "$output" | grep -qF 'OK'; then
    fail "A: expected OK in output; got: $output"
else
    pass "A: all 6 markers present exits 0 with OK message"
fi

# ---------------------------------------------------------------------------
# Test B: One marker missing -- exits 1 and names it
# ---------------------------------------------------------------------------

echo ""
echo "=== Test B: one marker missing ==="

# Replace the Worktree-remove-FIRST marker with a dummy string
body_b="$(printf '%s' "$FULL_TAIL" | sed 's/Worktree-remove-FIRST cleanup -- after PR merges/REMOVED_MARKER/')"
printf '%s\n%s' "Body." "$body_b" > "${TMPDIR_BASE}/missing_one.md"
output="$(bash "$LINT_SCRIPT" --file "${TMPDIR_BASE}/missing_one.md" 2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "B: expected exit 1, got $code"
elif ! printf '%s' "$output" | grep -qF 'Worktree-remove-FIRST'; then
    fail "B: expected missing marker name in output; got: $output"
else
    pass "B: one marker missing exits 1 and names the missing item"
fi

# ---------------------------------------------------------------------------
# Test C: All markers missing -- exits 1 and lists all 6
# ---------------------------------------------------------------------------

echo ""
echo "=== Test C: all markers missing ==="

echo "Spawn pluto for dotfiles. No hygiene tail here." > "${TMPDIR_BASE}/none.md"
output="$(bash "$LINT_SCRIPT" --file "${TMPDIR_BASE}/none.md" 2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "C: expected exit 1, got $code"
else
    all_listed=true
    for m in \
        'CWD-pin' \
        'base=develop discipline' \
        'ASCII discipline' \
        'history.md pre-size-check' \
        'Worktree-remove-FIRST' \
        'Hygiene tail completion'; do
        if ! printf '%s' "$output" | grep -qF "$m"; then
            fail "C: expected missing marker '$m' in output; got: $output"
            all_listed=false
            break
        fi
    done
    if [ "$all_listed" = true ]; then
        pass "C: all markers missing exits 1 and lists all 6"
    fi
fi

# ---------------------------------------------------------------------------
# Test D: File not found -- exits 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Test D: file not found ==="

output="$(bash "$LINT_SCRIPT" --file "${TMPDIR_BASE}/no-such-prompt.md" 2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "D: expected exit 1, got $code"
elif ! printf '%s' "$output" | grep -qiF 'not found'; then
    fail "D: expected 'not found' in error output; got: $output"
else
    pass "D: file not found exits 1 with error message"
fi

# ---------------------------------------------------------------------------
# Test E: Unknown argument -- exits 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Test E: unknown argument ==="

output="$(bash "$LINT_SCRIPT" --bogus-flag 2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "E: expected exit 1, got $code; output: $output"
else
    pass "E: unknown argument exits 1"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=========================================="
printf 'Passed: %d\n' "$passed"
printf 'Failed: %d\n' "$failed"
echo "=========================================="

if [ "$failed" -gt 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi

echo "All tests PASSED"
exit 0
