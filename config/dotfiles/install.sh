#!/usr/bin/env bash
# config/dotfiles/install.sh
#
# Idempotent dotfile installer.
# - Copies .gitconfig.template  → $HOME/.gitconfig  (with backup if needed)
# - Copies .npmrc.template      → $HOME/.npmrc
# - Symlinks .editorconfig      → $HOME/.editorconfig
# - Symlinks .aliases           → $HOME/.aliases
# - Copies .zshrc.template      → $HOME/.zshrc  (fresh install only)
#   OR appends dev-setup managed block to existing $HOME/.zshrc
# - Appends dev-setup managed block to existing $HOME/.bashrc
#
# Usage:
#   ./config/dotfiles/install.sh            # install for real
#   ./config/dotfiles/install.sh --dry-run  # show what would happen
#
# Env vars honoured at install time (substituted into .gitconfig):
#   GIT_AUTHOR_NAME        → replaces YOUR_NAME
#   GIT_AUTHOR_EMAIL       → replaces YOUR_EMAIL
#   GIT_AUTHOR_SIGNING_KEY → replaces YOUR_SIGNING_KEY (and uncomments the line)

set -euo pipefail

# ── Resolve the directory containing this script ────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colour helpers ───────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok()   { printf "${GREEN}✓ %s${RESET}\n" "$*"; }
skip() { printf "${CYAN}→ Already installed: %s${RESET}\n" "$*"; }
info() { printf "${YELLOW}  %s${RESET}\n" "$*"; }
dry()  { printf "${YELLOW}[dry-run] %s${RESET}\n" "$*"; }

# ── Parse flags ──────────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) printf "Unknown argument: %s\n" "$arg" >&2; exit 1 ;;
  esac
done

# ── Helper: copy a template file, skipping if destination already matches ───
# Usage: install_copy <src> <dest> [<label>]
install_copy() {
  local src="$1"
  local dest="$2"
  local label="${3:-$(basename "$dest")}"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$dest" ]]; then
      dry "Would back up existing $dest → ${dest}.bak and overwrite with $src"
    else
      dry "Would copy $src → $dest"
    fi
    return
  fi

  if [[ -f "$dest" ]]; then
    # Only back up if the destination is not already this template
    if ! diff -q "$src" "$dest" > /dev/null 2>&1; then
      cp "$dest" "${dest}.bak"
      info "Backed up existing $dest → ${dest}.bak"
      cp "$src" "$dest"
      ok "Installed $label"
    else
      skip "$label"
    fi
  else
    cp "$src" "$dest"
    ok "Installed $label"
  fi
}

# ── Helper: append managed block to a shell rc file if not already present ───
# Usage: append_managed_block <dest> <block> [<label>]
append_managed_block() {
  local dest="$1"
  local block="$2"
  local label="${3:-$(basename "$dest")}"
  local marker="# --- dev-setup managed block"

  if [[ "$DRY_RUN" == true ]]; then
    if grep -qF "$marker" "$dest" 2>/dev/null; then
      dry "$label (dev-setup block already present — would skip)"
    else
      dry "Would append dev-setup block to $label"
    fi
    return
  fi

  if grep -qF "$marker" "$dest" 2>/dev/null; then
    skip "$label (dev-setup block already present)"
    return
  fi

  printf '\n%s\n' "$block" >> "$dest"
  ok "Appended dev-setup block to $label"
}

# ── Helper: create a symlink, skipping if it already points to the right file
# Usage: install_symlink <target> <link_path> [<label>]
install_symlink() {
  local target="$1"
  local link="$2"
  local label="${3:-$(basename "$link")}"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "$target" ]]; then
      dry "Symlink already correct: $link → $target"
    else
      dry "Would create symlink: $link → $target"
    fi
    return
  fi

  if [[ -L "$link" ]]; then
    if [[ "$(readlink "$link")" == "$target" ]]; then
      skip "$label"
      return
    fi
    # Symlink exists but points somewhere else — replace it
    rm "$link"
  elif [[ -e "$link" ]]; then
    # Regular file in the way — back it up
    cp "$link" "${link}.bak"
    info "Backed up existing $link → ${link}.bak"
    rm "$link"
  fi

  ln -s "$target" "$link"
  ok "Linked $label"
}

# ── Substitute placeholders in $HOME/.gitconfig ─────────────────────────────
substitute_gitconfig() {
  local gitconfig="$HOME/.gitconfig"
  [[ -f "$gitconfig" ]] || return

  local changed=false

  if [[ -n "${GIT_AUTHOR_NAME:-}" ]]; then
    sed -i "s/YOUR_NAME/${GIT_AUTHOR_NAME}/g" "$gitconfig"
    changed=true
  fi

  if [[ -n "${GIT_AUTHOR_EMAIL:-}" ]]; then
    sed -i "s/YOUR_EMAIL/${GIT_AUTHOR_EMAIL}/g" "$gitconfig"
    changed=true
  fi

  if [[ -n "${GIT_AUTHOR_SIGNING_KEY:-}" ]]; then
    # Replace placeholder and uncomment the signingkey line in one pass
    sed -i \
      -e "s/YOUR_SIGNING_KEY/${GIT_AUTHOR_SIGNING_KEY}/g" \
      -e "s/^[[:space:]]*#[[:space:]]*\(signingkey = \)/\t\1/" \
      "$gitconfig"
    changed=true
  fi

  if [[ "$changed" == true ]]; then
    info "Substituted env vars into $gitconfig"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
printf "\n${CYAN}Installing dotfiles from %s${RESET}\n\n" "$DOTFILES_DIR"

# .gitconfig — copy so users can edit without touching the repo template
install_copy \
  "$DOTFILES_DIR/.gitconfig.template" \
  "$HOME/.gitconfig" \
  ".gitconfig"

# Substitute env var placeholders after copying (no-op if vars unset)
if [[ "$DRY_RUN" == false ]]; then
  substitute_gitconfig
fi

# .npmrc — copy for the same reason
install_copy \
  "$DOTFILES_DIR/.npmrc.template" \
  "$HOME/.npmrc" \
  ".npmrc"

# .editorconfig — symlink because users rarely need machine-specific overrides
install_symlink \
  "$DOTFILES_DIR/.editorconfig" \
  "$HOME/.editorconfig" \
  ".editorconfig"

# .aliases — symlink so updates to the repo are reflected immediately
install_symlink \
  "$DOTFILES_DIR/.aliases" \
  "$HOME/.aliases" \
  ".aliases"

# .vimrc — symlink so updates to the repo are reflected immediately
install_symlink \
  "$DOTFILES_DIR/.vimrc" \
  "$HOME/.vimrc" \
  ".vimrc"

# .zshrc — copy template on fresh install; append managed block to existing file
ZSHRC_MANAGED_BLOCK='# --- dev-setup managed block (do not edit) ---
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
# --- end dev-setup managed block ---'

if [[ -f "$HOME/.zshrc" ]]; then
  append_managed_block "$HOME/.zshrc" "$ZSHRC_MANAGED_BLOCK" ".zshrc"
else
  if [[ "$DRY_RUN" == true ]]; then
    dry "Would copy .zshrc.template → $HOME/.zshrc"
  else
    cp "$DOTFILES_DIR/.zshrc.template" "$HOME/.zshrc"
    ok "Installed .zshrc from template"
  fi
fi

# .bashrc — append managed block if file exists (nvm PATH already appended by nvm installer)
BASHRC_MANAGED_BLOCK='# --- dev-setup managed block (do not edit) ---
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
# --- end dev-setup managed block ---'

if [[ -f "$HOME/.bashrc" ]]; then
  append_managed_block "$HOME/.bashrc" "$BASHRC_MANAGED_BLOCK" ".bashrc"
fi

printf "\n${GREEN}Done.${RESET}\n\n"
