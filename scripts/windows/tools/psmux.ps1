# scripts/windows/tools/psmux.ps1 - psmux (tmux for Windows) installer
#
# Owner: Goofy (#2)
# Installs psmux - terminal multiplexer for Windows PowerShell

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

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
