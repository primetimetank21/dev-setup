# scripts/windows/tools/pi.ps1 - pi CLI installer
#
# Installs pi globally via npm at pinned version from .tool-versions.
# Version-aware: upgrades if installed version != pinned version.
# Package: @earendil-works/pi-coding-agent

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-Pi {
    $PiVersion = Get-ToolVersion -Name 'pi'
    $PiPackage = '@earendil-works/pi-coding-agent'

    # Detect installed version
    $InstalledVersion = ''
    if (Get-Command pi -ErrorAction SilentlyContinue) {
        $raw = (pi --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $PiVersion) {
        Write-Ok "pi already at pinned version $PiVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "pi $InstalledVersion installed; upgrading to pinned $PiVersion..."
    } else {
        Write-Info "Installing pi $PiVersion..."
    }

    Refresh-SessionPath
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "npm not found -- cannot install pi via npm; run 'npm install -g --ignore-scripts `"$PiPackage@$PiVersion`"' once Node is available"
        return
    }

    npm install -g --no-fund --no-audit --ignore-scripts "$PiPackage@$PiVersion"
    Assert-LastExit -ToolName 'pi'
    Write-Ok "pi installed at $PiVersion"
}
