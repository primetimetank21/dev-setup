#!/usr/bin/env bash
# scripts/linux/tools/herdr.sh -- Install Herdr at pinned version via the official installer
#
# Called by: scripts/linux/setup.sh
# Idempotent: yes -- version-aware; upgrades if installed version != pinned version.
# Opt-in: NOT in DEFAULT_TOOLS; only runs when requested via --only=herdr.
#
# Source basis:
# - Official Unix installer: https://herdr.dev/install.sh
# - Stable release manifest: https://herdr.dev/latest.json
#
# This wrapper keeps dev-setup's version pinning contract by requiring the
# pinned version to match the current stable manifest before running the
# official installer.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERDR_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" herdr)"
MANIFEST_URL="https://herdr.dev/latest.json"
INSTALLER_URL="https://herdr.dev/install.sh"
INSTALL_DIR="${HERDR_INSTALL_DIR:-$HOME/.local/bin}"

INSTALLED_VERSION=""
if command -v herdr &>/dev/null; then
  INSTALLED_VERSION="$(timeout 10 herdr --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

if [ "${INSTALLED_VERSION}" = "${HERDR_VERSION}" ]; then
  log_ok "herdr already at pinned version ${HERDR_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "herdr ${INSTALLED_VERSION} installed; upgrading to pinned ${HERDR_VERSION}..."
else
  log_info "Installing herdr ${HERDR_VERSION}..."
fi

MANIFEST="$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 20 "$MANIFEST_URL")" || {
  log_error "Unable to fetch ${MANIFEST_URL}"
  exit 1
}
MANIFEST_VERSION="$(awk -F '"' '/^[[:space:]]*"version"[[:space:]]*:/ { print $4; found=1 } END { if (!found) exit 1 }' <<EOF
$MANIFEST
EOF
)" || {
  log_error "Could not determine Herdr stable version from ${MANIFEST_URL}"
  exit 1
}
if [ -z "$MANIFEST_VERSION" ]; then
  log_error "Could not determine Herdr stable version from ${MANIFEST_URL}"
  exit 1
fi
if [ "$MANIFEST_VERSION" != "$HERDR_VERSION" ]; then
  log_error "Pinned herdr version ${HERDR_VERSION} does not match current stable manifest version ${MANIFEST_VERSION}"
  log_error "Update .tool-versions to the current stable release before using the official Herdr installer path"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
INSTALLER_PATH="${TMP_DIR}/install.sh"

curl -fsSL "$INSTALLER_URL" -o "$INSTALLER_PATH"
chmod +x "$INSTALLER_PATH"
HERDR_INSTALL_DIR="$INSTALL_DIR" sh "$INSTALLER_PATH"

ACTUAL_VERSION=""
if command -v herdr &>/dev/null; then
  ACTUAL_VERSION="$(timeout 10 herdr --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
elif [ -x "${INSTALL_DIR}/herdr" ]; then
  ACTUAL_VERSION="$(timeout 10 "${INSTALL_DIR}/herdr" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi
if [ "$ACTUAL_VERSION" != "$HERDR_VERSION" ]; then
  log_error "herdr install completed but version check failed (expected ${HERDR_VERSION}, got ${ACTUAL_VERSION:-missing})"
  exit 1
fi

log_ok "herdr installed at ${HERDR_VERSION}"
