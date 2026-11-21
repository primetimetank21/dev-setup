# Retirement regressions (#518). Compatible with Windows PowerShell 5.1.
# Real routers/resolvers execute in a private fixture with recording-only tool
# modules; no real installer, auth, network, host query, or session command runs.
# Actual profile writes use explicit private fallback paths and a non-forwarding
# host-query mock. This tests reviewed source, not a hostile-code sandbox.
# Usage: powershell -NoProfile -File tests\test_tool_retirement.ps1
# Set TEMP/TMP (TMPDIR on Unix) to select the disposable fixture parent.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TestsPassed = 0
$TestsFailed = 0
$RepoRoot = Split-Path $PSScriptRoot -Parent
$HostExe = (Get-Process -Id $PID).Path
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dev-setup-retirement-' + [guid]::NewGuid().ToString('N'))
$FixtureRepo = Join-Path $TempRoot 'repo'
$FixtureTools = Join-Path $FixtureRepo 'scripts\windows\tools'
$FixtureLib = Join-Path $FixtureRepo 'scripts\windows\lib'
$RunLog = Join-Path $TempRoot 'run.log'
$Retired = @('uv', 'squad-cli', 'squad', 'tmux', 'psmux')

function Test-Scenario {
    param([string]$Label, [scriptblock]$Test)
    try {
        & $Test
        Write-Host "PASS: $Label"
        $script:TestsPassed++
    } catch {
        Write-Host "FAIL: $Label -- $_"
        $script:TestsFailed++
    }
}
function Invoke-FixtureSetup {
    param([string]$Script, [string[]]$Arguments)
    # Redirect native stderr to a fixture file, preserving the actual child exit
    # even on PS 5.1, where native stderr under Stop can otherwise terminate early.
    $ErrorActionPreference = 'Continue'
    [System.IO.File]::WriteAllText($RunLog, '')
    $stderrFile = Join-Path $TempRoot 'stderr.txt'
    Push-Location $FixtureRepo
    try {
        $output = & $HostExe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Script @Arguments 2>$stderrFile | Out-String
        $status = $LASTEXITCODE
        $errorText = Get-Content -LiteralPath $stderrFile -Raw
        return @{ Output = $output; ErrorText = $errorText; Status = $status }
    } finally { Pop-Location }
}
function Assert-RunLog {
    param([string[]]$Expected)
    $actual = @(Get-Content -LiteralPath $RunLog)
    if (($actual -join ',') -cne ($Expected -join ',')) {
        throw "Dispatch order: expected [$($Expected -join ',')], got [$($actual -join ',')]"
    }
}

$savedEnvironment = @{}
foreach ($name in @('CI', 'HOME', 'USERPROFILE', 'RUN_LOG', 'FAIL_TOOL')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    New-Item -ItemType Directory -Path $FixtureTools, $FixtureLib, (Join-Path $TempRoot 'home') | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'setup.ps1') -Destination (Join-Path $FixtureRepo 'setup.ps1')
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\windows\setup.ps1') -Destination (Join-Path $FixtureRepo 'scripts\windows\setup.ps1')
    Copy-Item -Path (Join-Path $RepoRoot 'scripts\windows\lib\*.ps1') -Destination $FixtureLib
    # Extract only function NAMES from the AST. No production tool body is executed
    # or copied. The real registry and default array still run without -ToolsDir.
    foreach ($module in Get-ChildItem (Join-Path $RepoRoot 'scripts\windows\tools\*.ps1')) {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($module.FullName, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw "Tool module does not parse: $($module.Name)" }
        $functions = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true))
        if ($functions.Count -eq 0) { throw "No fixture function names in $($module.Name)" }
        $stub = foreach ($function in $functions) {
            @"
function $($function.Name) {
    Add-Content -LiteralPath `$env:RUN_LOG -Value '$($module.BaseName)' -Encoding ASCII
    if (`$env:FAIL_TOOL -eq '$($module.BaseName)') { throw 'fixture installer failure' }
}
"@
        }
        Set-Content -LiteralPath (Join-Path $FixtureTools $module.Name) -Value $stub -Encoding ASCII
    }
    $env:CI = 'true'
    $env:HOME = Join-Path $TempRoot 'home'
    $env:USERPROFILE = $env:HOME
    $env:RUN_LOG = $RunLog
    $env:FAIL_TOOL = ''

    Test-Scenario 'retired installer and generic fixture files are absent on both platforms' {
        foreach ($name in $Retired) {
            foreach ($relative in @("scripts/linux/tools/$name.sh", "scripts/windows/tools/$name.ps1",
                "tests/fixtures/stub-tools/linux/$name.sh", "tests/fixtures/stub-tools/windows/$name.ps1")) {
                if (Test-Path -LiteralPath (Join-Path $RepoRoot $relative)) { throw "Retired file remains: $relative" }
            }
        }
    }
    Test-Scenario 'retired profile helpers and indirect startup names are absent from source' {
        $content = Get-Content (Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1') -Raw
        if ($content -match 'uv|squad|tmux|psmux|start_up|tank_dev') {
            throw "Retired profile wiring remains: $($Matches[0])"
        }
    }
    . (Join-Path $RepoRoot 'scripts\lib\Read-ToolVersion.ps1')
    foreach ($name in $Retired) {
        Test-Scenario "retired pin rejected: $name" {
            $rejected = $false
            try { Get-ToolVersion -Name $name | Out-Null }
            catch {
                if ($_.Exception.Message -ne "Tool '$name' not found in .tool-versions") { throw }
                $rejected = $true
            }
            if (-not $rejected) { throw "Retired pin still exists: $name" }
        }
    }
    Test-Scenario 'retained pin still resolves' {
        if ((Get-ToolVersion -Name 'gh') -ne '2.92.0') { throw 'gh pin changed' }
    }

    $expectedAvailable = @('auth', 'copilot', 'copilot-cli', 'delta', 'dotfiles', 'gh', 'git', 'git-hook', 'herdr', 'lazygit', 'nvm', 'pi', 'profile', 'vim', 'winget-check')
    foreach ($entry in @('scripts\windows\setup.ps1', 'setup.ps1')) {
        $script = Join-Path $FixtureRepo $entry
        Test-Scenario "retained available list, no dispatch: $entry" {
            $result = Invoke-FixtureSetup -Script $script -Arguments @('-List')
            if ($result.Status -ne 0) { throw "List failed: $($result.Output) $($result.ErrorText)" }
            $names = @($result.Output -split '\r?\n' | Where-Object { $_ -and $_ -notmatch '^\[' })
            if (($names -join ',') -cne ($expectedAvailable -join ',')) {
                throw "Available tools changed: $($names -join ',')"
            }
            Assert-RunLog @()
        }
        foreach ($flag in @('-Only', '-Skip')) {
            foreach ($name in $Retired) {
                foreach ($selection in @($name, "gh,$name")) {
                    Test-Scenario "reject before dispatch: $entry $flag $selection" {
                        $result = Invoke-FixtureSetup -Script $script -Arguments @($flag, $selection)
                        if ($result.Status -ne 1 -or $result.Output -notmatch [regex]::Escape("Unknown tool: $name") -or
                            $result.Output -notmatch 'Available tools:') {
                            throw "Not normal unknown-tool rejection (exit $($result.Status)): $($result.Output) $($result.ErrorText)"
                        }
                        Assert-RunLog @()
                    }
                }
            }
        }
    }
    $rootScript = Join-Path $FixtureRepo 'setup.ps1'
    $expectedDefaults = @(Get-Content (Join-Path $RepoRoot 'tests\fixtures\baseline-tools-windows.txt'))
    foreach ($attempt in @(1, 2)) {
        Test-Scenario "recording-only default run $attempt preserves retained order" {
            $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-NonInteractive')
            if ($result.Status -ne 0) { throw "Default run failed: $($result.Output) $($result.ErrorText)" }
            Assert-RunLog $expectedDefaults
        }
    }
    Test-Scenario 'retained defaults stay ordered; opt-ins follow alphabetically' {
        $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-Only', 'pi,herdr,lazygit,delta,git-hook,gh,nvm')
        if ($result.Status -ne 0) { throw "Selection failed: $($result.Output)" }
        Assert-RunLog @('nvm', 'gh', 'git-hook', 'delta', 'herdr', 'lazygit', 'pi')
    }
    Test-Scenario 'copilot-cli registry alias still invokes the retained copilot module' {
        $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-Only', 'copilot-cli')
        if ($result.Status -ne 0) { throw "Alias selection failed: $($result.Output)" }
        Assert-RunLog @('copilot')
    }
    Test-Scenario 'retained exclusion preserves default order' {
        $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-Skip', 'auth,copilot')
        if ($result.Status -ne 0) { throw "Exclusion failed: $($result.Output)" }
        Assert-RunLog @('winget-check', 'git', 'nvm', 'gh', 'vim', 'dotfiles', 'profile', 'git-hook')
    }
    Test-Scenario 'installer failure stops dispatch and propagates through root' {
        $env:FAIL_TOOL = 'nvm'
        try {
            $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-NonInteractive')
            if ($result.Status -ne 1) { throw 'Installer failure was swallowed' }
            Assert-RunLog @('winget-check', 'git', 'nvm')
        } finally { $env:FAIL_TOOL = '' }
    }
    Test-Scenario 'repeat run after failure does not persist a partial selection' {
        $result = Invoke-FixtureSetup -Script $rootScript -Arguments @('-NonInteractive')
        if ($result.Status -ne 0) { throw 'Repeat run failed' }
        Assert-RunLog $expectedDefaults
    }

    # Use the ACTUAL profile writer, but never query a live host for $PROFILE.
    . (Join-Path $RepoRoot 'scripts\windows\tools\profile.ps1')
    function Invoke-HostQuery {
        param([string]$Exe)
        $global:LASTEXITCODE = 0
        return 'fixture-no-host-profile'
    }
    $retiredAliases = @('uvr', 'uvs', 'gosquad', 'tls', 'tks', 'tt', 'ta')
    foreach ($lineEnding in @('LF', 'CRLF')) {
        $eol = if ($lineEnding -eq 'LF') { "`n" } else { "`r`n" }
        # This block is never sourced. It models an old canonical managed block.
        $oldBlock = (@('# BEGIN dev-setup profile', "function Invoke-CopilotSquad { throw 'obsolete fixture' }",
            'Set-Alias gosquad Invoke-CopilotSquad', '# END dev-setup profile') -join $eol) + $eol
        foreach ($kind in @('fresh', 'empty', 'existing', 'legacy-at-start', 'legacy-prefixed', 'adjacent-blocks', 'interleaved-blocks', 'noncanonical')) {
            $profileDir = Join-Path $TempRoot "profiles-$lineEnding-$kind"
            New-Item -ItemType Directory -Path $profileDir | Out-Null
            $ps51 = Join-Path $profileDir 'ps51\Microsoft.PowerShell_profile.ps1'
            $ps7 = Join-Path $profileDir 'ps7\Microsoft.PowerShell_profile.ps1'
            $expectedUser = ''
            $seed = ''
            switch ($kind) {
                'existing' { $seed = '# retained user configuration'; $expectedUser = $seed }
                'legacy-at-start' {
                    $expectedUser = '# retained user configuration' + $eol
                    $seed = $oldBlock + $expectedUser
                }
                'legacy-prefixed' {
                    $expectedUser = '# retained prefix' + $eol + '# retained suffix' + $eol
                    $seed = '# retained prefix' + $eol + $oldBlock + '# retained suffix' + $eol
                }
                'adjacent-blocks' {
                    $expectedUser = '# retained suffix' + $eol
                    $seed = $oldBlock + $oldBlock + $expectedUser
                }
                'interleaved-blocks' {
                    $expectedUser = '# retained prefix' + $eol + '# retained middle' + $eol + '# retained suffix' + $eol
                    $seed = '# retained prefix' + $eol + $oldBlock + '# retained middle' + $eol + $oldBlock + '# retained suffix' + $eol
                }
                'noncanonical' {
                    $seed = '# user text mentions # BEGIN dev-setup profile inline' + $eol + '# END dev-setup profile inline' + $eol
                    $expectedUser = $seed
                }
            }
            if ($kind -ne 'fresh') {
                foreach ($profilePath in @($ps51, $ps7)) {
                    New-Item -ItemType Directory -Path (Split-Path $profilePath) | Out-Null
                    [IO.File]::WriteAllText($profilePath, $seed)
                }
            }
            foreach ($attempt in @(1, 2)) {
                Test-Scenario "private profile $lineEnding/$kind run $attempt replaces only managed blocks" {
                    Write-PowerShellProfile -Ps51Fallback $ps51 -Ps7Fallback $ps7 | Out-Null
                    foreach ($profilePath in @($ps51, $ps7)) {
                        $content = Get-Content -LiteralPath $profilePath -Raw
                        $blocks = [regex]::Matches($content, '(?m)^# BEGIN dev-setup profile\r?$')
                        if ($blocks.Count -ne 1) { throw "Duplicate/missing canonical block: $profilePath" }
                        if ($content -match 'uv|squad|tmux|psmux|tank_dev') { throw "Retired profile content remains: $($Matches[0])" }
                        $expectedPrefix = $expectedUser
                        if ($expectedUser.Length -gt 0) { $expectedPrefix += [Environment]::NewLine }
                        if ($content.Substring(0, $blocks[0].Index) -cne $expectedPrefix) {
                            throw "User bytes/line boundaries changed: $profilePath"
                        }
                        if ($attempt -eq 1) {
                            Copy-Item -LiteralPath $profilePath -Destination "$profilePath.first"
                        } elseif ($content -cne (Get-Content -LiteralPath "$profilePath.first" -Raw)) {
                            throw 'Repeat profile run changed bytes'
                        }
                    }
                }
            }
        }
        Test-Scenario "orphan cleanup $lineEnding strips all canonical blocks, preserving unrelated text" {
            $orphanDir = Join-Path $TempRoot "orphan-$lineEnding"
            New-Item -ItemType Directory -Path $orphanDir | Out-Null
            $resolvedProfile = Join-Path $orphanDir 'resolved.ps1'
            $fallback51 = Join-Path $orphanDir 'fallback51.ps1'
            $fallback7 = Join-Path $orphanDir 'fallback7.ps1'
            [IO.File]::WriteAllText($fallback51, $oldBlock + $oldBlock + '# retained suffix' + $eol)
            [IO.File]::WriteAllText($fallback7, '# retained prefix' + $eol + $oldBlock + '# retained suffix' + $eol)
            # Explicit resolver stub selects another PRIVATE path so both original
            # fallback paths exercise the actual writer's orphan-strip branch.
            function Resolve-ProfilePath {
                param([string]$HostExe, [string]$FallbackPath)
                return $resolvedProfile
            }
            foreach ($attempt in @(1, 2)) {
                Write-PowerShellProfile -Ps51Fallback $fallback51 -Ps7Fallback $fallback7 | Out-Null
                if ((Get-Content $fallback51 -Raw) -cne '# retained suffix') { throw 'Byte-zero duplicate orphan blocks not stripped cleanly' }
                if ((Get-Content $fallback7 -Raw) -cne ('# retained prefix' + $eol + '# retained suffix')) { throw 'Orphan strip changed unrelated line boundaries' }
                $content = Get-Content $resolvedProfile -Raw
                if (([regex]::Matches($content, '(?m)^# BEGIN dev-setup profile\r?$')).Count -ne 1) { throw 'Resolved private profile duplicated' }
            }
        }
    }
    # Regress combined removals: each expected boundary is literal fixture data,
    # not a result computed by the production strip algorithm. Additional blank
    # lines and space/tab-only lines outside matched blocks must not be normalized.
    foreach ($lineEnding in @('LF', 'CRLF')) {
        $eol = if ($lineEnding -eq 'LF') { "`n" } else { "`r`n" }
        $block = (@('# BEGIN dev-setup profile', '# obsolete managed fixture', '# END dev-setup profile') -join $eol) + $eol
        $separations = @(
            @{ Name = 'zero-blanks'; Blocks = $block + $block; Boundary = $eol }
            @{ Name = 'one-blank'; Blocks = $block + $eol + $block; Boundary = $eol }
            @{ Name = 'two-blanks'; Blocks = $block + $eol + $eol + $block; Boundary = $eol }
            @{ Name = 'four-blanks'; Blocks = $block + $eol + $eol + $eol + $eol + $block; Boundary = $eol + $eol + $eol }
            @{ Name = 'three-blocks'; Blocks = $block + $eol + $block + $eol + $block; Boundary = $eol }
            @{ Name = 'space-tab-blank'; Blocks = $block + " `t" + $eol + $block; Boundary = $eol + " `t" + $eol }
        )
        foreach ($separation in $separations) {
            foreach ($mode in @('update', 'orphan')) {
                Test-Scenario "combined profile removals $lineEnding/$($separation.Name)/$mode preserve exact user bytes across two writes" {
                    $caseDir = Join-Path $TempRoot "combined-$lineEnding-$($separation.Name)-$mode"
                    New-Item -ItemType Directory -Path $caseDir | Out-Null
                    $paths = @((Join-Path $caseDir 'fallback51.ps1'), (Join-Path $caseDir 'fallback7.ps1'))
                    $resolvedProfile = Join-Path $caseDir 'resolved.ps1'
                    $seed = 'before' + $eol + $separation.Blocks + 'after' + $eol
                    $expectedUser = 'before' + $separation.Boundary + 'after'
                    if ($mode -eq 'update') { $expectedUser += $eol + [Environment]::NewLine }
                    [IO.File]::WriteAllBytes((Join-Path $caseDir 'input.txt'), [Text.Encoding]::ASCII.GetBytes($seed))
                    [IO.File]::WriteAllBytes((Join-Path $caseDir 'expected-user-bytes.txt'), [Text.Encoding]::ASCII.GetBytes($expectedUser))
                    foreach ($path in $paths) { [IO.File]::WriteAllBytes($path, [Text.Encoding]::ASCII.GetBytes($seed)) }
                    function Resolve-ProfilePath {
                        param([string]$HostExe, [string]$FallbackPath)
                        if ($mode -eq 'orphan') { return $resolvedProfile }
                        return $FallbackPath
                    }
                    function Invoke-HostQuery { throw 'Unexpected host query in combined-removal fixture' }
                    $first = @{}
                    $problems = @()
                    foreach ($attempt in @(1, 2)) {
                        Write-PowerShellProfile -Ps51Fallback $paths[0] -Ps7Fallback $paths[1] | Out-Null
                        foreach ($path in $paths) {
                            $bytes = [IO.File]::ReadAllBytes($path)
                            $content = [Text.Encoding]::ASCII.GetString($bytes)
                            $actualUser = $content
                            $markers = [regex]::Matches($content, '(?m)^# BEGIN dev-setup profile\r?$')
                            if ($mode -eq 'update' -and $markers.Count -eq 1) {
                                $actualUser = $content.Substring(0, $markers[0].Index)
                            } elseif ($mode -eq 'update' -or $markers.Count -ne 0) {
                                $problems += "Unexpected canonical block count in $path run $attempt"
                            }
                            [IO.File]::WriteAllBytes("$path.run$attempt.actual-user-bytes.txt", [Text.Encoding]::ASCII.GetBytes($actualUser))
                            if ($actualUser -cne $expectedUser) { $problems += "User byte mismatch in $path run $attempt" }
                            $encoded = [Convert]::ToBase64String($bytes)
                            if ($attempt -eq 1) { $first[$path] = $encoded }
                            elseif ($encoded -cne $first[$path]) { $problems += "Repeat write changed bytes in $path" }
                        }
                    }
                    if ($problems.Count -gt 0) { throw ($problems -join '; ') }
                }
            }
        }
    }
    Test-Scenario 'generated profile retains aliases and removes retired definitions (load only)' {
        # Profiles load at session scope. Test-Scenario adds a function scope,
        # which would remove a local alias then try to replace a global AllScope
        # alias on Windows. A disposable runspace models actual startup and keeps
        # all generated definitions out of the surrounding test session.
        $profilePath = Join-Path $TempRoot 'profiles-LF-existing\ps51\Microsoft.PowerShell_profile.ps1'
        $profileCheck = @'
param([string]$FixtureProfilePath, [string[]]$RetiredAliasNames)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Exercise Windows' built-in alias semantics even on Linux PowerShell.
Set-Alias -Name rm -Value Remove-Item -Option AllScope -Scope Global -Force
. $FixtureProfilePath
foreach ($name in $RetiredAliasNames) {
    if (Get-Alias -Name $name -ErrorAction SilentlyContinue) { throw "Retired alias defined: $name" }
}
foreach ($name in @('Invoke-UvRun', 'Invoke-UvSync', 'Invoke-CopilotSquad', 'Invoke-PsmuxList', 'Invoke-PsmuxKillServer', 'Invoke-PsmuxNewSession', 'Invoke-PsmuxAttach', 'New-PsmuxSession')) {
    if (Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue) { throw "Retired function defined: $name" }
}
$expectedAliases = @{
    rm = 'Remove-CustomItem'
    ni = 'Invoke-NpmInstall'; nr = 'Invoke-NpmRun'; nrd = 'Invoke-NpmRunDev'; nrt = 'Invoke-NpmRunTest'
    gs = 'Get-GitStatus'; ghpr = 'New-GhPR'; py = 'Invoke-Python'; c = 'Clear-Host'
    ep = 'Edit-Profile'; sdn = 'Invoke-ShutdownNow'; tsdn = 'Invoke-TimedShutdown'; cancel_tsdn = 'Invoke-CancelTimedShutdown'
}
foreach ($name in $expectedAliases.Keys) {
    if ((Get-Alias -Name $name).Definition -ne $expectedAliases[$name]) { throw "Retained alias changed: $name" }
}
'profile-check-passed'
'@
        $profileShell = [PowerShell]::Create()
        try {
            $null = $profileShell.AddScript($profileCheck, $false).AddArgument($profilePath).AddArgument($retiredAliases)
            $loadOutput = @($profileShell.Invoke())
            # Expected absence probes can set HadErrors. Require explicit
            # completion; any terminating load/assertion error prevents it.
            if ($loadOutput.Count -ne 1 -or $loadOutput[0].ToString() -cne 'profile-check-passed') {
                throw ('Isolated profile startup did not complete: ' + ($profileShell.Streams.Error | Out-String))
            }
        } finally {
            $profileShell.Dispose()
        }
    }
} catch {
    $TestsFailed++
    Write-Host "FAIL: fixture setup/execution -- $_"
} finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    if ($TestsFailed -eq 0) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
        if (Test-Path -LiteralPath $TempRoot) { throw "Fixture cleanup failed: $TempRoot" }
        Write-Host "Removed owned retirement fixture: $TempRoot"
    } else {
        Write-Host "Failure evidence retained: $TempRoot"
    }
}
Write-Host "Results: $TestsPassed passed, $TestsFailed failed"
if ($TestsFailed -gt 0) { exit 1 }
exit 0
