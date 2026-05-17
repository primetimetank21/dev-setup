# scripts/windows/tools/auth.ps1 - GitHub authentication check and prompt
#
# Called by: scripts/windows/setup.ps1 (after gh CLI is installed)
# Owner:     Goofy (#2)
# Idempotent: yes - exits cleanly if already authenticated
#
# Mirrors scripts/linux/tools/auth.sh behavior:
#   1. If gh not on PATH, warn and return (non-fatal)
#   2. If already authenticated, report user and return
#   3. If non-interactive, warn and return
#   4. Otherwise launch gh auth login interactively

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

function Invoke-GhAuth {
    # Guard: gh CLI must be available
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warn 'gh CLI not found -- skipping auth check (install gh first)'
        return
    }

    # Already authenticated?
    $isAuthed = $false
    try {
        $null = & gh auth status 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { $isAuthed = $true }
    } catch {
        # gh auth status failed - not authenticated
    }
    $global:LASTEXITCODE = 0
    if ($isAuthed) {
        $ghUser = 'authenticated'
        try {
            $apiOut = & gh api user --jq '.login' 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $apiOut) {
                $ghUser = $apiOut.Trim()
            }
        } catch {
            # ignore - fall back to generic message
        }
        $global:LASTEXITCODE = 0
        Write-Ok "GitHub: already authenticated as @$ghUser"
        return
    }

    # Detect non-interactive environments
    $nonInteractive = $false
    if ($env:CI -eq 'true') { $nonInteractive = $true }
    if ($env:CODESPACES -eq 'true') { $nonInteractive = $true }
    if (-not [Environment]::UserInteractive) { $nonInteractive = $true }

    if ($nonInteractive) {
        Write-Warn 'GitHub: not authenticated (non-interactive environment)'
        Write-Warn "Run 'gh auth login' after setup to enable gh CLI and Copilot CLI"
        return
    }

    # Interactive: launch auth flow
    Write-Info 'GitHub CLI is installed but you are not authenticated.'
    Write-Info "Launching 'gh auth login' now..."
    Write-Host ''
    try {
        gh auth login --hostname github.com --git-protocol https --web
    } catch {
        Write-Warn "gh auth login encountered an error: $_"
    }
    Write-Host ''

    # Verify result
    $loginOk = $false
    try {
        $null = & gh auth status 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { $loginOk = $true }
    } catch {
        # auth status failed
    }
    $global:LASTEXITCODE = 0
    if ($loginOk) {
        $ghUser = 'authenticated'
        try {
            $apiOut = & gh api user --jq '.login' 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $apiOut) {
                $ghUser = $apiOut.Trim()
            }
        } catch {
            # ignore
        }
        $global:LASTEXITCODE = 0
        Write-Ok "GitHub: authenticated as @$ghUser"
    } else {
        Write-Warn "GitHub auth may not have completed. Run 'gh auth login' manually if needed."
    }
}
