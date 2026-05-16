# scripts/windows/tools/git.ps1 - Git for Windows installer
#
# Owner: Goofy (#2)
# Installs Git for Windows (includes Git Bash - MinGW bash)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

# Windows has no native zsh. Git for Windows ships Git Bash (MinGW bash),
# which is the practical unix-shell equivalent on Windows.
function Install-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git (and Git Bash) already installed: $(git --version)"
        return
    }
    Write-Info "Installing Git for Windows (includes Git Bash)..."
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "Git for Windows installed"
    Write-Info "Git Bash available at: C:\Program Files\Git\bin\bash.exe"
}
