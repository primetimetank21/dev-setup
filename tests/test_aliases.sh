#!/usr/bin/env bash
# tests/test_aliases.sh — Unit tests for shell alias functions
#
# Validates create_tmux() session detection and attachment logic.
# tmux is mocked for CI safety — no real tmux process is spawned.
#
# Test scenarios:
#   1. No session exists       → new-session created, attach called
#   2. tank_dev already exists → new-session NOT called, attach called
#   3. Different session exists → new-session called (tank_dev still missing), attach called
#
# Usage (from repo root):
#   bash tests/test_aliases.sh
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

# ── Path setup ────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"  # repo root, regardless of CWD
ALIASES_FILE="$REPO_ROOT/config/dotfiles/.aliases"

if [[ ! -f "$ALIASES_FILE" ]]; then
    echo "ERROR: $ALIASES_FILE not found. Run from repo root." >&2
    exit 1
fi

# ── Output helpers ────────────────────────────────────────────────────────────

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

# ── Mock infrastructure ───────────────────────────────────────────────────────
#
# We stub tmux as a shell function so no real tmux is needed in CI.
#
# MOCK_SESSION: set to a session name to simulate it as existing.
#               Leave empty to simulate no sessions exist.
# TMUX_CALLS:   array of subcommands called (e.g. "has-session", "new-session", "attach")

MOCK_SESSION=""
TMUX_CALLS=()

# Stub for tmux — intercepts all calls, records the subcommand, simulates behavior
tmux() {
    local subcmd="${1:-}"
    TMUX_CALLS+=("$subcmd")  # record which subcommand was invoked

    case "$subcmd" in
        has-session)
            # Positional args: has-session -t <session_name>
            # Return 0 (exists) only if the target matches MOCK_SESSION
            local target="${3:-}"  # argument after -t flag
            if [[ -n "$MOCK_SESSION" && "$target" == "$MOCK_SESSION" ]]; then
                return 0  # session exists
            fi
            return 1  # session does not exist
            ;;
        new-session|attach)
            # Stub: succeed silently — no real tmux process spawned
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# Reset mock state between tests
reset_mock() {
    TMUX_CALLS=()
    MOCK_SESSION=""
}

# Returns 0 if tmux was called with the given subcommand, 1 otherwise
was_called() {
    local target="$1"
    local call
    for call in "${TMUX_CALLS[@]:-}"; do
        [[ "$call" == "$target" ]] && return 0
    done
    return 1
}

# Returns 0 if tmux was NOT called with the given subcommand
was_not_called() {
    was_called "$1" && return 1
    return 0
}

# ── Load create_tmux from .aliases ────────────────────────────────────────────
#
# We extract just the create_tmux() function block, then source it so the mock
# tmux function above takes effect when create_tmux runs.

# shellcheck disable=SC1090
source <(sed -n '/^create_tmux()/,/^}$/p' "$ALIASES_FILE")

if ! declare -f create_tmux > /dev/null 2>&1; then
    echo "ERROR: create_tmux() not found in $ALIASES_FILE" >&2
    exit 1
fi

# ── Test 1: No session exists → create tank_dev and attach ───────────────────

test_no_session_creates_and_attaches() {
    reset_mock
    MOCK_SESSION=""  # no sessions running

    create_tmux

    # Expect new-session to be called (tank_dev must be created)
    if was_called "new-session"; then
        pass "no-session: tmux new-session was called to create tank_dev"
    else
        fail "no-session: expected tmux new-session to be called, but it was not"
    fi

    # Expect attach to be called
    if was_called "attach"; then
        pass "no-session: tmux attach was called to connect to the new session"
    else
        fail "no-session: expected tmux attach to be called, but it was not"
    fi
}

# ── Test 2: tank_dev already exists → attach only, no duplicate create ────────

test_tank_dev_exists_skips_create() {
    reset_mock
    MOCK_SESSION="tank_dev"  # tank_dev is already running

    create_tmux

    # Expect new-session NOT to be called (tank_dev already exists)
    if was_not_called "new-session"; then
        pass "tank_dev_exists: tmux new-session was NOT called — no duplicate session created"
    else
        fail "tank_dev_exists: tmux new-session should NOT be called when tank_dev already exists"
    fi

    # Expect attach to be called to connect to the existing session
    if was_called "attach"; then
        pass "tank_dev_exists: tmux attach was called to connect to existing session"
    else
        fail "tank_dev_exists: expected tmux attach to be called, but it was not"
    fi
}

# ── Test 3: Different session exists but not tank_dev → create tank_dev ───────

test_other_session_still_creates_tank_dev() {
    reset_mock
    MOCK_SESSION="some_other_project"  # unrelated session exists, but tank_dev does not

    create_tmux

    # Expect new-session to be called (tank_dev is still missing)
    if was_called "new-session"; then
        pass "other-session: tmux new-session called — tank_dev missing despite another session running"
    else
        fail "other-session: expected tmux new-session to be called since tank_dev does not exist"
    fi

    # Expect attach to be called
    if was_called "attach"; then
        pass "other-session: tmux attach was called"
    else
        fail "other-session: expected tmux attach to be called, but it was not"
    fi
}

# ── Run all tests ─────────────────────────────────────────────────────────────

echo ""
echo "▶ tests/test_aliases.sh — create_tmux() session detection"
echo ""

test_no_session_creates_and_attaches
echo ""
test_tank_dev_exists_skips_create
echo ""
test_other_session_still_creates_tank_dev

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Results: ${GREEN}${PASS} passed${RESET}, ${RED}${FAIL} failed${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

[[ "$FAIL" -eq 0 ]] || exit 1
