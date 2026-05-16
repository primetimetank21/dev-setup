#!/usr/bin/env bash
# tests/test_precommit_hygiene.sh
# Tests for pre-commit hygiene checks (Issue #240) and pre-push guard (Issue #224)
#
# Covers:
#   Check 1: Branch ancestry (squad/* must descend from develop)
#   Check 2: ASCII-only on staged *.ps1 files
#   Check 3: Rogue path check under .squad/
#   Check 4: Staged inbox file check
#   Check 5: Protected branch refuse (develop/main/master)
#   pre-push: Main push guard + advisory PSScriptAnalyzer exit-code
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
# Check 5 Tests: Refuse commits on protected branches
# ===========================================================================
echo ""
echo "=== Check 5: Protected branch refuse ==="

# Test 5a: FAIL - commit on develop should be refused
T5A_DIR="${TMPDIR_BASE}/t5a"
setup_test_repo "$T5A_DIR"
# Already on develop after setup_test_repo
echo "bad" > bad.txt
git add bad.txt
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T5a: commit on develop should be refused"
else
  pass "T5a: commit on develop is refused"
fi

# Test 5b: FAIL - commit on main should be refused
T5B_DIR="${TMPDIR_BASE}/t5b"
setup_test_repo "$T5B_DIR"
git checkout -q -b main
echo "bad" > bad.txt
git add bad.txt
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T5b: commit on main should be refused"
else
  pass "T5b: commit on main is refused"
fi

# Test 5c: FAIL - commit on master should be refused
T5C_DIR="${TMPDIR_BASE}/t5c"
mkdir -p "$T5C_DIR"
cd "$T5C_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
echo "init" > README.md
git add README.md
git commit -q -m "chore: init"
# Ensure we are on master (rename default branch if needed)
git branch -m master 2>/dev/null || true
echo "bad" > bad.txt
git add bad.txt
if sh "$HOOK" >/dev/null 2>&1; then
  fail "T5c: commit on master should be refused"
else
  pass "T5c: commit on master is refused"
fi

# Test 5d: PASS - commit on squad/* branch is allowed
T5D_DIR="${TMPDIR_BASE}/t5d"
setup_test_repo "$T5D_DIR"
git checkout -q -b squad/123-feature
echo "good" > good.txt
git add good.txt
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T5d: commit on squad/* branch is allowed"
else
  fail "T5d: commit on squad/* branch is allowed"
fi

# Test 5e: PASS - commit on pluto/* branch is allowed
T5E_DIR="${TMPDIR_BASE}/t5e"
setup_test_repo "$T5E_DIR"
git checkout -q -b pluto/249-fix
echo "good" > good.txt
git add good.txt
if sh "$HOOK" >/dev/null 2>&1; then
  pass "T5e: commit on pluto/* branch is allowed"
else
  fail "T5e: commit on pluto/* branch is allowed"
fi

# ===========================================================================
# pre-push Tests: Main push guard + advisory exit-code
# ===========================================================================
echo ""
echo "=== pre-push: main guard and advisory exit-code ==="

PUSH_HOOK="${REPO_ROOT}/hooks/pre-push"

# Helper: pipe a push-info line to the pre-push hook and return its exit code.
# Usage: run_push_hook "LOCAL_REF SHA REMOTE_REF SHA"
run_push_hook() {
  printf '%s\n' "$1" | sh "$PUSH_HOOK" origin "https://github.com/test/repo" >/dev/null 2>&1
}

# Test PP1: FAIL -- push whose REMOTE_REF is refs/heads/main must hard-fail
T_PP1_DIR="${TMPDIR_BASE}/tpp1"
setup_test_repo "$T_PP1_DIR"
cd "$T_PP1_DIR"
if run_push_hook "refs/heads/develop abc1234 refs/heads/main def5678"; then
  fail "Tpp1: direct push to main should hard-fail"
else
  pass "Tpp1: direct push to main is hard-rejected (exit non-zero)"
fi

# Test PP2: PASS -- push to develop is allowed
T_PP2_DIR="${TMPDIR_BASE}/tpp2"
setup_test_repo "$T_PP2_DIR"
cd "$T_PP2_DIR"
if run_push_hook "refs/heads/squad/224-test abc1234 refs/heads/develop def5678"; then
  pass "Tpp2: push to develop exits 0"
else
  fail "Tpp2: push to develop exits 0"
fi

# Test PP3: PASS -- push to a squad/* feature branch is allowed
T_PP3_DIR="${TMPDIR_BASE}/tpp3"
setup_test_repo "$T_PP3_DIR"
cd "$T_PP3_DIR"
if run_push_hook "refs/heads/squad/224-test abc1234 refs/heads/squad/224-test def5678"; then
  pass "Tpp3: push to feature branch exits 0"
else
  fail "Tpp3: push to feature branch exits 0"
fi

# Test PP4: FAIL -- any local ref pushing to refs/heads/main must be rejected
T_PP4_DIR="${TMPDIR_BASE}/tpp4"
setup_test_repo "$T_PP4_DIR"
cd "$T_PP4_DIR"
if run_push_hook "refs/heads/squad/hotfix abc1234 refs/heads/main def5678"; then
  fail "Tpp4: push targeting main from feature branch should fail"
else
  pass "Tpp4: push targeting main from any local branch is rejected"
fi

# Test PP5: PASS -- advisory PSScriptAnalyzer block exits 0 even without pwsh
# The hook uses `|| true` on all advisory commands so missing tools must not fail.
T_PP5_DIR="${TMPDIR_BASE}/tpp5"
setup_test_repo "$T_PP5_DIR"
cd "$T_PP5_DIR"
git checkout -q -b squad/224-advisory
# Commit a .ps1 so the hook has content to attempt analysis
echo 'Write-Host "advisory test"' > advisory.ps1
git add advisory.ps1
git commit -q -m "test: advisory ps1"
if run_push_hook "refs/heads/squad/224-advisory abc1234 refs/heads/squad/224-advisory def5678"; then
  pass "Tpp5: pre-push exits 0 on feature branch (advisory block does not fail CI)"
else
  fail "Tpp5: pre-push exits 0 on feature branch (advisory block does not fail CI)"
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
