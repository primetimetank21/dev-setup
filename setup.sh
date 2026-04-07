#!/usr/bin/env bash
# setup.sh — Entry point for dev-setup on Linux/macOS/WSL
#
# This script detects the operating system and routes to the correct
# platform-specific installer. It does NOT install any tools itself.
#
# Usage:
#   bash setup.sh
#   ./setup.sh        (after: chmod +x setup.sh)
#
# Supported platforms:
#   linux             — native Linux
#   wsl               — Windows Subsystem for Linux (routed as Linux)
#   macos             — macOS (Darwin)
#   windows-compat    — Cygwin/MSYS2/Git Bash (limited support, use setup.ps1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Logging helpers ──────────────────────────────────────────────────────────

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# ── OS Detection ─────────────────────────────────────────────────────────────

detect_os() {
  local os
  os="$(uname -s)"
  case "$os" in
    Linux*)
      # Check for WSL — /proc/version contains "microsoft" in WSL1 and WSL2
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    Darwin*)
      echo "macos"
      ;;
    CYGWIN*|MINGW*|MSYS*)
      # Running in a Unix emulation layer on Windows (Git Bash, MSYS2, Cygwin)
      # setup.ps1 is the correct entry point; this path is a fallback warning only
      echo "windows-compat"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# ── Routing ──────────────────────────────────────────────────────────────────

main() {
  local detected_os
  detected_os="$(detect_os)"

  log_info "dev-setup — entry point"
  log_info "Detected OS: ${detected_os}"

  case "$detected_os" in
    linux)
      log_ok "Platform: Linux"
      run_linux_setup
      ;;
    wsl)
      log_ok "Platform: WSL (running Linux scripts)"
      run_linux_setup
      ;;
    macos)
      log_ok "Platform: macOS"
      run_linux_setup
      ;;
    windows-compat)
      log_warn "Detected a Windows compatibility layer (Cygwin/MSYS2/Git Bash)."
      log_warn "For native Windows, run setup.ps1 in PowerShell instead:"
      log_warn "  powershell -ExecutionPolicy Bypass -File setup.ps1"
      log_warn "Attempting Linux-compatible path — some steps may fail."
      run_linux_setup
      ;;
    unknown)
      log_error "Unrecognised operating system: $(uname -s)"
      log_error "Supported platforms: Linux, macOS, WSL"
      log_error "For Windows, use: powershell -ExecutionPolicy Bypass -File setup.ps1"
      exit 1
      ;;
  esac
}

run_linux_setup() {
  local linux_script="${SCRIPT_DIR}/scripts/linux/setup.sh"

  if [[ ! -f "$linux_script" ]]; then
    log_error "Platform script not found: ${linux_script}"
    log_error "The repository may be incomplete. Please re-clone and try again."
    exit 1
  fi

  if [[ ! -x "$linux_script" ]]; then
    log_warn "${linux_script} is not executable — fixing with chmod +x"
    chmod +x "$linux_script"
  fi

  log_info "Handing off to: scripts/linux/setup.sh"
  exec bash "$linux_script"
}

main "$@"
