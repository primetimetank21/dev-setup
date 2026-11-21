# scripts/windows/tools/winget-check.ps1 - App Installer (winget) availability gate
#
# Extracted from the inline winget check in scripts/windows/setup.ps1 Main().
# Called by the dispatcher as the first tool step.
# Fails fast (exit 1) if winget is not available -- all subsequent tools need it.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

function Invoke-WingetGate {
    if (-not (Test-WingetAvailable)) {
        Write-Err "winget not found. Please install App Installer from the Microsoft Store."
        Write-Err "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1"
        exit 1
    }
    Write-Ok "winget available"
}
