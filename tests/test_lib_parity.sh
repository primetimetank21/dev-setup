#!/usr/bin/env bash
# tests/test_lib_parity.sh -- smoke test for read-tool-version parity across bash and PowerShell
#
# Usage: bash tests/test_lib_parity.sh

set -uo pipefail

PASS=0
FAIL=0
SKIP=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${RESET}: $1"; SKIP=$((SKIP + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SH_READER="${REPO_ROOT}/scripts/lib/read-tool-version.sh"
PS1_READER="${REPO_ROOT}/scripts/lib/Read-ToolVersion.ps1"
CAPTURED_STDOUT=''
CAPTURED_RC=0

capture_sh() {
    local tool="$1"
    CAPTURED_STDOUT="$(sh "$SH_READER" "$tool" 2>/dev/null)"
    CAPTURED_RC=$?
}

capture_ps() {
    local tool="$1"
    CAPTURED_STDOUT="$(PS1_READER="$PS1_READER" TOOL_NAME="$tool" pwsh -NoProfile -Command "& { . \$env:PS1_READER; Get-ToolVersion -Name \$env:TOOL_NAME }" 2>/dev/null)"
    CAPTURED_RC=$?
}

assert_matching_version() {
    local label="$1"
    local tool="$2"
    local sh_out=''
    local sh_rc=0
    local ps_out=''
    local ps_rc=0

    capture_sh "$tool"
    sh_out="$CAPTURED_STDOUT"
    sh_rc=$CAPTURED_RC

    capture_ps "$tool"
    ps_out="$CAPTURED_STDOUT"
    ps_rc=$CAPTURED_RC

    if [ "$sh_rc" -eq 0 ] && [ "$ps_rc" -eq 0 ] && [ "$sh_out" = "$ps_out" ]; then
        pass "$label: $tool version matches ($sh_out)"
    else
        fail "$label: sh rc=$sh_rc out='$sh_out'; ps1 rc=$ps_rc out='$ps_out'"
    fi
}

assert_matching_missing_tool() {
    local label="$1"
    local tool="$2"
    local sh_out=''
    local sh_rc=0
    local ps_out=''
    local ps_rc=0

    capture_sh "$tool"
    sh_out="$CAPTURED_STDOUT"
    sh_rc=$CAPTURED_RC

    capture_ps "$tool"
    ps_out="$CAPTURED_STDOUT"
    ps_rc=$CAPTURED_RC

    if [ "$sh_rc" -ne 0 ] && [ "$ps_rc" -ne 0 ] && [ -z "$sh_out" ] && [ -z "$ps_out" ]; then
        pass "$label: missing tool returns empty stdout and non-zero on both platforms"
    else
        fail "$label: sh rc=$sh_rc out='$sh_out'; ps1 rc=$ps_rc out='$ps_out'"
    fi
}

if [ ! -f "$SH_READER" ]; then
    fail "bash reader not found: $SH_READER"
fi

if [ ! -f "$PS1_READER" ]; then
    fail "PowerShell reader not found: $PS1_READER"
fi

if [ "$FAIL" -eq 0 ] && ! command -v pwsh >/dev/null 2>&1; then
    skip "T4: pwsh is not available; skipping lib parity smoke test"
    echo ""
    echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
    exit 0
fi

if [ "$FAIL" -eq 0 ]; then
    assert_matching_version "T1" "nodejs"
    assert_matching_version "T2" "nvm"
    assert_matching_missing_tool "T3" "nonexistent-tool"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
