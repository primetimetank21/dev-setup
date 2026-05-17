# scripts/windows/tools/copilot.ps1 - GitHub Copilot CLI installer
#
# Owner: Goofy (#2, #255)
# Installs GitHub Copilot CLI at pinned version from .tool-versions via npm.
# Version-aware: upgrades if installed version != pinned version.
# Package: @github/copilot (modern, active). Do NOT use @githubnext/github-copilot-cli (deprecated).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-CopilotCli {
    $CopilotCliVersion = Get-ToolVersion -Name 'copilot-cli'

    # Detect installed version; binary may emit warnings to stderr before the semver
    $InstalledVersion = ''
    if (Get-Command copilot -ErrorAction SilentlyContinue) {
        $raw = (copilot --version 2>&1) | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    } else {
        try {
            $extensions = gh extension list 2>&1
            if ($extensions -match "gh-copilot") {
                Write-Ok "GitHub Copilot CLI (gh extension) already installed"
                return
            }
        } catch {
            Write-Verbose "gh extension check skipped: $_"
        }
    }

    if ($InstalledVersion -eq $CopilotCliVersion) {
        Write-Ok "GitHub Copilot CLI already at pinned version $CopilotCliVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "Copilot CLI $InstalledVersion installed; upgrading to pinned $CopilotCliVersion..."
    } else {
        Write-Info "Installing GitHub Copilot CLI $CopilotCliVersion..."
    }

    Refresh-SessionPath
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "npm not found -- cannot install copilot-cli via npm; run 'npm install -g `"@github/copilot@$CopilotCliVersion`"' once Node is available"
        return
    }

    npm install -g "@github/copilot@$CopilotCliVersion"
    Assert-LastExit -ToolName "GitHub Copilot CLI"
    Write-Ok "GitHub Copilot CLI installed at $CopilotCliVersion"
}
