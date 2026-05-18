#!/usr/bin/env pwsh
# tests/test_spawn_prompt_lint.ps1
# Tests for scripts/lint-spawn-prompt.ps1 (Issue #414)
#
# Covers:
#   A. All 6 markers present -- exits 0 with OK message
#   B. One marker missing -- exits 1 and names the missing marker
#   C. All markers missing -- exits 1 and lists all 6
#   D. File not found -- exits 1 with error message
#   E. Unknown argument -- exits 1
#
# Usage:
#   pwsh -File tests\test_spawn_prompt_lint.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptPath = Join-Path $RepoRoot 'scripts\lint-spawn-prompt.ps1'

# Temp directory for test fixtures (cleaned up on exit)
$TmpDir = Join-Path $RepoRoot "tests\.tmp_lint_prompt_$PID"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

function Remove-TmpDir {
    if (Test-Path -LiteralPath $TmpDir) {
        Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Remove-TmpDir } -ErrorAction SilentlyContinue

# Full hygiene tail block for reuse in tests
$FullTail = @"
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
# Test A: All 6 present -- exits 0
# ---------------------------------------------------------------------------

Test-Scenario 'all 6 markers present exits 0 with OK message' {
    $promptFile = Join-Path $TmpDir 'all6.md'
    [System.IO.File]::WriteAllText($promptFile, "Spawn donald for issue 99.`n`n$FullTail", [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --file $promptFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Expected exit 0, got $LASTEXITCODE; output: $output" }
    if ($output -notmatch 'OK') { throw "Expected OK in output; got: $output" }
}

# ---------------------------------------------------------------------------
# Test B: One marker missing -- exits 1 and names it
# ---------------------------------------------------------------------------

Test-Scenario 'one marker missing exits 1 and names the missing item' {
    # Remove the Worktree-remove-FIRST marker
    $body = $FullTail -replace 'Worktree-remove-FIRST cleanup -- after PR merges', 'REMOVED_MARKER'
    $promptFile = Join-Path $TmpDir 'missing_one.md'
    [System.IO.File]::WriteAllText($promptFile, "Body.`n`n$body", [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --file $promptFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    if ($output -notmatch 'Worktree-remove-FIRST') { throw "Expected missing marker name in output; got: $output" }
    if ($output -notmatch 'FAIL') { throw "Expected FAIL label in output; got: $output" }
}

# ---------------------------------------------------------------------------
# Test C: All markers missing -- exits 1 and lists all 6
# ---------------------------------------------------------------------------

Test-Scenario 'all markers missing exits 1 and lists all 6' {
    $promptFile = Join-Path $TmpDir 'none.md'
    [System.IO.File]::WriteAllText($promptFile, "Spawn chip for issue 7. No hygiene tail here.", [System.Text.Encoding]::ASCII)

    $output = pwsh -File $ScriptPath --file $promptFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    foreach ($m in @('CWD-pin','base=develop discipline','ASCII discipline',
                      'history.md pre-size-check','Worktree-remove-FIRST','Hygiene tail completion')) {
        if ($output.IndexOf($m) -lt 0) { throw "Expected missing marker '$m' in output; got: $output" }
    }
}

# ---------------------------------------------------------------------------
# Test D: File not found -- exits 1
# ---------------------------------------------------------------------------

Test-Scenario 'file not found exits 1 with error message' {
    $noFile = Join-Path $TmpDir 'no-such-prompt.md'

    $output = pwsh -File $ScriptPath --file $noFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
    if ($output -notmatch 'not found') { throw "Expected 'not found' in error output; got: $output" }
}

# ---------------------------------------------------------------------------
# Test E: Unknown argument -- exits 1
# ---------------------------------------------------------------------------

Test-Scenario 'unknown argument exits 1' {
    $output = pwsh -File $ScriptPath --bogus-flag 2>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "Expected exit 1, got $LASTEXITCODE" }
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
