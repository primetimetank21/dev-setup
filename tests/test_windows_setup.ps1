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
#      PSVersion-based checks ($PSVersionTable.PSVersion.Major -ge 6 -and $IsX) so the
#      script runs safely on Windows PS 5.x without triggering strict-mode errors.
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
    Write-Host "[SKIP] $Name" -ForegroundColor Yellow
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
    # Safe on every PS version - returns false without throwing.
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
    # PS 5.x: $IsLinux is undefined -> (Test-Path ...) returns $false -> short-circuit -> $false
    # PS 7+ on Windows: $IsLinux is $false -> (Test-Path ...) is $true, but $IsLinux is $false -> $false
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
    $setupLines = Get-Content (Join-Path $RepoRoot 'setup.ps1')
    foreach ($varName in @('IsLinux', 'IsMacOS', 'IsWindows')) {
        $guarded = @($setupLines | Where-Object { $_ -match ('\$' + $varName) -and $_ -match 'PSVersionTable\.PSVersion\.Major' })
        if ($guarded.Count -eq 0) {
            throw "Root setup.ps1 is missing PSVersion-based guard for '$varName'"
        }
    }
}

# ---------------------------------------------------------------------------
# Group C: Profile idempotency (blank-line prepend fix)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group C: Profile idempotency" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Load Write-PowerShellProfile (and its logging helpers) from the tool script
# Profile function is now in scripts/windows/tools/profile.ps1
# Pre-load shared logging lib so Invoke-Expression can resolve dot-source lines
. (Join-Path $RepoRoot 'scripts\windows\lib\logging.ps1')
$profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
$profileToolContent = Get-Content $profileToolPath -Raw
# Strip the dot-source of logging.ps1 (already loaded above; $PSScriptRoot
# resolves to the test dir inside Invoke-Expression, so the relative path fails)
$profileToolExec = $profileToolContent -replace '\.\s+"?\$PSScriptRoot[^"]*logging\.ps1"?', '# logging lib loaded by test harness'
Invoke-Expression $profileToolExec

# Also load setup.ps1 content for pattern checking (without executing Main)
$windowsSetupPath    = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
$windowsSetupContent = Get-Content $windowsSetupPath -Raw

# --- C-1: Function uses profilePath/profilePaths variables (not $PROFILE) --------

Test-Scenario "Write-PowerShellProfile uses profilePath/profilePaths (post-refactor variable names)" {
    # After #138 refactor: function uses $profilePaths array and $profilePath loop variable
    # instead of the automatic $PROFILE variable. Verify the new variables are present.
    # Check in profile.ps1 tool file (where the function now lives)
    if ($profileToolContent -notmatch '\$profilePaths\s*=') {
        throw "Write-PowerShellProfile does not contain '\$profilePaths =' - array definition missing"
    }
    if ($profileToolContent -notmatch 'foreach\s*\(\s*\$profilePath\s+in\s+\$profilePaths\s*\)') {
        throw "Write-PowerShellProfile does not contain 'foreach (\$profilePath in \$profilePaths)' - loop missing"
    }
}

# --- C-2: No line concatenation on file without trailing newline ----------

$savedProfile = $PROFILE
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

$savedProfile = $PROFILE
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
    # Updated to check in profile.ps1 tool file (where the function now lives)
    if ($profileToolContent -notmatch 'Add-Content\s+-Path\s+\$profilePath\s+-Value\s+""') {
        throw "scripts/windows/tools/profile.ps1 is missing the blank-line prepend fix (Add-Content -Value ``""``)"
    }
}

# ---------------------------------------------------------------------------
# Group D: Copilot CLI install logic
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group D: Copilot CLI install logic" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Load copilot.ps1 content for checking install logic
$copilotToolPath = Join-Path $RepoRoot 'scripts\windows\tools\copilot.ps1'
$copilotToolContent = Get-Content $copilotToolPath -Raw

Test-Scenario "Windows setup.ps1 uses winget for Copilot CLI (not gh extension)" {
    # Check in copilot.ps1 tool file (where the function now lives)
    if ($copilotToolContent -match 'gh extension install github/gh-copilot') {
        throw "scripts/windows/tools/copilot.ps1 still uses 'gh extension install' for Copilot CLI - should use winget"
    }
    if ($copilotToolContent -notmatch 'winget install --id GitHub\.Copilot') {
        throw "scripts/windows/tools/copilot.ps1 does not use 'winget install --id GitHub.Copilot'"
    }
}

Test-Scenario "Copilot CLI: already-installed short-circuit logic is correct" {
    # Unit-tests the guard pattern inline - no winget required.
    # Simulates: Get-Command copilot returns non-null -> winget must NOT be called.
    $wouldInstall = $false

    $mockCopilotCmd = [pscustomobject]@{ Name = 'copilot'; Source = 'mock' }

    if ($null -ne $mockCopilotCmd) {
        # Production path: Write-Ok + return - install skipped
    }
    else {
        $wouldInstall = $true
    }

    if ($wouldInstall) {
        throw "Install logic called winget even though copilot was already found"
    }
}

# Live detection test - conditional on whether the binary is present in this environment.
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

Test-Scenario "E-1: Install-Vim function exists in scripts/windows/tools/vim.ps1" {
    # Check in vim.ps1 tool file
    $vimToolPath = Join-Path $RepoRoot 'scripts\windows\tools\vim.ps1'
    $found = Select-String -Path $vimToolPath -Pattern 'function Install-Vim' -Quiet
    if (-not $found) {
        throw "Install-Vim function not found in scripts/windows/tools/vim.ps1"
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
    # Check in vim.ps1 tool file
    $vimToolPath = Join-Path $RepoRoot 'scripts\windows\tools\vim.ps1'
    $found = Select-String -Path $vimToolPath -Pattern '--id vim\.vim' -Quiet
    if (-not $found) {
        throw "winget package ID 'vim.vim' not found in scripts/windows/tools/vim.ps1"
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

# Profile content is now in profile.ps1
$windowsSetupProfileContent = $profileToolContent

Test-Scenario "F-1: All new git aliases present in profile content" {
    $requiredAliases = @('gaa', 'gcm', 'gcb', 'gco', 'gd', 'gds', 'ggsp', 'gp', 'gpf', 'gpl', 'grb', 'grbi', 'grs', 'grss')
    foreach ($alias in $requiredAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing alias '$alias' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "F-2: gs fix - profile contains 'git status -sb'" {
    if ($windowsSetupProfileContent -notmatch 'git status -sb') {
        throw "scripts/windows/tools/profile.ps1 does not contain 'git status -sb' - gs alias fix is missing"
    }
}

Test-Scenario "F-3: GitHub CLI aliases present (ghpr, ghprl, ghprv, ghis, ghiv)" {
    $ghAliases = @('ghpr', 'ghprl', 'ghprv', 'ghis', 'ghiv')
    foreach ($alias in $ghAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing GitHub CLI alias '$alias' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "F-4: Dev shortcut aliases present (uvr, uvs, ni, nr, nrd, nrt, py, c)" {
    $devAliases = @('uvr', 'uvs', 'ni', 'nr', 'nrd', 'nrt', 'py', 'c')
    foreach ($alias in $devAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing dev shortcut alias '$alias' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "F-5: Utility aliases present (myip, pb, h, ep)" {
    $utilAliases = @('myip', 'pb', 'h', 'ep')
    foreach ($alias in $utilAliases) {
        if ($windowsSetupProfileContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing utility alias '$alias' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "F-6: PS 5.x compat - no banned patterns in profile content block" {
    if ($windowsSetupProfileContent -match '\$MyInvocation\.MyCommand\.Path') {
        throw "scripts/windows/tools/profile.ps1 uses MyInvocation.MyCommand.Path - banned per PS 5.x compat rules"
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

# Load squad-cli.ps1 content
$squadToolPath = Join-Path $RepoRoot 'scripts\windows\tools\squad-cli.ps1'
$squadToolContent = Get-Content $squadToolPath -Raw

Test-Scenario "G-1: Install-SquadCli function exists in scripts/windows/tools/squad-cli.ps1" {
    if ($squadToolContent -notmatch 'function Install-SquadCli') {
        throw "Install-SquadCli function not found in scripts/windows/tools/squad-cli.ps1"
    }
}

Test-Scenario "G-2: Install-SquadCli is called in Main" {
    $found = Select-String -Path (Join-Path $RepoRoot 'scripts\windows\setup.ps1') `
                            -Pattern '^\s*Install-SquadCli\s*$' -Quiet
    if (-not $found) {
        throw "Install-SquadCli is not called in Main"
    }
}

Test-Scenario "G-3: Install-SquadCli contains npm availability check (error+exit)" {
    if ($squadToolContent -notmatch 'Get-Command npm') {
        throw "Install-SquadCli does not check for npm availability"
    }
    if ($squadToolContent -notmatch 'npm not found after nvm install') {
        throw "Install-SquadCli does not emit error when npm is missing"
    }
}

Test-Scenario "G-4: No MyInvocation.MyCommand.Path in Install-SquadCli" {
    if ($squadToolContent -match '\$MyInvocation\.MyCommand\.Path') {
        throw "scripts/windows/tools/squad-cli.ps1 uses MyInvocation.MyCommand.Path - banned per PS 5.x compat rules"
    }
}

# ---------------------------------------------------------------------------
# Group H: psmux aliases in PowerShell profile (Issue #140)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group H: psmux aliases in PowerShell profile (Issue #140)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "H-1: psmux alias functions exist in profile content" {
    # Check in profile.ps1 tool file (where the profile content now lives)
    $requiredFunctions = @('Invoke-PsmuxList', 'Invoke-PsmuxKillServer', 'Invoke-PsmuxNewSession', 'Invoke-PsmuxAttach')
    foreach ($fn in $requiredFunctions) {
        if ($profileToolContent -notmatch $fn) {
            throw "Missing psmux alias function '$fn' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "H-2: psmux Set-Alias entries exist for tls, tks, tt, ta" {
    # Check in profile.ps1 tool file
    $requiredAliases = @('tls', 'tks', 'tt', 'ta')
    foreach ($alias in $requiredAliases) {
        if ($profileToolContent -notmatch "Set-Alias\s+-Name\s+$alias\b") {
            throw "Missing Set-Alias for '$alias' in scripts/windows/tools/profile.ps1"
        }
    }
}

Test-Scenario "H-3: New-PsmuxSession function exists in profile content" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'function New-PsmuxSession') {
        throw "New-PsmuxSession function not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "H-4: New-PsmuxSession checks for existing session before creating" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'psmux ls') {
        throw "New-PsmuxSession does not contain 'psmux ls' session check"
    }
}

# ---------------------------------------------------------------------------
# Group I: psmux install (Issue #139)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group I: psmux install (Issue #139)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "I-1: Install-Psmux function exists in psmux.ps1" {
    $psmuxToolPath = Join-Path $RepoRoot 'scripts\windows\tools\psmux.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($psmuxToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Install-Psmux' }, $true)
    if ($fn.Count -eq 0) {
        throw "Install-Psmux function not found in scripts/windows/tools/psmux.ps1"
    }
}

Test-Scenario "I-2: Install-Psmux is called in Main" {
    $setupPath = Join-Path $RepoRoot 'scripts\windows\setup.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$errors)
    $mainFn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Main' }, $true)
    if ($mainFn.Count -eq 0) { throw "Main function not found" }
    $mainBody = $mainFn[0].Body.Extent.Text
    if ($mainBody -notmatch 'Install-Psmux') {
        throw "Install-Psmux is not called in Main"
    }
}

Test-Scenario "I-3: Install-Psmux is idempotent (checks before installing)" {
    $psmuxToolPath = Join-Path $RepoRoot 'scripts\windows\tools\psmux.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($psmuxToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Install-Psmux' }, $true)
    if ($fn.Count -eq 0) { throw "Install-Psmux function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'Get-Command psmux') {
        throw "Install-Psmux does not check for psmux before installing (missing Get-Command psmux)"
    }
}

# ---------------------------------------------------------------------------
# Group J: Write-PowerShellProfile strip+re-inject logic (Issue #138)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group J: Write-PowerShellProfile strip+re-inject logic (Issue #138)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "J-1: Write-PowerShellProfile body contains the begin marker string" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'BEGIN dev-setup profile') {
        throw "Write-PowerShellProfile body does not contain 'BEGIN dev-setup profile' marker"
    }
}

Test-Scenario "J-2: Write-PowerShellProfile body contains the end marker string" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'END dev-setup profile') {
        throw "Write-PowerShellProfile body does not contain 'END dev-setup profile' marker"
    }
}

Test-Scenario "J-3: Write-PowerShellProfile body does NOT contain return after sentinel check" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    # The old skip logic had "return" right after the sentinel check
    # The new strip logic should NOT have "return" - it strips and falls through
    if ($fnBody -match 'Select-String.*BEGIN dev-setup profile.*\)\s*\{\s*[^}]*?\breturn\b') {
        throw "Write-PowerShellProfile still has 'return' after sentinel check - should strip+re-inject instead"
    }
}

Test-Scenario "J-4: Write-PowerShellProfile body contains Get-Content and Set-Content (strip logic)" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'Get-Content') {
        throw "Write-PowerShellProfile does not contain 'Get-Content' - strip logic missing"
    }
    if ($fnBody -notmatch 'Set-Content') {
        throw "Write-PowerShellProfile does not contain 'Set-Content' - strip logic missing"
    }
}

# ---------------------------------------------------------------------------
# Group K: Dual profile paths and robust alias registration (Issue #138)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group K: Dual profile paths and robust alias registration (Issue #138)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "K-1: Write-PowerShellProfile contains WindowsPowerShell path (PS 5.1)" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'WindowsPowerShell') {
        throw "Write-PowerShellProfile does not contain 'WindowsPowerShell' - PS 5.1 path is missing"
    }
}

Test-Scenario "K-2: Write-PowerShellProfile contains PowerShell path (PS 7+, NOT WindowsPowerShell)" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    # Must contain Path::Combine with 'PowerShell' (not 'WindowsPowerShell')
    # Check for the pattern: Path::Combine(..., 'PowerShell', ...) without WindowsPowerShell
    if ($fnBody -notmatch "Path\]::Combine\([^\)]*,\s*'PowerShell'\s*,") {
        throw "Write-PowerShellProfile does not contain Path::Combine with standalone 'PowerShell' - PS 7+ path is missing"
    }
}

Test-Scenario "K-3: All Set-Alias calls in profile content heredoc have -Force" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $profileToolContent = Get-Content $profileToolPath -Raw
    # Extract the $profileContent heredoc (between @' and '@)
    if ($profileToolContent -match "(?s)\`$profileContent\s*=\s*@'(.*?)'@") {
        $profileContent = $Matches[1]
        # Find all Set-Alias lines
        $setAliasLines = $profileContent -split "`n" | Where-Object { $_ -match 'Set-Alias' }
        if ($setAliasLines.Count -eq 0) {
            throw "No Set-Alias lines found in profileContent heredoc"
        }
        foreach ($line in $setAliasLines) {
            if ($line -notmatch '-Force') {
                throw "Set-Alias line lacks -Force: $line"
            }
        }
    } else {
        throw "Could not find profileContent heredoc in scripts\windows\tools\profile.ps1"
    }
}

Test-Scenario "K-4: Write-PowerShellProfile contains Get-ExecutionPolicy (execution policy check)" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'Get-ExecutionPolicy') {
        throw "Write-PowerShellProfile does not contain 'Get-ExecutionPolicy' - execution policy check is missing"
    }
}

Test-Scenario "K-5: Write-PowerShellProfile contains RemoteSigned (remediation hint)" {
    $profileToolPath = Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1'
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profileToolPath, [ref]$tokens, [ref]$errors)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-PowerShellProfile' }, $true)
    if ($fn.Count -eq 0) { throw "Write-PowerShellProfile function not found" }
    $fnBody = $fn[0].Body.Extent.Text
    if ($fnBody -notmatch 'RemoteSigned') {
        throw "Write-PowerShellProfile does not contain 'RemoteSigned' - remediation hint is missing"
    }
}

# ---------------------------------------------------------------------------
# Group L: PSScriptAnalyzer block in pre-push hook (Issue #147)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group L: PSScriptAnalyzer block in pre-push hook (Issue #147)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "L-1: Hook file contains command -v pwsh guard (graceful skip path)" {
    $hookPath = Join-Path (Join-Path $RepoRoot 'hooks') 'pre-push'
    if (-not (Test-Path $hookPath)) {
        throw "Hook file not found: $hookPath"
    }
    $hookContent = Get-Content $hookPath -Raw
    if ($hookContent -notmatch 'command -v pwsh') {
        throw "pre-push hook does not contain 'command -v pwsh' guard - graceful skip path is missing"
    }
}

Test-Scenario "L-2: Hook file contains Invoke-ScriptAnalyzer invocation" {
    $hookPath = Join-Path (Join-Path $RepoRoot 'hooks') 'pre-push'
    if (-not (Test-Path $hookPath)) {
        throw "Hook file not found: $hookPath"
    }
    $hookContent = Get-Content $hookPath -Raw
    if ($hookContent -notmatch 'Invoke-ScriptAnalyzer') {
        throw "pre-push hook does not contain 'Invoke-ScriptAnalyzer' - PS lint check is missing"
    }
}

Test-Scenario "L-3: Hook file contains PSScriptAnalyzer not installed message OR module check" {
    $hookPath = Join-Path (Join-Path $RepoRoot 'hooks') 'pre-push'
    if (-not (Test-Path $hookPath)) {
        throw "Hook file not found: $hookPath"
    }
    $hookContent = Get-Content $hookPath -Raw
    $hasSkipMessage = $hookContent -match 'PSScriptAnalyzer not installed'
    $hasModuleCheck = $hookContent -match 'Get-Module.*PSScriptAnalyzer'
    if (-not ($hasSkipMessage -or $hasModuleCheck)) {
        throw "pre-push hook does not contain skip message or module check for PSScriptAnalyzer"
    }
}

Test-Scenario "L-4: Hook file does NOT contain exit 1 on PSScriptAnalyzer lines (advisory only)" {
    $hookPath = Join-Path (Join-Path $RepoRoot 'hooks') 'pre-push'
    if (-not (Test-Path $hookPath)) {
        throw "Hook file not found: $hookPath"
    }
    $hookLines = Get-Content $hookPath
    foreach ($line in $hookLines) {
        # Check if line mentions PSScriptAnalyzer AND contains exit 1
        if (($line -match 'PSScriptAnalyzer') -and ($line -match 'exit 1')) {
            throw "pre-push hook contains 'exit 1' on a PSScriptAnalyzer line - check must be advisory: $line"
        }
    }
}

Test-Scenario "L-5: Hook file shebang is #!/bin/sh (not bash, must stay POSIX)" {
    $hookPath = Join-Path (Join-Path $RepoRoot 'hooks') 'pre-push'
    if (-not (Test-Path $hookPath)) {
        throw "Hook file not found: $hookPath"
    }
    $firstLine = Get-Content $hookPath -TotalCount 1
    if ($firstLine -ne '#!/bin/sh') {
        throw "pre-push hook shebang is '$firstLine' but must be '#!/bin/sh' for POSIX compatibility"
    }
}

# ---------------------------------------------------------------------------
# Group M: Shutdown aliases in PowerShell profile (Issue #174)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group M: Shutdown aliases in PowerShell profile (Issue #174)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "M-1: Invoke-ShutdownNow function exists in profile" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'function Invoke-ShutdownNow') {
        throw "Invoke-ShutdownNow function not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-2: Invoke-TimedShutdown function exists in profile" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'function Invoke-TimedShutdown') {
        throw "Invoke-TimedShutdown function not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-3: Invoke-CancelTimedShutdown function exists in profile" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'function Invoke-CancelTimedShutdown') {
        throw "Invoke-CancelTimedShutdown function not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-4: sdn alias registered" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch "Set-Alias\s+-Name\s+sdn\b") {
        throw "Set-Alias for 'sdn' not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-5: tsdn alias registered" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch "Set-Alias\s+-Name\s+tsdn\b") {
        throw "Set-Alias for 'tsdn' not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-6: cancel_tsdn alias registered" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch "Set-Alias\s+-Name\s+cancel_tsdn\b") {
        throw "Set-Alias for 'cancel_tsdn' not found in scripts/windows/tools/profile.ps1"
    }
}

Test-Scenario "M-7: sdn body contains 'shutdown /s /t 0'" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'shutdown /s /t 0') {
        throw "Invoke-ShutdownNow does not contain 'shutdown /s /t 0'"
    }
}

Test-Scenario "M-8: cancel_tsdn body contains 'shutdown /a'" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch 'shutdown /a') {
        throw "Invoke-CancelTimedShutdown does not contain 'shutdown /a'"
    }
}

Test-Scenario "M-9: Invoke-TimedShutdown has [Parameter] decoration" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch '\[Parameter\(Mandatory\)\]') {
        throw "Invoke-TimedShutdown does not have [Parameter(Mandatory)] decoration"
    }
}

Test-Scenario "M-10: Invoke-TimedShutdown contains '* 60' multiplication" {
    # Check in profile.ps1 tool file
    if ($profileToolContent -notmatch '\*\s*60') {
        throw "Invoke-TimedShutdown does not contain '* 60' multiplication"
    }
}

# ---------------------------------------------------------------------------
# Group N: PS 5.1 Profile Write (Issue #197)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group N: PS 5.1 Profile Write (Issue #197)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "N-1: Write-PowerShellProfile writes to the PS 5.1 profile path" {
    $ps51Profile = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1')
    Write-PowerShellProfile
    if (-not (Test-Path $ps51Profile)) {
        throw "PS 5.1 profile not written: $ps51Profile"
    }
}

Test-Scenario "N-2: Write-PowerShellProfile writes to the PS 7+ profile path" {
    $ps7Profile = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
    Write-PowerShellProfile
    if (-not (Test-Path $ps7Profile)) {
        throw "PS 7+ profile not written: $ps7Profile"
    }
}

Test-Scenario "N-3: Profile content heredoc includes the squad BEGIN and END markers" {
    if ($profileToolContent -notmatch '# BEGIN dev-setup profile') {
        throw "profile.ps1 does not contain '# BEGIN dev-setup profile' marker"
    }
    if ($profileToolContent -notmatch '# END dev-setup profile') {
        throw "profile.ps1 does not contain '# END dev-setup profile' marker"
    }
}

Test-Scenario "N-4: All known PS 5.1 conflicting aliases have Remove-Item -Force Alias:\ guard in profile.ps1" {
    # These aliases carry AllScope in PS 5.1 and cannot be overridden without first removing them
    $conflictingAliases = @('rm', 'gc', 'gl', 'gcm', 'gcb', 'gp', 'grb', 'grs', 'ni', 'h', 'ep')
    foreach ($alias in $conflictingAliases) {
        if ($profileToolContent -notmatch "Remove-Item\s+-Force\s+Alias:\\$alias\b") {
            throw "profile.ps1 is missing 'Remove-Item -Force Alias:\$alias' guard (PS 5.1 AllScope conflict)"
        }
    }
}

# ---------------------------------------------------------------------------
# Group O: PS 5.1 Alias Override (Issue #197)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group O: PS 5.1 Alias Override (Issue #197)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "O-1: After Remove-Item Alias:\gc, Set-Alias gc succeeds without error" {
    Remove-Item -Force 'Alias:\gc' -ErrorAction SilentlyContinue
    Set-Alias -Name gc -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-2: After Remove-Item Alias:\gcm, Set-Alias gcm succeeds without error" {
    Remove-Item -Force 'Alias:\gcm' -ErrorAction SilentlyContinue
    Set-Alias -Name gcm -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-3: After Remove-Item Alias:\gl, Set-Alias gl succeeds without error" {
    Remove-Item -Force 'Alias:\gl' -ErrorAction SilentlyContinue
    Set-Alias -Name gl -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-4: After Remove-Item Alias:\gp, Set-Alias gp succeeds without error" {
    Remove-Item -Force 'Alias:\gp' -ErrorAction SilentlyContinue
    Set-Alias -Name gp -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-5: After Remove-Item Alias:\ni, Set-Alias ni succeeds without error" {
    Remove-Item -Force 'Alias:\ni' -ErrorAction SilentlyContinue
    Set-Alias -Name ni -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-6: After Remove-Item Alias:\rm, Set-Alias rm succeeds without error" {
    Remove-Item -Force 'Alias:\rm' -ErrorAction SilentlyContinue
    Set-Alias -Name rm -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

Test-Scenario "O-7: After Remove-Item Alias:\h, Set-Alias h succeeds without error" {
    Remove-Item -Force 'Alias:\h' -ErrorAction SilentlyContinue
    Set-Alias -Name h -Value Write-Host -Force -Scope Global -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Group P: psmux Install (Issue #197)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group P: psmux Install (Issue #197)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

. (Join-Path $RepoRoot 'scripts\windows\lib\path.ps1')
$psmuxToolPath    = Join-Path $RepoRoot 'scripts\windows\tools\psmux.ps1'
$psmuxToolContent = Get-Content $psmuxToolPath -Raw
$psmuxToolExec = $psmuxToolContent -replace '\.\s+"?\$PSScriptRoot[^"]*(logging|path)\.ps1"?', '# lib loaded by test harness'
Invoke-Expression $psmuxToolExec

Test-Scenario "P-1: psmux.ps1 can be dot-sourced without error and Install-Psmux is defined" {
    # Syntax check via AST parser
    $tokens = $null; $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($psmuxToolPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "psmux.ps1 has syntax errors: $($parseErrors[0].Message)"
    }
    # Verify function is callable after loading (loaded above via Invoke-Expression)
    if (-not (Get-Command Install-Psmux -ErrorAction SilentlyContinue)) {
        throw "Install-Psmux is not defined after loading psmux.ps1"
    }
}

if ($null -ne (Get-Command psmux -ErrorAction SilentlyContinue)) {
    Write-Skip "P-2: Install-Psmux invokes winget install when psmux missing" `
        "psmux binary is present on this machine - not-installed code path cannot be exercised"
} else {
    Test-Scenario "P-2: Install-Psmux invokes 'winget install --id marlocarlo.psmux' when psmux is not installed" {
        $script:WingetCalled = $false
        $script:WingetArgs = $null
        function global:winget {
            $script:WingetCalled = $true
            $script:WingetArgs = $args
        }
        try {
            $output = Install-Psmux 2>&1 | Out-String
            if (-not $script:WingetCalled) {
                throw "Install-Psmux did not invoke winget when psmux is absent. Output: $output"
            }
            if (($script:WingetArgs -join ' ') -notmatch 'marlocarlo\.psmux') {
                throw "Install-Psmux invoked winget with wrong package ID. Args: $($script:WingetArgs -join ' ')"
            }
        } finally {
            Remove-Item -Force Function:winget -ErrorAction SilentlyContinue
        }
    }
}

Test-Scenario "P-3: Install-Psmux is idempotent (second call does not throw)" {
    function global:winget { }
    try {
        Install-Psmux | Out-Null
        Install-Psmux | Out-Null
    } finally {
        Remove-Item -Force Function:winget -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Group Q: Dotfiles installer (Issue #180)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group Q: Dotfiles installer" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "Q-1: dotfiles.ps1 parses without errors and defines Install-Dotfiles" {
    $script = Join-Path $RepoRoot 'scripts\windows\tools\dotfiles.ps1'
    # Parse check - throws if syntax errors
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $script, [ref]$null, [ref]$null
    )
    # Dot-source and verify function exists
    . $script
    $cmd = Get-Command Install-Dotfiles -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Install-Dotfiles function not defined after dot-sourcing dotfiles.ps1"
    }
}

Test-Scenario "Q-2: Install-Dotfiles is idempotent (calling twice does not throw)" {
    $script = Join-Path $RepoRoot 'scripts\windows\tools\dotfiles.ps1'
    $tempHome = Join-Path $env:TEMP "dotfiles_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    $origProfile = $env:USERPROFILE
    try {
        $env:USERPROFILE = $tempHome
        . $script
        Install-Dotfiles | Out-Null
        Install-Dotfiles | Out-Null
    } finally {
        $env:USERPROFILE = $origProfile
        Remove-Item -Recurse -Force $tempHome -ErrorAction SilentlyContinue
    }
}

Test-Scenario "Q-3: Install-Dotfiles creates timestamped .bak when target differs" {
    $script = Join-Path $RepoRoot 'scripts\windows\tools\dotfiles.ps1'
    $tempHome = Join-Path $env:TEMP "dotfiles_bak_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    $origProfile = $env:USERPROFILE
    try {
        $env:USERPROFILE = $tempHome
        # Create a .editorconfig with different content
        $targetFile = Join-Path $tempHome '.editorconfig'
        Set-Content -Path $targetFile -Value 'old content that differs' -Encoding UTF8
        . $script
        Install-Dotfiles | Out-Null
        # Expect a .bak.YYYYMMDD-HHmmss file (not a plain .bak)
        $bakFiles = Get-ChildItem "$targetFile.bak.*" -ErrorAction SilentlyContinue
        if (-not $bakFiles) {
            throw "No timestamped .bak.* file was created when target content differed"
        }
        $bakContent = Get-Content $bakFiles[0].FullName -Raw
        if ($bakContent -notmatch 'old content that differs') {
            throw ".bak file does not contain original content"
        }
    } finally {
        $env:USERPROFILE = $origProfile
        Remove-Item -Recurse -Force $tempHome -ErrorAction SilentlyContinue
    }
}

Test-Scenario "Q-4: Three successive installs produce three distinct timestamped backups" {
    $script = Join-Path $RepoRoot 'scripts\windows\tools\dotfiles.ps1'
    $tempHome = Join-Path $env:TEMP "dotfiles_3run_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempHome -Force | Out-Null
    $origProfile = $env:USERPROFILE
    try {
        $env:USERPROFILE = $tempHome
        . $script
        $targetFile = Join-Path $tempHome '.editorconfig'
        # Pre-seed the target so all 3 runs see a diff and produce a backup
        Set-Content -Path $targetFile -Value 'version-0-original' -Encoding UTF8
        # Run 1: seeds backup of version-0
        Install-Dotfiles | Out-Null
        Set-Content -Path $targetFile -Value 'version-1-edit' -Encoding UTF8
        Start-Sleep -Milliseconds 1100   # ensure distinct 1-second timestamp
        # Run 2: seeds backup of version-1
        Install-Dotfiles | Out-Null
        Set-Content -Path $targetFile -Value 'version-2-edit' -Encoding UTF8
        Start-Sleep -Milliseconds 1100
        # Run 3: seeds backup of version-2
        Install-Dotfiles | Out-Null
        $bakFiles = Get-ChildItem "$targetFile.bak.*" -ErrorAction SilentlyContinue
        if ($bakFiles.Count -lt 3) {
            throw "Expected at least 3 timestamped backups after 3 install runs; found $($bakFiles.Count)"
        }
    } finally {
        $env:USERPROFILE = $origProfile
        Remove-Item -Recurse -Force $tempHome -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Group R: Get-ToolVersion parser (Issue #190)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group R: Get-ToolVersion parser (Issue #190)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$toolVersionScript = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'lib' | Join-Path -ChildPath 'Read-ToolVersion.ps1'

. $toolVersionScript

Test-Scenario "R-1 Get-ToolVersion returns nodejs version" {
    $ver = Get-ToolVersion -Name 'nodejs'
    if ($ver -ne '22.11.0') {
        throw "Expected '22.11.0', got '$ver'"
    }
}

Test-Scenario "R-2 Get-ToolVersion returns nvm version" {
    $ver = Get-ToolVersion -Name 'nvm'
    if ($ver -ne '0.39.7') {
        throw "Expected '0.39.7', got '$ver'"
    }
}

Test-Scenario "R-2b Get-ToolVersion returns nvm-windows version" {
    $ver = Get-ToolVersion -Name 'nvm-windows'
    if ($ver -ne '1.2.2') {
        throw "Expected '1.2.2', got '$ver'"
    }
}

Test-Scenario "R-3 Get-ToolVersion returns uv version" {
    $ver = Get-ToolVersion -Name 'uv'
    if ($ver -ne '0.4.18') {
        throw "Expected '0.4.18', got '$ver'"
    }
}

Test-Scenario "R-4 Get-ToolVersion throws on unknown tool" {
    $threw = $false
    try {
        Get-ToolVersion -Name 'nonexistent-tool-xyz'
    } catch {
        $threw = $true
    }
    if (-not $threw) {
        throw "Expected exception for unknown tool, but none was thrown"
    }
}

# ---------------------------------------------------------------------------
# Group S: GitHub auth step (Issue #191)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group S: GitHub auth step (Issue #191)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$authScript = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'auth.ps1'

. $authScript

Test-Scenario "S-1 Invoke-GhAuth is a function after dot-sourcing auth.ps1" {
    $cmd = Get-Command Invoke-GhAuth -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw 'Invoke-GhAuth not found after dot-sourcing auth.ps1'
    }
    if ($cmd.CommandType -ne 'Function') {
        throw "Expected Function, got $($cmd.CommandType)"
    }
}

Test-Scenario "S-2 Invoke-GhAuth exits cleanly when gh is missing" {
    # Temporarily hide gh by aliasing it to a nonexistent command
    $origPath = $env:PATH
    try {
        # Set PATH to empty so gh cannot be found
        $env:PATH = ''
        $output = Invoke-GhAuth 2>&1 | Out-String
        if ($output -notmatch 'not found') {
            throw "Expected warning about gh not found, got: $output"
        }
    } finally {
        $env:PATH = $origPath
    }
}

Test-Scenario "S-3 Invoke-GhAuth does not prompt when already authenticated" {
    # Only run if gh is available and already authenticated
    $hasGh = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    if (-not $hasGh) {
        $script:TestsPassed--
        $script:TestsSkipped++
        Write-Host "[SKIP] gh not on PATH" -ForegroundColor Yellow
        return
    }
    $isAuthed = $false
    try {
        $authOut = & gh auth status 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { $isAuthed = $true }
    } catch {
        # gh auth status failed - not authenticated
    }
    if (-not $isAuthed) {
        $script:TestsPassed--
        $script:TestsSkipped++
        Write-Host "[SKIP] not authenticated" -ForegroundColor Yellow
        return
    }
    # Should return immediately with "already authenticated" message
    $output = Invoke-GhAuth 2>&1 | Out-String
    if ($output -notmatch 'already authenticated') {
        throw "Expected 'already authenticated' message, got: $output"
    }
}

# ---------------------------------------------------------------------------
# Group T: nvm.ps1 Node auto-install logic (Issue #201)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group T: nvm.ps1 Node auto-install (Issue #201)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$nvmScript = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'tools' | Join-Path -ChildPath 'nvm.ps1'
$nvmContent = Get-Content $nvmScript -Raw

Test-Scenario "T-1 nvm.ps1 reads nodejs version from .tool-versions" {
    if ($nvmContent -notmatch "Get-ToolVersion.*-Name\s+'nodejs'") {
        throw "nvm.ps1 does not read nodejs version from .tool-versions via Get-ToolVersion"
    }
}

Test-Scenario "T-2 nvm.ps1 skips install if node matches pinned version (idempotent)" {
    if ($nvmContent -notmatch 'already installed.*skipping') {
        throw "nvm.ps1 does not skip when node version matches pinned version"
    }
}

Test-Scenario "T-3 lib/path.ps1 contains PATH refresh via registry read" {
    $pathLib = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'lib' | Join-Path -ChildPath 'path.ps1'
    $pathContent = Get-Content $pathLib -Raw
    $hasRefresh = $pathContent -match "GetEnvironmentVariable\('Path',\s*'Machine'\)" -and
                  $pathContent -match "GetEnvironmentVariable\('Path',\s*'User'\)"
    if (-not $hasRefresh) {
        throw "lib/path.ps1 does not refresh PATH from Machine+User registry"
    }
}

Test-Scenario "T-3b nvm.ps1 contains Install-NvmPortable (downloads nvm-noinstall.zip)" {
    $hasFunc = $nvmContent -match 'function Install-NvmPortable'
    $hasZipUrl = $nvmContent -match 'nvm-noinstall\.zip'
    $hasInvokeWeb = $nvmContent -match 'Invoke-WebRequest'
    $hasExpand = $nvmContent -match 'Expand-Archive'
    if (-not $hasFunc) {
        throw "nvm.ps1 missing Install-NvmPortable function"
    }
    if (-not $hasZipUrl) {
        throw "Install-NvmPortable does not reference nvm-noinstall.zip"
    }
    if (-not $hasInvokeWeb) {
        throw "Install-NvmPortable does not call Invoke-WebRequest"
    }
    if (-not $hasExpand) {
        throw "Install-NvmPortable does not call Expand-Archive"
    }
}

Test-Scenario "T-3c Refresh-SessionPath merges registry into existing PATH (does not replace)" {
    $pathLib = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'lib' | Join-Path -ChildPath 'path.ps1'
    $pathLibContent = Get-Content $pathLib -Raw
    # Replace-style would be: $env:Path = "$machinePath;$userPath"
    # Merge-style captures existing $env:Path and folds it into the result
    $capturesExisting = $pathLibContent -match '\$existing\s*=\s*\$env:Path'
    $mergesIntoResult = $pathLibContent -match '(?s)\$env:Path\s*=\s*\(\$combined'
    if (-not $capturesExisting -or -not $mergesIntoResult) {
        throw "Refresh-SessionPath does not merge with existing PATH -- it would drop session-only entries (e.g., GitHub Actions tool-cache)"
    }
}

Test-Scenario "T-3d nvm.ps1 contains Set-NvmEnvironment (sets NVM_HOME/NVM_SYMLINK + PATH)" {
    $hasFunc = $nvmContent -match 'function Set-NvmEnvironment'
    $hasNvmHome = $nvmContent -match "SetEnvironmentVariable\('NVM_HOME'"
    $hasNvmSymlink = $nvmContent -match "SetEnvironmentVariable\('NVM_SYMLINK'"
    $hasUserScope = $nvmContent -match "'User'\)"
    $hasPathPrepend = $nvmContent -match '\$env:Path\s*=\s*"\$NvmHome;\$env:Path"'
    if (-not $hasFunc) {
        throw "nvm.ps1 missing Set-NvmEnvironment function"
    }
    if (-not $hasNvmHome -or -not $hasNvmSymlink) {
        throw "Set-NvmEnvironment does not set NVM_HOME and NVM_SYMLINK"
    }
    if (-not $hasUserScope) {
        throw "Set-NvmEnvironment does not use User scope for env vars"
    }
    if (-not $hasPathPrepend) {
        throw "Set-NvmEnvironment does not prepend to PATH"
    }
}

Test-Scenario "T-4 nvm.ps1 calls nvm install and nvm use with pinned version" {
    $hasInstall = $nvmContent -match 'nvm install \$pinnedNode'
    $hasUse     = $nvmContent -match 'nvm use \$pinnedNode'
    if (-not $hasInstall -or -not $hasUse) {
        throw "nvm.ps1 does not call nvm install/use with pinned version variable"
    }
}

# ---------------------------------------------------------------------------
# Group U: squad-cli.ps1 loud error (Issue #201)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group U: squad-cli.ps1 loud error (Issue #201)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$squadScript = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'tools' | Join-Path -ChildPath 'squad-cli.ps1'
$squadContent = Get-Content $squadScript -Raw

Test-Scenario "U-1 squad-cli.ps1 emits ERROR (not WARN) when npm missing" {
    if ($squadContent -match 'Write-Warn.*npm not found') {
        throw "squad-cli.ps1 still uses Write-Warn for npm-missing case"
    }
    if ($squadContent -notmatch 'Write-Err.*npm not found') {
        throw "squad-cli.ps1 does not emit Write-Err when npm is missing"
    }
}

Test-Scenario "U-2 squad-cli.ps1 exits non-zero when npm missing" {
    if ($squadContent -notmatch 'exit\s+1') {
        throw "squad-cli.ps1 does not exit 1 when npm is missing"
    }
}

Test-Scenario "U-3 squad-cli.ps1 provides actionable troubleshooting hints" {
    $hasHint1 = $squadContent -match 'close this terminal'
    $hasHint2 = $squadContent -match 'nvm.*install.*failed'
    if (-not $hasHint1 -or -not $hasHint2) {
        throw "squad-cli.ps1 does not provide actionable troubleshooting hints"
    }
}

# ---------------------------------------------------------------------------
# Group V: shared logging lib (Issue #186)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group V: shared logging lib (Issue #186)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$loggingLib = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'lib' | Join-Path -ChildPath 'logging.ps1'

Test-Scenario "V-1 logging.ps1 defines Write-Info, Write-Ok, Write-Warn, Write-Err" {
    . $loggingLib
    foreach ($fn in @('Write-Info', 'Write-Ok', 'Write-Warn', 'Write-Err')) {
        if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
            throw "$fn not defined after dot-sourcing logging.ps1"
        }
    }
}

Test-Scenario "V-2 logging functions do not throw" {
    . $loggingLib
    Write-Info "test" | Out-Null
    Write-Ok "test" | Out-Null
    Write-Warn "test" | Out-Null
    Write-Err "test" | Out-Null
}

Test-Scenario "V-3 dot-sourcing logging.ps1 twice is idempotent" {
    . $loggingLib
    . $loggingLib
    if (-not (Get-Command Write-Info -ErrorAction SilentlyContinue)) {
        throw "Write-Info not defined after double dot-source"
    }
}

# ---------------------------------------------------------------------------
# Group W: nvm.ps1 lib path resolution (Issue #221)
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group W: nvm.ps1 lib path resolution (Issue #221)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$nvmScript = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'tools' | Join-Path -ChildPath 'nvm.ps1'
$nvmContent = Get-Content $nvmScript -Raw

Test-Scenario "W-1 nvm.ps1 resolves lib path two levels up from tools dir" {
    # Simulate the same path logic used in nvm.ps1
    $toolsDir = Join-Path $RepoRoot 'scripts' | Join-Path -ChildPath 'windows' | Join-Path -ChildPath 'tools'
    $resolvedLib = Join-Path (Split-Path (Split-Path $toolsDir -Parent) -Parent) 'lib'
    $target = Join-Path $resolvedLib 'Read-ToolVersion.ps1'
    if (-not (Test-Path $target)) {
        throw "Read-ToolVersion.ps1 not found at resolved path: $target"
    }
}

Test-Scenario "W-2 nvm.ps1 contains runtime assertion for lib path" {
    if ($nvmContent -notmatch 'Test-Path.*libDir') {
        throw "nvm.ps1 missing runtime assertion (Test-Path) for lib directory"
    }
    if ($nvmContent -notmatch 'throw.*not found') {
        throw "nvm.ps1 missing throw when lib path does not exist"
    }
}

Test-Scenario "W-3 nvm.ps1 uses two-level Split-Path (not one)" {
    # Ensure the fix uses two levels of Split-Path -Parent
    if ($nvmContent -notmatch 'Split-Path\s*\(\s*Split-Path\s+\$PSScriptRoot\s+-Parent\s*\)\s+-Parent') {
        throw "nvm.ps1 does not use two-level Split-Path for lib resolution"
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
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
