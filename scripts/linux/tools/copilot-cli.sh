#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI binary
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald
# Idempotent: yes — checks for the binary directory before attempting install.
#
# Prerequisite: gh CLI must be installed and authenticated (see gh.sh, auth.sh)
#
# Note: On gh 2.89.0+, 'gh copilot' is a built-in that prompts interactively
# on first use. Output suppression swallows that prompt, stdin gets EOF, and
# the binary is never downloaded. This script pipes 'y' to trigger a
# non-interactive download and verifies via directory existence check.

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping Copilot CLI install (run gh.sh first)"
  exit 0
fi

if ! gh auth status &>/dev/null; then
  log_warn "gh is not authenticated — skipping Copilot CLI install (run auth.sh first)"
  exit 0
fi

COPILOT_INSTALL_DIR="${HOME}/.local/share/gh/copilot"

if [[ -d "$COPILOT_INSTALL_DIR" ]] && [[ -n "$(ls -A "$COPILOT_INSTALL_DIR" 2>/dev/null)" ]]; then
  log_ok "GitHub Copilot CLI already installed"
  exit 0
fi

log_info "Installing GitHub Copilot CLI binary..."

# Pipe 'y' to answer the install prompt non-interactively.
# timeout 60 prevents hanging if the binary launches interactively after download.
# set +e / set -e because timeout exits non-zero when it kills the process.
set +e
printf 'y\n' | timeout 60 gh copilot >/dev/null 2>&1
set -e

if [[ -d "$COPILOT_INSTALL_DIR" ]] && [[ -n "$(ls -A "$COPILOT_INSTALL_DIR" 2>/dev/null)" ]]; then
  log_ok "GitHub Copilot CLI installed"
else
  log_warn "Could not auto-install Copilot CLI binary — run 'gh copilot' in your terminal to install manually"
fi
