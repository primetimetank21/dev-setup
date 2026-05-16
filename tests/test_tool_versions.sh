#!/usr/bin/env bash
# tests/test_tool_versions.sh -- verify read-tool-version.sh parses .tool-versions
#
# Usage: bash tests/test_tool_versions.sh

set -uo pipefail

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
READER="${REPO_ROOT}/scripts/lib/read-tool-version.sh"

# Test 1: nodejs returns expected value
expected="22.11.0"
got="$(sh "$READER" nodejs)"
if [ "$got" = "$expected" ]; then
    pass "nodejs version is $expected"
else
    fail "nodejs version: expected '$expected', got '$got'"
fi

# Test 2: nvm returns expected value
expected="0.39.7"
got="$(sh "$READER" nvm)"
if [ "$got" = "$expected" ]; then
    pass "nvm version is $expected"
else
    fail "nvm version: expected '$expected', got '$got'"
fi

# Test 3: uv returns expected value
expected="0.4.18"
got="$(sh "$READER" uv)"
if [ "$got" = "$expected" ]; then
    pass "uv version is $expected"
else
    fail "uv version: expected '$expected', got '$got'"
fi

# Test 4: unknown tool exits non-zero
if sh "$READER" nonexistent-tool >/dev/null 2>&1; then
    fail "nonexistent tool should exit non-zero"
else
    pass "nonexistent tool exits non-zero"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
