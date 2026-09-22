# tests/test_herdr_installer_pwsh.ps1 -- parity tests for herdr opt-in installer
#
# Tests:
#   T_herdr_in_list     -- herdr appears in -List output (opt-in discoverable)
#   T_herdr_not_default -- herdr is NOT installed by a default no-arg run
#   T_herdr_version_pin -- .tool-versions contains a herdr pin
#   T_herdr_optin_stub  -- -Only 'herdr' with stub dir runs only herdr
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_herdr_installer_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot     = Split-Path $PSScriptRoot -Parent
$WinSetup     = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$StubDir      = Join-Path $RepoRoot 'tests\fixtures\stub-tools\windows'
$ToolVersions = Join-Path $RepoRoot '.tool-versions'

function Test-Scenario {
    param([string]$Name, [scriptblock]$Test)
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ---------------------------------------------------------------------------
# T_herdr_in_list: -List on real registry includes 'herdr'
# ---------------------------------------------------------------------------

Test-Scenario "T_herdr_in_list: herdr appears in -List output (opt-in discoverable)" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-List exited $ec (expected 0)" }
    if ($out -notmatch '\bherdr\b') {
        throw "herdr missing from -List output; has herdr.ps1 been registered in ToolRegistry?"
    }
}

# ---------------------------------------------------------------------------
# T_herdr_not_default: default no-arg run with stub dir does NOT run herdr
# ---------------------------------------------------------------------------

Test-Scenario "T_herdr_not_default: herdr does NOT run in a default install (opt-in only)" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if ($content -contains 'herdr') {
            throw "herdr ran in a default no-arg install (must be opt-in only)"
        }
    }
    finally {
        $env:RUN_LOG = $null
        Remove-Item $runLog -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# T_herdr_version_pin: .tool-versions contains a herdr entry
# ---------------------------------------------------------------------------

Test-Scenario "T_herdr_version_pin: herdr is pinned in .tool-versions" {
    $lines = Get-Content $ToolVersions
    $entry = $lines | Where-Object { $_ -match '^herdr\s+' }
    if (-not $entry) {
        throw "herdr not found in .tool-versions"
    }
    $ver = ($entry -split '\s+')[1]
    Write-Host "  herdr pinned at $ver" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# T_herdr_optin_stub: -Only 'herdr' with stub dir runs only herdr
# ---------------------------------------------------------------------------

Test-Scenario "T_herdr_optin_stub: -Only 'herdr' runs only herdr via stub" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir -Only 'herdr' 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if (-not $content) { throw "-Only 'herdr' produced empty run-log" }
        if ($content -notcontains 'herdr') {
            throw "-Only 'herdr' did not run herdr stub; log: $($content -join ', ')"
        }
        $extra = $content | Where-Object { $_ -ne 'herdr' }
        if ($extra) { throw "-Only 'herdr' ran unexpected tools: $($extra -join ', ')" }
    }
    finally {
        $env:RUN_LOG = $null
        Remove-Item $runLog -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Results: $TestsPassed passed, $TestsFailed failed, $TestsSkipped skipped"
if ($TestsFailed -gt 0) { exit 1 }
exit 0
