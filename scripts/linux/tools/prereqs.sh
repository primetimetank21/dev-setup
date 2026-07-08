#!/usr/bin/env bash
# scripts/linux/tools/prereqs.sh -- Install system prerequisites
#
# Extracted from scripts/linux/setup.sh install_prerequisites().
# Called by the dispatcher as a normal tool step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../lib/log.sh"

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

platform="$(detect_platform)"
log_info "Installing system prerequisites..."

if [[ "$platform" == "macos" ]]; then
  if ! command -v brew &>/dev/null; then
    log_warn "Homebrew not found -- install it from https://brew.sh and re-run setup"
    exit 0
  fi
  brew install curl git vim tmux
else
  sudo apt-get update -qq
  sudo apt-get install -y curl git build-essential vim tmux
fi

log_ok "Prerequisites installed"
