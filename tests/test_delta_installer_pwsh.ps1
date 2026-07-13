# tests/test_delta_installer_pwsh.ps1 -- parity tests for git-delta opt-in installer (#466)
#
# Tests:
#   T_delta_in_list       -- delta appears in -List output (opt-in discoverable)
#   T_delta_not_default   -- delta is NOT installed by a default no-arg run
#   T_delta_gitconfig_iso -- Set-DeltaGitConfig writes core.pager=delta under an
#                            isolated GIT_CONFIG_GLOBAL (does not touch real config)
#   T_delta_gitconfig_idem -- Set-DeltaGitConfig is idempotent (safe to run twice)
#
# Usage: powershell -ExecutionPolicy Bypass -File tests\test_delta_installer_pwsh.ps1
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$WinSetup   = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$DeltaPs1   = Join-Path $RepoRoot 'scripts\windows\tools\delta.ps1'
$StubDir    = Join-Path $RepoRoot 'tests\fixtures\stub-tools\windows'

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

# ---------------------------------------------------------------------------
# T_delta_in_list: -List on real registry includes 'delta'
# Fails RED when delta.ps1 is not dot-sourced + registered in setup.ps1.
# ---------------------------------------------------------------------------

Test-Scenario "T_delta_in_list: delta appears in -List output (opt-in discoverable)" {
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup -List 2>&1 | Out-String
    $ec  = $LASTEXITCODE
    if ($ec -ne 0) { throw "-List exited $ec (expected 0)" }
    if ($out -notmatch '\bdelta\b') {
        throw "delta missing from -List output; has delta.ps1 been registered in ToolRegistry?"
    }
}

# ---------------------------------------------------------------------------
# T_delta_not_default: default no-arg run with stub dir does NOT run delta
# ---------------------------------------------------------------------------

Test-Scenario "T_delta_not_default: delta does NOT run in a default install (opt-in only)" {
    $runLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $runLog
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $WinSetup `
            -ToolsDir $StubDir 2>&1 | Out-Null
        $content = Get-Content $runLog -ErrorAction SilentlyContinue
        if ($content -contains 'delta') {
            throw "delta ran in a default no-arg install (must be opt-in only)"
        }
    }
    finally {
        $env:RUN_LOG = $null
        Remove-Item $runLog -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# T_delta_gitconfig_iso: Set-DeltaGitConfig writes core.pager=delta under
# an isolated GIT_CONFIG_GLOBAL; real ~/.gitconfig is never touched.
# Fails RED when delta.ps1 does not exist.
# ---------------------------------------------------------------------------

Test-Scenario "T_delta_gitconfig_iso: core.pager=delta written to isolated config" {
    if (-not (Test-Path $DeltaPs1)) {
        throw "delta.ps1 not found at $DeltaPs1 -- RED (pre-implementation)"
    }
    $isolatedConfig = [System.IO.Path]::GetTempFileName()
    $savedConfig = $env:GIT_CONFIG_GLOBAL
    try {
        $env:GIT_CONFIG_GLOBAL = $isolatedConfig
        # Dot-source delta.ps1 to load Set-DeltaGitConfig (and Install-Delta)
        # Install-Delta is defined but not called here.
        . $DeltaPs1
        Set-DeltaGitConfig
        $pager = git config --global --get core.pager
        if ($pager -ne 'delta') {
            throw "core.pager expected 'delta', got '$pager'"
        }
        $filter = git config --global --get interactive.diffFilter
        if ($filter -ne 'delta --color-only') {
            throw "interactive.diffFilter expected 'delta --color-only', got '$filter'"
        }
    }
    finally {
        $env:GIT_CONFIG_GLOBAL = $savedConfig
        Remove-Item $isolatedConfig -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# T_delta_gitconfig_idem: running Set-DeltaGitConfig twice does not error
# ---------------------------------------------------------------------------

Test-Scenario "T_delta_gitconfig_idem: Set-DeltaGitConfig is idempotent (safe to run twice)" {
    if (-not (Test-Path $DeltaPs1)) {
        throw "delta.ps1 not found at $DeltaPs1 -- RED (pre-implementation)"
    }
    $isolatedConfig = [System.IO.Path]::GetTempFileName()
    $savedConfig = $env:GIT_CONFIG_GLOBAL
    try {
        $env:GIT_CONFIG_GLOBAL = $isolatedConfig
        . $DeltaPs1
        Set-DeltaGitConfig  # first run
        Set-DeltaGitConfig  # second run -- must not error
        $dark = git config --global --get delta.dark
        if ($dark -ne 'true') {
            throw "delta.dark expected 'true' after double-run, got '$dark'"
        }
    }
    finally {
        $env:GIT_CONFIG_GLOBAL = $savedConfig
        Remove-Item $isolatedConfig -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Results: $TestsPassed passed, $TestsFailed failed, $TestsSkipped skipped"
if ($TestsFailed -gt 0) { exit 1 }
exit 0
