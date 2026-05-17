#!/usr/bin/env bash
# scripts/linux/tools/squad-cli.sh -- Install squad-cli globally via npm at pinned version
#
# Called by: scripts/linux/setup.sh
# Owner:     Goofy (#106, #255)
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQUAD_CLI_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" squad-cli)"

# Detect installed version (squad --version may emit a warning on stderr before the version)
INSTALLED_VERSION=""
if command -v squad &>/dev/null; then
  INSTALLED_VERSION="$(squad --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
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
  log_error "npm not found after nvm install. Possible causes:"
  log_error "  1. PATH refresh failed -- close this terminal and open a new one, then re-run setup"
  log_error "  2. nvm install failed silently -- check 'nvm list' and try 'nvm install <version>' manually"
  log_error "  3. Node is installed elsewhere but not on PATH"
  exit 1
fi

npm install -g "@bradygaster/squad-cli@${SQUAD_CLI_VERSION}"
log_ok "squad-cli installed at ${SQUAD_CLI_VERSION}"
