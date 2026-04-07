#!/usr/bin/env bash
# scripts/linux/tools/auth.sh — GitHub authentication check and prompt
#
# Called by: scripts/linux/setup.sh (after gh is installed)
# Owner:     Donald (#13)
# Idempotent: yes — exits 0 immediately if already authenticated

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }

# Require gh CLI
if ! command -v gh &>/dev/null; then
  log_warn "gh CLI not found — skipping auth check (run gh.sh first)"
  exit 0
fi

# Already authenticated?
if gh auth status &>/dev/null; then
  GH_USER="$(gh api user --jq '.login' 2>/dev/null || echo 'authenticated')"
  log_ok "GitHub: already authenticated as @${GH_USER}"
  exit 0
fi

# Detect non-interactive environments (CI, Codespaces, piped stdin)
is_non_interactive() {
  [[ "${CI:-}" == "true" ]] || [[ "${CODESPACES:-}" == "true" ]] || ! [[ -t 0 && -t 1 ]]
}

if is_non_interactive; then
  log_warn "GitHub: not authenticated (non-interactive environment)"
  log_warn "Run 'gh auth login' after setup to enable gh CLI and Copilot CLI"
  exit 0
fi

# Interactive: prompt user
log_info "GitHub CLI is installed but you're not authenticated."
log_info "Launching 'gh auth login' now..."
echo ""
gh auth login
echo ""

if gh auth status &>/dev/null; then
  GH_USER="$(gh api user --jq '.login' 2>/dev/null || echo 'authenticated')"
  log_ok "GitHub: authenticated as @${GH_USER}"
else
  log_warn "GitHub auth may not have completed. Run 'gh auth login' manually if needed."
fi
