#!/bin/sh
# scripts/linux/lib/log.sh
# Shared logging helpers (sourced by setup.sh and tool scripts).
# Defines: log_info, log_ok, log_warn, log_error
# Source with: . "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"

log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }
