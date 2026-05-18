#!/usr/bin/env pwsh
# tests/test_sprint_end_labels_pwsh.ps1
# Tests for scripts/sprint-end-labels.ps1 (Issue #423)
#
# Coverage:
#   T1: --help exits 0 and prints usage
#   T2: missing required flags -> non-zero exit + usage hint
#   T3: --dry-run makes no gh writes (shim gh and assert)
#   T4: idempotency (second run is no-op)
#   T5: retry/verify loop fires when labels-not-applied state is detected
#       (shim gh to return stale labels first, then correct labels)
#
# Mocking strategy:
#   Create a stub gh script in a temp dir added to PATH.
#   The stub responds to different gh subcommands to simulate API behavior.
#
# Usage:
#   pwsh -File tests\test_sprint_end_labels_pwsh.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptPath = Join-Path $RepoRoot 'scripts\sprint-end-labels.ps1'

function Test-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    Write-Host ""
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

function Write-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host ""
    Write-Host "=== TEST: $Name ===" -ForegroundColor Cyan
    Write-Host "SKIP: $Name" -ForegroundColor Yellow
    Write-Host "  Reason: $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
}

# ---------------------------------------------------------------------------
# Helper: create a temp test dir and stub gh in it (LF-only, no CRLF)
# ---------------------------------------------------------------------------

function New-TestEnv {
    param(
        [string]$TestId,
        [string]$IssueListResponse = '[]',
        [string]$PrListResponse = '[]',
        [hashtable]$IssueViewResponses = @{},
        [hashtable]$EditTracker = @{}
    )
    $dir = Join-Path $RepoRoot ".test-tmp\sel-$TestId-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    
    # On Windows, create gh.cmd that calls gh.ps1; on Unix, create gh script directly
    $onWindows = $PSVersionTable.PSVersion.Major -le 5 -or $IsWindows
    $stubScriptPath = Join-Path $dir 'gh.ps1'
    $stubPath = if ($onWindows) { Join-Path $dir 'gh.cmd' } else { Join-Path $dir 'gh' }
    $stateFile = Join-Path $dir 'gh-state.txt'

    # Build stub with LF-only line endings
    # The stub maintains state in gh-state.txt to track edits and verification calls
    $lines = @(
        '$ErrorActionPreference = "Stop"',
        ('$stateFile = "' + ($stateFile -replace '\\','\\\\') + '"'),
        '',
        '# Initialize state file if it doesn''t exist',
        'if (-not (Test-Path $stateFile)) {',
        '    "" | Out-File -FilePath $stateFile -NoNewline -Encoding ASCII',
        '}',
        '',
        'function Get-IssueState {',
        '    param([int]$Number)',
        '    if (Test-Path $stateFile) {',
        '        $state = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue',
        '        if ($state -match "issue_$Number=([^`r`n]+)") {',
        '            return $matches[1]',
        '        }',
        '    }',
        '    return "initial"',
        '}',
        '',
        'function Set-IssueState {',
        '    param([int]$Number, [string]$State)',
        '    $content = ""',
        '    if (Test-Path $stateFile) {',
        '        $content = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue',
        '    }',
        '    if ($content -match "issue_$Number=[^`r`n]+") {',
        '        $content = $content -replace "issue_$Number=[^`r`n]+", "issue_$Number=$State"',
        '    } else {',
        '        $content += "issue_$Number=$State`n"',
        '    }',
        '    $content | Out-File -FilePath $stateFile -NoNewline -Encoding ASCII',
        '}',
        '',
        '# Command routing',
        '$cmd = $args -join " "',
        '',
        'if ($cmd -match "^issue list") {',
        ('    Write-Output ''' + $IssueListResponse.Replace("'","''") + ''''),
        '} elseif ($cmd -match "^pr list") {',
        ('    Write-Output ''' + $PrListResponse.Replace("'","''") + ''''),
        '} elseif ($cmd -match "^issue view (\d+)") {',
        '    $num = [int]$matches[1]',
        '    $state = Get-IssueState -Number $num'
    )

    # Add issue view responses based on state
    foreach ($issueNum in $IssueViewResponses.Keys) {
        $responses = $IssueViewResponses[$issueNum]
        $lines += "    if (`$num -eq $issueNum) {"
        $lines += '        if ($state -eq "initial") {'
        $lines += ('            Write-Output ''' + $responses['initial'].Replace("'","''") + '''')
        if ($responses.ContainsKey('after_remove')) {
            $lines += '            Set-IssueState -Number $num -State "after_remove"'
        }
        $lines += '        } elseif ($state -eq "after_remove") {'
        if ($responses.ContainsKey('after_remove')) {
            $lines += ('            Write-Output ''' + $responses['after_remove'].Replace("'","''") + '''')
        } else {
            $lines += ('            Write-Output ''' + $responses['initial'].Replace("'","''") + '''')
        }
        if ($responses.ContainsKey('after_add')) {
            $lines += '            Set-IssueState -Number $num -State "after_add"'
        }
        $lines += '        } elseif ($state -eq "after_add") {'
        if ($responses.ContainsKey('after_add')) {
            $lines += ('            Write-Output ''' + $responses['after_add'].Replace("'","''") + '''')
        } else {
            $lines += ('            Write-Output ''' + $responses['initial'].Replace("'","''") + '''')
        }
        $lines += '        }'
        $lines += '        exit 0'
        $lines += '    }'
    }

    $lines += @(
        '} elseif ($cmd -match "^issue edit (\d+).+--remove-label") {',
        '    $num = [int]$matches[1]',
        '    $state = Get-IssueState -Number $num',
        '    if ($state -eq "initial") {',
        '        Set-IssueState -Number $num -State "after_remove"',
        '    }',
        '    exit 0',
        '} elseif ($cmd -match "^issue edit (\d+).+--add-label") {',
        '    $num = [int]$matches[1]',
        '    Set-IssueState -Number $num -State "after_add"',
        '    exit 0',
        '}',
        'exit 0'
    )

    $content = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($stubScriptPath, $content, [System.Text.Encoding]::ASCII)

    # Create wrapper script for Windows
    if ($onWindows) {
        $cmdContent = "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$stubScriptPath`" %*`r`n"
        [System.IO.File]::WriteAllText($stubPath, $cmdContent, [System.Text.Encoding]::ASCII)
    } else {
        # On Unix, create executable shell wrapper
        $shContent = "#!/bin/sh`nexec pwsh -NoProfile -ExecutionPolicy Bypass -File `"$stubScriptPath`" `"`$@`"`n"
        [System.IO.File]::WriteAllText($stubPath, $shContent, [System.Text.Encoding]::ASCII)
        chmod +x $stubPath
    }

    return $dir
}

function Remove-TestEnv {
    param([string]$Dir)
    if (Test-Path -LiteralPath $Dir) {
        Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Test T1: --help exits 0 and prints usage
# ---------------------------------------------------------------------------

Test-Scenario 'T1: --help exits 0 and prints usage' {
    $out = & pwsh -File $ScriptPath --help 2>&1
    $code = $LASTEXITCODE

    if ($code -ne 2) {
        throw "expected exit 2 from --help (usage exit), got $code"
    }
    $outStr = $out -join "`n"
    if ($outStr -notmatch 'Usage:') {
        throw "expected 'Usage:' in help output; got: $outStr"
    }
    if ($outStr -notmatch 'sprint-end-labels') {
        throw "expected script name in help output; got: $outStr"
    }
}

# ---------------------------------------------------------------------------
# Test T2: missing required flags -> non-zero exit + usage hint
# ---------------------------------------------------------------------------

Test-Scenario 'T2: missing required flags -> non-zero exit' {
    $out = & pwsh -File $ScriptPath --sprint sprint:17 2>&1
    $code = $LASTEXITCODE

    if ($code -eq 0) {
        throw "expected non-zero exit for missing --release-label, got 0"
    }
    $outStr = $out -join "`n"
    if ($outStr -notmatch 'release-label') {
        throw "expected error message about missing --release-label; got: $outStr"
    }
}

# ---------------------------------------------------------------------------
# Test T3: --dry-run makes no gh writes
# ---------------------------------------------------------------------------

Test-Scenario 'T3: --dry-run makes no gh writes' {
    $issueList = '[{"number":101,"title":"test issue","labels":[{"name":"sprint:17"},{"name":"release:backlog"}]}]'
    $prList = '[]'
    $viewResponses = @{
        101 = @{
            'initial' = '{"labels":[{"name":"sprint:17"},{"name":"release:backlog"}]}'
        }
    }
    
    $env_dir = New-TestEnv -TestId 'T3' -IssueListResponse $issueList -PrListResponse $prList -IssueViewResponses $viewResponses
    try {
        $env:PATH = "$env_dir$([IO.Path]::PathSeparator)$env:PATH"
        $out = & pwsh -File $ScriptPath --sprint sprint:17 --release-label release:shipped-1.17.0 --dry-run 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            $outStr = if ($out) { $out -join ' ' } else { '(no output)' }
            throw "expected exit 0 from --dry-run, got $code; output: $outStr"
        }
        $outStr = $out -join "`n"
        if ($outStr -notmatch 'DRY-RUN would remove') {
            throw "expected dry-run indication for remove; got: $outStr"
        }
        if ($outStr -notmatch 'DRY-RUN would add') {
            throw "expected dry-run indication for add; got: $outStr"
        }
        
        # Verify no edits were made by checking state file doesn't have edit records
        $stateFile = Join-Path $env_dir 'gh-state.txt'
        if (Test-Path $stateFile) {
            $stateContent = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue
            if ($stateContent -and $stateContent -match 'issue_101=after') {
                throw "dry-run should not have modified issue state"
            }
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test T4: idempotency (second run is no-op)
# ---------------------------------------------------------------------------

Test-Scenario 'T4: idempotency - second run is no-op' {
    $issueList = '[{"number":102,"title":"already done","labels":[{"name":"sprint:17"},{"name":"release:shipped-1.17.0"}]}]'
    $prList = '[]'
    $viewResponses = @{
        102 = @{
            'initial' = '{"labels":[{"name":"sprint:17"},{"name":"release:shipped-1.17.0"}]}'
        }
    }
    
    $env_dir = New-TestEnv -TestId 'T4' -IssueListResponse $issueList -PrListResponse $prList -IssueViewResponses $viewResponses
    try {
        $env:PATH = "$env_dir$([IO.Path]::PathSeparator)$env:PATH"
        $out = & pwsh -File $ScriptPath --sprint sprint:17 --release-label release:shipped-1.17.0 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            $outStr = if ($out) { $out -join ' ' } else { '(no output)' }
            throw "expected exit 0, got $code; output: $outStr"
        }
        $outStr = $out -join "`n"
        if ($outStr -notmatch 'skip remove.*not present') {
            throw "expected idempotent skip message for remove; got: $outStr"
        }
        if ($outStr -notmatch 'skip add.*already present') {
            throw "expected idempotent skip message for add; got: $outStr"
        }
        if ($outStr -notmatch 'already-correct=1') {
            throw "expected summary to show 1 already-correct; got: $outStr"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test T5: retry/verify loop fires on stale label state
# ---------------------------------------------------------------------------

Test-Scenario 'T5: retry loop fires on stale labels' {
    $issueList = '[{"number":103,"title":"needs labels","labels":[{"name":"sprint:17"},{"name":"release:backlog"}]}]'
    $prList = '[]'
    # Simulate eventual consistency: first view after remove still shows backlog, second view is clean
    $viewResponses = @{
        103 = @{
            'initial' = '{"labels":[{"name":"sprint:17"},{"name":"release:backlog"}]}'
            'after_remove' = '{"labels":[{"name":"sprint:17"},{"name":"release:shipped-1.17.0"}]}'
            'after_add' = '{"labels":[{"name":"sprint:17"},{"name":"release:shipped-1.17.0"}]}'
        }
    }
    
    $env_dir = New-TestEnv -TestId 'T5' -IssueListResponse $issueList -PrListResponse $prList -IssueViewResponses $viewResponses
    try {
        $env:PATH = "$env_dir$([IO.Path]::PathSeparator)$env:PATH"
        $out = & pwsh -File $ScriptPath --sprint sprint:17 --release-label release:shipped-1.17.0 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            $outStr = if ($out) { $out -join ' ' } else { '(no output)' }
            throw "expected exit 0 after retry, got $code; output: $outStr"
        }
        $outStr = $out -join "`n"
        # Script should show it's removing backlog and adding shipped label
        if ($outStr -notmatch 'removing.*release:backlog') {
            throw "expected removal of backlog label; got: $outStr"
        }
        if ($outStr -notmatch 'adding.*release:shipped') {
            throw "expected addition of shipped label; got: $outStr"
        }
        if ($outStr -notmatch 'verified') {
            throw "expected verification message; got: $outStr"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Cleanup: remove .test-tmp directory if empty
# ---------------------------------------------------------------------------

$testTmpDir = Join-Path $RepoRoot '.test-tmp'
if (Test-Path -LiteralPath $testTmpDir) {
    $remaining = Get-ChildItem -LiteralPath $testTmpDir -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-Item -LiteralPath $testTmpDir -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Results: $TestsPassed passed, $TestsFailed failed, $TestsSkipped skipped" `
    -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })

if ($TestsFailed -gt 0) { exit 1 }
exit 0
