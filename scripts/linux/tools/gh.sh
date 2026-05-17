#!/usr/bin/env bash
# scripts/linux/tools/gh.sh -- Install GitHub CLI (gh) at pinned version
#
# Called by: scripts/linux/setup.sh
# Owner:     Donald / Goofy (#255)
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
#
# Linux: downloads the pinned release tarball from GitHub releases (reliable
# cross-distro version pinning; no apt package suffix guessing required).
# macOS: brew install gh (brew does not publish versioned gh formulae; logs WARN
# if installed version differs from pin).

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" gh)"

# Detect installed version
INSTALLED_VERSION=""
if command -v gh &>/dev/null; then
  INSTALLED_VERSION="$(gh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

if [ "${INSTALLED_VERSION}" = "${GH_VERSION}" ]; then
  log_ok "gh already at pinned version ${GH_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "gh ${INSTALLED_VERSION} installed; upgrading to pinned ${GH_VERSION}..."
else
  log_info "Installing GitHub CLI ${GH_VERSION}..."
fi

PLATFORM="$(uname -s)"
if [[ "$PLATFORM" == "Darwin" ]]; then
  # Homebrew does not publish versioned formulae for gh.
  # Install/upgrade to latest and warn if it differs from the pin.
  log_warn "macOS/brew: versioned formulae for gh are not reliably available; installing latest"
  if command -v gh &>/dev/null; then
    brew upgrade gh || true
  else
    brew install gh
  fi
  ACTUAL_VERSION="$(gh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
  if [ "${ACTUAL_VERSION}" != "${GH_VERSION}" ]; then
    log_warn "gh ${ACTUAL_VERSION} installed (pinned: ${GH_VERSION}); brew cannot guarantee exact version"
  else
    log_ok "gh installed at ${GH_VERSION}"
  fi
else
  # Linux: download pinned release tarball from GitHub releases
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)        ARCH_SUFFIX="amd64" ;;
    aarch64|arm64) ARCH_SUFFIX="arm64" ;;
    *)             log_error "Unsupported architecture: ${ARCH}"; exit 1 ;;
  esac

  TARBALL="gh_${GH_VERSION}_linux_${ARCH_SUFFIX}.tar.gz"
  TARBALL_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${TARBALL}"
  INSTALL_DIR="${HOME}/.local/bin"
  WORK_DIR="${HOME}/.local/share/dev-setup-install/gh"

  mkdir -p "$INSTALL_DIR"
  mkdir -p "$WORK_DIR"

  log_info "Downloading ${TARBALL}..."
  curl -fsSL "$TARBALL_URL" -o "${WORK_DIR}/${TARBALL}"
  tar -xzf "${WORK_DIR}/${TARBALL}" -C "$WORK_DIR"
  cp "${WORK_DIR}/gh_${GH_VERSION}_linux_${ARCH_SUFFIX}/bin/gh" "${INSTALL_DIR}/gh"
  chmod +x "${INSTALL_DIR}/gh"
  rm -rf "$WORK_DIR"

  log_ok "gh ${GH_VERSION} installed to ${INSTALL_DIR}/gh"
fi
