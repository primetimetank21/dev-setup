#!/usr/bin/env bash
# scripts/linux/tools/delta.sh -- Install git-delta (syntax-highlighting git pager) at pinned version
#
# Called by: scripts/linux/setup.sh
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
# Opt-in: NOT in DEFAULT_TOOLS; only runs when requested via --only=delta.
#
# Ubuntu 22.04+: installs via apt-get (git-delta package).
# Older/non-apt Linux: downloads the pinned release tarball from GitHub releases.
# macOS: brew install git-delta (warns if brew version differs from pin).
#
# Defines apply_delta_git_config() for testability.
# Main install block is guarded by BASH_SOURCE/argv0 check so this file can
# be sourced in tests to call apply_delta_git_config in isolation.

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELTA_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" delta)"

apply_delta_git_config() {
  log_info "Applying global git config for delta..."
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.dark true
  # Light-mode override: git config --global delta.dark false
  git config --global merge.conflictStyle zdiff3
  log_ok "delta git config applied (core.pager=delta, dark=true)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail

  # Detect installed version
  INSTALLED_VERSION=""
  if command -v delta &>/dev/null; then
    INSTALLED_VERSION="$(delta --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi

  if [ "${INSTALLED_VERSION}" = "${DELTA_VERSION}" ]; then
    log_ok "git-delta already at pinned version ${DELTA_VERSION}"
    apply_delta_git_config
    exit 0
  fi

  if [ -n "${INSTALLED_VERSION}" ]; then
    log_info "git-delta ${INSTALLED_VERSION} installed; upgrading to pinned ${DELTA_VERSION}..."
  else
    log_info "Installing git-delta ${DELTA_VERSION}..."
  fi

  PLATFORM="$(uname -s)"
  if [[ "$PLATFORM" == "Darwin" ]]; then
    # Homebrew: versioned formulae for git-delta are not reliably pinnable.
    if command -v delta &>/dev/null; then
      brew upgrade git-delta || true
    else
      brew install git-delta
    fi
    ACTUAL_VERSION="$(delta --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
    if [ "${ACTUAL_VERSION}" != "${DELTA_VERSION}" ]; then
      log_warn "git-delta ${ACTUAL_VERSION} installed (pinned: ${DELTA_VERSION}); brew cannot guarantee exact version"
    else
      log_ok "git-delta installed at ${DELTA_VERSION}"
    fi
  else
    # Linux: prefer apt-get (Ubuntu 22.04+), fall back to pinned tarball
    APT_OK=0
    if command -v apt-get &>/dev/null; then
      log_info "Trying apt-get install git-delta..."
      sudo apt-get install -y git-delta 2>/dev/null && APT_OK=1 || APT_OK=0
    fi

    if [ "$APT_OK" -eq 1 ]; then
      ACTUAL_VERSION="$(delta --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
      if [ "${ACTUAL_VERSION}" != "${DELTA_VERSION}" ]; then
        log_warn "apt installed git-delta ${ACTUAL_VERSION} (pinned: ${DELTA_VERSION}); use tarball for exact pin"
      fi
      log_ok "git-delta installed via apt at ${ACTUAL_VERSION}"
    else
      # Tarball: asset name delta-<version>-<arch-triple>.tar.gz
      ARCH="$(uname -m)"
      case "$ARCH" in
        x86_64)        ARCH_TRIPLE="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) ARCH_TRIPLE="aarch64-unknown-linux-gnu" ;;
        *)             log_error "Unsupported architecture: ${ARCH}"; exit 1 ;;
      esac

      TARBALL="delta-${DELTA_VERSION}-${ARCH_TRIPLE}.tar.gz"
      TARBALL_URL="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${TARBALL}"
      INSTALL_DIR="${HOME}/.local/bin"
      WORK_DIR="${HOME}/.local/share/dev-setup-install/delta"

      mkdir -p "$INSTALL_DIR"
      mkdir -p "$WORK_DIR"

      log_info "Downloading ${TARBALL}..."
      curl -fsSL "$TARBALL_URL" -o "${WORK_DIR}/${TARBALL}"
      tar -xzf "${WORK_DIR}/${TARBALL}" -C "$WORK_DIR"
      cp "${WORK_DIR}/delta-${DELTA_VERSION}-${ARCH_TRIPLE}/delta" "${INSTALL_DIR}/delta"
      chmod +x "${INSTALL_DIR}/delta"
      rm -rf "$WORK_DIR"

      log_ok "git-delta ${DELTA_VERSION} installed to ${INSTALL_DIR}/delta"
    fi
  fi

  apply_delta_git_config
fi
