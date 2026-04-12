#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI extension
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald
# Idempotent: yes — checks if gh copilot is already available (built-in or extension)
#
# Prerequisite: gh CLI must be installed and authenticated (see gh.sh)
#
# Note: In gh 2.x+, 'gh copilot' may be a built-in command rather than an
# extension. This script handles both cases gracefully.

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping Copilot CLI install (run gh.sh first)"
  exit 0
fi

# Check if gh copilot is already available (built-in in gh 2.x+ or installed extension)
if gh copilot --help &>/dev/null 2>&1; then
  log_ok "GitHub Copilot CLI already available"
  exit 0
fi

# gh extension install requires authentication
if ! gh auth status &>/dev/null; then
  log_warn "gh is not authenticated — skipping Copilot CLI install"
  log_warn "Run 'gh auth login' then re-run setup to install the Copilot CLI extension"
  exit 0
fi

# Remove any conflicting gh alias that would block extension install
if gh alias list 2>/dev/null | grep -q "^copilot"; then
  log_warn "Removing conflicting gh alias 'copilot' (leftover from prior install)..."
  gh alias delete copilot
fi

log_info "Installing GitHub Copilot CLI..."

# Temporarily disable set -e to capture install output and handle gracefully.
# In newer gh versions, 'copilot' may be promoted to a built-in, causing
# extension install to fail with a specific error we can detect and accept.
set +e
install_out="$(gh extension install github/gh-copilot 2>&1)"
install_rc=$?
set -e

if [[ $install_rc -ne 0 ]]; then
  if printf '%s' "$install_out" | grep -q "matches the name of a built-in"; then
    log_ok "GitHub Copilot CLI is available as a built-in gh command"
    exit 0
  fi
  printf '%s\n' "$install_out"
  exit 1
fi

log_ok "GitHub Copilot CLI installed — run 'gh copilot --help' to get started"
