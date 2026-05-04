# scripts/windows/setup.ps1 - Core Windows installer orchestrator
#
# Called by: setup.ps1 (root entry point)
# Owner:     Goofy (#2)
#
# Orchestrates developer tool installation on Windows by delegating to per-tool scripts.
# Each tool installer is idempotent - safe to run multiple times.
# Requires: Windows 10 1709+ with App Installer (winget) available.
#
# Usage (direct):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

# Dot-source tool installer modules
. "$PSScriptRoot\tools\git.ps1"
. "$PSScriptRoot\tools\uv.ps1"
. "$PSScriptRoot\tools\nvm.ps1"
. "$PSScriptRoot\tools\gh.ps1"
. "$PSScriptRoot\tools\vim.ps1"
. "$PSScriptRoot\tools\psmux.ps1"
. "$PSScriptRoot\tools\copilot.ps1"
. "$PSScriptRoot\tools\squad-cli.ps1"
. "$PSScriptRoot\tools\profile.ps1"

function Install-GitHook {
    Write-Info "Configuring git hooks..."
    & git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git config core.hooksPath hooks
        Write-Ok "Git hooks configured (core.hooksPath=hooks)"
    } else {
        Write-Warn "Not inside a git repo - skipping hooks config"
    }
}

function Main {
    Write-Info "Starting Windows setup..."
    Write-Info "Checking for winget..."
    if (-not (Test-WingetAvailable)) {
        Write-Err "winget not found. Please install App Installer from the Microsoft Store."
        Write-Err "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1"
        exit 1
    }

    Install-Git
    Install-Uv
    Install-Nvm
    Install-GhCli
    Install-Vim
    Install-Psmux
    Install-CopilotCli
    Install-SquadCli
    Write-PowerShellProfile
    Install-GitHook

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: nvm install lts && nvm use lts"
    Write-Info "  3. Run: gh auth login"
}

Main
