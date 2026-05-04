# scripts/windows/tools/squad-cli.ps1 - squad-cli installer
#
# Owner: Goofy (#2)
# Installs squad-cli globally via npm

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

# install squad-cli globally via npm
function Install-SquadCli {
    if (Get-Command squad -ErrorAction SilentlyContinue) {
        Write-Ok "squad-cli already installed: $(squad --version 2>&1)"
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "npm not found -- skipping squad-cli install"
        return
    }
    Write-Info "Installing squad-cli..."
    npm install -g "@bradygaster/squad-cli"
    Write-Ok "squad-cli installed"
}
