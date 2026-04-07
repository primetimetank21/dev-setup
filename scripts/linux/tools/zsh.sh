#!/usr/bin/env bash
# scripts/linux/tools/zsh.sh — Install and configure zsh
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#4)
# Idempotent: yes — checks if zsh is already installed before acting
#
# TODO (Donald): Implement zsh installation and configuration.
#   - apt install zsh (Linux) / brew install zsh (macOS)
#   - Install Oh My Zsh or equivalent if desired
#   - Set zsh as the default shell (chsh -s $(which zsh))

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

if command -v zsh &>/dev/null; then
  log_ok "zsh already installed: $(zsh --version)"
  exit 0
fi

log_info "zsh not found — installation not yet implemented"
# TODO (Donald): Add install logic here
exit 0
