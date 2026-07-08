#!/usr/bin/env bash
# scripts/dev/regenerate-baseline-fixtures.sh
#
# Extracts DEFAULT_TOOLS arrays from source scripts and (re)writes the
# committed baseline fixture files, OR checks that the fixture files match.
#
# Usage:
#   bash scripts/dev/regenerate-baseline-fixtures.sh           # regenerate
#   bash scripts/dev/regenerate-baseline-fixtures.sh --check   # check only (never writes)
#
# The fixture files are the single source of truth for T_baseline_real_defaults.
# DO NOT run this script automatically during implementation -- fixtures are
# hand-verified and committed; the script is for post-refactor maintenance.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINUX_FIXTURE="${REPO_ROOT}/tests/fixtures/baseline-tools-linux.txt"
WIN_FIXTURE="${REPO_ROOT}/tests/fixtures/baseline-tools-windows.txt"
LINUX_SETUP="${REPO_ROOT}/scripts/linux/setup.sh"
WIN_SETUP="${REPO_ROOT}/scripts/windows/setup.ps1"

# Extract Linux DEFAULT_TOOLS from source (bash array literal)
extract_linux() {
  awk '/^DEFAULT_TOOLS=\(/{found=1; next} found && /^\)/{found=0} found{gsub(/[" \t]/, ""); if(length($0)>0) print}' "$LINUX_SETUP"
}

# Extract Windows $DefaultTools from source (PS array literal, single-quoted entries)
extract_windows() {
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command "
      \$content = Get-Content '$WIN_SETUP' -Raw
      if (\$content -match '(?s)\\\$DefaultTools\s*=\s*@\((.*?)\)') {
        \$block = \$Matches[1]
        \$block.Split([char[]]@([char]13,[char]10)) |
          ForEach-Object { \$_.Trim().Trim(\"'\").Trim('\"') } |
          Where-Object { \$_ -and \$_ -notmatch '^#' }
      }
    "
  elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "
      \$content = Get-Content '$WIN_SETUP' -Raw
      if (\$content -match '(?s)\\\$DefaultTools\s*=\s*@\((.*?)\)') {
        \$block = \$Matches[1]
        \$block.Split([char[]]@([char]13,[char]10)) |
          ForEach-Object { \$_.Trim().Trim(\"'\").Trim('\"') } |
          Where-Object { \$_ -and \$_ -notmatch '^#' }
      }
    "
  else
    echo "ERROR: pwsh/powershell not found -- cannot extract Windows defaults" >&2
    exit 1
  fi
}

MODE="${1:-}"

if [[ "$MODE" == "--check" ]]; then
  rc=0
  linux_actual="$(extract_linux)"
  win_actual="$(extract_windows)"

  if ! diff <(cat "$LINUX_FIXTURE") <(printf '%s\n' "$linux_actual") >/dev/null 2>&1; then
    echo "DRIFT: Linux DEFAULT_TOOLS does not match fixture."
    echo "  Fixture: $LINUX_FIXTURE"
    echo "  Run: bash scripts/dev/regenerate-baseline-fixtures.sh"
    diff <(cat "$LINUX_FIXTURE") <(printf '%s\n' "$linux_actual") || true
    rc=1
  fi

  if ! diff <(cat "$WIN_FIXTURE") <(printf '%s\n' "$win_actual") >/dev/null 2>&1; then
    echo "DRIFT: Windows \$DefaultTools does not match fixture."
    echo "  Fixture: $WIN_FIXTURE"
    echo "  Run: bash scripts/dev/regenerate-baseline-fixtures.sh"
    diff <(cat "$WIN_FIXTURE") <(printf '%s\n' "$win_actual") || true
    rc=1
  fi

  if [[ $rc -eq 0 ]]; then
    echo "OK: baseline fixtures match source arrays."
  fi
  exit $rc
fi

# Regenerate mode: extract and write
extract_linux | tee "$LINUX_FIXTURE"
extract_windows | tee "$WIN_FIXTURE"
echo "Fixtures regenerated. Review diff and commit if intentional."
