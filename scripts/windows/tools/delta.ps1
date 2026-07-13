# scripts/windows/tools/delta.ps1 - git-delta installer
#
# Installs git-delta at pinned version from .tool-versions.
# Opt-in: NOT in $DefaultTools; only runs when requested via -Only 'delta'.
# winget preferred (id dandavison.delta); scoop fallback when winget unavailable.
#
# Defines Set-DeltaGitConfig for testability: applies global git config for
# delta without requiring a full install run.
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Invoke-DeltaGitConfig {
    Write-Info "Applying global git config for delta..."
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global delta.dark true
    # Light-mode override: git config --global delta.dark false
    git config --global merge.conflictStyle zdiff3
    Write-Ok "delta git config applied (core.pager=delta, dark=true)"
}

function Install-Delta {
    $DeltaVersion = Get-ToolVersion -Name 'delta'

    # Detect installed version
    $InstalledVersion = ''
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        $raw = (delta --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $DeltaVersion) {
        Write-Ok "git-delta already at pinned version $DeltaVersion"
        Invoke-DeltaGitConfig
        return
    }

    if ($InstalledVersion) {
        Write-Info "git-delta $InstalledVersion installed; upgrading to pinned $DeltaVersion..."
    } else {
        Write-Info "Installing git-delta $DeltaVersion..."
    }

    # winget preferred; fall back to scoop if winget is unavailable
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id dandavison.delta --version $DeltaVersion --silent `
            --accept-source-agreements --accept-package-agreements
        Assert-LastExit -ToolName "git-delta" -AllowedExitCodes @(0, -1978335189)
        Refresh-SessionPath
        Write-Ok "git-delta installed via winget at $DeltaVersion"
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Info "winget not available; falling back to scoop..."
        scoop install delta
        Assert-LastExit -ToolName "git-delta (scoop)"
        Write-Warn "scoop installed latest delta; version may differ from pinned $DeltaVersion"
    } else {
        Write-Err "Neither winget nor scoop available; cannot install git-delta"
        throw "git-delta install failed: no supported package manager found"
    }

    Invoke-DeltaGitConfig
}
