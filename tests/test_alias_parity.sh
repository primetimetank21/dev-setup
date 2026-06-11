#!/usr/bin/env bash
# tests/test_alias_parity.sh -- Alias parity check between Linux and Windows
#
# Extracts alias/function names from:
#   - config/dotfiles/.aliases          (Linux: alias X=..., function X() {...})
#   - scripts/windows/tools/profile.ps1 (Windows: Set-Alias -Name X, function X {...})
#
# Compares the two sets and reports asymmetric differences.
# Test PASSES if sets are equal OR differences are in ALLOWED_ALIAS_DRIFT.
# Test FAILS if there are undocumented differences.
#
# Usage (from repo root):
#   bash tests/test_alias_parity.sh
#
# Exit codes:
#   0 -- all aliases in parity (or drift is documented)
#   1 -- undocumented alias drift detected

set -uo pipefail

# -- Path setup ----------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_ALIASES="$REPO_ROOT/config/dotfiles/.aliases"
WINDOWS_PROFILE="$REPO_ROOT/scripts/windows/tools/profile.ps1"

if [[ ! -f "$LINUX_ALIASES" ]]; then
    echo "ERROR: $LINUX_ALIASES not found." >&2
    exit 1
fi

if [[ ! -f "$WINDOWS_PROFILE" ]]; then
    echo "ERROR: $WINDOWS_PROFILE not found." >&2
    exit 1
fi

# -- Allowed drift -------------------------------------------------------------
# Aliases that intentionally exist on one platform but not the other.
# Format: "alias_name:platform" where platform is "linux" or "windows"
# meaning the alias exists ONLY on that platform.

ALLOWED_ALIAS_DRIFT=(
    "gb:windows"          # git branch shortcut -- Windows only (no Linux equivalent yet)
    "..:linux"            # cd .. -- navigation shortcut, not applicable on Windows
    "...:linux"           # cd ../.. -- navigation shortcut
    "....:linux"          # cd ../../.. -- navigation shortcut
    "~:linux"             # cd ~ -- navigation shortcut
    "-:linux"             # cd - -- navigation shortcut
    "ls:linux"            # ls --color=auto -- ls is not aliased on Windows
    "ll:linux"            # ls -alF -- ls variant
    "la:linux"            # ls -A -- ls variant
    "l:linux"             # ls -CF -- ls variant
    "lh:linux"            # ls -alFh -- ls variant
    "path:linux"          # echo PATH -- Linux-specific
    "reload:linux"        # source ~/.zshrc -- Linux-specific
    "ports:linux"         # ss -tulnp -- Linux-specific
    "vb:linux"            # vim ~/.bashrc -- Linux-specific
    "sb:linux"            # source ~/.bashrc -- Linux-specific
    "vz:linux"            # vim ~/.zshrc -- Linux-specific
    "sz:linux"            # source ~/.zshrc -- Linux-specific
    "vv:linux"            # vim ~/.vimrc -- Linux-specific
    "va:linux"            # vim ~/.aliases -- Linux-specific
    "pip:linux"           # pip3 -- handled differently on Windows
    "dk:linux"            # docker -- not aliased on Windows
    "dkc:linux"           # docker-compose -- not aliased on Windows
    "dkps:linux"          # docker ps -- not aliased on Windows
    "dkpsa:linux"         # docker ps -a -- not aliased on Windows
    "rm:windows"          # Remove-CustomItem -- Windows-specific override
    "touch:windows"       # Set-FileTimestamp -- Windows-specific override
    "start_up:linux"      # shell startup function -- Linux-specific
    "create_tmux:linux"   # tmux session create -- Linux uses tmux directly
    "New-PsmuxSession:windows"  # Windows equivalent of create_tmux
    # v5.2 profile-path resolution helpers (issue #441/#442) -- Windows-only PS
    # internal functions; they query $PROFILE on PS hosts and have no Linux equiv.
    "Invoke-HostQuery:windows"      # Windows-only PS helper: resolves PS host type
    "Resolve-ProfilePath:windows"   # Windows-only PS helper: resolves $PROFILE path
)

# -- Extract Linux aliases -----------------------------------------------------

extract_linux_aliases() {
    local file="$1"
    # Extract alias names: lines matching "alias NAME=..."
    grep -E '^\s*alias\s+' "$file" \
        | sed -E "s/^\s*alias\s+([^=]+)=.*/\1/" \
        | sed 's/^-- //'

    # Extract function names: lines matching "funcname() {"
    grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{' "$file" \
        | sed -E 's/^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\).*/\1/'
}

# -- Extract Windows aliases ---------------------------------------------------

extract_windows_aliases() {
    local file="$1"
    # Extract Set-Alias -Name X names
    grep -iE '^\s*Set-Alias\s+-Name\s+' "$file" \
        | sed -E 's/.*-Name\s+([^ ]+).*/\1/'

    # Extract function names (exclude helper/internal functions)
    # Internal functions: Write-Info, Write-Ok, Write-Warn, Write-Err, Write-PowerShellProfile
    grep -E '^\s*function\s+[A-Za-z]' "$file" \
        | sed -E 's/^\s*function\s+([A-Za-z_][A-Za-z0-9_-]*).*/\1/' \
        | grep -vE '^(Write-Info|Write-Ok|Write-Warn|Write-Err|Write-PowerShellProfile|Remove-CustomItem|Set-FileTimestamp|Get-GitStatus|Invoke-GitCommit|Get-GitBranch|Add-GitFiles|Get-GitLogPretty|Get-GitLog|Invoke-GitFetch|Invoke-GitFetchPrune|Invoke-GitStash|Get-GitStashList|Add-GitAllFiles|Invoke-GitCommitMessage|New-GitBranch|Invoke-GitCheckout|Get-GitDiff|Get-GitDiffStaged|Invoke-GitStashPop|Invoke-GitPush|Invoke-GitPushForce|Invoke-GitPull|Invoke-GitRebase|Invoke-GitRebaseInteractive|Invoke-GitRestore|Invoke-GitRestoreStaged|New-GhPR|Get-GhPRList|Get-GhPRView|Get-GhIssueList|Get-GhIssueView|Invoke-UvRun|Invoke-UvSync|Invoke-NpmInstall|Invoke-NpmRun|Invoke-NpmRunDev|Invoke-NpmRunTest|Invoke-Python|Get-MyIp|Invoke-PingBing|Edit-Profile|Invoke-PsmuxList|Invoke-PsmuxKillServer|Invoke-PsmuxNewSession|Invoke-PsmuxAttach|Invoke-ShutdownNow|Invoke-TimedShutdown|Invoke-CancelTimedShutdown)$'
}

# -- Compare -------------------------------------------------------------------

echo ""
echo ">>> tests/test_alias_parity.sh -- Cross-platform alias parity check"
echo ""

# Get sorted unique alias lists
LINUX_SET=$(extract_linux_aliases "$LINUX_ALIASES" | sort -u)
WINDOWS_SET=$(extract_windows_aliases "$WINDOWS_PROFILE" | sort -u)

echo "Linux aliases found:   $(echo "$LINUX_SET" | wc -l | tr -d ' ')"
echo "Windows aliases found: $(echo "$WINDOWS_SET" | wc -l | tr -d ' ')"
echo ""

# Find differences
LINUX_ONLY=$(comm -23 <(echo "$LINUX_SET") <(echo "$WINDOWS_SET"))
WINDOWS_ONLY=$(comm -13 <(echo "$LINUX_SET") <(echo "$WINDOWS_SET"))

UNDOCUMENTED_DRIFT=0

# Check Linux-only aliases against allowed drift
if [[ -n "$LINUX_ONLY" ]]; then
    echo "Aliases in Linux but not Windows:"
    while IFS= read -r alias_name; do
        [[ -z "$alias_name" ]] && continue
        allowed=false
        for drift in "${ALLOWED_ALIAS_DRIFT[@]}"; do
            drift_name="${drift%%:*}"
            drift_platform="${drift##*:}"
            if [[ "$drift_name" == "$alias_name" && "$drift_platform" == "linux" ]]; then
                allowed=true
                break
            fi
        done
        if $allowed; then
            echo "  [allowed] $alias_name"
        else
            echo "  [UNDOCUMENTED] $alias_name"
            UNDOCUMENTED_DRIFT=$((UNDOCUMENTED_DRIFT + 1))
        fi
    done <<< "$LINUX_ONLY"
    echo ""
fi

# Check Windows-only aliases against allowed drift
if [[ -n "$WINDOWS_ONLY" ]]; then
    echo "Aliases in Windows but not Linux:"
    while IFS= read -r alias_name; do
        [[ -z "$alias_name" ]] && continue
        allowed=false
        for drift in "${ALLOWED_ALIAS_DRIFT[@]}"; do
            drift_name="${drift%%:*}"
            drift_platform="${drift##*:}"
            if [[ "$drift_name" == "$alias_name" && "$drift_platform" == "windows" ]]; then
                allowed=true
                break
            fi
        done
        if $allowed; then
            echo "  [allowed] $alias_name"
        else
            echo "  [UNDOCUMENTED] $alias_name"
            UNDOCUMENTED_DRIFT=$((UNDOCUMENTED_DRIFT + 1))
        fi
    done <<< "$WINDOWS_ONLY"
    echo ""
fi

# -- Result --------------------------------------------------------------------

if [[ "$UNDOCUMENTED_DRIFT" -eq 0 ]]; then
    if [[ -z "$LINUX_ONLY" && -z "$WINDOWS_ONLY" ]]; then
        echo "[PASS] Alias sets are identical across platforms."
    else
        echo "[PASS] All alias differences are documented in ALLOWED_ALIAS_DRIFT."
    fi
    exit 0
else
    echo "[FAIL] $UNDOCUMENTED_DRIFT undocumented alias difference(s) found."
    echo ""
    echo "To fix: either add the alias to both platforms, or document the"
    echo "difference in the ALLOWED_ALIAS_DRIFT list in this test file."
    exit 1
fi
