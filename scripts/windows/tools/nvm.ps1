# scripts/windows/tools/nvm.ps1 - nvm-windows + Node.js installer
#
# Owner: Goofy (#2)
# Installs nvm-windows (Node Version Manager for Windows), then auto-installs
# the pinned Node.js version from .tool-versions so node/npm are usable in
# the same setup session.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

function Install-Nvm {
    # Load pinned versions from .tool-versions
    # Two levels up: tools -> windows -> scripts, then into shared lib/
    $libDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'lib'
    if (-not (Test-Path $libDir)) {
        throw "Shared lib directory not found at $libDir"
    }
    $readToolVersion = Join-Path $libDir 'Read-ToolVersion.ps1'
    if (-not (Test-Path $readToolVersion)) {
        throw "Read-ToolVersion.ps1 not found at $readToolVersion"
    }
    . $readToolVersion
    $pinnedNode = Get-ToolVersion -Name 'nodejs'

    # -- Check if Node is already installed at the pinned version -----------
    $existingNode = Get-Command node -ErrorAction SilentlyContinue
    if ($existingNode) {
        $currentVer = (& node --version 2>&1).ToString().TrimStart('v')
        if ($currentVer -eq $pinnedNode) {
            Write-Ok "Node $pinnedNode already installed -- skipping"
            return
        }
        Write-Info "Node $currentVer found but pinned version is $pinnedNode"
    }

    # -- Install nvm-windows if missing ------------------------------------
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
        $nvmVersion = Get-ToolVersion -Name 'nvm'
        Write-Info "Installing nvm-windows (pinned: $nvmVersion)..."
        winget install --id CoreyButler.NVMforWindows --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "nvm-windows install failed (winget exit $LASTEXITCODE) -- cannot install Node"
            return
        }
        Refresh-SessionPath
        if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
            Write-Warn "nvm not found on PATH after install -- open a new terminal and re-run setup"
            return
        }
        Write-Ok "nvm-windows installed"
    } else {
        Write-Ok "nvm already installed: $(nvm version)"
    }

    # -- Install and activate pinned Node version --------------------------
    Write-Info "Installing Node.js $pinnedNode via nvm..."
    & nvm install $pinnedNode
    & nvm use $pinnedNode
    Refresh-SessionPath

    # -- Verify node/npm are on PATH ---------------------------------------
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        Write-Ok "node $(& node --version) ready"
    } else {
        Write-Warn "node not found on PATH after nvm install -- try opening a new terminal"
    }
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        Write-Ok "npm $(& npm --version) ready"
    } else {
        Write-Warn "npm not found on PATH after nvm install -- try opening a new terminal"
    }
}
