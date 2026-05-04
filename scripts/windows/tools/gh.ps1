# scripts/windows/tools/gh.ps1 - GitHub CLI installer
#
# Owner: Goofy (#2)
# Installs GitHub CLI (gh)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

function Install-GhCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh already installed: $(gh --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "gh CLI installed"
}
