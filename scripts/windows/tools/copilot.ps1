# scripts/windows/tools/copilot.ps1 - GitHub Copilot CLI installer
#
# Owner: Goofy (#2)
# Installs GitHub Copilot CLI (standalone binary via winget)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

function Install-CopilotCli {
    # Accept either the standalone binary (winget) or the legacy gh extension
    if (Get-Command copilot -ErrorAction SilentlyContinue) {
        Write-Ok "GitHub Copilot CLI already installed"
        return
    }
    try {
        $extensions = gh extension list 2>&1
        if ($extensions -match "gh-copilot") {
            Write-Ok "GitHub Copilot CLI (gh extension) already installed"
            return
        }
    } catch {
        Write-Verbose "gh extension check skipped: $_"
    }

    Write-Info "Installing GitHub Copilot CLI..."
    # Mirrors the official install script (https://gh.io/copilot-install) on Windows:
    # on Windows it routes to `winget install GitHub.Copilot` (standalone binary).
    winget install --id GitHub.Copilot --silent --accept-source-agreements --accept-package-agreements
    Refresh-SessionPath
    Write-Ok "Copilot CLI installed"
}
