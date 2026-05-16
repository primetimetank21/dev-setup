# scripts/windows/tools/gh.ps1 - GitHub CLI installer
#
# Owner: Goofy (#2)
# Installs GitHub CLI (gh)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

function Install-GhCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh already installed: $(gh --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    Assert-LastExit -ToolName "GitHub CLI" -AllowedExitCodes @(0, -1978335189)
    Refresh-SessionPath
    Write-Ok "gh CLI installed"
}
