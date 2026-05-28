#!/usr/bin/env pwsh
# tests/test_sprint_end_labels_pwsh.ps1
# Tests for scripts/sprint-end-labels.ps1 (Issue #423)
#
# Coverage:
#   T1. --help exits 0 and prints usage.
#   T2. Missing required flags exits non-zero with a usage hint.
#   T_C. Missing --release-label exits non-zero.
#   T_D. Bad --release-label prefix exits non-zero with guidance.
#   T3. --dry-run performs no gh writes.
#   T4. Running twice is idempotent; the second run is a no-op.
#   T5. Verification retry loop re-queries stale label state and succeeds.
#   T6. Verification retry loop fails loudly after 3 retries.
#   T7. Launcher is LF-only and keeps shebang bytes.
#
# Usage:
#   pwsh -File tests\test_sprint_end_labels_pwsh.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot       = Split-Path $PSScriptRoot -Parent
$ScriptPath     = Join-Path $RepoRoot 'scripts\sprint-end-labels.ps1'
$PowerShellPath = (Get-Process -Id $PID).Path

function Test-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host ''
    Write-Host "=== TEST: $Name ===" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "PASS: $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "FAIL: $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Write-AsciiFile {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::ASCII)
}

function ConvertTo-CompactJson {
    param($Value)

    return ($Value | ConvertTo-Json -Depth 10 -Compress)
}

function New-TestEnv {
    param(
        [string]$TestId,
        [hashtable]$State
    )

    $dir = Join-Path $RepoRoot ".test-tmp\sel-pwsh-$TestId-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $statePath = Join-Path $dir 'state.json'
    Write-AsciiFile -Path $statePath -Content (ConvertTo-CompactJson -Value $State)

    $stubPs1Path = Join-Path $dir 'gh.ps1'
    $stubPs1 = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

$ErrorActionPreference = 'Stop'
$statePath = $env:GH_STATE_PATH
$writeLog  = $env:GH_WRITE_LOG
$viewLog   = $env:GH_VIEW_LOG

if ([string]::IsNullOrWhiteSpace($statePath) -or -not (Test-Path -LiteralPath $statePath)) {
    Write-Host 'missing GH_STATE_PATH' -ForegroundColor Red
    exit 1
}

function Write-AsciiText {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.Encoding]::ASCII)
}

function Append-AsciiLine {
    param([string]$Path, [string]$Line)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    [System.IO.File]::AppendAllText($Path, $Line + "`n", [System.Text.Encoding]::ASCII)
}

function Load-State {
    $json = [System.IO.File]::ReadAllText($statePath)
    if ([string]::IsNullOrWhiteSpace($json)) {
        return @{}
    }
    return ($json | ConvertFrom-Json)
}

function Save-State {
    param($Value)
    Write-AsciiText -Path $statePath -Text ($Value | ConvertTo-Json -Depth 10 -Compress)
}

function Convert-Labels {
    param([string[]]$Labels)
    $result = @()
    foreach ($label in @($Labels)) {
        $result += @{ name = [string]$label }
    }
    return $result
}

function Get-CollectionName {
    param([string]$Number)
    foreach ($name in @('issues', 'prs')) {
        foreach ($item in @($script:state.$name)) {
            if ([string]$item.number -eq $Number) {
                return $name
            }
        }
    }
    return $null
}

function Get-ItemByNumber {
    param([string]$Number)
    foreach ($name in @('issues', 'prs')) {
        foreach ($item in @($script:state.$name)) {
            if ([string]$item.number -eq $Number) {
                return $item
            }
        }
    }
    return $null
}

function Remove-RepoArgs {
    param([string[]]$Arguments)
    $clean = @()
    $i = 0
    while ($i -lt $Arguments.Count) {
        if ($Arguments[$i] -eq '--repo') {
            $i += 2
            continue
        }
        $clean += $Arguments[$i]
        $i++
    }
    return $clean
}

function Get-QueueProperty {
    param([string]$Name)
    if ($null -eq $script:state.viewQueues) {
        return $null
    }
    foreach ($property in $script:state.viewQueues.PSObject.Properties) {
        if ($property.Name -eq $Name) {
            return $property
        }
    }
    return $null
}

$script:state = Load-State
$cleanArgs = @(Remove-RepoArgs -Arguments $Rest)
if ($cleanArgs.Count -lt 2) {
    exit 1
}

$command = $cleanArgs[0]
$subcommand = $cleanArgs[1]

switch ("$command $subcommand") {
    'issue list' {
        $items = @()
        foreach ($item in @($script:state.issues)) {
            if (@($item.labels) -contains $script:state.sprintLabel) {
                $items += @{
                    number = [int]$item.number
                    title  = [string]$item.title
                    labels = @(Convert-Labels -Labels @($item.labels))
                }
            }
        }
        Write-Output (ConvertTo-Json -InputObject @($items) -Depth 6 -Compress)
        exit 0
    }
    'pr list' {
        $items = @()
        foreach ($item in @($script:state.prs)) {
            if (@($item.labels) -contains $script:state.sprintLabel) {
                $items += @{
                    number = [int]$item.number
                    title  = [string]$item.title
                    labels = @(Convert-Labels -Labels @($item.labels))
                }
            }
        }
        Write-Output (ConvertTo-Json -InputObject @($items) -Depth 6 -Compress)
        exit 0
    }
    'issue view' {
        $number = [string]$cleanArgs[2]
        Append-AsciiLine -Path $viewLog -Line ("view:{0}" -f $number)
        $queueProperty = Get-QueueProperty -Name $number
        if ($null -ne $queueProperty) {
            $queue = @($queueProperty.Value)
            if ($queue.Count -gt 0) {
                $labels = @($queue[0])
                if ($queue.Count -gt 1) {
                    $remaining = @()
                    for ($j = 1; $j -lt $queue.Count; $j++) {
                        $remaining += ,@($queue[$j])
                    }
                    $queueProperty.Value = $remaining
                }
                else {
                    $script:state.viewQueues.PSObject.Properties.Remove($number)
                }
                Save-State -Value $script:state
                Write-Output (@{ labels = @(Convert-Labels -Labels $labels) } | ConvertTo-Json -Depth 6 -Compress)
                exit 0
            }
        }

        $item = Get-ItemByNumber -Number $number
        if ($null -eq $item) {
            exit 1
        }
        Write-Output (@{ labels = @(Convert-Labels -Labels @($item.labels)) } | ConvertTo-Json -Depth 6 -Compress)
        exit 0
    }
    'issue edit' {
        $number = [string]$cleanArgs[2]
        $item = Get-ItemByNumber -Number $number
        if ($null -eq $item) {
            exit 1
        }

        $labels = @($item.labels)
        $i = 3
        while ($i -lt $cleanArgs.Count) {
            switch ($cleanArgs[$i]) {
                '--add-label' {
                    $i++
                    $label = [string]$cleanArgs[$i]
                    if ($labels -notcontains $label) {
                        $labels += $label
                    }
                    Append-AsciiLine -Path $writeLog -Line ("add:{0}:{1}" -f $number, $label)
                }
                '--remove-label' {
                    $i++
                    $label = [string]$cleanArgs[$i]
                    $newLabels = @()
                    foreach ($existing in $labels) {
                        if ($existing -ne $label) {
                            $newLabels += $existing
                        }
                    }
                    $labels = $newLabels
                    Append-AsciiLine -Path $writeLog -Line ("remove:{0}:{1}" -f $number, $label)
                }
            }
            $i++
        }

        $collectionName = Get-CollectionName -Number $number
        $updated = @()
        foreach ($existing in @($script:state.$collectionName)) {
            if ([string]$existing.number -eq $number) {
                $updated += @{
                    number = [int]$existing.number
                    title  = [string]$existing.title
                    labels = @($labels)
                }
            }
            else {
                $updated += @{
                    number = [int]$existing.number
                    title  = [string]$existing.title
                    labels = @($existing.labels)
                }
            }
        }
        $script:state.$collectionName = $updated
        Save-State -Value $script:state
        Write-Output '{}'
        exit 0
    }
    default {
        exit 1
    }
}
'@
    Write-AsciiFile -Path $stubPs1Path -Content $stubPs1

    $launcherPath = Join-Path $dir 'gh'
    $launcher = @"
#!/usr/bin/env bash
set -e
DIR=`$(CDPATH= cd -- "`$(dirname -- "`$0")" && pwd)
exec "$PowerShellPath" -NoProfile -ExecutionPolicy Bypass -File "`$DIR/gh.ps1" "`$@"
"@
    Write-AsciiFile -Path $launcherPath -Content ($launcher.Replace("`r", ''))

    $cmdPath = Join-Path $dir 'gh.cmd'
    $cmdContent = "@echo off`r`n`"$PowerShellPath`" -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh.ps1`" %*`r`n"
    Write-AsciiFile -Path $cmdPath -Content $cmdContent

    $isWindowsRuntime = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    if (-not $isWindowsRuntime) {
        & chmod +x $launcherPath 2>$null | Out-Null
    }

    return $dir
}

function Remove-TestEnv {
    param([string]$Dir)

    if (Test-Path -LiteralPath $Dir) {
        Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ScriptRun {
    param(
        [string[]]$Arguments,
        [string]$EnvDir = ''
    )

    $savedPath     = $env:PATH
    $savedState    = $env:GH_STATE_PATH
    $savedWriteLog = $env:GH_WRITE_LOG
    $savedViewLog  = $env:GH_VIEW_LOG
    $savedErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'
        if ($EnvDir -ne '') {
            $env:PATH = $EnvDir + [System.IO.Path]::PathSeparator + $env:PATH
            $env:GH_STATE_PATH = Join-Path $EnvDir 'state.json'
            $env:GH_WRITE_LOG  = Join-Path $EnvDir 'writes.log'
            $env:GH_VIEW_LOG   = Join-Path $EnvDir 'views.log'
        }

        $output = & $PowerShellPath -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
    finally {
        $ErrorActionPreference = $savedErrorActionPreference
        $env:PATH = $savedPath
        if ($null -eq $savedState) {
            Remove-Item Env:GH_STATE_PATH -ErrorAction SilentlyContinue
        }
        else {
            $env:GH_STATE_PATH = $savedState
        }
        if ($null -eq $savedWriteLog) {
            Remove-Item Env:GH_WRITE_LOG -ErrorAction SilentlyContinue
        }
        else {
            $env:GH_WRITE_LOG = $savedWriteLog
        }
        if ($null -eq $savedViewLog) {
            Remove-Item Env:GH_VIEW_LOG -ErrorAction SilentlyContinue
        }
        else {
            $env:GH_VIEW_LOG = $savedViewLog
        }
    }
}

function Get-LogLines {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path)
}

Test-Scenario 'T1: --help exits 0 and prints usage' {
    $result = Invoke-ScriptRun -Arguments @('--help')
    if ($result.ExitCode -ne 0) {
        throw "expected exit 0, got $($result.ExitCode); output: $($result.Output)"
    }
    if ($result.Output -notmatch 'sprint-end-labels\.ps1') {
        throw "expected usage text in output; got: $($result.Output)"
    }
}

Test-Scenario 'T2: missing required flags exits non-zero with usage hint' {
    $result = Invoke-ScriptRun -Arguments @('--release-label', 'release:shipped-1.17.0')
    if ($result.ExitCode -eq 0) {
        throw 'expected non-zero exit for missing --sprint'
    }
    if ($result.Output -notmatch '--sprint <label> is required') {
        throw "expected missing --sprint guidance; got: $($result.Output)"
    }
    if ($result.Output -notmatch 'use --help for usage') {
        throw "expected usage hint; got: $($result.Output)"
    }
}

Test-Scenario 'T_C: missing --release-label exits 2 with guidance' {
    $result = Invoke-ScriptRun -Arguments @('--sprint', 'sprint:17')
    if ($result.ExitCode -ne 2) {
        throw "expected exit 2 for missing --release-label, got $($result.ExitCode); output: $($result.Output)"
    }
    if ($result.Output -notmatch '--release-label <label> is required') {
        throw "expected missing --release-label guidance; got: $($result.Output)"
    }
}

Test-Scenario 'T_D: bad release-label prefix exits 2 with guidance' {
    $result = Invoke-ScriptRun -Arguments @('--sprint', 'sprint:17', '--release-label', 'type:bogus', '--dry-run')
    if ($result.ExitCode -ne 2) {
        throw "expected exit 2 from bad release label, got $($result.ExitCode); output: $($result.Output)"
    }
    if ($result.Output -notmatch 'release:shipped-') {
        throw "expected guidance about release:shipped- prefix; got: $($result.Output)"
    }
}

Test-Scenario 'T3: --dry-run performs no gh writes' {
    $state = @{
        sprintLabel = 'sprint:17'
        issues = @(
            @{ number = 101; title = 'Closed issue'; labels = @('sprint:17', 'release:backlog', 'type:feature') }
        )
        prs = @(
            @{ number = 102; title = 'Merged PR'; labels = @('sprint:17', 'release:backlog', 'area:meta') }
        )
        viewQueues = @{}
    }
    $envDir = New-TestEnv -TestId 'dryrun' -State $state
    try {
        $result = Invoke-ScriptRun -EnvDir $envDir -Arguments @('--sprint', 'sprint:17', '--release-label', 'release:shipped-1.17.0', '--dry-run')
        if ($result.ExitCode -ne 0) {
            throw "expected exit 0, got $($result.ExitCode); output: $($result.Output)"
        }
        $writeLines = @(Get-LogLines -Path (Join-Path $envDir 'writes.log'))
        if ($writeLines.Count -ne 0) {
            throw "expected no gh writes during --dry-run; saw: $($writeLines -join ', ')"
        }
        if ($result.Output -notmatch 'DRY-RUN would remove: release:backlog') {
            throw "expected dry-run remove log; got: $($result.Output)"
        }
        if ($result.Output -notmatch 'DRY-RUN would add: release:shipped-1.17.0') {
            throw "expected dry-run add log; got: $($result.Output)"
        }
    }
    finally {
        Remove-TestEnv -Dir $envDir
    }
}

Test-Scenario 'T4: second run is idempotent and performs no new writes' {
    $state = @{
        sprintLabel = 'sprint:17'
        issues = @(
            @{ number = 201; title = 'Closed issue'; labels = @('sprint:17', 'release:backlog', 'type:feature') }
        )
        prs = @(
            @{ number = 202; title = 'Merged PR'; labels = @('sprint:17', 'area:meta') }
        )
        viewQueues = @{}
    }
    $envDir = New-TestEnv -TestId 'idempotent' -State $state
    try {
        $first = Invoke-ScriptRun -EnvDir $envDir -Arguments @('--sprint', 'sprint:17', '--release-label', 'release:shipped-1.17.0')
        if ($first.ExitCode -ne 0) {
            throw "first run failed: $($first.Output)"
        }

        $writePath = Join-Path $envDir 'writes.log'
        $writesAfterFirst = @(Get-LogLines -Path $writePath)
        if ($writesAfterFirst.Count -ne 3) {
            throw "expected 3 writes on first run, saw $($writesAfterFirst.Count): $($writesAfterFirst -join ', ')"
        }

        $second = Invoke-ScriptRun -EnvDir $envDir -Arguments @('--sprint', 'sprint:17', '--release-label', 'release:shipped-1.17.0')
        if ($second.ExitCode -ne 0) {
            throw "second run failed: $($second.Output)"
        }

        $writesAfterSecond = @(Get-LogLines -Path $writePath)
        if ($writesAfterSecond.Count -ne $writesAfterFirst.Count) {
            throw "expected no new writes on second run; before=$($writesAfterFirst.Count) after=$($writesAfterSecond.Count)"
        }
        if ($second.Output -notmatch 'skip remove: release:backlog not present') {
            throw "expected skip-remove idempotency log; got: $($second.Output)"
        }
        if ($second.Output -notmatch 'skip add: release:shipped-1.17.0 already present') {
            throw "expected skip-add idempotency log; got: $($second.Output)"
        }
    }
    finally {
        Remove-TestEnv -Dir $envDir
    }
}

Test-Scenario 'T5: retry loop re-queries stale label state and then succeeds' {
    $state = @{
        sprintLabel = 'sprint:17'
        issues = @(
            @{ number = 301; title = 'Retry issue'; labels = @('sprint:17') }
        )
        prs = @()
        viewQueues = @{
            '301' = @(
                @('sprint:17'),
                @('sprint:17'),
                @('sprint:17', 'release:shipped-1.17.0')
            )
        }
    }
    $envDir = New-TestEnv -TestId 'retry-success' -State $state
    try {
        $result = Invoke-ScriptRun -EnvDir $envDir -Arguments @('--sprint', 'sprint:17', '--release-label', 'release:shipped-1.17.0')
        if ($result.ExitCode -ne 0) {
            throw "expected retry case to succeed; output: $($result.Output)"
        }

        $viewLines = @(Get-LogLines -Path (Join-Path $envDir 'views.log'))
        if ($viewLines.Count -ne 3) {
            throw "expected 3 verification reads, saw $($viewLines.Count): $($viewLines -join ', ')"
        }
        if ($result.Output -notmatch 'retry in 1s') {
            throw "expected 1s retry log; got: $($result.Output)"
        }
        if ($result.Output -notmatch 'retry in 2s') {
            throw "expected 2s retry log; got: $($result.Output)"
        }
        if ($result.Output -notmatch "verified: #301 has 'release:shipped-1.17.0'") {
            throw "expected verification success log; got: $($result.Output)"
        }
    }
    finally {
        Remove-TestEnv -Dir $envDir
    }
}

Test-Scenario 'T6: retry loop fails loudly after 3 retries' {
    $state = @{
        sprintLabel = 'sprint:17'
        issues = @(
            @{ number = 401; title = 'Fail issue'; labels = @('sprint:17') }
        )
        prs = @()
        viewQueues = @{
            '401' = @(
                @('sprint:17'),
                @('sprint:17'),
                @('sprint:17'),
                @('sprint:17')
            )
        }
    }
    $envDir = New-TestEnv -TestId 'retry-fail' -State $state
    try {
        $result = Invoke-ScriptRun -EnvDir $envDir -Arguments @('--sprint', 'sprint:17', '--release-label', 'release:shipped-1.17.0')
        if ($result.ExitCode -eq 0) {
            throw "expected verification failure, got success; output: $($result.Output)"
        }
        if ($result.Output -notmatch 'verification FAILED for #401 after 3 retries') {
            throw "expected fail-loud message; got: $($result.Output)"
        }
        if ($result.Output -notmatch 'current labels:') {
            throw "expected current labels in failure output; got: $($result.Output)"
        }
    }
    finally {
        Remove-TestEnv -Dir $envDir
    }
}

Test-Scenario 'T7: launcher is LF-only and keeps shebang bytes' {
    $state = @{
        sprintLabel = 'sprint:17'
        issues = @()
        prs = @()
        viewQueues = @{}
    }
    $envDir = New-TestEnv -TestId 'launcher-lf' -State $state
    try {
        $launcherPath = Join-Path $envDir 'gh'
        $bytes = [System.IO.File]::ReadAllBytes($launcherPath)
        if ($bytes.Length -lt 2) {
            throw "launcher too short to contain shebang bytes; length=$($bytes.Length)"
        }
        # Regression for PR #438: the POSIX launcher must be LF-only.
        # Content is session-deterministic, not identical across machines.
        if ($bytes -contains 0x0D) {
            throw 'launcher contains CR bytes (0x0D); must be LF-only for POSIX bash'
        }
        if ($bytes[0] -ne 0x23 -or $bytes[1] -ne 0x21) {
            throw 'launcher missing shebang bytes 0x23 0x21 (#!); file header may be corrupted'
        }
    }
    finally {
        Remove-TestEnv -Dir $envDir
    }
}

$testTmpDir = Join-Path $RepoRoot '.test-tmp'
if (Test-Path -LiteralPath $testTmpDir) {
    $remaining = Get-ChildItem -LiteralPath $testTmpDir -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-Item -LiteralPath $testTmpDir -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ' Results' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host "Passed:  $TestsPassed" -ForegroundColor Green
Write-Host "Failed:  $TestsFailed" -ForegroundColor $(if ($TestsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host "Skipped: $TestsSkipped" -ForegroundColor Yellow

if ($TestsFailed -gt 0) { exit 1 }
exit 0
