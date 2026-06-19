#!/usr/bin/env bash
# scripts/linux/tools/squad-cli.sh -- Install squad-cli globally via npm at pinned version
#
# Called by: scripts/linux/setup.sh
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.

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
SQUAD_CLI_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" squad-cli)"

log_info "Pinned squad-cli version: ${SQUAD_CLI_VERSION}"

# Detect installed version; use timeout to prevent a network-dependent binary from hanging
INSTALLED_VERSION=""
if command -v squad &>/dev/null; then
  INSTALLED_VERSION="$(timeout 10 squad --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

if [ "${INSTALLED_VERSION}" = "${SQUAD_CLI_VERSION}" ]; then
  log_ok "squad-cli already at pinned version ${SQUAD_CLI_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "squad-cli ${INSTALLED_VERSION} installed; upgrading to pinned ${SQUAD_CLI_VERSION}..."
else
  log_info "Installing squad-cli ${SQUAD_CLI_VERSION}..."
fi

if ! command -v npm &>/dev/null; then
  log_warn "npm not found -- cannot install squad-cli; run 'npm install -g @bradygaster/squad-cli@${SQUAD_CLI_VERSION}' once Node is available"
  exit 0
fi

npm install -g --no-fund --no-audit "@bradygaster/squad-cli@${SQUAD_CLI_VERSION}"
log_ok "squad-cli installed at ${SQUAD_CLI_VERSION}"
