#!/usr/bin/env pwsh
# tests/test_changelog_fold.ps1
# Tests for scripts/changelog-fold.sh (Issue #415)
#
# Coverage:
#   A. Dry-run output is printed to stdout; CHANGELOG.md is not modified.
#   B. Apply mode correctly folds [Unreleased] into [X.Y.Z] and restores
#      a fresh [Unreleased] block.
#   C. Missing-entries detection: entries present in the gh query but absent
#      from [Unreleased] are reported to stderr.
#   D. Idempotency gate: a second --apply for the same version exits 1 with
#      a clear "already folded" error message.
#   E. Argument validation: missing --release-version exits 2.
#
# Mocking strategy:
#   Tests A-C create a stub gh script in a temp dir added to PATH.
#   Test D relies on the idempotency check which runs BEFORE any gh calls.
#   New-TestEnv creates a git sandbox with tag 0.9.7 so tag resolution is
#   self-contained for CI (no dependency on host repo tags).
#
# Usage:
#   pwsh -File tests\test_changelog_fold.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptPath = Join-Path $RepoRoot 'scripts\changelog-fold.sh'

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
# Bash discovery (skips WSL stub at System32\bash.exe per Sprint-17 lesson)
# ---------------------------------------------------------------------------

$bashPath = $null
$candidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe',
    '/usr/bin/bash',
    '/bin/bash'
)
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c -ErrorAction SilentlyContinue) {
        $bashPath = $c
        break
    }
}
if (-not $bashPath) {
    try {
        $cmd = Get-Command bash -ErrorAction Stop
        if ($cmd.Source -notmatch '[\\/]System32[\\/]bash\.exe$') {
            $bashPath = $cmd.Source
        }
    } catch { }
}

if (-not $bashPath) {
    Write-Skip 'all tests' 'bash not available on this machine'
    exit 0
}

Write-Host "Using bash at: $bashPath" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Minimal CHANGELOG fixture used by tests A, B, C
# ---------------------------------------------------------------------------

$FixtureChangelog = @'
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.9.7] - 2026-05-17

### Added
- Sprint-end label automation (#382)

### Changed

### Fixed

### Removed
'@

# ---------------------------------------------------------------------------
# Minimal CHANGELOG for idempotency test D (version already present)
# ---------------------------------------------------------------------------

$IdempotentChangelog = @'
# Changelog

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.9.99] - 2026-05-18

### Added
- already there (#1)

### Changed

### Fixed

### Removed

## [0.9.7] - 2026-05-17

### Added
- Sprint-end label automation (#382)

### Changed

### Fixed

### Removed
'@

# ---------------------------------------------------------------------------
# Helper: convert a Windows path to a POSIX path for Git Bash
# ---------------------------------------------------------------------------

function ConvertTo-PosixPath {
    param([string]$WinPath)
    $p = $WinPath.Replace('\', '/')
    if ($p -match '^([A-Za-z]):(.*)') {
        return '/' + $Matches[1].ToLower() + $Matches[2]
    }
    return $p
}

# ---------------------------------------------------------------------------
# Helper: create a temp test dir and stub gh in it (LF-only, no CRLF)
# ---------------------------------------------------------------------------

function New-TestEnv {
    param(
        [string]$TestId,
        [string]$GhPrJson    = '[]',
        [string]$GhIssueJson = '[]'
    )
    $dir      = Join-Path $RepoRoot ".test-tmp\cf-$TestId-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $stubPath = Join-Path $dir 'gh'

    # Build stub with LF-only line endings (CRLF breaks the bash shebang).
    # JSON is wrapped in bash single-quotes so internal double-quotes are literal.
    $lines = @(
        '#!/usr/bin/env bash',
        'case "$1 $2" in',
        ("  `"pr list`")    printf '%s\n' " + "'" + $GhPrJson    + "' ;;"),
        ("  `"issue list`") printf '%s\n' " + "'" + $GhIssueJson + "' ;;"),
        "  *)            exit 0 ;;",
        "esac"
    )
    $content = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($stubPath, $content, [System.Text.Encoding]::ASCII)

    # chmod +x so bash can execute it via PATH lookup
    $posixStub = ConvertTo-PosixPath $stubPath
    & $bashPath -c "chmod +x '$posixStub'"

    # Initialize git repo with 0.9.7 tag for tag-resolution tests (Issue #430).
    # changelog-fold.ps1 / changelog-fold.sh resolve --last-tag via git commands,
    # so the test sandbox must have the tag present to be self-contained for CI.
    Push-Location $dir
    try {
        & git init -q 2>&1 | Out-Null
        & git config user.name "Test User" 2>&1 | Out-Null
        & git config user.email "test@example.com" 2>&1 | Out-Null
        "initial" | Out-File -FilePath "README.md" -Encoding ASCII -NoNewline
        & git add README.md 2>&1 | Out-Null
        & git commit -q -m "initial commit" 2>&1 | Out-Null
        & git tag 0.9.7 HEAD 2>&1 | Out-Null
    }
    finally {
        Pop-Location
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
# Test A: dry-run prints proposed section to stdout; CHANGELOG unchanged
# ---------------------------------------------------------------------------

Test-Scenario 'A: dry-run output present; CHANGELOG not modified' {
    $env_dir = New-TestEnv -TestId 'A'
    $tmpChangelog = Join-Path $env_dir 'CHANGELOG.md'
    Set-Content -Path $tmpChangelog -Value $FixtureChangelog -Encoding ASCII

    $posixEnvDir    = ConvertTo-PosixPath $env_dir
    $posixScript    = ConvertTo-PosixPath $ScriptPath
    $posixChangelog = ConvertTo-PosixPath $tmpChangelog
    try {
        $out = & $bashPath -c "
cd '$posixEnvDir' &&
export PATH='$posixEnvDir':`$PATH
'$posixScript' \
    --release-version 0.9.99 \
    --last-tag 0.9.7 \
    --release-date 2026-05-18 \
    --changelog-path '$posixChangelog' \
    --dry-run
" 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            throw "expected exit 0 from --dry-run, got $code; output: $($out -join ' ')"
        }
        $outStr = $out -join "`n"
        if ($outStr -notmatch 'Proposed') {
            throw "expected 'Proposed' in stdout; got: $outStr"
        }
        if ($outStr -notmatch '\[0\.9\.99\]') {
            throw "expected version header in stdout; got: $outStr"
        }
        # CHANGELOG must be unchanged (no [0.9.99] in it)
        $afterContent = Get-Content -LiteralPath $tmpChangelog -Raw
        if ($afterContent -match '\[0\.9\.99\]') {
            throw "--dry-run must not modify CHANGELOG.md"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test B: apply mode folds [Unreleased] into [X.Y.Z]; fresh [Unreleased] restored
# ---------------------------------------------------------------------------

Test-Scenario 'B: apply mode folds CHANGELOG.md correctly' {
    $prJson    = '[{"number":901,"title":"feat: add thing","labels":[{"name":"type:feature"}],"mergedAt":"2026-05-01T00:00:00Z"}]'
    $issueJson = '[{"number":902,"title":"fix: fix bug","labels":[{"name":"type:bug"}],"closedAt":"2026-05-01T00:00:00Z"}]'
    $env_dir   = New-TestEnv -TestId 'B' -GhPrJson $prJson -GhIssueJson $issueJson
    $tmpChangelog = Join-Path $env_dir 'CHANGELOG.md'
    Set-Content -Path $tmpChangelog -Value $FixtureChangelog -Encoding ASCII

    $posixEnvDir    = ConvertTo-PosixPath $env_dir
    $posixScript    = ConvertTo-PosixPath $ScriptPath
    $posixChangelog = ConvertTo-PosixPath $tmpChangelog
    try {
        $out = & $bashPath -c "
cd '$posixEnvDir' &&
export PATH='$posixEnvDir':`$PATH
'$posixScript' \
    --release-version 0.9.99 \
    --last-tag 0.9.7 \
    --release-date 2026-05-18 \
    --changelog-path '$posixChangelog' \
    --apply
" 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            throw "expected exit 0 from --apply, got $code; output: $($out -join ' ')"
        }

        $result = Get-Content -LiteralPath $tmpChangelog -Raw

        # New version header present
        if ($result -notmatch '\[0\.9\.99\] - 2026-05-18') {
            throw "new version header not found in CHANGELOG.md"
        }
        # Fresh [Unreleased] present
        if ($result -notmatch '(?m)^## \[Unreleased\]') {
            throw "fresh [Unreleased] block not found in CHANGELOG.md"
        }
        # [Unreleased] appears BEFORE [0.9.99]
        $unrelIdx = $result.IndexOf('## [Unreleased]')
        $verIdx   = $result.IndexOf('## [0.9.99]')
        if ($unrelIdx -ge $verIdx) {
            throw "[Unreleased] must appear before [0.9.99]"
        }
        # Categorized entries present
        if ($result -notmatch 'feat: add thing \(#901\)') {
            throw "Added entry #901 not found"
        }
        if ($result -notmatch 'fix: fix bug \(#902\)') {
            throw "Fixed entry #902 not found"
        }
        # Previous version still present
        if ($result -notmatch '\[0\.9\.7\]') {
            throw "prior version [0.9.7] not preserved"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test C: missing-entries detection reports to stderr
# ---------------------------------------------------------------------------

Test-Scenario 'C: missing entries reported to stderr' {
    # PR #999 is not referenced in [Unreleased] of the fixture
    $prJson  = '[{"number":999,"title":"feat: unreported feature","labels":[{"name":"type:feature"}],"mergedAt":"2026-05-01T00:00:00Z"}]'
    $env_dir = New-TestEnv -TestId 'C' -GhPrJson $prJson
    $tmpChangelog = Join-Path $env_dir 'CHANGELOG.md'
    Set-Content -Path $tmpChangelog -Value $FixtureChangelog -Encoding ASCII

    $posixEnvDir    = ConvertTo-PosixPath $env_dir
    $posixScript    = ConvertTo-PosixPath $ScriptPath
    $posixChangelog = ConvertTo-PosixPath $tmpChangelog
    try {
        $tmpErr     = Join-Path $env_dir 'stderr.txt'
        $posixErr   = ConvertTo-PosixPath $tmpErr
        & $bashPath -c "
cd '$posixEnvDir' &&
export PATH='$posixEnvDir':`$PATH
'$posixScript' \
    --release-version 0.9.99 \
    --last-tag 0.9.7 \
    --release-date 2026-05-18 \
    --changelog-path '$posixChangelog' \
    --dry-run \
    2>'$posixErr'
" | Out-Null
        $errContent = if (Test-Path $tmpErr) { Get-Content -LiteralPath $tmpErr -Raw } else { '' }

        if ($errContent -notmatch 'Missing from \[Unreleased\]') {
            throw "expected 'Missing from [Unreleased]' in stderr; got: $errContent"
        }
        if ($errContent -notmatch '#999') {
            throw "expected '#999' in missing-entries warning; got: $errContent"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test D: idempotency -- second --apply exits 1 with "already folded"
# ---------------------------------------------------------------------------

Test-Scenario 'D: idempotency gate exits 1 for already-folded version' {
    $env_dir = New-TestEnv -TestId 'D'
    $tmpChangelog = Join-Path $env_dir 'CHANGELOG.md'
    Set-Content -Path $tmpChangelog -Value $IdempotentChangelog -Encoding ASCII

    $posixEnvDir    = ConvertTo-PosixPath $env_dir
    $posixScript    = ConvertTo-PosixPath $ScriptPath
    $posixChangelog = ConvertTo-PosixPath $tmpChangelog
    try {
        $out = & $bashPath -c "
cd '$posixEnvDir' &&
export PATH='$posixEnvDir':`$PATH
'$posixScript' \
    --release-version 0.9.99 \
    --last-tag 0.9.7 \
    --release-date 2026-05-18 \
    --changelog-path '$posixChangelog' \
    --apply
" 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 1) {
            throw "expected exit 1 from idempotency gate, got $code; output: $($out -join ' ')"
        }
        $outStr = $out -join "`n"
        if ($outStr -notmatch 'already folded') {
            throw "expected 'already folded' in error output; got: $outStr"
        }
    }
    finally {
        Remove-TestEnv -Dir $env_dir
    }
}

# ---------------------------------------------------------------------------
# Test E: missing --release-version exits 2
# ---------------------------------------------------------------------------

Test-Scenario 'E: missing --release-version exits 2' {
    $posixScript = ConvertTo-PosixPath $ScriptPath
    $out  = & $bashPath -c "'$posixScript' --last-tag 0.9.7 --dry-run" 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 2) {
        throw "expected exit 2 for missing --release-version, got $code; output: $($out -join ' ')"
    }
    $outStr = $out -join "`n"
    if ($outStr -notmatch 'release-version') {
        throw "expected '--release-version' in error output; got: $outStr"
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
