#!/usr/bin/env bash
# tests/test_precommit_hygiene.sh
# Tests for pre-commit hygiene checks (Issue #240)
#
# Covers:
#   Check 1: Branch ancestry (squad/* must descend from develop)
#   Check 2: ASCII-only on staged *.ps1 files
#   Check 3: Rogue path check under .squad/
#   Check 4: Staged inbox file check
#
# Usage:
#   bash tests/test_precommit_hygiene.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK="${REPO_ROOT}/hooks/pre-commit"

passed=0
failed=0

pass() { printf '\033[0;32m[PASS]\033[0m %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf '\033[0;31m[FAIL]\033[0m %s\n' "$1"; failed=$((failed + 1)); }

# Create a temp directory for test repos
TMPDIR_BASE="${REPO_ROOT}/tests/.tmp_hygiene_$$"
mkdir -p "$TMPDIR_BASE"
# shellcheck disable=SC2329
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# Helper: create a fresh git repo with develop branch and a squad branch
setup_test_repo() {
  local repo_dir="$1"
  mkdir -p "$repo_dir"
  cd "$repo_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Initial commit on main
  echo "init" > README.md
  git add README.md
  git commit -q -m "chore: init"
  # Create develop from main
  git checkout -q -b develop
  echo "develop" >> README.md
  git add README.md
  git commit -q -m "chore: develop base"
}

# ===========================================================================
# Check 1 Tests: Branch ancestry
# ===========================================================================
echo ""
echo "=== Check 1: Branch ancestry ==="

# Test 1a: PASS - squad branch forked from develop
T1A_DIR="${TMPDIR_BASE}/t1a"
setup_test_repo "$T1A_DIR"
git checkout -q -b pluto/test-feature
echo "feature" > feature.txt
git add feature.txt
# Run the hook (should pass ancestry check)
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T1a: squad branch forked from develop passes ancestry check"
else
  fail "T1a: squad branch forked from develop passes ancestry check"
fi

# Test 1b: FAIL - squad branch NOT from develop (orphan-based)
T1B_DIR="${TMPDIR_BASE}/t1b"
setup_test_repo "$T1B_DIR"
# Create an orphan branch (no shared history with develop)
git checkout -q --orphan pluto/bad-branch
git rm -rf -q .
echo "orphan" > orphan.txt
git add orphan.txt
git commit -q -m "chore: orphan start"
# Stage something
echo "more" >> orphan.txt
git add orphan.txt
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T1b: squad branch NOT from develop should fail ancestry check"
else
  pass "T1b: squad branch NOT from develop fails ancestry check"
fi

# Test 1c: PASS - non-squad branch skips ancestry check
T1C_DIR="${TMPDIR_BASE}/t1c"
setup_test_repo "$T1C_DIR"
git checkout -q -b feature/something
echo "x" > x.txt
git add x.txt
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T1c: non-squad branch skips ancestry check"
else
  fail "T1c: non-squad branch skips ancestry check"
fi

# ===========================================================================
# Check 2 Tests: ASCII-only on staged .ps1 files
# ===========================================================================
echo ""
echo "=== Check 2: ASCII-only .ps1 ==="

# Test 2a: FAIL - .ps1 with non-ASCII
T2A_DIR="${TMPDIR_BASE}/t2a"
setup_test_repo "$T2A_DIR"
git checkout -q -b pluto/ascii-test
# Create a .ps1 with an em dash (UTF-8 bytes for U+2014: E2 80 94)
printf 'Write-Host "hello \xe2\x80\x94 world"\n' > test.ps1
git add test.ps1
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T2a: .ps1 with non-ASCII bytes should fail"
else
  pass "T2a: .ps1 with non-ASCII bytes fails"
fi

# Test 2b: PASS - .ps1 with only ASCII
T2B_DIR="${TMPDIR_BASE}/t2b"
setup_test_repo "$T2B_DIR"
git checkout -q -b pluto/ascii-pass
echo 'Write-Host "hello -- world"' > test.ps1
git add test.ps1
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T2b: .ps1 with ASCII-only passes"
else
  fail "T2b: .ps1 with ASCII-only passes"
fi

# Test 2c: PASS - non-.ps1 file with non-ASCII is allowed
T2C_DIR="${TMPDIR_BASE}/t2c"
setup_test_repo "$T2C_DIR"
git checkout -q -b pluto/non-ps1
printf 'hello \xe2\x80\x94 world\n' > notes.md
git add notes.md
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T2c: non-.ps1 with non-ASCII is allowed"
else
  fail "T2c: non-.ps1 with non-ASCII is allowed"
fi

# ===========================================================================
# Check 3 Tests: Rogue path check under .squad/
# ===========================================================================
echo ""
echo "=== Check 3: Rogue .squad/ paths ==="

# Test 3a: PASS - valid .squad/ path
T3A_DIR="${TMPDIR_BASE}/t3a"
setup_test_repo "$T3A_DIR"
git checkout -q -b pluto/squad-valid
mkdir -p .squad/agents/pluto
echo "# Charter" > .squad/agents/pluto/charter.md
git add .squad/agents/pluto/charter.md
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T3a: valid .squad/ path passes"
else
  fail "T3a: valid .squad/ path passes"
fi

# Test 3b: FAIL - rogue .squad/ path
T3B_DIR="${TMPDIR_BASE}/t3b"
setup_test_repo "$T3B_DIR"
git checkout -q -b pluto/squad-rogue
mkdir -p .squad/random
echo "rogue" > .squad/random/notes.md
git add .squad/random/notes.md
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T3b: rogue .squad/ path should fail"
else
  pass "T3b: rogue .squad/ path fails"
fi

# Test 3c: PASS - .squad/team.md is valid
T3C_DIR="${TMPDIR_BASE}/t3c"
setup_test_repo "$T3C_DIR"
git checkout -q -b pluto/squad-team
mkdir -p .squad
echo "# Team" > .squad/team.md
git add .squad/team.md
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T3c: .squad/team.md passes"
else
  fail "T3c: .squad/team.md passes"
fi

# Test 3d: PASS - .squad/skills/x/SKILL.md is valid
T3D_DIR="${TMPDIR_BASE}/t3d"
setup_test_repo "$T3D_DIR"
git checkout -q -b pluto/squad-skill
mkdir -p .squad/skills/testing
echo "# Skill" > .squad/skills/testing/SKILL.md
git add .squad/skills/testing/SKILL.md
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T3d: .squad/skills/name/SKILL.md passes"
else
  fail "T3d: .squad/skills/name/SKILL.md passes"
fi

# Test 3e: FAIL - .squad/agents/pluto/random.md is rogue
T3E_DIR="${TMPDIR_BASE}/t3e"
setup_test_repo "$T3E_DIR"
git checkout -q -b pluto/squad-agent-rogue
mkdir -p .squad/agents/pluto
echo "rogue" > .squad/agents/pluto/random.md
git add .squad/agents/pluto/random.md
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T3e: .squad/agents/name/random.md should fail"
else
  pass "T3e: .squad/agents/name/random.md fails"
fi

# ===========================================================================
# Check 4 Tests: Staged inbox file check
# ===========================================================================
echo ""
echo "=== Check 4: Staged inbox files ==="

# Test 4a: FAIL - file staged under .squad/decisions/inbox/
T4A_DIR="${TMPDIR_BASE}/t4a"
setup_test_repo "$T4A_DIR"
git checkout -q -b pluto/inbox-test
mkdir -p .squad/decisions/inbox
echo "decision" > .squad/decisions/inbox/test.md
git add -f .squad/decisions/inbox/test.md
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T4a: staged inbox file should fail"
else
  pass "T4a: staged inbox file fails"
fi

# Test 4b: PASS - no inbox files staged
T4B_DIR="${TMPDIR_BASE}/t4b"
setup_test_repo "$T4B_DIR"
git checkout -q -b pluto/inbox-clean
echo "clean" > clean.txt
git add clean.txt
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T4b: no inbox files staged passes"
else
  fail "T4b: no inbox files staged passes"
fi

# ===========================================================================
# Summary
# ===========================================================================
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
