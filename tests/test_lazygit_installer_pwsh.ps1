# tests/test_lazygit_installer_pwsh.ps1 -- parity tests for lazygit opt-in installer (#467)
#
# Tests:
#   T_lazygit_in_list     -- lazygit appears in -List output (opt-in discoverable)
#   T_lazygit_not_default -- lazygit is NOT installed by a default no-arg run
#   T_lazygit_version_pin -- .tool-versions contains a lazygit pin
#   T_lazygit_optin_stub  -- -Only 'lazygit' with stub dir runs only lazygit
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_lazygit_installer_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot    = Split-Path $PSScriptRoot -Parent
$WinSetup    = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$StubDir     = Join-Path $RepoRoot 'tests\fixtures\stub-tools\windows'
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
# T_lazygit_in_list: -List on real registry includes 'lazygit'
# Fails RED when lazygit.ps1 is not dot-sourced + registered in setup.ps1.
# ---------------------------------------------------------------------------

Test-Scenario "T_lazygit_in_list: lazygit appears in -List output (opt-in discoverable)" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-List exited $ec (expected 0)" }
    if ($out -notmatch '\blazygit\b') {
        throw "lazygit missing from -List output; has lazygit.ps1 been registered in ToolRegistry?"
    }
}

# ---------------------------------------------------------------------------
# T_lazygit_not_default: default no-arg run with stub dir does NOT run lazygit
# ---------------------------------------------------------------------------

Test-Scenario "T_lazygit_not_default: lazygit does NOT run in a default install (opt-in only)" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if ($content -contains 'lazygit') {
            throw "lazygit ran in a default no-arg install (must be opt-in only)"
        }
    }
    finally {
        $env:RUN_LOG = $null
        Remove-Item $runLog -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# T_lazygit_version_pin: .tool-versions contains a lazygit entry
# Fails RED before lazygit is added to .tool-versions.
# ---------------------------------------------------------------------------

Test-Scenario "T_lazygit_version_pin: lazygit is pinned in .tool-versions" {
    $lines = Get-Content $ToolVersions
    $entry = $lines | Where-Object { $_ -match '^lazygit\s+' }
    if (-not $entry) {
        throw "lazygit not found in .tool-versions -- RED (pre-implementation)"
    }
    $ver = ($entry -split '\s+')[1]
    Write-Host "  lazygit pinned at $ver" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# T_lazygit_optin_stub: -Only 'lazygit' with stub dir runs only lazygit
# Fails RED when lazygit.ps1 stub is not in the stub dir OR not in ToolRegistry.
# ---------------------------------------------------------------------------

Test-Scenario "T_lazygit_optin_stub: -Only 'lazygit' runs only lazygit via stub" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir -Only 'lazygit' 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if (-not $content) { throw "-Only 'lazygit' produced empty run-log" }
        if ($content -notcontains 'lazygit') {
            throw "-Only 'lazygit' did not run lazygit stub; log: $($content -join ', ')"
        }
        $extra = $content | Where-Object { $_ -ne 'lazygit' }
        if ($extra) { throw "-Only 'lazygit' ran unexpected tools: $($extra -join ', ')" }
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
