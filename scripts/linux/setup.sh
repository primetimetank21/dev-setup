#!/usr/bin/env bash
# scripts/linux/setup.sh — Core Linux/macOS/WSL installer
#
# Called by: setup.sh (root entry point)
# Owner:     Donald (#1, #4–#7)
#
# This script sources individual tool installers from scripts/linux/tools/.
# Each tool script is idempotent — safe to run multiple times.
#
# Usage (direct):
#   bash scripts/linux/setup.sh
#
# TODO (Donald): Implement the full installer body below.
#   - Install system packages (apt/brew depending on OS)
#   - Source each tool script in scripts/linux/tools/
#   - Apply dotfiles from config/dotfiles/ (coordinate with Pluto)
#   - Set default shell to zsh if not already set

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# Source a tool script, logging success/failure
run_tool() {
  local tool_name="$1"
  local tool_script="${TOOLS_DIR}/${tool_name}.sh"

  if [[ ! -f "$tool_script" ]]; then
    log_warn "Tool script not found, skipping: ${tool_script}"
    return 0
  fi

  log_info "Installing: ${tool_name}"
  # shellcheck source=/dev/null
  if bash "${tool_script}"; then
    log_ok "${tool_name} — done"
  else
    log_error "${tool_name} — FAILED (see above)"
    return 1
  fi
}

main() {
  log_info "Starting Linux/macOS setup"
  log_info "Repo root: ${REPO_ROOT}"

  # TODO (Donald): Uncomment and implement as each tool script is completed
  # run_tool "zsh"
  # run_tool "uv"
  # run_tool "nvm"
  # run_tool "gh"
  # run_tool "copilot-cli"

  log_ok "Setup complete. Open a new shell to apply all changes."
}

main "$@"
