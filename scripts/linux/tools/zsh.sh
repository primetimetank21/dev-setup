#!/usr/bin/env bash
# scripts/linux/tools/zsh.sh — Install and configure zsh
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#7)
# Idempotent: yes — checks if zsh is already installed before acting

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

if command -v zsh &>/dev/null; then
  log_ok "zsh already installed: $(zsh --version)"
  exit 0
fi

PLATFORM="$(uname -s)"
if [[ "$PLATFORM" == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    log_warn "Homebrew not found — skipping zsh install via brew"
    exit 0
  fi
  brew install zsh
else
  sudo apt-get update -qq
  sudo apt-get install -y zsh
fi

# Set zsh as default shell (idempotent — check current shell first)
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  log_info "Setting zsh as default shell..."
  if grep -qF "$ZSH_PATH" /etc/shells; then
    chsh -s "$ZSH_PATH" || log_warn "Could not change shell automatically (may need sudo or manual action)"
  else
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
    chsh -s "$ZSH_PATH" || log_warn "Could not change shell automatically"
  fi
fi

log_ok "zsh installed: $(zsh --version)"
