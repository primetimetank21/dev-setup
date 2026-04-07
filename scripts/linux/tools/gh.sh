#!/usr/bin/env bash
# scripts/linux/tools/gh.sh — Install GitHub CLI (gh)
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald (#6)
# Idempotent: yes — checks if gh is already installed before acting

set -euo pipefail

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

if command -v gh &>/dev/null; then
  log_ok "gh already installed: $(gh --version | head -1)"
  exit 0
fi

PLATFORM="$(uname -s)"
if [[ "$PLATFORM" == "Darwin" ]]; then
  brew install gh
else
  # Linux — use GitHub's official apt repo
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
fi

log_ok "gh installed: $(gh --version | head -1)"
