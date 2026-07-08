#!/usr/bin/env bash
# scripts/linux/tools/git-hook.sh -- Configure git hooks
#
# Extracted from the inline git-hook block in scripts/linux/setup.sh main().
# Called by the dispatcher as a normal tool step.
# Self-guards: exits 0 cleanly when git is not present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../lib/log.sh"

if ! command -v git >/dev/null 2>&1; then
  log_warn "git not present -- skipping hooks configuration"
  exit 0
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath hooks
  log_ok "Git hooks configured (core.hooksPath=hooks)"
else
  log_warn "Not inside a git repo -- skipping hooks configuration"
fi
