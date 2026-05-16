#!/usr/bin/env bash
# scripts/linux/tools/nvm.sh -- Install nvm (Node Version Manager) + pinned Node
#
# Called by: scripts/linux/setup.sh
# Owner:     Goofy (#2) / Donald (#4)
# Idempotent: yes -- checks if pinned Node version is already installed

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Read pinned Node version from .tool-versions
PINNED_NODE="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" nodejs)"

# -- Check if Node is already at the pinned version -----------------------
if command -v node &>/dev/null; then
  CURRENT_VER="$(node --version 2>/dev/null | sed 's/^v//')"
  if [ "$CURRENT_VER" = "$PINNED_NODE" ]; then
    log_ok "Node ${PINNED_NODE} already installed -- skipping"
    exit 0
  fi
  log_info "Node ${CURRENT_VER} found but pinned version is ${PINNED_NODE}"
fi

# -- Install nvm if missing -----------------------------------------------
if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
  NVM_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" nvm)"
  log_info "Installing nvm (pinned: ${NVM_VERSION})..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
else
  log_ok "nvm already installed at ${NVM_DIR}"
fi

# Source nvm in current shell session
export NVM_DIR="$NVM_DIR"
# shellcheck source=/dev/null
\. "$NVM_DIR/nvm.sh"

log_ok "nvm ready: $(nvm --version 2>/dev/null || echo 'unknown')"

# -- Install and activate pinned Node version ------------------------------
log_info "Installing Node.js ${PINNED_NODE} via nvm..."
nvm install "$PINNED_NODE" || {
  log_error "nvm install ${PINNED_NODE} failed -- try 'nvm install ${PINNED_NODE}' manually"
  exit 1
}
nvm use "$PINNED_NODE"

# -- Verify ----------------------------------------------------------------
if command -v node &>/dev/null; then
  log_ok "node $(node --version) ready"
else
  log_warn "node not found on PATH after nvm install"
fi
if command -v npm &>/dev/null; then
  log_ok "npm $(npm --version) ready"
else
  log_warn "npm not found on PATH after nvm install"
fi
