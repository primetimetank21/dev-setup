#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#7)
# Idempotent: yes — checks if copilot is already installed before acting
#
# Prerequisite: gh CLI must be installed and authenticated (see gh.sh)
#
# TODO (Donald): Implement GitHub Copilot CLI installation.
#   - Install via gh extension: gh extension install github/gh-copilot
#   - Verify: gh copilot --version
#   - If gh is not authenticated, print a helpful message and skip

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

if gh extension list 2>/dev/null | grep -q "gh-copilot"; then
  log_ok "GitHub Copilot CLI already installed"
  exit 0
fi

if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping Copilot CLI install (run gh.sh first)"
  exit 0
fi

log_info "GitHub Copilot CLI not found — installation not yet implemented"
# TODO (Donald): Add install logic here
exit 0
