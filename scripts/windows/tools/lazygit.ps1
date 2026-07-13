# scripts/windows/tools/lazygit.ps1 - lazygit installer
#
# Installs lazygit at pinned version from .tool-versions.
# Opt-in: NOT in $DefaultTools; only runs when requested via -Only 'lazygit'.
# winget preferred (id JesseDuffield.lazygit); scoop fallback when winget unavailable.
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-Lazygit {
    $LgVersion = Get-ToolVersion -Name 'lazygit'

    # Detect installed version
    $InstalledVersion = ''
    if (Get-Command lazygit -ErrorAction SilentlyContinue) {
        $raw = (lazygit --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $LgVersion) {
        Write-Ok "lazygit already at pinned version $LgVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "lazygit $InstalledVersion installed; upgrading to pinned $LgVersion..."
    } else {
        Write-Info "Installing lazygit $LgVersion..."
    }

    # winget preferred; fall back to scoop if winget is unavailable
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id JesseDuffield.lazygit --version $LgVersion --silent `
            --accept-source-agreements --accept-package-agreements
        Assert-LastExit -ToolName "lazygit" -AllowedExitCodes @(0, -1978335189)
        Refresh-SessionPath
        Write-Ok "lazygit installed via winget at $LgVersion"
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Info "winget not available; falling back to scoop..."
        scoop install lazygit
        Assert-LastExit -ToolName "lazygit (scoop)"
        Write-Warn "scoop installed latest lazygit; version may differ from pinned $LgVersion"
    } else {
        Write-Err "Neither winget nor scoop available; cannot install lazygit"
        throw "lazygit install failed: no supported package manager found"
    }
}
