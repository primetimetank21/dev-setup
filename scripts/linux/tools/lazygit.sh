#!/usr/bin/env bash
# scripts/linux/tools/lazygit.sh -- Install lazygit (terminal UI for git) at pinned version
#
# Called by: scripts/linux/setup.sh
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
# Opt-in: NOT in DEFAULT_TOOLS; only runs when requested via --only=lazygit.
#
# macOS: brew install lazygit (warns if brew version differs from pin).
# Linux: downloads the pinned release tarball from GitHub releases.
#   Asset naming: lazygit_<version>_linux_x86_64.tar.gz (no leading v; lowercase os/arch).
#   Binary is at the archive root -- extract and install to ~/.local/bin.
#   Note: Ubuntu PPA lags significantly; tarball is primary for version accuracy.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LG_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" lazygit)"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail

  # Detect installed version
  INSTALLED_VERSION=""
  if command -v lazygit &>/dev/null; then
    INSTALLED_VERSION="$(lazygit --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi

  if [ "${INSTALLED_VERSION}" = "${LG_VERSION}" ]; then
    log_ok "lazygit already at pinned version ${LG_VERSION}"
    exit 0
  fi

  if [ -n "${INSTALLED_VERSION}" ]; then
    log_info "lazygit ${INSTALLED_VERSION} installed; upgrading to pinned ${LG_VERSION}..."
  else
    log_info "Installing lazygit ${LG_VERSION}..."
  fi

  PLATFORM="$(uname -s)"
  if [[ "$PLATFORM" == "Darwin" ]]; then
    # Homebrew: versioned formulae for lazygit are not reliably pinnable.
    if command -v lazygit &>/dev/null; then
      brew upgrade lazygit || true
    else
      brew install lazygit
    fi
    ACTUAL_VERSION="$(lazygit --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
    if [ "${ACTUAL_VERSION}" != "${LG_VERSION}" ]; then
      log_warn "lazygit ${ACTUAL_VERSION} installed (pinned: ${LG_VERSION}); brew cannot guarantee exact version"
    else
      log_ok "lazygit installed at ${LG_VERSION}"
    fi
  else
    # Linux: tarball from GitHub releases (asset names use lowercase os/arch, no leading v).
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64)        ARCH_SUFFIX="x86_64" ;;
      aarch64|arm64) ARCH_SUFFIX="arm64" ;;
      *)             log_error "Unsupported architecture: ${ARCH}"; exit 1 ;;
    esac

    TARBALL="lazygit_${LG_VERSION}_linux_${ARCH_SUFFIX}.tar.gz"
    TARBALL_URL="https://github.com/jesseduffield/lazygit/releases/download/v${LG_VERSION}/${TARBALL}"
    INSTALL_DIR="${HOME}/.local/bin"
    WORK_DIR="${HOME}/.local/share/dev-setup-install/lazygit"

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$WORK_DIR"

    log_info "Downloading ${TARBALL}..."
    curl -fsSL "$TARBALL_URL" -o "${WORK_DIR}/${TARBALL}"
    # Binary is at the archive root (no version-named subdirectory).
    tar -xzf "${WORK_DIR}/${TARBALL}" -C "$WORK_DIR"
    cp "${WORK_DIR}/lazygit" "${INSTALL_DIR}/lazygit"
    chmod +x "${INSTALL_DIR}/lazygit"
    rm -rf "$WORK_DIR"

    log_ok "lazygit ${LG_VERSION} installed to ${INSTALL_DIR}/lazygit"
  fi
fi
