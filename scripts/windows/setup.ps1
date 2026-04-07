# scripts/windows/setup.ps1 — Core Windows installer
#
# Called by: setup.ps1 (root entry point)
# Owner:     Goofy (#2)
#
# This script installs developer tools on Windows using winget and/or scoop.
# Each tool check is idempotent — safe to run multiple times.
#
# Usage (direct):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1
#
# TODO (Goofy): Implement the full installer body below.
#   - Install zsh (via WSL or Git Bash) or PowerShell equivalent
#   - Install uv: https://astral.sh/uv
#   - Install nvm-windows: https://github.com/coreybutler/nvm-windows
#   - Install gh CLI: winget install --id GitHub.cli
#   - Install GitHub Copilot CLI: gh extension install github/gh-copilot
#   - Apply dotfiles from config\dotfiles\ (coordinate with Pluto)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }

function Main {
  Write-Info "Starting Windows setup"

  # TODO (Goofy): Uncomment and implement as each tool is ready
  # Install-Zsh
  # Install-Uv
  # Install-Nvm
  # Install-GhCli
  # Install-CopilotCli

  Write-Ok "Setup complete. Restart your terminal to apply all changes."
}

# TODO (Goofy): Implement each Install-* function here
# Example pattern:
# function Install-GhCli {
#   if (Get-Command gh -ErrorAction SilentlyContinue) {
#     Write-Ok "gh already installed: $(gh --version)"
#     return
#   }
#   Write-Info "Installing gh CLI..."
#   winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
# }

Main
