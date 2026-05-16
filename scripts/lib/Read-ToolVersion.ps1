# scripts/lib/Read-ToolVersion.ps1 -- read a pinned version from .tool-versions
#
# Provides: Get-ToolVersion -Name <toolname>
# Returns the version string. Throws if tool not found.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ToolVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    # Walk up from this script to repo root (lib -> scripts -> repo root)
    $libDir = Split-Path $PSScriptRoot -Parent
    $repoRoot = Split-Path $libDir -Parent
    $toolVersionsFile = Join-Path $repoRoot '.tool-versions'

    if (-not (Test-Path $toolVersionsFile)) {
        throw ".tool-versions not found at $toolVersionsFile"
    }

    $lines = Get-Content $toolVersionsFile
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $parts = $trimmed -split '\s+', 2
        if ($parts[0] -eq $Name) {
            return $parts[1]
        }
    }

    throw "Tool '$Name' not found in .tool-versions"
}
