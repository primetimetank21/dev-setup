#!/usr/bin/env bash
# scripts/linux/tools/auth.sh — GitHub auth check and prompt
#
# Called by: scripts/linux/setup.sh (after gh is installed)
# Idempotent: yes — checks if already authenticated before prompting

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

# Verify gh CLI is available
if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping auth check"
  exit 0
fi

# Check if already authenticated
if gh auth status &>/dev/null; then
  log_ok "GitHub: already authenticated ($(gh api user --jq '.login' 2>/dev/null || echo 'unknown user'))"
  exit 0
fi

# Non-interactive check: CI, Codespaces, or no attached TTY
is_non_interactive() {
  [[ "${CI:-}" == "true" ]] || [[ "${CODESPACES:-}" == "true" ]] || ! [[ -t 0 && -t 1 ]]
}

if is_non_interactive; then
  log_warn "GitHub: not authenticated (non-interactive environment detected)"
  log_warn "Run 'gh auth login' after setup to enable gh CLI and Copilot CLI"
  exit 0
fi

# Interactive: prompt user
log_info "GitHub CLI is installed but not authenticated."
log_info "Launching 'gh auth login'..."
echo ""
gh auth login
echo ""

if gh auth status &>/dev/null; then
  log_ok "GitHub: authenticated successfully"
else
  log_warn "GitHub: authentication may not have completed. Run 'gh auth login' manually."
fi
