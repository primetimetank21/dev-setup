# scripts/windows/tools/uv.ps1 - uv (Python package manager) installer
#
# Owner: Goofy (#2)
# Installs uv via official install script

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

function Install-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Ok "uv already installed: $(uv --version)"
        return
    }
    Write-Info "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    Assert-LastExit -ToolName "uv"
    Write-Ok "uv installed"
}
