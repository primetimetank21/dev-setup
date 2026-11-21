# scripts/windows/tools/herdr.ps1 - Herdr installer
#
# Installs Herdr at pinned version via the official Windows installer.
# Version-aware: upgrades if installed version != pinned version.
# Opt-in: NOT in $DefaultTools; only runs when requested via -Only 'herdr'.
#
# Source basis:
# - Official Windows installer: https://herdr.dev/install.ps1
# - Stable release manifest: https://herdr.dev/latest.json
#
# This wrapper keeps dev-setup's version pinning contract by requiring the
# pinned version to match the current stable manifest before running the
# official installer.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"

function Install-Herdr {
    $HerdrVersion = Get-ToolVersion -Name 'herdr'
    $ManifestUrl  = 'https://herdr.dev/latest.json'
    $InstallerUrl = 'https://herdr.dev/install.ps1'

    $InstalledVersion = ''
    if (Get-Command herdr -ErrorAction SilentlyContinue) {
        $raw = (herdr --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $InstalledVersion = $m.Value }
    }

    if ($InstalledVersion -eq $HerdrVersion) {
        Write-Ok "herdr already at pinned version $HerdrVersion"
        return
    }

    if ($InstalledVersion) {
        Write-Info "herdr $InstalledVersion installed; upgrading to pinned $HerdrVersion..."
    } else {
        Write-Info "Installing herdr $HerdrVersion..."
    }

    $manifest = Invoke-RestMethod -Uri $ManifestUrl
    if (-not $manifest.version) {
        throw "Could not determine Herdr stable version from $ManifestUrl"
    }
    if ([string]$manifest.version -ne $HerdrVersion) {
        throw "Pinned herdr version $HerdrVersion does not match current stable manifest version $($manifest.version)"
    }

    $tmpDir = Join-Path $env:TEMP ("herdr-dev-setup-" + [guid]::NewGuid().ToString('N'))
    $installerPath = Join-Path $tmpDir 'install.ps1'
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $installerPath -UseBasicParsing
        & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -Channel stable
        if ($LASTEXITCODE -ne 0) {
            throw "Herdr installer exited with code $LASTEXITCODE"
        }
    }
    finally {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Refresh-SessionPath
    $ActualVersion = ''
    if (Get-Command herdr -ErrorAction SilentlyContinue) {
        $raw = (herdr --version 2>&1) | Select-Object -First 1 | Out-String
        $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
        if ($m.Success) { $ActualVersion = $m.Value }
    }
    if ($ActualVersion -ne $HerdrVersion) {
        throw "herdr install completed but version check failed (expected $HerdrVersion, got $ActualVersion)"
    }

    Write-Ok "herdr installed at $HerdrVersion"
}
