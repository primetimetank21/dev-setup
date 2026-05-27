#!/usr/bin/env bash
# scripts/linux/tools/copilot-cli.sh -- Install GitHub Copilot CLI at pinned version
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald / Goofy (#255)
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
#
# Install mechanism: npm install -g @github/copilot@<version>
# This guarantees the pinned version and works regardless of the system package manager.

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
COPILOT_CLI_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" copilot-cli)"

log_info "Pinned copilot-cli version: ${COPILOT_CLI_VERSION}"

# Detect installed version; use timeout to prevent a network-dependent binary from hanging
INSTALLED_VERSION=""
if command -v copilot &>/dev/null; then
  INSTALLED_VERSION="$(timeout 10 copilot --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

if [ "${INSTALLED_VERSION}" = "${COPILOT_CLI_VERSION}" ]; then
  log_ok "GitHub Copilot CLI already at pinned version ${COPILOT_CLI_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "Copilot CLI ${INSTALLED_VERSION} installed; upgrading to pinned ${COPILOT_CLI_VERSION}..."
else
  log_info "Installing GitHub Copilot CLI ${COPILOT_CLI_VERSION}..."
fi

if ! command -v npm &>/dev/null; then
  log_warn "npm not found -- cannot install copilot-cli via npm; run 'npm install -g @github/copilot@${COPILOT_CLI_VERSION}' once Node is available"
  exit 0
fi

# In a Codespace, gh copilot extension already provides copilot capability -- skip npm install
if [[ "${CODESPACES:-}" == "true" ]] && timeout 10 gh copilot --version &>/dev/null 2>&1; then
  log_ok "Codespace detected with gh copilot extension -- skipping npm install"
  exit 0
fi

# Suppress interactive postinstall prompts in non-interactive / CI environments
is_non_interactive() {
  [[ "${CI:-}" == "true" ]] || [[ "${CODESPACES:-}" == "true" ]] || ! [[ -t 0 && -t 1 ]]
}
if is_non_interactive; then
  export CI=true
fi

npm install -g --no-fund --no-audit "@github/copilot@${COPILOT_CLI_VERSION}"
log_ok "GitHub Copilot CLI installed at ${COPILOT_CLI_VERSION}"
