#!/usr/bin/env bash
# scripts/lint-spawn-prompt.sh
# Checks a coordinator spawn prompt for all 6 mandatory hygiene tail markers.
#
# Usage:
#   bash scripts/lint-spawn-prompt.sh [--file <path>]
#   cat prompt.md | bash scripts/lint-spawn-prompt.sh
#
# Options:
#   --file <path>  Spawn-prompt file to lint (default: stdin)
#
# Exit 0 if all 6 markers are present.
# Exit 1 with a list of missing markers if any are absent.
# Side-effect-free and idempotent.

set -euo pipefail

file_path=''

while [ $# -gt 0 ]; do
    case "$1" in
        --file) file_path="$2"; shift 2 ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Read input
if [ -n "$file_path" ]; then
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path" >&2
        exit 1
    fi
    prompt_text="$(cat "$file_path")"
else
    prompt_text="$(cat)"
fi

# The 6 mandatory hygiene tail markers (in order from spawn-prompt-hygiene.md)
markers=(
    'CWD-pin -- before every file write'
    'base=develop discipline'
    'ASCII discipline -- after every file write'
    'history.md pre-size-check -- before every append'
    'Worktree-remove-FIRST cleanup -- after PR merges'
    'Hygiene tail completion'
)

missing=()
for marker in "${markers[@]}"; do
    if ! printf '%s' "$prompt_text" | grep -qF "$marker"; then
        missing+=("$marker")
    fi
done

if [ ${#missing[@]} -eq 0 ]; then
    echo "OK: All 6 hygiene tail markers present."
    exit 0
else
    echo "FAIL: Missing ${#missing[@]} of 6 hygiene tail markers:" >&2
    for m in "${missing[@]}"; do
        echo "  - $m" >&2
    done
    echo "" >&2
    echo "Run scripts/squad-spawn.sh to assemble prompts with the hygiene tail auto-injected." >&2
    exit 1
fi
