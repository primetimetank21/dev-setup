# tests/test_setup_flags_pwsh.ps1 -- WI-1 baseline + -List/-Help tests (#468)
#
# Tests the framework spine: $DefaultTools constant, -ToolsDir seam,
# -List, -Help, root forwarding, baseline-diff.
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_setup_flags_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, arrows, or emoji.

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$WinSetup  = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$RootSetup = Join-Path $RepoRoot 'setup.ps1'
$StubDir   = Join-Path $RepoRoot 'tests\fixtures\stub-tools\windows'
$BaselineFixture = Join-Path $RepoRoot 'tests\fixtures\baseline-tools-windows.txt'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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

function Write-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    Write-Host "[SKIP] $Name -- $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
}

function Setup-Harness {
    $script:RunLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG   = $script:RunLog
}

function Teardown-Harness {
    Remove-Item $script:RunLog -ErrorAction SilentlyContinue
    $env:RUN_LOG = $null
}

function Assert-LogEquals {
    param([string]$ExpectedFile)
    $actual   = (Get-Content $script:RunLog -ErrorAction SilentlyContinue) -join "`n"
    $expected = (Get-Content $ExpectedFile)  -join "`n"
    if ($actual -ne $expected) {
        throw "Run-log mismatch.`n  Expected: $expected`n  Actual:   $actual"
    }
}

function Invoke-SetupScript {
    param([string]$Script, [string[]]$Args)
    $result = powershell -NoProfile -ExecutionPolicy Bypass -File $Script @Args 2>&1 | Out-String
    return @{ Output = $result; ExitCode = $LASTEXITCODE }
}

# ---------------------------------------------------------------------------
# T_baseline_noarg: no-arg with -ToolsDir logs defaults.txt exactly
# ---------------------------------------------------------------------------

Test-Scenario "T_baseline_noarg: no-arg run logs exactly defaults.txt" {
    Setup-Harness
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -ToolsDir $StubDir 2>&1 | Out-Null
        Assert-LogEquals (Join-Path $StubDir 'defaults.txt')
    }
    finally { Teardown-Harness }
}

# ---------------------------------------------------------------------------
# T_baseline_real_defaults: fixture matches live $DefaultTools array
# ---------------------------------------------------------------------------

Test-Scenario "T_baseline_real_defaults: fixture matches DefaultTools in source" {
    $winContent = Get-Content $WinSetup -Raw
    if ($winContent -notmatch '(?s)\$DefaultTools\s*=\s*@\((.*?)\)') {
        throw "Could not find `$DefaultTools array in $WinSetup"
    }
    $block = $Matches[1]
    $actual = $block.Split([char[]]@([char]13, [char]10)) |
        ForEach-Object { $_.Trim().Trim("'").Trim('"') } |
        Where-Object { $_ -and $_ -notmatch '^#' }
    $expected = Get-Content $BaselineFixture
    $diff = Compare-Object $expected $actual
    if ($diff) {
        $diffStr = ($diff | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ', '
        throw "DefaultTools drift from fixture: $diffStr"
    }
}

# ---------------------------------------------------------------------------
# T_list_output: -List prints AvailableTools, exit 0
# ---------------------------------------------------------------------------

Test-Scenario "T_list_output: -List exits 0 and contains available tools" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List -ToolsDir $StubDir 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-List exited $ec (expected 0)" }
    if ($out -notmatch 'alpha') { throw "-List output does not contain 'alpha'" }
    if ($out -notmatch 'delta') { throw "-List output does not contain 'delta'" }
}

# ---------------------------------------------------------------------------
# T_list_no_install: -List with -ToolsDir produces no RUN_LOG entries
# ---------------------------------------------------------------------------

Test-Scenario "T_list_no_install: -List produces no run-log entries" {
    Setup-Harness
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List -ToolsDir $StubDir 2>&1 | Out-Null
        $content = Get-Content $script:RunLog -ErrorAction SilentlyContinue
        if ($content) { throw "-List wrote to run-log: $content" }
    }
    finally { Teardown-Harness }
}

# ---------------------------------------------------------------------------
# T_help_output: -Help prints usage with flag names, exit 0
# ---------------------------------------------------------------------------

Test-Scenario "T_help_output: -Help exits 0 and mentions -List, -Only, -Skip" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -Help 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-Help exited $ec (expected 0)" }
    if ($out -notmatch '-List')  { throw "-Help output does not mention '-List'" }
    if ($out -notmatch '-Only')  { throw "-Help output does not mention '-Only'" }
    if ($out -notmatch '-Skip')  { throw "-Help output does not mention '-Skip'" }
}

# ---------------------------------------------------------------------------
# T_help_no_toolsdir: -Help does NOT expose -ToolsDir (hidden seam)
# ---------------------------------------------------------------------------

Test-Scenario "T_help_no_toolsdir: -Help does not expose hidden -ToolsDir flag" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -Help 2>&1 | Out-String
    if ($out -match 'ToolsDir') {
        throw "-Help output exposes -ToolsDir (must remain hidden)"
    }
}

# ---------------------------------------------------------------------------
# T_param_ps51: param block parses without error under PS 5.1
# ---------------------------------------------------------------------------

Test-Scenario "T_param_ps51: setup.ps1 param block is PS 5.1 compatible" {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($WinSetup, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $msgs = ($errors | ForEach-Object { $_.Message }) -join '; '
        throw "Parse errors in setup.ps1: $msgs"
    }
}

# ---------------------------------------------------------------------------
# T_unknown_arg: truly unknown argument to setup via root exits non-zero
# (We can test this by checking that an unrecognised flag causes failure.
#  Since PS param() silently ignores extra named params, we test via an
#  explicit unknown-arg guard in setup.ps1 output.)
# ---------------------------------------------------------------------------

Test-Scenario "T_unknown_arg: unrecognized flag exits non-zero" {
    # PS with [CmdletBinding()] rejects unknown params -- stderr propagates up;
    # wrap in try/catch so the parent does not terminate, then check exit code.
    try {
        $null = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -BogusUnknownFlag123 2>&1
    } catch { }
    if ($LASTEXITCODE -eq 0) {
        throw "Expected non-zero exit for unknown param -BogusUnknownFlag123, got 0"
    }
}

# ---------------------------------------------------------------------------
# T_root_list: root setup.ps1 -List forwards to platform script, exits 0
# ---------------------------------------------------------------------------

Test-Scenario "T_root_list: root setup.ps1 -List forwards and exits 0" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $RootSetup `
        -List -ToolsDir $StubDir 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "Root setup.ps1 -List exited $ec (expected 0)" }
    if ($out -notmatch 'alpha') { throw "Root forwarding: -List output missing 'alpha'" }
}

# ---------------------------------------------------------------------------
# T_root_help: root setup.ps1 -Help exits 0
# ---------------------------------------------------------------------------

Test-Scenario "T_root_help: root setup.ps1 -Help exits 0" {
    powershell -NoProfile -ExecutionPolicy Bypass -File $RootSetup -Help 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Root setup.ps1 -Help exited $LASTEXITCODE (expected 0)"
    }
}

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST RESULTS (test_setup_flags_pwsh.ps1)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed:  $TestsPassed"  -ForegroundColor Green
Write-Host "Skipped: $TestsSkipped" -ForegroundColor Yellow
Write-Host "Failed:  $TestsFailed"  -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($TestsFailed -gt 0) { exit 1 } else { exit 0 }
