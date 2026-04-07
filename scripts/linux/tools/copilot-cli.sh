#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI extension
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#9)
# Idempotent: yes — checks if gh-copilot extension is already installed
#
# Prerequisite: gh CLI must be installed and authenticated (see gh.sh)

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping Copilot CLI install (run gh.sh first)"
  exit 0
fi

if gh extension list 2>/dev/null | grep -q "gh-copilot"; then
  log_ok "GitHub Copilot CLI already installed"
  exit 0
fi

# gh extension install requires authentication
if ! gh auth status &>/dev/null; then
  log_warn "gh is not authenticated — skipping Copilot CLI install"
  log_warn "Run 'gh auth login' then re-run setup to install the Copilot CLI extension"
  exit 0
fi

log_info "Installing GitHub Copilot CLI..."
gh extension install github/gh-copilot

log_ok "Copilot CLI installed: $(gh copilot --version 2>/dev/null || echo 'installed')"
