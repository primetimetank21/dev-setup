# tests/test_tui_pwsh.ps1 -- Slice 3 TUI and resolver tests (#495)
#
# Tests: Resolve-FinalToolset (unit, dot-sourced from tui.ps1)
#        Show-ToolMenu integration paths (selection-file seam, empty)
#        ASCII purity of tui.ps1, -Help hiding of -SelectionFile.
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_tui_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, arrows, or emoji.
# Cancel path (Esc/Q) and ReadKey failure are manual-only gates (no real key-reader seam).
# Test count: 14

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
# Quiet Accent styling tests
# ===========================================================================

# ---------------------------------------------------------------------------
# T_quiet_accent_roles_ps: each semantic role maps to the selected console color.
# ---------------------------------------------------------------------------
Test-Scenario "T_quiet_accent_roles_ps: semantic roles map to Quiet Accent colors" {
    $expected = @{
        Heading      = [ConsoleColor]::Cyan
        Focus        = [ConsoleColor]::Cyan
        Checked      = [ConsoleColor]::Green
        OptIn        = [ConsoleColor]::Yellow
        Confirmation = [ConsoleColor]::Green
        Warning      = [ConsoleColor]::Yellow
        Cancel       = [ConsoleColor]::Yellow
    }
    foreach ($role in $expected.Keys) {
        $actual = Get-TuiRoleColor -Role $role
        if ($actual -ne $expected[$role]) {
            throw "$role expected $($expected[$role]), got $actual"
        }
    }
}

# ---------------------------------------------------------------------------
# T_quiet_accent_plain_ps: forced plain and NO_COLOR suppress console styling.
# ---------------------------------------------------------------------------
Test-Scenario "T_quiet_accent_plain_ps: forced plain and NO_COLOR disable styling" {
    $savedOverride = $env:_PS_TUI_COLOR_OVERRIDE
    $savedNoColor  = $env:NO_COLOR
    try {
        $env:_PS_TUI_COLOR_OVERRIDE = '0'
        if (Test-TuiColorEnabled) { throw 'Forced-plain seam enabled styling' }

        $env:_PS_TUI_COLOR_OVERRIDE = '1'
        $env:NO_COLOR = '1'
        if (Test-TuiColorEnabled) { throw 'NO_COLOR did not override forced color' }
    }
    finally {
        $env:_PS_TUI_COLOR_OVERRIDE = $savedOverride
        $env:NO_COLOR = $savedNoColor
    }
}

# ---------------------------------------------------------------------------
# T_quiet_accent_redirected_ps: a piped child process must remain plain.
# ---------------------------------------------------------------------------
Test-Scenario "T_quiet_accent_redirected_ps: redirected output disables styling" {
    $command = "& { . '$TuiLib'; if (Test-TuiColorEnabled) { exit 1 } }"
    powershell -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Color styling remained enabled for redirected output'
    }
}

# ---------------------------------------------------------------------------
# T_quiet_accent_restores_ps: forced color applies roles and restores even when
# the output operation fails.
# ---------------------------------------------------------------------------
Test-Scenario "T_quiet_accent_restores_ps: foreground color restores on success and failure" {
    $savedOverride = $env:_PS_TUI_COLOR_OVERRIDE
    $savedWriter   = $script:_TuiWriteOverride
    try {
        $env:_PS_TUI_COLOR_OVERRIDE = '1'
        if (-not (Test-TuiColorEnabled)) {
            throw 'Console color access is unavailable for forced-color seam'
        }

        $before = [Console]::ForegroundColor
        $script:_TuiWriteOverride = {
            param($Text, $ErrorOutput)
            $script:_TuiWriteCall = @($Text, $ErrorOutput)
        }
        Write-TuiStyled -Text 'role-check' -Color (Get-TuiRoleColor -Role 'Confirmation')
        if ([Console]::ForegroundColor -ne $before) {
            throw 'Foreground color did not restore after styled write'
        }

        $script:_TuiWriteOverride = {
            throw 'forced output failure'
        }
        $threw = $false
        try {
            Write-TuiStyled -Text 'restore-check' -Color (Get-TuiRoleColor -Role 'Warning')
        }
        catch {
            $threw = $true
        }
        if (-not $threw) { throw 'Forced output failure did not propagate' }
        if ([Console]::ForegroundColor -ne $before) {
            throw 'Foreground color did not restore after output failure'
        }
    }
    finally {
        $script:_TuiWriteOverride = $savedWriter
        Remove-Variable -Scope Script -Name _TuiWriteCall -ErrorAction SilentlyContinue
        $env:_PS_TUI_COLOR_OVERRIDE = $savedOverride
    }
}

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

# ---------------------------------------------------------------------------
# T_noninteractive_cannot_be_overridden_ps: explicit flag always suppresses menu
# ---------------------------------------------------------------------------
Test-Scenario "T_noninteractive_cannot_be_overridden_ps: explicit flag wins over environment" {
    Setup-Harness
    $savedSeam = $env:_PS_TUI_TEST_MENU
    $env:_PS_TUI_TEST_MENU = '1'
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -NonInteractive -ToolsDir $StubDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Setup exited $LASTEXITCODE" }
        $actual   = (Get-Content $script:RunLog -ErrorAction SilentlyContinue) -join "`n"
        $expected = (Get-Content (Join-Path $StubDir 'defaults.txt')) -join "`n"
        if ($actual -ne $expected) {
            throw "Non-interactive override failed.`n  Expected: $expected`n  Actual:   $actual"
        }
    }
    finally {
        $env:_PS_TUI_TEST_MENU = $savedSeam
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
Write-Host '  - Cancel (Esc/Q): exit 0, "Install cancelled." printed, nothing installed'
Write-Host '  - Arrow Up/Down navigation in Windows Terminal (PS 5.1 + pwsh)'
Write-Host '  - Arrow navigation in legacy conhost (cmd.exe host, PS 5.1)'
Write-Host '  - Opt-in tools shown unchecked below defaults with "(opt-in)" label'
Write-Host '  - Space toggles current item; A toggles all'
Write-Host '  - All defaults checked + Enter == no-arg non-interactive run result'
Write-Host '  - Uncheck a default, confirm => that tool skipped'
Write-Host '  - [Console]::ReadKey failure: warning to stderr ("Interactive menu failed..."), exit 0 (no install)'
Write-Host ''

if ($TestsFailed -gt 0) { exit 1 }
