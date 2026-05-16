#!/usr/bin/env sh
# scripts/lib/read-tool-version.sh -- read a pinned version from .tool-versions
#
# Usage: sh scripts/lib/read-tool-version.sh <tool-name>
# Prints the version string to stdout. Exits non-zero if tool not found.

set -e

if [ -z "${1:-}" ]; then
    echo "Usage: read-tool-version.sh <tool-name>" >&2
    exit 1
fi

TOOL_NAME="$1"

# Walk up from this script to repo root (two levels: lib/ -> scripts/ -> repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TOOL_VERSIONS_FILE="${REPO_ROOT}/.tool-versions"

if [ ! -f "$TOOL_VERSIONS_FILE" ]; then
    echo "Error: .tool-versions not found at ${TOOL_VERSIONS_FILE}" >&2
    exit 1
fi

VERSION=""
while IFS= read -r line || [ -n "$line" ]; do
    # Skip blank lines and comments
    case "$line" in
        ''|'#'*) continue ;;
    esac
    # Parse "toolname version"
    name="${line%% *}"
    ver="${line#* }"
    if [ "$name" = "$TOOL_NAME" ]; then
        VERSION="$ver"
        break
    fi
done < "$TOOL_VERSIONS_FILE"

if [ -z "$VERSION" ]; then
    echo "Error: tool '${TOOL_NAME}' not found in .tool-versions" >&2
    exit 1
fi

printf '%s' "$VERSION"
