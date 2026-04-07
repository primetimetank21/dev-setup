#!/usr/bin/env bash
# scripts/linux/tools/nvm.sh — Install nvm (Node Version Manager)
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#6)
# Idempotent: yes — checks if nvm is already installed before acting
#
# TODO (Donald): Implement nvm installation.
#   - Install via: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
#   - Source nvm in current session after install
#   - Install a default Node LTS version: nvm install --lts

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  log_ok "nvm already installed at ${NVM_DIR}"
  exit 0
fi

log_info "nvm not found — installation not yet implemented"
# TODO (Donald): Add install logic here
exit 0
