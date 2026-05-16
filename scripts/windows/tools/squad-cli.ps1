# scripts/windows/tools/squad-cli.ps1 - squad-cli installer
#
# Owner: Goofy (#2)
# Installs squad-cli globally via npm

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

# install squad-cli globally via npm
function Install-SquadCli {
    if (Get-Command squad -ErrorAction SilentlyContinue) {
        Write-Ok "squad-cli already installed: $(squad --version 2>&1)"
        return
    }
    Refresh-SessionPath
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Err "npm not found after nvm install. Possible causes:"
        Write-Err "  1. PATH refresh failed -- close this terminal and open a new one, then re-run setup"
        Write-Err "  2. nvm install failed silently -- check 'nvm list' and try 'nvm install <version>' manually"
        Write-Err "  3. Node is installed elsewhere but not on PATH"
        exit 1
    }
    Write-Info "Installing squad-cli..."
    npm install -g "@bradygaster/squad-cli"
    Assert-LastExit -ToolName "squad-cli"
    Write-Ok "squad-cli installed"
}
