#!/usr/bin/env bash
# scripts/linux/tools/squad-cli.sh -- Install squad-cli globally via npm
#
# Called by: scripts/linux/setup.sh
# Owner:     Goofy (#106)
# Idempotent: yes -- checks for squad binary before attempting install.

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

if command -v squad &>/dev/null; then
  log_ok "squad-cli already installed: $(squad --version 2>&1)"
  exit 0
fi

if ! command -v npm &>/dev/null; then
  log_error "npm not found after nvm install. Possible causes:"
  log_error "  1. PATH refresh failed -- close this terminal and open a new one, then re-run setup"
  log_error "  2. nvm install failed silently -- check 'nvm list' and try 'nvm install <version>' manually"
  log_error "  3. Node is installed elsewhere but not on PATH"
  exit 1
fi

log_info "Installing squad-cli..."
npm install -g "@bradygaster/squad-cli"
log_ok "squad-cli installed"
