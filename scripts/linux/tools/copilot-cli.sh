#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI binary
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald
# Idempotent: yes — checks for the binary directory before attempting install.
#
# Prerequisite: gh CLI must be installed and authenticated (see gh.sh, auth.sh)
#
# Note: On gh 2.89.0+, 'gh copilot' checks update.IsCI() (CI env var) before
# showing the interactive install prompt (pkg/cmd/copilot/copilot.go). Setting
# CI=true triggers a non-interactive binary download — no PTY or 'script' needed.
# Binary is installed as ~/.local/share/gh/copilot/copilot (named "copilot").

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

# gh 2.89.0+ checks update.IsCI() before showing the install prompt (pkg/cmd/copilot/copilot.go).
# When CI=true, IsCI() returns true and gh downloads the binary non-interactively.
# The binary is installed as ~/.local/share/gh/copilot/copilot (named "copilot", not "gh-copilot").
# timeout 60: the copilot binary may wait for input after download — kill it once install is done.
CI=true timeout 60 gh copilot >/dev/null 2>&1 || true

if [[ -d "$COPILOT_INSTALL_DIR" ]] && [[ -n "$(ls -A "$COPILOT_INSTALL_DIR" 2>/dev/null)" ]]; then
  log_ok "GitHub Copilot CLI installed"
else
  log_warn "Could not auto-install Copilot CLI binary — run 'gh copilot' in your terminal to install manually"
fi
