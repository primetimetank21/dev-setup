#!/usr/bin/env bash
# scripts/linux/tools/uv.sh — Install uv (Python package manager)
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#5)
# Idempotent: yes — checks if uv is already installed before acting

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

if command -v uv &>/dev/null; then
  log_ok "uv already installed: $(uv --version)"
  exit 0
fi

log_info "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# uv installs to ~/.local/bin — ensure it's on PATH in current session
export PATH="$HOME/.local/bin:$PATH"

log_ok "uv installed: $(uv --version)"
