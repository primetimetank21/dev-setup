#!/usr/bin/env bash
# scripts/linux/tools/nvm.sh — Install nvm (Node Version Manager) + Node LTS
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#4)
# Idempotent: yes — checks if nvm is already installed before acting

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  log_ok "nvm already installed at ${NVM_DIR}"
  exit 0
fi

log_info "Installing nvm..."
NVM_VERSION="$(curl -sSf https://api.github.com/repos/nvm-sh/nvm/releases/latest \
  | grep '"tag_name"' \
  | sed 's/.*"v\([^"]*\)".*/\1/')"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash

# Source nvm in current shell session
export NVM_DIR="$NVM_DIR"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

log_ok "nvm installed: $(nvm --version 2>/dev/null || echo 'restart shell to activate')"

# Install LTS Node
log_info "Installing Node.js LTS..."
nvm install --lts \
  || log_warn "nvm install --lts failed — source ~/.nvm/nvm.sh in a new shell and retry"
