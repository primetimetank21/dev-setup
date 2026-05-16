#!/usr/bin/env bash
# scripts/linux/tools/uv.sh — Install uv (Python package manager)
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#5)
# Idempotent: yes — checks if uv is already installed before acting

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

if command -v uv &>/dev/null; then
  log_ok "uv already installed: $(uv --version)"
  exit 0
fi

log_info "Installing uv..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UV_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" uv)"
curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh

# uv installs to ~/.local/bin — ensure it's on PATH in current session
export PATH="$HOME/.local/bin:$PATH"

log_ok "uv installed: $(uv --version)"
