#!/usr/bin/env bash
# scripts/linux/tools/dotfiles.sh -- Apply dotfiles configuration
#
# Extracted from the inline dotfiles block in scripts/linux/setup.sh main().
# Called by the dispatcher as a normal tool step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../lib/log.sh"

dotfiles_script="${REPO_ROOT}/config/dotfiles/install.sh"

if [[ -f "$dotfiles_script" ]]; then
  log_info "Applying dotfiles..."
  bash "$dotfiles_script" && log_ok "Dotfiles applied"
else
  log_warn "Dotfiles install script not found at ${dotfiles_script} -- skipping"
fi
