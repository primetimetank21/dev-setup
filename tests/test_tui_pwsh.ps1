# tests/test_tui_pwsh.ps1 -- Slice 3 TUI and resolver tests (#495)
#
# Tests: Resolve-FinalToolset, Resolve-ToolSelection (unit, dot-sourced from tui.ps1)
#        Show-ToolMenu integration paths (selection-file seam, cancel seam, empty)
#        ASCII purity of tui.ps1, -Help hiding of -SelectionFile.
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_tui_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, arrows, or emoji.

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot        = Split-Path $PSScriptRoot -Parent
$WinSetup        = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$TuiLib          = Join-Path $RepoRoot 'scripts\windows\lib\tui.ps1'
$StubDir         = Join-Path $RepoRoot 'tests\fixtures\stub-tools\windows'
$SelectionFile   = Join-Path $StubDir 'selection.txt'

# ---------------------------------------------------------------------------
# Helpers (same pattern as test_setup_flags_pwsh.ps1)
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

function Setup-Harness {
    $script:RunLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG   = $script:RunLog
}

function Teardown-Harness {
    Remove-Item $script:RunLog -ErrorAction SilentlyContinue
    $env:RUN_LOG = $null
}

function Assert-ArrayEquals {
    param([string[]]$Expected, [string[]]$Actual, [string]$Label)
    $diff = Compare-Object $Expected $Actual
    if ($diff) {
        $e = $Expected -join ', '
        $a = if ($Actual) { $Actual -join ', ' } else { '(empty)' }
        throw "${Label}: expected [$e] got [$a]"
    }
}

# ---------------------------------------------------------------------------
# Dot-source tui.ps1 for unit tests.
# Will fail with "Cannot find path" if tui.ps1 does not exist yet (RED state).
# ---------------------------------------------------------------------------
. $TuiLib

# ===========================================================================
# Resolve-FinalToolset unit tests
# ===========================================================================

# ---------------------------------------------------------------------------
# T_resolve_toolset_defaults_ps: no -Only/-Skip => DefaultTools unchanged
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_toolset_defaults_ps: defaults path returns DefaultTools" {
    $d      = @('alpha', 'bravo', 'charlie')
    $result = Resolve-FinalToolset -DefaultTools $d
    Assert-ArrayEquals -Expected $d -Actual $result -Label 'defaults path'
}

# ---------------------------------------------------------------------------
# T_resolve_toolset_only_ps: -Only preserves default order + appends opt-ins
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_toolset_only_ps: -Only order-preserved + opt-in appended" {
    $d = @('alpha', 'bravo', 'charlie')
    # Request bravo (default) and delta (opt-in); expect default-order first, then opt-in
    $result = Resolve-FinalToolset -DefaultTools $d -Only 'bravo,delta' -OnlySet $true
    Assert-ArrayEquals -Expected @('bravo', 'delta') -Actual $result -Label '-Only path'
}

# ---------------------------------------------------------------------------
# T_resolve_toolset_skip_ps: -Skip removes named tool, keeps rest in default order
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_toolset_skip_ps: -Skip removes tool in default order" {
    $d      = @('alpha', 'bravo', 'charlie')
    $result = Resolve-FinalToolset -DefaultTools $d -Skip 'bravo' -SkipSet $true
    Assert-ArrayEquals -Expected @('alpha', 'charlie') -Actual $result -Label '-Skip path'
}

# ===========================================================================
# Resolve-ToolSelection unit tests
# ===========================================================================

# ---------------------------------------------------------------------------
# T_resolve_selection_defaults_ps: all items checked => full CSV
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_selection_defaults_ps: all checked gives full CSV" {
    $items   = @('alpha', 'bravo', 'charlie')
    $checked = @($true, $true, $true)
    $csv     = Resolve-ToolSelection -Checked $checked -Items $items
    if ($csv -ne 'alpha,bravo,charlie') {
        throw "Expected 'alpha,bravo,charlie' got '$csv'"
    }
}

# ---------------------------------------------------------------------------
# T_resolve_selection_subset_ps: subset checked => order-preserved subset CSV
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_selection_subset_ps: subset checked gives correct CSV" {
    $items   = @('alpha', 'bravo', 'charlie')
    $checked = @($true, $false, $true)
    $csv     = Resolve-ToolSelection -Checked $checked -Items $items
    if ($csv -ne 'alpha,charlie') {
        throw "Expected 'alpha,charlie' got '$csv'"
    }
}

# ---------------------------------------------------------------------------
# T_resolve_selection_optin_ps: opt-in checked => appended in CSV after defaults
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_selection_optin_ps: opt-in item appended after defaults in CSV" {
    # items: alpha + bravo are defaults, delta is opt-in (already sorted by caller)
    $items   = @('alpha', 'bravo', 'delta')
    $checked = @($true, $false, $true)
    $csv     = Resolve-ToolSelection -Checked $checked -Items $items
    if ($csv -ne 'alpha,delta') {
        throw "Expected 'alpha,delta' got '$csv'"
    }
}

# ---------------------------------------------------------------------------
# T_resolve_selection_empty_ps: nothing checked => empty CSV (callers handle exit)
# ---------------------------------------------------------------------------
Test-Scenario "T_resolve_selection_empty_ps: nothing checked gives empty CSV" {
    $items   = @('alpha', 'bravo')
    $checked = @($false, $false)
    $csv     = Resolve-ToolSelection -Checked $checked -Items $items
    if ($csv -ne '') {
        throw "Expected empty string got '$csv'"
    }
}

# ===========================================================================
# Integration tests (subprocess)
# ===========================================================================

# ---------------------------------------------------------------------------
# T_menu_selection_file_e2e_ps: -Interactive -SelectionFile -ToolsDir => correct run-log
# selection.txt: delta (opt-in), blank, alpha (default)
# expected install order: alpha (default order), then delta (opt-in)
# ---------------------------------------------------------------------------
Test-Scenario "T_menu_selection_file_e2e_ps: SelectionFile integration routes to correct install" {
    Setup-Harness
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -Interactive -SelectionFile $SelectionFile -ToolsDir $StubDir 2>&1 | Out-Null
        $ec = $LASTEXITCODE
        if ($ec -ne 0) { throw "Expected exit 0, got $ec" }
        $actual   = (Get-Content $script:RunLog -ErrorAction SilentlyContinue) -join "`n"
        $expected = "alpha`ndelta"
        if ($actual -ne $expected) {
            throw "Run-log mismatch. Expected: [$expected] Actual: [$actual]"
        }
    }
    finally { Teardown-Harness }
}

# ---------------------------------------------------------------------------
# T_menu_cancel_aborts_ps: Show-ToolMenu returns $null => exit 0, no tools run
# Uses _PS_TUI_TEST_MENU (force menu path) + _PS_TUI_MOCK=cancel test seams.
# ---------------------------------------------------------------------------
Test-Scenario "T_menu_cancel_aborts_ps: cancel return exits 0 with empty run-log" {
    Setup-Harness
    $env:_PS_TUI_TEST_MENU = '1'
    $env:_PS_TUI_MOCK      = 'cancel'
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -Interactive -ToolsDir $StubDir 2>&1 | Out-Null
        $ec = $LASTEXITCODE
        if ($ec -ne 0) { throw "Expected exit 0 on cancel, got $ec" }
        $content = Get-Content $script:RunLog -ErrorAction SilentlyContinue
        if ($content) { throw "Tools ran on cancel: $($content -join ', ')" }
    }
    finally {
        Remove-Item env:_PS_TUI_TEST_MENU -ErrorAction SilentlyContinue
        Remove-Item env:_PS_TUI_MOCK -ErrorAction SilentlyContinue
        Teardown-Harness
    }
}

# ---------------------------------------------------------------------------
# T_menu_noop_empty_ps: empty SelectionFile => "nothing selected" exit 0, no tools run
# ---------------------------------------------------------------------------
Test-Scenario "T_menu_noop_empty_ps: empty SelectionFile exits 0 with empty run-log" {
    Setup-Harness
    $emptyFile = [System.IO.Path]::GetTempFileName()
    try {
        # Write an empty selection file (blank lines only)
        Set-Content -Path $emptyFile -Value '' -Encoding UTF8
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -Interactive -SelectionFile $emptyFile -ToolsDir $StubDir 2>&1 | Out-Null
        $ec = $LASTEXITCODE
        if ($ec -ne 0) { throw "Expected exit 0 on empty selection, got $ec" }
        $content = Get-Content $script:RunLog -ErrorAction SilentlyContinue
        if ($content) { throw "Tools ran on empty selection: $($content -join ', ')" }
    }
    finally {
        Remove-Item $emptyFile -ErrorAction SilentlyContinue
        Teardown-Harness
    }
}

# ---------------------------------------------------------------------------
# T_noarg_noninteractive_compat_ps: [DRIFT] no params + CI env => defaults installed
# ---------------------------------------------------------------------------
Test-Scenario "T_noarg_noninteractive_compat_ps: [DRIFT] no-arg + CI => run-log == defaults" {
    Setup-Harness
    $savedCI = $env:CI
    $env:CI  = 'true'
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Setup exited $LASTEXITCODE" }
        $actual   = (Get-Content $script:RunLog -ErrorAction SilentlyContinue) -join "`n"
        $expected = (Get-Content (Join-Path $StubDir 'defaults.txt')) -join "`n"
        if ($actual -ne $expected) {
            throw "Drift gate failed.`n  Expected: $expected`n  Actual:   $actual"
        }
    }
    finally {
        $env:CI = $savedCI
        Teardown-Harness
    }
}

# ===========================================================================
# Static / purity checks
# ===========================================================================

# ---------------------------------------------------------------------------
# T_ascii_purity_ps: tui.ps1 contains no non-ASCII bytes (plan requirement)
# ---------------------------------------------------------------------------
Test-Scenario "T_ascii_purity_ps: tui.ps1 is pure ASCII (no byte > 127)" {
    $bytes    = [System.IO.File]::ReadAllBytes($TuiLib)
    $nonAscii = @($bytes | Where-Object { $_ -gt 127 })
    if ($nonAscii.Count -gt 0) {
        throw "Non-ASCII bytes found in tui.ps1 ($($nonAscii.Count) offsets)"
    }
}

# ---------------------------------------------------------------------------
# T_help_no_seam_ps: -Help output does NOT expose -SelectionFile
# ---------------------------------------------------------------------------
Test-Scenario "T_help_no_seam_ps: -Help does not expose -SelectionFile" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -Help 2>&1 | Out-String
    if ($out -match 'SelectionFile') {
        throw "-Help output exposes -SelectionFile (must remain hidden)"
    }
}

# ---------------------------------------------------------------------------
# T_parse_tui_ps51: tui.ps1 parses without errors under PS 5.1
# ---------------------------------------------------------------------------
Test-Scenario "T_parse_tui_ps51: tui.ps1 has no PS 5.1 parse errors" {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $TuiLib, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $msgs = ($errors | ForEach-Object { $_.Message }) -join '; '
        throw "Parse errors in tui.ps1: $msgs"
    }
}

# ===========================================================================
# Summary
# ===========================================================================

Write-Host ''
$color = if ($TestsFailed -gt 0) { 'Red' } else { 'Green' }
Write-Host "Results: $TestsPassed passed, $TestsFailed failed, $TestsSkipped skipped." `
    -ForegroundColor $color
Write-Host ''
Write-Host 'Manual verification required (not CI-testable):' -ForegroundColor Yellow
Write-Host '  - Arrow Up/Down navigation in Windows Terminal (PS 5.1 + pwsh)'
Write-Host '  - Arrow navigation in legacy conhost (cmd.exe host, PS 5.1)'
Write-Host '  - Opt-in tools shown unchecked below defaults with "(opt-in)" label'
Write-Host '  - ESC / Q cancels cleanly (exit 0, no install)'
Write-Host '  - Space toggles current item; A toggles all'
Write-Host '  - All defaults checked + Enter == no-arg non-interactive run result'
Write-Host '  - Uncheck a default, confirm => that tool skipped'
Write-Host '  - [Console]::ReadKey failure: warning logged to stderr, exit 0 (no install)'
Write-Host ''

if ($TestsFailed -gt 0) { exit 1 }
