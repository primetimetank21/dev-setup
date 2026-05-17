# scripts/windows/tools/gh.ps1 - GitHub CLI installer
#
# Owner: Goofy (#2, #255)
# Installs GitHub CLI (gh) at pinned version from .tool-versions.
# Version-aware: upgrades if installed version != pinned version.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-GhCli {
    $GhVersion = Get-ToolVersion -Name 'gh'

    # Detect installed version
    $InstalledVersion = ''
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $raw = (gh --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $GhVersion) {
        Write-Ok "gh already at pinned version $GhVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "gh $InstalledVersion installed; upgrading to pinned $GhVersion..."
    } else {
        Write-Info "Installing GitHub CLI $GhVersion..."
    }

    winget install --id GitHub.cli --version $GhVersion --silent --accept-source-agreements --accept-package-agreements
    Assert-LastExit -ToolName "GitHub CLI" -AllowedExitCodes @(0, -1978335189)
    Refresh-SessionPath
    Write-Ok "gh CLI installed at $GhVersion"
}
