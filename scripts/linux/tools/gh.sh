#!/usr/bin/env bash
# scripts/linux/tools/gh.sh — Install GitHub CLI (gh)
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#7)
# Idempotent: yes — checks if gh is already installed before acting
#
# TODO (Donald): Implement gh CLI installation.
#   - Linux: install via apt (GitHub's official apt repo) or brew
#   - macOS: brew install gh
#   - Docs: https://cli.github.com/manual/installation

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

if command -v gh &>/dev/null; then
  log_ok "gh already installed: $(gh --version | head -1)"
  exit 0
fi

log_info "gh not found — installation not yet implemented"
# TODO (Donald): Add install logic here
exit 0
