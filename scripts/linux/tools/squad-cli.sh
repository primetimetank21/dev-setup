#!/usr/bin/env bash
# scripts/linux/tools/squad-cli.sh -- Install squad-cli globally via npm
#
# Called by: scripts/linux/setup.sh
# Owner:     Goofy (#106)
# Idempotent: yes -- checks for squad binary before attempting install.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

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
