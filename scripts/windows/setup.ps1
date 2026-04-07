# scripts/windows/setup.ps1 — Core Windows installer
#
# Called by: setup.ps1 (root entry point)
# Owner:     Goofy (#2)
#
# Installs developer tools on Windows using winget as the primary package manager.
# Each install function is idempotent — safe to run multiple times.
# Requires: Windows 10 1709+ with App Installer (winget) available.
#
# Usage (direct):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

# Windows has no native zsh. Git for Windows ships Git Bash (MinGW bash),
# which is the practical unix-shell equivalent on Windows.
function Install-GitBash {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git (and Git Bash) already installed: $(git --version)"
        return
    }
    Write-Info "Installing Git for Windows (includes Git Bash)..."
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "Git for Windows installed"
    Write-Info "Git Bash available at: C:\Program Files\Git\bin\bash.exe"
}

function Install-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Ok "uv already installed: $(uv --version)"
        return
    }
    Write-Info "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    Write-Ok "uv installed"
}

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

function Install-GhCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh already installed: $(gh --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "gh CLI installed"
}

function Install-CopilotCli {
    try {
        $extensions = gh extension list 2>&1
        if ($extensions -match "gh-copilot") {
            Write-Ok "GitHub Copilot CLI already installed"
            return
        }
    } catch {
        Write-Warn "gh CLI not authenticated or not found — skipping Copilot CLI install"
        Write-Warn "Run 'gh auth login' then re-run this script to install Copilot CLI"
        return
    }
    Write-Info "Installing GitHub Copilot CLI..."
    gh extension install github/gh-copilot
    Write-Ok "Copilot CLI installed"
}

function Main {
    Write-Info "Starting Windows setup..."
    Write-Info "Checking for winget..."
    if (-not (Test-WingetAvailable)) {
        Write-Err "winget not found. Please install App Installer from the Microsoft Store."
        Write-Err "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1"
        exit 1
    }

    Install-GitBash
    Install-Uv
    Install-Nvm
    Install-GhCli
    Install-CopilotCli

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: nvm install lts && nvm use lts"
    Write-Info "  3. Run: gh auth login"
}

Main
