#!/usr/bin/env bash
# scripts/linux/tools/pi.sh -- Install pi CLI globally via npm at pinned version
#
# Called by: scripts/linux/setup.sh
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
# Opt-in: NOT in DEFAULT_TOOLS; only runs when requested via --only=pi.
#
# Install mechanism: npm install -g --ignore-scripts @earendil-works/pi-coding-agent@<version>
# This is the documented install path and supports exact version pinning.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

# Source nvm if available, to get node/npm on PATH in this subshell.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck source=/dev/null
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh" --no-use
  nvm use default 2>/dev/null || true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" pi)"
PI_PACKAGE='@earendil-works/pi-coding-agent'

log_info "Pinned pi version: ${PI_VERSION}"

# Detect installed version; use timeout to avoid hangs from shell startup hooks.
INSTALLED_VERSION=""
if command -v pi &>/dev/null; then
  INSTALLED_VERSION="$(timeout 10 pi --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

if [ "${INSTALLED_VERSION}" = "${PI_VERSION}" ]; then
  log_ok "pi already at pinned version ${PI_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "pi ${INSTALLED_VERSION} installed; upgrading to pinned ${PI_VERSION}..."
else
  log_info "Installing pi ${PI_VERSION}..."
fi

if ! command -v npm &>/dev/null; then
  log_warn "npm not found -- cannot install pi via npm; run 'npm install -g --ignore-scripts ${PI_PACKAGE}@${PI_VERSION}' once Node is available"
  exit 0
fi

npm install -g --no-fund --no-audit --ignore-scripts "${PI_PACKAGE}@${PI_VERSION}"
log_ok "pi installed at ${PI_VERSION}"
