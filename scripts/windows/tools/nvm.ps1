# scripts/windows/tools/nvm.ps1 - nvm-windows installer
#
# Owner: Goofy (#2)
# Installs nvm-windows (Node Version Manager for Windows)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

function Install-Nvm {
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        Write-Ok "nvm already installed: $(nvm version)"
        return
    }
    Write-Info "Installing nvm-windows..."
    winget install --id CoreyButler.NVMforWindows --silent --accept-source-agreements --accept-package-agreements
    # Reload PATH so nvm is usable in the current session without restarting
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Ok "nvm-windows installed"
    Write-Warn "Run 'nvm install lts && nvm use lts' in a new terminal to install Node.js"
}
