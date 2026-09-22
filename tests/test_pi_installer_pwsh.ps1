# tests/test_pi_installer_pwsh.ps1 -- parity tests for pi opt-in installer
#
# Tests:
#   T_pi_in_list     -- pi appears in -List output (opt-in discoverable)
#   T_pi_not_default -- pi is NOT installed by a default no-arg run
#   T_pi_version_pin -- .tool-versions contains a pi pin
#   T_pi_optin_stub  -- -Only 'pi' with stub dir runs only pi
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_pi_installer_pwsh.ps1
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
# T_pi_in_list: -List on real registry includes 'pi'
# ---------------------------------------------------------------------------

Test-Scenario "T_pi_in_list: pi appears in -List output (opt-in discoverable)" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-List exited $ec (expected 0)" }
    if ($out -notmatch '\bpi\b') {
        throw "pi missing from -List output; has pi.ps1 been registered in ToolRegistry?"
    }
}

# ---------------------------------------------------------------------------
# T_pi_not_default: default no-arg run with stub dir does NOT run pi
# ---------------------------------------------------------------------------

Test-Scenario "T_pi_not_default: pi does NOT run in a default install (opt-in only)" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if ($content -contains 'pi') {
            throw "pi ran in a default no-arg install (must be opt-in only)"
        }
    }
    finally {
        $env:RUN_LOG = $null
        Remove-Item $runLog -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# T_pi_version_pin: .tool-versions contains a pi entry
# ---------------------------------------------------------------------------

Test-Scenario "T_pi_version_pin: pi is pinned in .tool-versions" {
    $lines = Get-Content $ToolVersions
    $entry = $lines | Where-Object { $_ -match '^pi\s+' }
    if (-not $entry) {
        throw "pi not found in .tool-versions"
    }
    $ver = ($entry -split '\s+')[1]
    Write-Host "  pi pinned at $ver" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# T_pi_optin_stub: -Only 'pi' with stub dir runs only pi
# ---------------------------------------------------------------------------

Test-Scenario "T_pi_optin_stub: -Only 'pi' runs only pi via stub" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir -Only 'pi' 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if (-not $content) { throw "-Only 'pi' produced empty run-log" }
        if ($content -notcontains 'pi') {
            throw "-Only 'pi' did not run pi stub; log: $($content -join ', ')"
        }
        $extra = $content | Where-Object { $_ -ne 'pi' }
        if ($extra) { throw "-Only 'pi' ran unexpected tools: $($extra -join ', ')" }
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
