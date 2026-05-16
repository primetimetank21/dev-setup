# scripts/windows/tools/psmux.ps1 - psmux (tmux for Windows) installer
#
# Owner: Goofy (#2)
# Installs psmux - terminal multiplexer for Windows PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

# psmux - tmux equivalent for Windows PowerShell terminal multiplexer.
function Install-Psmux {
    if (Get-Command psmux -ErrorAction SilentlyContinue) {
        Write-Ok "psmux already installed: $(psmux --version 2>&1)"
        return
    }
    Write-Info "Installing psmux..."
    winget install --id marlocarlo.psmux --accept-source-agreements --accept-package-agreements --silent
    Write-Ok "psmux installed."
}
