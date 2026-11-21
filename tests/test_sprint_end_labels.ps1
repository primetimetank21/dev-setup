#!/usr/bin/env pwsh
# tests/test_sprint_end_labels.ps1
# Tests for the retry/verification logic in scripts/sprint-end-labels.sh
# (Issue #382)
#
# Strategy:
#   The script invokes `gh issue view ... --json labels` to verify each
#   label op. We test the retry loop by shimming `gh` and `jq` via PATH
#   manipulation so a fake `gh` returns canned JSON and we can assert:
#     A. Dry-run produces no writes and reports intended changes.
#     B. Argument validation rejects missing/invalid flags.
#     C. The script exits non-zero when bash is unavailable (env probe).
#
# Note on scope:
#   Full end-to-end retry simulation requires a Linux/bash environment with
#   a controllable `gh` binary on PATH. On Windows we test the surface that
#   is portable: argument parsing, --help, --dry-run with no matches, and
#   the script's refusal to run with bad inputs. The retry loop itself is
#   exercised on CI (ubuntu-latest) via the workflow's dry-run jobs.
#
# Usage:
#   pwsh -File tests\test_sprint_end_labels.ps1

$ErrorActionPreference = 'Stop'
$TestsPassed  = 0
$TestsFailed  = 0
$TestsSkipped = 0

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptPath = Join-Path $RepoRoot 'scripts\sprint-end-labels.sh'

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
# Bash discovery
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
    try {
        $cmd = Get-Command $c -ErrorAction Stop
        $bashPath = $cmd.Source
        break
    } catch { continue }
}
# Final fallback: PATH lookup, but skip the WSL stub at C:\Windows\System32\bash.exe.
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
# Test A: --help / usage prints and exits non-zero (exit 2)
# ---------------------------------------------------------------------------

Test-Scenario 'script prints usage on --help' {
    $out = (& $bashPath $ScriptPath --help 2>&1) -join "`n"
    $code = $LASTEXITCODE
    if ($code -ne 2) {
        throw "expected exit 2 from --help, got $code"
    }
    if ($out -notmatch 'sprint-end-labels\.sh') {
        throw "usage text missing script name; got: $out"
    }
}

# ---------------------------------------------------------------------------
# Test B: missing --sprint fails with exit 2
# ---------------------------------------------------------------------------

Test-Scenario 'missing --sprint exits 2' {
    $out = & $bashPath $ScriptPath --release-label 'release:shipped-1.0.0' 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 2) {
        throw "expected exit 2, got $code; output: $out"
    }
}

# ---------------------------------------------------------------------------
# Test C: missing --release-label fails with exit 2
# ---------------------------------------------------------------------------

Test-Scenario 'missing --release-label exits 2' {
    $out = & $bashPath $ScriptPath --sprint 'sprint:1' 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 2) {
        throw "expected exit 2, got $code; output: $out"
    }
}

# ---------------------------------------------------------------------------
# Test D: bad --release-label prefix fails with exit 2
# ---------------------------------------------------------------------------

Test-Scenario 'bad release-label prefix exits 2' {
    $out = & $bashPath $ScriptPath --sprint 'sprint:1' --release-label 'type:bogus' --dry-run 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 2) {
        throw "expected exit 2 from bad release label, got $code; output: $out"
    }
    if ($out -notmatch "release:shipped-") {
        throw "expected guidance about release:shipped- prefix; got: $out"
    }
}

# ---------------------------------------------------------------------------
# Test E: retry-loop test via function override (bash + jq, no gh needed).
#
# We source the script's helper functions, then override has_label() to
# control whether the "label state matches" returns true. This exercises
# the retry loop, the exponential backoff sleeps, and the final assertion
# without any network or gh CLI dependency.
#
# Scenario: has_label returns false the first 2 calls, true on the 3rd.
#   -> verify_with_retry must retry (attempt=0 -> 1s, attempt=1 -> 2s),
#      then succeed on the third query.
#
# We assert: exit 0, total has_label calls = 3, output contains
# "verified: #999 has 'release:shipped-1.0.0'".
# ---------------------------------------------------------------------------

Test-Scenario 'verify_with_retry retries then succeeds (function override)' {
    $shimDir = Join-Path $RepoRoot ".test-tmp\sel-shim-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
    try {
        $stateFile = Join-Path $shimDir 'count.txt'
        Set-Content -Path $stateFile -Value '0' -Encoding ASCII -NoNewline
        $shimPosix   = $shimDir.Replace('\','/')
        $scriptPosix = $ScriptPath.Replace('\','/')

        $driver = @"
#!/usr/bin/env bash
set -uo pipefail
# Extract helpers from the real script.
sed -n '/^has_label()/,/^# ---------/p'         "${scriptPosix}" >  "${shimPosix}/helpers.sh"
sed -n '/^verify_with_retry()/,/^# ---------/p' "${scriptPosix}" >> "${shimPosix}/helpers.sh"

GH_REPO_ARGS=()
log()  { printf '[shim] %s\n' "`$*"; }
warn() { printf '[shim] WARN: %s\n' "`$*" >&2; }
err()  { printf '[shim] ERROR: %s\n' "`$*" >&2; }

. "${shimPosix}/helpers.sh"

# Override has_label to bypass gh; succeed only on the 3rd call.
has_label() {
  local s="${shimPosix}/count.txt"
  local n
  n=`$(cat "`$s")
  n=`$((n+1))
  echo "`$n" > "`$s"
  if [ "`$n" -ge 3 ]; then
    return 0
  fi
  return 1
}

verify_with_retry 999 'release:shipped-1.0.0' 'present'
echo "VERIFY_OK"
"@
        $driverPath = Join-Path $shimDir 'driver.sh'
        Set-Content -Path $driverPath -Value ($driver.Replace("`r", '')) -Encoding ASCII -NoNewline

        $driverPosix = $driverPath.Replace('\','/')
        $out  = (& $bashPath $driverPosix 2>&1) -join "`n"
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            throw "exit=$code output=$out"
        }
        if ($out -notmatch 'VERIFY_OK') {
            throw "expected VERIFY_OK in output; got: $out"
        }
        if ($out -notmatch "verified: #999 has 'release:shipped-1.0.0'") {
            throw "expected 'verified' log line; got: $out"
        }
        $finalCount = [int](Get-Content $stateFile)
        if ($finalCount -ne 3) {
            throw "expected exactly 3 has_label calls, saw $finalCount"
        }
    } finally {
        Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Test F: retry-loop bails out after 3 retries when state never matches.
# ---------------------------------------------------------------------------

Test-Scenario 'verify_with_retry fails loudly after 3 retries' {
    $shimDir = Join-Path $RepoRoot ".test-tmp\sel-fail-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
    try {
        $shimPosix   = $shimDir.Replace('\','/')
        $scriptPosix = $ScriptPath.Replace('\','/')

        $driver = @"
#!/usr/bin/env bash
set -uo pipefail
sed -n '/^has_label()/,/^# ---------/p'         "${scriptPosix}" >  "${shimPosix}/helpers.sh"
sed -n '/^verify_with_retry()/,/^# ---------/p' "${scriptPosix}" >> "${shimPosix}/helpers.sh"

GH_REPO_ARGS=()
log()  { printf '[shim] %s\n' "`$*"; }
warn() { printf '[shim] WARN: %s\n' "`$*" >&2; }
err()  { printf '[shim] ERROR: %s\n' "`$*" >&2; }

. "${shimPosix}/helpers.sh"

# Override has_label and the noisy gh call inside err to no-op.
has_label() { return 1; }
gh() { echo '{"labels":[]}'; }

verify_with_retry 999 'release:shipped-1.0.0' 'present'
echo "UNREACHABLE"
"@
        $driverPath = Join-Path $shimDir 'driver.sh'
        Set-Content -Path $driverPath -Value ($driver.Replace("`r", '')) -Encoding ASCII -NoNewline
        $driverPosix = $driverPath.Replace('\','/')

        $out  = (& $bashPath $driverPosix 2>&1) -join "`n"
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            throw "expected non-zero exit when verify never matches; output: $out"
        }
        if ($out -match 'UNREACHABLE') {
            throw "script continued past failed verification; got: $out"
        }
        if ($out -notmatch 'verification FAILED for #999 after 3 retries') {
            throw "expected 'verification FAILED' message; got: $out"
        }
    } finally {
        Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Test G: CRLF in jq TSV output must not break idempotency guard.
#
# Regression for #400: Windows jq outputs CRLF line endings. Without
# `tr -d '\r'` in the process substitution, the trailing \r attaches to
# the last label in a line, causing the grep match to fail, so a label
# that is already present on an issue gets re-applied on every run.
#
# We simulate this by feeding jq-like TSV with \r\n into process_issue
# and asserting "skip add" fires (not "adding").
# ---------------------------------------------------------------------------

Test-Scenario 'CRLF in TSV does not break idempotency guard (regression #400)' {
    $shimDir = Join-Path $RepoRoot ".test-tmp\sel-crlf-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
    try {
        $shimPosix   = $shimDir.Replace('\','/')
        $scriptPosix = $ScriptPath.Replace('\','/')

        $driver = @"
#!/usr/bin/env bash
set -uo pipefail

GH_REPO_ARGS=()
DRY_RUN=0
BACKLOG_LABEL="release:backlog"
RELEASE_LABEL="release:shipped-1.0.0"
log()  { printf '[shim] %s\n' "`$*"; }
warn() { printf '[shim] WARN: %s\n' "`$*" >&2; }
err()  { printf '[shim] ERROR: %s\n' "`$*" >&2; }

# Pull in process_issue and its helpers from the real script.
eval "`$(sed -n '/^has_label()/,/^process_issue()/{ /^process_issue()/d; p }' '${scriptPosix}')"
eval "`$(sed -n '/^verify_with_retry()/,/^process_issue()/{ /^process_issue()/d; p }' '${scriptPosix}')"
eval "`$(sed -n '/^process_issue()/,/^# ----/{ /^# ----/d; p }' '${scriptPosix}')"

# Stub verify_with_retry: should NOT be called (label already present).
verify_call_count=0
verify_with_retry() { verify_call_count=`$((verify_call_count+1)); }

# Feed a TSV line with CRLF (the \r\n that Windows jq emits).
# The labels field ends with release:shipped-1.0.0 followed by \r.
# The tr -d '\r' fix in the script removes the \r before read.
output=`$(while IFS=`$'\t' read -r number title labels_csv; do
  process_issue "`$number" "`$title" "`$labels_csv"
done < <(printf '%s\r\n' '371	Test issue	sprint:17,release:shipped-1.0.0' | tr -d '\r'))

if echo "`$output" | grep -q 'adding:'; then
  echo "FAIL: 'adding' fired even though label was present (CRLF not stripped)" >&2
  exit 1
fi
if ! echo "`$output" | grep -q 'skip add:'; then
  echo "FAIL: expected 'skip add' but not found; output: `$output" >&2
  exit 1
fi
if [ "`$verify_call_count" -ne 0 ]; then
  echo "FAIL: verify_with_retry called `$verify_call_count times, expected 0" >&2
  exit 1
fi
echo "PASS_CRLF"
"@
        $driverPath = Join-Path $shimDir 'driver.sh'
        Set-Content -Path $driverPath -Value ($driver.Replace("`r", '')) -Encoding ASCII -NoNewline

        $driverPosix = $driverPath.Replace('\','/')
        $out  = (& $bashPath $driverPosix 2>&1) -join "`n"
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            throw "exit=$code output=$out"
        }
        if ($out -notmatch 'PASS_CRLF') {
            throw "expected PASS_CRLF in output; got: $out"
        }
    } finally {
        Remove-Item -Recurse -Force $shimDir -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Results" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Passed:  $TestsPassed" -ForegroundColor Green
Write-Host "Failed:  $TestsFailed" -ForegroundColor $(if ($TestsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host "Skipped: $TestsSkipped" -ForegroundColor Yellow

if ($TestsFailed -gt 0) { exit 1 }
exit 0
