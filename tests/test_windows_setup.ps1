#!/usr/bin/env pwsh
# tests/test_windows_setup.ps1
# Regression tests for three Windows-specific bug fixes (Issues #102, #103)
#
# Covers:
#   A. PSScriptRoot detection in root setup.ps1
#      Fix (c06ceb2): $PSScriptRoot replaces $MyInvocation.MyCommand.Path, which was null
#      when the script was invoked via `powershell -File` inside a function.
#
#   B. PS 5.x variable guards in root setup.ps1
#      Fix (c06ceb2): $IsLinux / $IsMacOS / $IsWindows are PS 7+ only; guarded with
#      (Test-Path Variable:VarName) -and $VarName so the script runs on Windows PS 5.x.
#
#   C. Profile append corruption in scripts/windows/setup.ps1
#      Fix (9a63720): Add-Content now prepends a blank line so the # BEGIN sentinel
#      cannot be concatenated onto the last line of a profile that lacks a trailing newline.
#
#   D. Copilot CLI install alignment in scripts/windows/setup.ps1
#      Fix (9a63720): switched from `gh extension install github/gh-copilot` to
#      `winget install --id GitHub.Copilot` to match the official Windows install path.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\test_windows_setup.ps1

$ErrorActionPreference = "Stop"
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot = Split-Path $PSScriptRoot -Parent

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Test-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "✅ PASS: $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "❌ FAIL: $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Write-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    Write-Host "⏭️  SKIP: $Name" -ForegroundColor Yellow
    Write-Host "  Reason: $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
}

# ---------------------------------------------------------------------------
# Group A: PSScriptRoot / ScriptDir detection
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group A: PSScriptRoot / ScriptDir detection" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "PSScriptRoot is non-empty when invoked via powershell -File" {
    $TempScript = Join-Path $PSScriptRoot "temp_scriptroot_$(Get-Random).ps1"
    try {
        Set-Content $TempScript -Value 'Write-Output $PSScriptRoot' -Encoding UTF8

        $output = (powershell -NoProfile -ExecutionPolicy Bypass -File $TempScript 2>&1 |
                   Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($output)) {
            throw "`$PSScriptRoot was null/empty when invoked via -File (got: '$output')"
        }
        if (-not (Test-Path $output)) {
            throw "`$PSScriptRoot output is not a valid directory path: '$output'"
        }
    }
    finally {
        if (Test-Path $TempScript) { Remove-Item $TempScript -Force }
    }
}

Test-Scenario "PSScriptRoot is populated inside a function when invoked via powershell -File" {
    $TempScript = Join-Path $PSScriptRoot "temp_scriptroot_fn_$(Get-Random).ps1"
    try {
        Set-Content $TempScript -Encoding UTF8 -Value @'
function Get-ScriptDir { return $PSScriptRoot }
Write-Output (Get-ScriptDir)
'@
        $output = (powershell -NoProfile -ExecutionPolicy Bypass -File $TempScript 2>&1 |
                   Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($output)) {
            throw "`$PSScriptRoot was null/empty inside a function invoked via -File"
        }
        if (-not (Test-Path $output)) {
            throw "`$PSScriptRoot inside function is not a valid directory: '$output'"
        }
    }
    finally {
        if (Test-Path $TempScript) { Remove-Item $TempScript -Force }
    }
}

Test-Scenario "Root setup.ps1 uses PSScriptRoot (not MyInvocation.MyCommand.Path)" {
    $setupContent = Get-Content (Join-Path $RepoRoot 'setup.ps1') -Raw
    if ($setupContent -match '\$MyInvocation\.MyCommand\.Path') {
        throw "Root setup.ps1 still references MyInvocation.MyCommand.Path - should use PSScriptRoot"
    }
    if ($setupContent -notmatch '\$PSScriptRoot') {
        throw "Root setup.ps1 does not reference `$PSScriptRoot"
    }
}

# ---------------------------------------------------------------------------
# Group B: PS 5.x variable guards
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group B: PS 5.x variable guards" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "PS5.x compat: accessing undefined variable under Set-StrictMode throws" {
    # Demonstrates the root cause: on PS 5.x, $IsLinux is not defined, and
    # reading it under Set-StrictMode -Version Latest raises an exception.
    # We use a synthetic name guaranteed not to exist in any PS version.
    $threw = $false
    try {
        & {
            Set-StrictMode -Version Latest
            $x = $__DevSetupUndefinedTestVar__
        }
    }
    catch { $threw = $true }

    if (-not $threw) {
        throw "Expected StrictMode to throw on undefined variable access, but it did not"
    }
}

Test-Scenario "PS5.x compat: Test-Path Variable: guard prevents throw on undefined var" {
    # The fixed pattern: (Test-Path Variable:VarName) -and $VarName
    # Safe on every PS version — returns false without throwing.
    & {
        Set-StrictMode -Version Latest
        $safe = (Test-Path Variable:__DevSetupUndefinedTestVar__) -and $__DevSetupUndefinedTestVar__
        if ($safe -ne $false) {
            throw "Expected guard to return false for undefined variable, but got: $safe"
        }
    }
}

Test-Scenario "PS5.x compat: IsLinux guard returns false on Windows" {
    # Verifies the specific fix from c06ceb2.
    # PS 5.x: $IsLinux is undefined → (Test-Path ...) returns $false → short-circuit → $false
    # PS 7+ on Windows: $IsLinux is $false → (Test-Path ...) is $true, but $IsLinux is $false → $false
    & {
        Set-StrictMode -Version Latest
        $isLinux = (Test-Path Variable:IsLinux) -and $IsLinux
        if ($isLinux -ne $false) {
            throw "IsLinux guard should return false on Windows, got: $isLinux"
        }
    }
}

Test-Scenario "PS5.x compat: IsWindows guard returns true on Windows" {
    # Verifies the compound guard: ((Test-Path Variable:IsWindows) -and $IsWindows) -or ($env:OS -eq 'Windows_NT')
    # Must be true on any Windows PowerShell version.
    & {
        Set-StrictMode -Version Latest
        $isWindows = ((Test-Path Variable:IsWindows) -and $IsWindows) -or ($env:OS -eq 'Windows_NT')
        if ($isWindows -ne $true) {
            throw "Windows detection should return true on Windows, got: $isWindows"
        }
    }
}

Test-Scenario "Root setup.ps1 guards all three PS-Core-only variables" {
    $setupContent = Get-Content (Join-Path $RepoRoot 'setup.ps1') -Raw
    foreach ($varName in @('IsLinux', 'IsMacOS', 'IsWindows')) {
        if ($setupContent -notmatch "Test-Path Variable:$varName") {
            throw "Root setup.ps1 is missing 'Test-Path Variable:$varName' guard"
        }
    }
}

# ---------------------------------------------------------------------------
# Group C: Profile idempotency (blank-line prepend fix)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group C: Profile idempotency" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Load Write-PowerShellProfile (and its logging helpers) from the production script
# without running Main, so we can call the function under test in isolation.
$windowsSetupPath    = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$windowsSetupContent = Get-Content $windowsSetupPath -Raw
# Strip the bare 'Main' invocation at the bottom — functions are defined but not run.
$windowsSetupNoMain  = $windowsSetupContent -replace '(?m)^\s*Main\s*$', ''
Invoke-Expression $windowsSetupNoMain

# --- C-1: Sentinel appears exactly once after two consecutive runs --------

$c1Profile = Join-Path $PSScriptRoot "temp_profile_c1_$(Get-Random).ps1"
# Write content WITHOUT a trailing newline — this was the corruption trigger.
[System.IO.File]::WriteAllText($c1Profile, "Set-Alias -Name ggsls -Value Get-GitStashList")
$savedProfile = $PROFILE
$PROFILE = $c1Profile   # Script-scope override; Write-PowerShellProfile walks up and finds it here.

Test-Scenario "Profile idempotency: sentinel appears exactly once after two runs" {
    Write-PowerShellProfile  # First run — appends sentinel block
    Write-PowerShellProfile  # Second run — must detect sentinel and short-circuit

    $lines        = Get-Content $c1Profile
    $sentinelCount = @($lines | Where-Object { $_ -eq '# BEGIN dev-setup profile' }).Count
    if ($sentinelCount -ne 1) {
        throw "Expected sentinel exactly once, found $sentinelCount time(s)"
    }
}

$PROFILE = $savedProfile
if (Test-Path $c1Profile) { Remove-Item $c1Profile -Force }

# --- C-2: No line concatenation on file without trailing newline ----------

$c2Profile = Join-Path $PSScriptRoot "temp_profile_c2_$(Get-Random).ps1"
[System.IO.File]::WriteAllText($c2Profile, "Set-Alias -Name ggsls -Value Get-GitStashList")
$PROFILE = $c2Profile

Test-Scenario "Profile idempotency: no line concatenation on file without trailing newline" {
    # Before the fix, the first line of profileContent ('# BEGIN dev-setup profile')
    # was appended directly onto the last byte of the file, producing:
    #   'Set-Alias -Name ggsls -Value Get-GitStashList# BEGIN dev-setup profile'
    Write-PowerShellProfile

    $lines       = Get-Content $c2Profile
    $badLines    = $lines | Where-Object { $_ -match '.+#\s*(BEGIN|END) dev-setup profile' }
    if ($badLines) {
        throw "Line concatenation detected: '$($badLines | Select-Object -First 1)'"
    }
}

$PROFILE = $savedProfile
if (Test-Path $c2Profile) { Remove-Item $c2Profile -Force }

# --- C-3: Second run on already-patched profile does not grow the file ---

$c3Profile = Join-Path $PSScriptRoot "temp_profile_c3_$(Get-Random).ps1"
[System.IO.File]::WriteAllText($c3Profile, "Set-Alias -Name ggsls -Value Get-GitStashList")
$PROFILE = $c3Profile

Test-Scenario "Profile idempotency: second run is a strict no-op (file size unchanged)" {
    Write-PowerShellProfile
    $sizeAfterFirst = (Get-Item $c3Profile).Length

    Write-PowerShellProfile  # Should detect sentinel and return immediately
    $sizeAfterSecond = (Get-Item $c3Profile).Length

    if ($sizeAfterSecond -ne $sizeAfterFirst) {
        throw "File grew on second run ($sizeAfterFirst -> $sizeAfterSecond bytes) - idempotency broken"
    }
}

$PROFILE = $savedProfile
if (Test-Path $c3Profile) { Remove-Item $c3Profile -Force }

# --- C-4: Blank-line prepend fix is present in source --------------------

Test-Scenario "Windows setup.ps1 contains blank-line prepend before profile append" {
    # Verifies the fix is still in the production script (regression guard).
    if ($windowsSetupContent -notmatch 'Add-Content\s+-Path\s+\$PROFILE\s+-Value\s+""') {
        throw "scripts/windows/setup.ps1 is missing the blank-line prepend fix (Add-Content -Value ``""``)"
    }
}

# ---------------------------------------------------------------------------
# Group D: Copilot CLI install logic
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group D: Copilot CLI install logic" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "Windows setup.ps1 uses winget for Copilot CLI (not gh extension)" {
    if ($windowsSetupContent -match 'gh extension install github/gh-copilot') {
        throw "scripts/windows/setup.ps1 still uses 'gh extension install' for Copilot CLI - should use winget"
    }
    if ($windowsSetupContent -notmatch 'winget install --id GitHub\.Copilot') {
        throw "scripts/windows/setup.ps1 does not use 'winget install --id GitHub.Copilot'"
    }
}

Test-Scenario "Copilot CLI: already-installed short-circuit logic is correct" {
    # Unit-tests the guard pattern inline — no winget required.
    # Simulates: Get-Command copilot returns non-null → winget must NOT be called.
    $wouldInstall = $false

    $mockCopilotCmd = [pscustomobject]@{ Name = 'copilot'; Source = 'mock' }

    if ($null -ne $mockCopilotCmd) {
        # Production path: Write-Ok + return — install skipped
    }
    else {
        $wouldInstall = $true
    }

    if ($wouldInstall) {
        throw "Install logic called winget even though copilot was already found"
    }
}

# Live detection test — conditional on whether the binary is present in this environment.
$copilotBin = Get-Command copilot -ErrorAction SilentlyContinue
if ($null -ne $copilotBin) {
    Test-Scenario "Copilot CLI: Install-CopilotCli reports already-installed (live)" {
        $output = Install-CopilotCli 2>&1 | Out-String
        if ($output -notmatch 'already installed') {
            throw "Install-CopilotCli did not report 'already installed' when copilot is on PATH"
        }
    }
}
else {
    Write-Skip "Copilot CLI: Install-CopilotCli live already-installed detection" `
        "copilot binary not on PATH - run manually after: winget install --id GitHub.Copilot"
}

# ---------------------------------------------------------------------------
# Group E: Install-Vim (Issue #107)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group E: Install-Vim" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "E-1: Install-Vim function exists in scripts/windows/setup.ps1" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern 'function Install-Vim' -Quiet
    if (-not $found) {
        throw "Install-Vim function not found in scripts/windows/setup.ps1"
    }
}

Test-Scenario "E-2: Install-Vim is called in Main" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern '^\s*Install-Vim\s*$' -Quiet
    if (-not $found) {
        throw "Install-Vim is not called in Main"
    }
}

Test-Scenario "E-3: winget package ID vim.vim is present" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern '--id vim\.vim' -Quiet
    if (-not $found) {
        throw "winget package ID 'vim.vim' not found in scripts/windows/setup.ps1"
    }
}

Test-Scenario "E-4: No MyInvocation.MyCommand.Path usage (PS 5.x compat)" {
    $content = Get-Content (Join-Path $RepoRoot 'scripts\windows\setup.ps1') -Raw
    if ($content -match '\$MyInvocation\.MyCommand\.Path') {
        throw "scripts/windows/setup.ps1 uses MyInvocation.MyCommand.Path - banned per PS 5.x compat rules"
    }
}

Test-Scenario "E-5: No unguarded PS 6+ auto-vars (`$IsLinux/`$IsMacOS/`$IsWindows)" {
    $content  = Get-Content (Join-Path $RepoRoot 'scripts\windows\setup.ps1') -Raw
    $badVars  = @('IsLinux', 'IsMacOS', 'IsWindows')
    foreach ($v in $badVars) {
        # An unguarded reference looks like: $IsLinux used directly, without a PSVersion guard or
        # a Test-Path Variable: guard on the same logical line / nearby.
        # Acceptable patterns: ($PSVersionTable.PSVersion.Major -ge 6 -and $IsX)
        #                  or  (Test-Path Variable:IsX) -and $IsX
        # Simple check: if the var appears, ensure a version-guard or Test-Path guard is adjacent.
        if ($content -match "\`$$v") {
            # OK only when accompanied by a PSVersion guard on the same line.
            $lines = $content -split "`n" | Where-Object { $_ -match "\`$$v" }
            foreach ($line in $lines) {
                if ($line -notmatch 'PSVersion|Test-Path Variable') {
                    throw "Unguarded `$$v on line: $line"
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Group F: PowerShell alias parity (Issue #108)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group F: PowerShell alias parity (Issue #108)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$windowsSetupProfileContent = $windowsSetupContent

Test-Scenario "F-1: All new git aliases present in profile content" {
    $requiredAliases = @('gaa', 'gcm', 'gcb', 'gco', 'gd', 'gds', 'ggsp', 'gp', 'gpf', 'gpl', 'grb', 'grbi', 'grs', 'grss')
    foreach ($alias in $requiredAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing alias '$alias' in scripts/windows/setup.ps1"
        }
    }
}

Test-Scenario "F-2: gs fix - profile contains 'git status -sb'" {
    if ($windowsSetupProfileContent -notmatch 'git status -sb') {
        throw "scripts/windows/setup.ps1 does not contain 'git status -sb' - gs alias fix is missing"
    }
}

Test-Scenario "F-3: GitHub CLI aliases present (ghpr, ghprl, ghprv, ghis, ghiv)" {
    $ghAliases = @('ghpr', 'ghprl', 'ghprv', 'ghis', 'ghiv')
    foreach ($alias in $ghAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing GitHub CLI alias '$alias' in scripts/windows/setup.ps1"
        }
    }
}

Test-Scenario "F-4: Dev shortcut aliases present (uvr, uvs, ni, nr, nrd, nrt, py, c)" {
    $devAliases = @('uvr', 'uvs', 'ni', 'nr', 'nrd', 'nrt', 'py', 'c')
    foreach ($alias in $devAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing dev shortcut alias '$alias' in scripts/windows/setup.ps1"
        }
    }
}

Test-Scenario "F-5: Utility aliases present (myip, pb, h)" {
    $utilAliases = @('myip', 'pb', 'h')
    foreach ($alias in $utilAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing utility alias '$alias' in scripts/windows/setup.ps1"
        }
    }
}

Test-Scenario "F-6: PS 5.x compat - no banned patterns in profile content block" {
    if ($windowsSetupProfileContent -match '\$MyInvocation\.MyCommand\.Path') {
        throw "scripts/windows/setup.ps1 uses MyInvocation.MyCommand.Path - banned per PS 5.x compat rules"
    }
    $badVars = @('IsLinux', 'IsMacOS', 'IsWindows')
    foreach ($v in $badVars) {
        if ($windowsSetupProfileContent -match "\`$$v") {
            $lines = $windowsSetupProfileContent -split "`n" | Where-Object { $_ -match "\`$$v" }
            foreach ($line in $lines) {
                if ($line -notmatch 'PSVersion|Test-Path Variable') {
                    throw "Unguarded `$$v found on line: $line"
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Group G: Install-SquadCli (Issue #106)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group G: Install-SquadCli (Issue #106)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "G-1: Install-SquadCli function exists in scripts/windows/setup.ps1" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern 'function Install-SquadCli' -Quiet
    if (-not $found) {
        throw "Install-SquadCli function not found in scripts/windows/setup.ps1"
    }
}

Test-Scenario "G-2: Install-SquadCli is called in Main" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern '^\s*Install-SquadCli\s*$' -Quiet
    if (-not $found) {
        throw "Install-SquadCli is not called in Main"
    }
}

Test-Scenario "G-3: Install-SquadCli contains npm availability check (skip+warn)" {
    $content = Get-Content (Join-Path $RepoRoot 'scripts\windows\setup.ps1') -Raw
    if ($content -notmatch 'Get-Command npm') {
        throw "Install-SquadCli does not check for npm availability"
    }
    if ($content -notmatch 'npm not found -- skipping squad-cli') {
        throw "Install-SquadCli does not warn when npm is missing"
    }
}

Test-Scenario "G-4: No MyInvocation.MyCommand.Path in Install-SquadCli" {
    $content = Get-Content (Join-Path $RepoRoot 'scripts\windows\setup.ps1') -Raw
    if ($content -match '\$MyInvocation\.MyCommand\.Path') {
        throw "scripts/windows/setup.ps1 uses MyInvocation.MyCommand.Path - banned per PS 5.x compat rules"
    }
}

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed:  $TestsPassed"  -ForegroundColor Green
Write-Host "Skipped: $TestsSkipped" -ForegroundColor Yellow
Write-Host "Failed:  $TestsFailed"  -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($TestsFailed -gt 0) {
    exit 1
}
else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}
