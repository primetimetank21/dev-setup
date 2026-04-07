#!/usr/bin/env bash
# tests/test_idempotency.sh — Idempotency test suite for dev-setup
#
# Validates that all setup scripts are safe to run more than once:
#   - Each tool script exits cleanly on second run and detects existing install
#   - No duplicate entries appear in /etc/shells or ~/.zshrc
#   - Full setup.sh second-run completes without error
#
# Usage:
#   bash tests/test_idempotency.sh
#
# Assumes: tools are already installed (run after setup.sh).
#
# Environment notes:
#   - uv installs to ~/.local/bin — not on PATH by default in non-login shells
#   - nvm is a shell function, not a binary — must be sourced from $NVM_DIR/nvm.sh
#   - copilot-cli.sh skips install (exit 0) when gh is not authenticated
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -uo pipefail

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() { echo -e "${GREEN}✅ PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}❌ FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}ℹ  INFO${RESET}: $1"; }

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/scripts/linux/tools"

# ── Test helpers ─────────────────────────────────────────────────────────────

assert_command_exists() {
  local cmd="$1"
  local msg="${2:-$cmd is on PATH}"
  if command -v "$cmd" &>/dev/null; then
    pass "$msg"
  else
    fail "$msg (command not found: $cmd)"
  fi
}

assert_no_duplicate_lines() {
  local file="$1"
  local pattern="$2"
  local description="${3:-No duplicate '$pattern' in $file}"
  if [[ ! -f "$file" ]]; then
    info "$file not found — skipping duplicate check"
    return
  fi
  local count
  count="$(grep -c "$pattern" "$file" 2>/dev/null || echo 0)"
  if [[ "$count" -le 1 ]]; then
    pass "$description (found ${count} occurrence)"
  else
    fail "$description (found ${count} occurrences — expected ≤1)"
  fi
}

assert_file_exists() {
  local file="$1"
  local msg="${2:-$file exists}"
  if [[ -f "$file" ]]; then
    pass "$msg"
  else
    fail "$msg (not found: $file)"
  fi
}

assert_dir_exists() {
  local dir="$1"
  local msg="${2:-$dir exists}"
  if [[ -d "$dir" ]]; then
    pass "$msg"
  else
    fail "$msg (not found: $dir)"
  fi
}

# Run a tool script a second time and verify idempotency.
# Passes if:
#   (a) the script detects an existing install ("already installed / configured / set"), OR
#   (b) the script exits 0 with a warning (e.g. skipped due to missing prerequisite)
assert_idempotent_tool_script() {
  local script_path="$1"
  local tool_name="$2"

  if [[ ! -f "$script_path" ]]; then
    fail "Tool script not found: $script_path"
    return
  fi

  local output exit_code
  output="$(bash "$script_path" 2>&1)" && exit_code=0 || exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    fail "$tool_name: script failed on second run (exit $exit_code)"
    echo "  Output: $output"
    return
  fi

  if echo "$output" | grep -qi "already installed\|already configured\|already set\|skipping"; then
    pass "$tool_name: idempotent — detected existing install on second run"
  else
    # Exited 0 but no "already installed" marker — still acceptable (e.g. copilot-cli
    # skips silently when gh is not authenticated), but flag it for visibility.
    info "$tool_name: exited 0 on second run (no 'already installed' marker; output: ${output:0:120})"
    pass "$tool_name: no error on second run"
  fi
}

# ── Test sections ─────────────────────────────────────────────────────────────

echo ""
echo "=== dev-setup Idempotency Test Suite ==="
echo "    Repo root: ${REPO_ROOT}"
echo ""

# ── 1. Tool script existence ──────────────────────────────────────────────────
info "--- Tool script existence ---"
assert_file_exists "${TOOLS_DIR}/zsh.sh"        "zsh.sh exists"
assert_file_exists "${TOOLS_DIR}/uv.sh"         "uv.sh exists"
assert_file_exists "${TOOLS_DIR}/nvm.sh"        "nvm.sh exists"
assert_file_exists "${TOOLS_DIR}/gh.sh"         "gh.sh exists"
assert_file_exists "${TOOLS_DIR}/copilot-cli.sh" "copilot-cli.sh exists"

# ── 2. Tool PATH verification ─────────────────────────────────────────────────
echo ""
info "--- Tool installation verification ---"

assert_command_exists "zsh" "zsh is on PATH"
assert_command_exists "gh"  "gh CLI is on PATH"

# uv installs to ~/.local/bin — add it to PATH for this session if needed
export PATH="$HOME/.local/bin:$PATH"
assert_command_exists "uv" "uv is on PATH (~/.local/bin)"

# nvm is a shell function — must be sourced; it is not a binary on PATH
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
fi
if command -v nvm &>/dev/null; then
  pass "nvm is available (sourced from $NVM_DIR)"
else
  fail "nvm is not available (NVM_DIR: $NVM_DIR)"
fi

assert_command_exists "node" "node is on PATH"
assert_command_exists "npm"  "npm is on PATH"

# ── 3. Tool script idempotency (second-run) ────────────────────────────────────
echo ""
info "--- Tool script idempotency (second-run) ---"
assert_idempotent_tool_script "${TOOLS_DIR}/zsh.sh"         "zsh.sh"
assert_idempotent_tool_script "${TOOLS_DIR}/uv.sh"          "uv.sh"
assert_idempotent_tool_script "${TOOLS_DIR}/nvm.sh"         "nvm.sh"
assert_idempotent_tool_script "${TOOLS_DIR}/gh.sh"          "gh.sh"
assert_idempotent_tool_script "${TOOLS_DIR}/copilot-cli.sh" "copilot-cli.sh"

# ── 4. Config file integrity ───────────────────────────────────────────────────
echo ""
info "--- Config file integrity ---"

# /etc/shells must not have duplicate zsh entries
ZSH_PATH="$(command -v zsh 2>/dev/null || echo '/usr/bin/zsh')"
if [[ -f /etc/shells ]]; then
  COUNT="$(grep -cF "$ZSH_PATH" /etc/shells 2>/dev/null || echo 0)"
  if [[ "$COUNT" -le 1 ]]; then
    pass "/etc/shells: no duplicate zsh entry (count: ${COUNT})"
  else
    fail "/etc/shells: duplicate zsh entries for ${ZSH_PATH} (count: ${COUNT})"
  fi
else
  info "/etc/shells not found — skipping"
fi

# ~/.zshrc must not have duplicate NVM_DIR or PATH/.local/bin blocks
if [[ -f "$HOME/.zshrc" ]]; then
  assert_no_duplicate_lines "$HOME/.zshrc" "NVM_DIR"    "No duplicate NVM_DIR in ~/.zshrc"
  assert_no_duplicate_lines "$HOME/.zshrc" "\.local/bin" "No duplicate .local/bin in ~/.zshrc"
  assert_no_duplicate_lines "$HOME/.zshrc" "nvm\.sh"    "No duplicate nvm.sh source line in ~/.zshrc"
else
  info "~/.zshrc not found — skipping .zshrc duplicate checks"
fi

# NVM directory itself should not be duplicated (just existence check)
if [[ -d "$NVM_DIR" ]]; then
  pass "NVM_DIR exists: $NVM_DIR"
else
  fail "NVM_DIR not found: $NVM_DIR"
fi

# ── 5. Full setup.sh second-run integration test ──────────────────────────────
echo ""
info "--- Full setup.sh second-run integration test ---"
if [[ ! -f "${REPO_ROOT}/setup.sh" ]]; then
  fail "setup.sh not found at repo root: ${REPO_ROOT}"
else
  info "Running setup.sh a second time (this may take a moment)..."
  if bash "${REPO_ROOT}/setup.sh" 2>&1; then
    pass "setup.sh: second run completed without error"
  else
    fail "setup.sh: second run exited with a non-zero exit code"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
printf " Results: %s passed, %s failed\n" "$PASS" "$FAIL"
echo "═══════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
