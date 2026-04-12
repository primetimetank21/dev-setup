#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh — Install GitHub Copilot CLI
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald
# Idempotent: yes — checks for ~/.local/bin/copilot before attempting install.
#
# Installs the standalone GitHub Copilot CLI (github/copilot-cli) via the
# official install script (https://gh.io/copilot-install). Non-root install
# lands at ~/.local/bin/copilot, which is already in PATH via the dev-setup
# managed block.

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

COPILOT_BIN="${HOME}/.local/bin/copilot"

if [[ -x "$COPILOT_BIN" ]]; then
  log_ok "GitHub Copilot CLI already installed"
  exit 0
fi

log_info "Installing GitHub Copilot CLI..."

# Official install script. Non-root: installs to ~/.local/bin/copilot (in PATH).
# Root: installs to /usr/local/bin/copilot.
if curl -fsSL https://gh.io/copilot-install | bash; then
  if [[ -x "$COPILOT_BIN" ]]; then
    log_ok "GitHub Copilot CLI installed"
  else
    log_warn "Install script ran but binary not found at ${COPILOT_BIN} — may need manual install"
  fi
else
  log_warn "Could not install GitHub Copilot CLI — run 'curl -fsSL https://gh.io/copilot-install | bash' manually"
fi
