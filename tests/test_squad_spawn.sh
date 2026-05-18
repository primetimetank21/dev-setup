#!/usr/bin/env bash
# tests/test_squad_spawn.sh
# Tests for scripts/squad-spawn.sh (Issue #414)
#
# Covers:
#   A. Substitution: {name}, {N}, {worktree-path} replaced in output
#   B. Missing template exits 1
#   C. Idempotent: body already containing all 6 markers is not double-injected
#   D. Empty body exits 1
#   E. Missing body file exits 1
#
# Usage:
#   bash tests/test_squad_spawn.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SPAWN_SCRIPT="${REPO_ROOT}/scripts/squad-spawn.sh"

passed=0
failed=0

pass() { printf '\033[0;32m[PASS]\033[0m %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf '\033[0;31m[FAIL]\033[0m %s\n' "$1"; failed=$((failed + 1)); }

TMPDIR_BASE="${REPO_ROOT}/tests/.tmp_squad_spawn_$$"
mkdir -p "$TMPDIR_BASE"
# shellcheck disable=SC2329
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Test A: Substitutions are applied correctly
# ---------------------------------------------------------------------------

echo ""
echo "=== Test A: substitution ==="

echo "Spawn donald to work on issue 123." > "${TMPDIR_BASE}/body_a.md"
output="$(bash "$SPAWN_SCRIPT" \
    --body "${TMPDIR_BASE}/body_a.md" \
    --name donald \
    --issue 123 \
    --worktree /coding/dev-setup-123 \
    2>&1)" && code=0 || code=$?

if [ "$code" -ne 0 ]; then
    fail "A: expected exit 0, got $code"
elif printf '%s' "$output" | grep -qF '{name}'; then
    fail "A: {name} placeholder not substituted"
elif printf '%s' "$output" | grep -qF '{N}'; then
    fail "A: {N} placeholder not substituted"
elif printf '%s' "$output" | grep -qF '{worktree-path}'; then
    fail "A: {worktree-path} placeholder not substituted"
elif ! printf '%s' "$output" | grep -qF 'donald'; then
    fail "A: agent name 'donald' not found in output"
elif ! printf '%s' "$output" | grep -qF '123'; then
    fail "A: issue number '123' not found in output"
elif ! printf '%s' "$output" | grep -qF '/coding/dev-setup-123'; then
    fail "A: worktree path not found in output"
else
    all_ok=true
    for m in \
        'CWD-pin' \
        'base=develop discipline' \
        'ASCII discipline' \
        'history.md pre-size-check' \
        'Worktree-remove-FIRST' \
        'Hygiene tail completion'; do
        if ! printf '%s' "$output" | grep -qF "$m"; then
            fail "A: marker '$m' missing from output"
            all_ok=false
            break
        fi
    done
    if [ "$all_ok" = true ]; then
        pass "A: substitution replaces name, issue, and worktree-path in output"
    fi
fi

# ---------------------------------------------------------------------------
# Test B: Missing template exits 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Test B: missing template ==="

echo "Some body." > "${TMPDIR_BASE}/body_b.md"
output="$(bash "$SPAWN_SCRIPT" \
    --body "${TMPDIR_BASE}/body_b.md" \
    --template "${TMPDIR_BASE}/nonexistent-template.md" \
    2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "B: expected exit 1, got $code"
elif ! printf '%s' "$output" | grep -qiF 'Template not found'; then
    fail "B: error message missing; got: $output"
else
    pass "B: missing template exits 1 with error message"
fi

# ---------------------------------------------------------------------------
# Test C: Idempotent -- body already containing all 6 markers
# ---------------------------------------------------------------------------

echo ""
echo "=== Test C: idempotent ==="

cat > "${TMPDIR_BASE}/body_c.md" << 'IDEMPOTENT_BODY'
Spawn goofy for issue 42.

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
IDEMPOTENT_BODY

output="$(bash "$SPAWN_SCRIPT" \
    --body "${TMPDIR_BASE}/body_c.md" \
    --name goofy \
    --issue 42 \
    --worktree /coding/dev-setup-42 \
    2>&1)" && code=0 || code=$?

if [ "$code" -ne 0 ]; then
    fail "C: expected exit 0, got $code"
else
    # Count occurrences of the first marker -- must be exactly 1
    count="$(printf '%s' "$output" | grep -cF 'CWD-pin -- before every file write' || true)"
    if [ "$count" -ne 1 ]; then
        fail "C: marker appeared $count times (expected 1); hygiene tail was double-injected"
    else
        pass "C: idempotent -- all-6-marker body is not double-injected"
    fi
fi

# ---------------------------------------------------------------------------
# Test D: Empty body exits 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Test D: empty body ==="

printf '   ' > "${TMPDIR_BASE}/body_d.md"
output="$(bash "$SPAWN_SCRIPT" \
    --body "${TMPDIR_BASE}/body_d.md" \
    2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "D: expected exit 1, got $code"
elif ! printf '%s' "$output" | grep -qiF 'empty'; then
    fail "D: expected 'empty' in error output; got: $output"
else
    pass "D: empty body exits 1"
fi

# ---------------------------------------------------------------------------
# Test E: Missing body file exits 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Test E: missing body file ==="

output="$(bash "$SPAWN_SCRIPT" \
    --body "${TMPDIR_BASE}/no-such-body.md" \
    2>&1)" && code=0 || code=$?

if [ "$code" -ne 1 ]; then
    fail "E: expected exit 1, got $code"
elif ! printf '%s' "$output" | grep -qiF 'not found'; then
    fail "E: expected 'not found' in error output; got: $output"
else
    pass "E: missing body file exits 1"
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
