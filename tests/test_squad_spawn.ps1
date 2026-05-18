#!/usr/bin/env pwsh
# tests/test_squad_spawn.ps1
# Tests for scripts/squad-spawn.ps1 (Issue #414)
#
# Covers:
#   A. Substitution: {name}, {N}, {worktree-path} replaced in output
#   B. Missing template exits 1
#   C. Idempotent: body already containing all 6 markers is not double-injected
#   D. Empty body exits 1
#   E. Missing body file exits 1
#
# Usage:
#   pwsh -File tests\test_squad_spawn.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptPath = Join-Path $RepoRoot 'scripts\squad-spawn.ps1'

# Temp directory for test fixtures (cleaned up on exit)
$TmpDir = Join-Path $RepoRoot "tests\.tmp_squad_spawn_$PID"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

function Remove-TmpDir {
    if (Test-Path -LiteralPath $TmpDir) {
        Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Register cleanup
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Remove-TmpDir } -ErrorAction SilentlyContinue

function Test-Scenario {
    param([string]$Name, [scriptblock]$Test)
    Write-Host ""
    Write-Host "=== TEST: $Name ===" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "PASS: $Name" -ForegroundColor Green
        $script:TestsPassed++
    } catch {
        Write-Host "FAIL: $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ---------------------------------------------------------------------------
# Test A: Substitutions are applied correctly
# ---------------------------------------------------------------------------

Test-Scenario 'substitution replaces name, issue, and worktree-path in output' {
    $bodyFile = Join-Path $TmpDir 'body_a.md'
    [System.IO.File]::WriteAllText($bodyFile, "Spawn Donald to work on issue 123.", [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --body $bodyFile --name donald --issue 123 --worktree 'C:\Coding\dev-setup-123' 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) { throw "Expected exit 0, got $LASTEXITCODE" }
    if ($output -match '\{name\}')         { throw "{name} placeholder not substituted" }
    if ($output -match '\{N\}')            { throw "{N} placeholder not substituted" }
    if ($output -match '\{worktree-path\}') { throw "{worktree-path} placeholder not substituted" }
    if ($output -notmatch 'donald')        { throw "agent name 'donald' not found in output" }
    if ($output -notmatch '123')           { throw "issue number '123' not found in output" }
    if ($output -notmatch [regex]::Escape('C:\Coding\dev-setup-123')) {
        throw "worktree path not found in output"
    }
    # Output must contain all 6 hygiene tail markers
    foreach ($m in @('CWD-pin','base=develop discipline','ASCII discipline',
                      'history.md pre-size-check','Worktree-remove-FIRST','Hygiene tail completion')) {
        if ($output.IndexOf($m) -lt 0) { throw "Marker '$m' not found in output" }
    }
}

# ---------------------------------------------------------------------------
# Test B: Missing template exits 1 with error message
# ---------------------------------------------------------------------------

Test-Scenario 'missing template exits 1 with error message' {
    $bodyFile = Join-Path $TmpDir 'body_b.md'
    [System.IO.File]::WriteAllText($bodyFile, "Some spawn body.", [System.Text.Encoding]::ASCII)

    $fakeTpl = Join-Path $TmpDir 'nonexistent-template.md'

    $output = pwsh -File $ScriptPath --body $bodyFile --template $fakeTpl 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    if ($output -notmatch 'Template not found') { throw "Error message missing; got: $output" }
}

# ---------------------------------------------------------------------------
# Test C: Idempotent -- body already contains all 6 markers is not re-injected
# ---------------------------------------------------------------------------

Test-Scenario 'idempotent: all-6-marker body is not double-injected' {
    $fullBody = @"
Spawn goofy for issue 42.

### Hygiene Tail -- MANDATORY (do not omit any item)

**1. CWD-pin -- before every file write**
Run and PASS before touching any file.

**2. base=develop discipline**
Every gh pr create MUST pass --base develop explicitly.

**3. ASCII discipline -- after every file write**
0 non-ASCII bytes in every committed file.

**4. history.md pre-size-check -- before every append**
Check size before appending.

**5. Worktree-remove-FIRST cleanup -- after PR merges**
From the MAIN checkout, harvest then remove worktree.

**6. Hygiene tail completion**
Append history.md entry when done.
"@
    $bodyFile = Join-Path $TmpDir 'body_c.md'
    [System.IO.File]::WriteAllText($bodyFile, $fullBody, [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --body $bodyFile --name goofy --issue 42 --worktree 'C:\Coding\dev-setup-42' 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Expected exit 0, got $LASTEXITCODE" }

    # Count occurrences of the first marker -- must appear exactly once
    $markerText = 'CWD-pin -- before every file write'
    $count = 0
    $idx = 0
    while ($true) {
        $idx = $output.IndexOf($markerText, $idx)
        if ($idx -lt 0) { break }
        $count++
        $idx++
    }
    if ($count -ne 1) { throw "Marker appeared $count times (expected 1); hygiene tail was double-injected" }
}

# ---------------------------------------------------------------------------
# Test D: Empty body exits 1
# ---------------------------------------------------------------------------

Test-Scenario 'empty body file exits 1' {
    $bodyFile = Join-Path $TmpDir 'body_d.md'
    [System.IO.File]::WriteAllText($bodyFile, '   ', [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --body $bodyFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    if ($output -notmatch 'empty') { throw "Expected 'empty' in error output; got: $output" }
}

# ---------------------------------------------------------------------------
# Test E: Missing body file exits 1
# ---------------------------------------------------------------------------

Test-Scenario 'missing body file exits 1' {
    $noFile = Join-Path $TmpDir 'no-such-body.md'

    $output = pwsh -File $ScriptPath --body $noFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    if ($output -notmatch 'not found') { throw "Expected 'not found' in error output; got: $output" }
}

# ---------------------------------------------------------------------------
# Cleanup and summary
# ---------------------------------------------------------------------------

Remove-TmpDir

Write-Host ""
Write-Host "==========================================" -ForegroundColor White
Write-Host "Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'White' })
Write-Host "==========================================" -ForegroundColor White

if ($TestsFailed -gt 0) {
    Write-Host "TESTS FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "All tests PASSED" -ForegroundColor Green
exit 0
