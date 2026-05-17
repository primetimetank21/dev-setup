# scripts/windows/tools/squad-cli.ps1 - squad-cli installer
#
# Owner: Goofy (#2, #255)
# Installs squad-cli globally via npm at pinned version from .tool-versions.
# Version-aware: upgrades if installed version != pinned version.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-SquadCli {
    $SquadCliVersion = Get-ToolVersion -Name 'squad-cli'

    # Detect installed version (squad --version may emit a warning before the semver)
    $InstalledVersion = ''
    if (Get-Command squad -ErrorAction SilentlyContinue) {
        $raw = (squad --version 2>&1) | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $SquadCliVersion) {
        Write-Ok "squad-cli already at pinned version $SquadCliVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "squad-cli $InstalledVersion installed; upgrading to pinned $SquadCliVersion..."
    } else {
        Write-Info "Installing squad-cli $SquadCliVersion..."
    }

    Refresh-SessionPath
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Err "npm not found after nvm install. Possible causes:"
        Write-Err "  1. PATH refresh failed -- close this terminal and open a new one, then re-run setup"
        Write-Err "  2. nvm install failed silently -- check 'nvm list' and try 'nvm install <version>' manually"
        Write-Err "  3. Node is installed elsewhere but not on PATH"
        exit 1
    }
    npm install -g "@bradygaster/squad-cli@$SquadCliVersion"
    Assert-LastExit -ToolName "squad-cli"
    Write-Ok "squad-cli installed at $SquadCliVersion"
}
