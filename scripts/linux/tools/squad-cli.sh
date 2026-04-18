#!/usr/bin/env bash
# scripts/linux/tools/squad-cli.sh — Install squad-cli globally via npm
#
# Called by: scripts/linux/setup.sh
# Owner:     Goofy (#106)
# Idempotent: yes — checks for squad binary before attempting install.

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

if command -v squad &>/dev/null; then
  log_ok "squad-cli already installed: $(squad --version 2>&1)"
  exit 0
fi

if ! command -v npm &>/dev/null; then
  log_warn "npm not found -- skipping squad-cli install"
  exit 0
fi

log_info "Installing squad-cli..."
npm install -g "@bradygaster/squad-cli"
log_ok "squad-cli installed"
