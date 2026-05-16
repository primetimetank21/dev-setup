#!/usr/bin/env bash
# scripts/linux/uninstall.sh
#
# Idempotent uninstaller for dev-setup.
# - Restores dotfile .bak files created by config/dotfiles/install.sh
# - Removes dev-setup managed blocks from ~/.zshrc and ~/.bashrc
# - Does NOT remove installed tools (uv, nvm, gh, vim, copilot, etc.)
#
# Usage:
#   ./scripts/linux/uninstall.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/log.sh"

# ── Restore dotfile .bak files ───────────────────────────────────────────────
# Restores the newest timestamped backup (.bak.YYYYMMDD-HHMMSS).
# That is the state just before the most recent install run.
# To recover the original-original, use the oldest .bak.* file manually.
restore_backup() {
  local target="$1"
  # Prefer newest timestamped backup; fall back to legacy .bak
  local newest
  # shellcheck disable=SC2012
  newest=$(ls -t "${target}.bak."* 2>/dev/null | head -n 1) || newest=''
  if [[ -n "$newest" ]]; then
    mv "$newest" "$target"
    log_ok "Restored $target from $(basename "$newest")"
  elif [[ -f "${target}.bak" ]]; then
    mv "${target}.bak" "$target"
    log_ok "Restored $target from ${target}.bak (legacy)"
  else
    log_warn "No backup found for $target"
  fi
}

printf '\ndev-setup uninstaller\n\n'

# Dotfiles that install.sh may have backed up
DOTFILES=(
  "$HOME/.gitconfig"
  "$HOME/.npmrc"
  "$HOME/.editorconfig"
  "$HOME/.aliases"
  "$HOME/.vimrc"
)

for dotfile in "${DOTFILES[@]}"; do
  restore_backup "$dotfile"
done

# ── Remove managed blocks from shell rc files ────────────────────────────────
remove_managed_block() {
  local file="$1"
  local begin_marker="# --- dev-setup managed block (do not edit) ---"
  local end_marker="# --- end dev-setup managed block ---"

  if [[ ! -f "$file" ]]; then
    log_warn "$file does not exist"
    return
  fi

  if ! grep -qF "$begin_marker" "$file"; then
    log_warn "No dev-setup block in $file"
    return
  fi

  # Remove the managed block (inclusive of markers) and any leading blank line
  sed -i.tmp "/$begin_marker/,/$end_marker/d" "$file"
  # Clean up the temp file sed creates with -i
  rm -f "${file}.tmp"

  log_ok "Removed dev-setup block from $file"
}

remove_managed_block "$HOME/.zshrc"
remove_managed_block "$HOME/.bashrc"

# ── Unset core.hooksPath ─────────────────────────────────────────────────────
git config --unset-all core.hooksPath 2>/dev/null || true
log_ok "core.hooksPath unset (git falls back to per-repo .git/hooks)"

# ── Summary ──────────────────────────────────────────────────────────────────
printf '\n'; log_ok "Uninstalled. Tools (uv, nvm, gh, etc.) remain. Remove them manually if you wish."; printf '\n'
