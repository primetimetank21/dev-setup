# scripts/windows/setup.ps1 - Core Windows installer
#
# Called by: setup.ps1 (root entry point)
# Owner:     Goofy (#2)
#
# Installs developer tools on Windows using winget as the primary package manager.
# Each install function is idempotent - safe to run multiple times.
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
    } catch { }

    Write-Info "Installing GitHub Copilot CLI..."
    # Mirrors the official install script (https://gh.io/copilot-install) on Windows:
    # on Windows it routes to `winget install GitHub.Copilot` (standalone binary).
    winget install --id GitHub.Copilot --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "Copilot CLI installed"
}

function Write-PowerShellProfile {
    $sentinel = '# BEGIN dev-setup profile'

    # Idempotency check - skip if already written
    if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern ([regex]::Escape($sentinel)) -Quiet)) {
        Write-Ok "PowerShell profile shortcuts already installed"
        return
    }

    $profileContent = @'
# BEGIN dev-setup profile
# -- Linux-compatible commands --------------------------------------------------

function Remove-CustomItem {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )
    Remove-Item -Path $Path -Recurse -Force
}
Remove-Item -Force Alias:\rm -ErrorAction SilentlyContinue
Set-Alias -Name rm -Value Remove-CustomItem

function Set-FileTimestamp {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}
Set-Alias -Name touch -Value Set-FileTimestamp

# -- Git shortcuts --------------------------------------------------------------

function Get-GitStatus { git status $args }
Set-Alias -Name gs -Value Get-GitStatus

function Invoke-GitCommit { git commit $args }
Remove-Item -Force Alias:\gc -ErrorAction SilentlyContinue
Set-Alias -Name gc -Value Invoke-GitCommit

function Get-GitBranch { git branch $args }
Set-Alias -Name gb -Value Get-GitBranch

function Add-GitFiles { git add $args }
Set-Alias -Name ga -Value Add-GitFiles

function Get-GitLogPretty { git log --graph --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' $args }
Remove-Item -Force Alias:\gl -ErrorAction SilentlyContinue
Set-Alias -Name gl -Value Get-GitLogPretty

function Get-GitLog { git log $args }
Set-Alias -Name glog -Value Get-GitLog

function Invoke-GitFetch { git fetch $args }
Set-Alias -Name gf -Value Invoke-GitFetch

function Invoke-GitFetchPrune { git fetch --prune $args }
Set-Alias -Name gfp -Value Invoke-GitFetchPrune

function Invoke-GitStash { git stash $args }
Set-Alias -Name ggs -Value Invoke-GitStash

function Get-GitStashList { git stash list $args }
Set-Alias -Name ggsls -Value Get-GitStashList

# END dev-setup profile
'@

    # Ensure profile directory exists
    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Append to profile (create if absent).
    # Always prepend a blank line so we don't concatenate onto any existing last line.
    if (Test-Path $PROFILE) {
        Add-Content -Path $PROFILE -Value ""
    }
    Add-Content -Path $PROFILE -Value $profileContent
    Write-Ok "PowerShell profile shortcuts installed to $PROFILE"
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
    Write-PowerShellProfile

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: nvm install lts && nvm use lts"
    Write-Info "  3. Run: gh auth login"
}

Main
