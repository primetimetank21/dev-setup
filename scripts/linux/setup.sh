#!/usr/bin/env bash
# scripts/linux/setup.sh — Core Linux/macOS/WSL installer
#
# Called by: setup.sh (root entry point)
# Owner:     Donald (#1, #4–#7, #9)
#
# This script installs system prerequisites and runs individual tool installers
# from scripts/linux/tools/. Each tool script is idempotent — safe to re-run.
#
# Usage (direct):
#   bash scripts/linux/setup.sh

set -euo pipefail
exec 2>&1  # Merge stderr into stdout for ordered output in piped/Devcontainer environments

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

detect_platform() {
  local os
  os="$(uname -s)"
  if [[ "$os" == "Darwin" ]]; then
    echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  else
    echo "linux"
  fi
}

install_prerequisites() {
  local platform="$1"
  log_info "Installing system prerequisites..."

  if [[ "$platform" == "macos" ]]; then
    if ! command -v brew &>/dev/null; then
      log_warn "Homebrew not found — install it from https://brew.sh and re-run setup"
      return 0
    fi
    brew install curl git
  else
    sudo apt-get update -qq
    sudo apt-get install -y curl git build-essential
  fi

  log_ok "Prerequisites installed"
}

main() {
  local platform
  platform="$(detect_platform)"

  log_info "Starting Linux/macOS setup"
  log_info "Platform: ${platform}"
  log_info "Repo root: ${REPO_ROOT}"

  install_prerequisites "$platform"

  run_tool "zsh"
  run_tool "uv"
  run_tool "nvm"
  run_tool "gh"
  run_tool "auth"
  run_tool "copilot-cli"

  # Apply dotfiles if Pluto's installer exists
  local dotfiles_script="${REPO_ROOT}/config/dotfiles/install.sh"
  if [[ -f "$dotfiles_script" ]]; then
    log_info "Applying dotfiles..."
    bash "$dotfiles_script" && log_ok "Dotfiles applied"
  fi

  log_ok "Setup complete. Open a new shell to apply all changes."
}

main "$@"
