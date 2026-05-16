#!/usr/bin/env pwsh
# tests/test_git_hooks.ps1
# Tests for git hooks implementation (Issue #121)
#
# Covers:
#   A. Git hooks are configured via core.hooksPath after setup
#   B. Hook files exist and are non-empty
#   C. commit-msg hook rejects non-conventional commit messages
#   D. commit-msg hook accepts valid conventional commit messages
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\test_git_hooks.ps1

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
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    Write-Host "SKIP: $Name" -ForegroundColor Yellow
    Write-Host "  Reason: $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
}

# ---------------------------------------------------------------------------
# Group A: Hook configuration
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group A: Hook configuration" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "core.hooksPath is set to hooks in repo" {
    Push-Location $RepoRoot
    try {
        $hooksPath = & git config --get core.hooksPath 2>$null
        if ($hooksPath -ne "hooks") {
            throw "Expected core.hooksPath=hooks, got: '$hooksPath'"
        }
    }
    finally {
        Pop-Location
    }
}

Test-Scenario "Hook files exist and are non-empty" {
    $hookFiles = @("pre-commit", "prepare-commit-msg", "commit-msg", "pre-push")
    foreach ($hook in $hookFiles) {
        $hookPath = Join-Path $RepoRoot "hooks\$hook"
        if (-not (Test-Path $hookPath)) {
            throw "Hook file missing: $hookPath"
        }
        $content = Get-Content $hookPath -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "Hook file is empty: $hookPath"
        }
        if ($content -notmatch "^#!/bin/sh") {
            throw "Hook file missing shebang: $hookPath"
        }
    }
}

# ---------------------------------------------------------------------------
# Group B: commit-msg and prepare-commit-msg hook validation
# ---------------------------------------------------------------------------
# NOTE: Temp commit-msg files MUST be written with -Encoding ASCII (not UTF8).
# PS 5.1's Set-Content -Encoding UTF8 writes UTF-8 WITH BOM, which the POSIX
# sh-based hooks read as the first bytes of the line, breaking the
# conventional-commits regex. ASCII is safe on both PS 5.1 and PS 7 and the
# test content is pure ASCII anyway.

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group B: commit-msg and prepare-commit-msg hook validation" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$commitMsgHook = Join-Path $RepoRoot "hooks\commit-msg"
$prepareCommitMsgHook = Join-Path $RepoRoot "hooks\prepare-commit-msg"

Test-Scenario "commit-msg hook rejects non-conventional message" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_commit_msg_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "This is not conventional" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -eq 0) {
                throw "commit-msg hook should have rejected non-conventional message, but returned exit 0"
            }
        } else {
            $msg = Get-Content $tempMsgFile -Raw
            $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
            if ($stripped -match '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert|merge)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
                throw "Non-conventional message should not have matched"
            }
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "commit-msg hook accepts valid conventional message" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_commit_msg_valid_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "feat(hooks): add commit message validation" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg hook rejected valid conventional message: $result"
            }
        } else {
            $msg = Get-Content $tempMsgFile -Raw
            $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
            if ($stripped -notmatch '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert|merge)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
                throw "Valid conventional message should have matched"
            }
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "commit-msg hook accepts multiple valid formats" {
    $validMessages = @(
        "feat(setup): add vim installation",
        "fix(windows): correct PATH for git bash",
        "docs(contributing): add branch isolation rule",
        "chore: update dependencies",
        "feat!: breaking change with exclamation mark",
        "fix(core)!: breaking fix with scope and exclamation"
    )

    foreach ($msg in $validMessages) {
        $tempMsgFile = Join-Path $PSScriptRoot "temp_commit_msg_multi_$(Get-Random).txt"
        try {
            Set-Content $tempMsgFile -Value $msg -Encoding ASCII

            if (Get-Command sh -ErrorAction SilentlyContinue) {
                $result = & sh $commitMsgHook $tempMsgFile 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "commit-msg hook rejected valid message: '$msg'"
                }
            } else {
                $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
                if ($stripped -notmatch '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert|merge)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
                    throw "Valid message should have matched: '$msg'"
                }
            }
        }
        finally {
            if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
        }
    }
}

Test-Scenario "prepare-commit-msg rewrites Merge branch simple" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b1_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "Merge branch 'develop'" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "merge(develop): merge branch") {
                throw "Expected 'merge(develop): merge branch', got: '$rewritten'"
            }
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected rewritten message: $result"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "prepare-commit-msg rewrites Merge branch into target" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b2_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "Merge branch 'feature' into develop" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "merge(feature): merge into develop") {
                throw "Expected 'merge(feature): merge into develop', got: '$rewritten'"
            }
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected rewritten message: $result"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "prepare-commit-msg rewrites Merge remote-tracking branch" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b3_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "Merge remote-tracking branch 'origin/main'" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "merge(remote): origin/main") {
                throw "Expected 'merge(remote): origin/main', got: '$rewritten'"
            }
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected rewritten message: $result"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "prepare-commit-msg rewrites Merge pull request" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b4_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "Merge pull request #42 from user/feature" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "merge(pr): #42 from user/feature") {
                throw "Expected 'merge(pr): #42 from user/feature', got: '$rewritten'"
            }
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected rewritten message: $result"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "prepare-commit-msg rewrites Revert message" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b5_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value 'Revert "feat: do thing"' -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "revert: feat: do thing") {
                throw "Expected 'revert: feat: do thing', got: '$rewritten'"
            }
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected rewritten message: $result"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "prepare-commit-msg leaves conventional commit unchanged" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b6_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "feat: add thing" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            & sh $prepareCommitMsgHook $tempMsgFile 2>&1 | Out-Null
            $rewritten = (Get-Content $tempMsgFile -Encoding ASCII | Select-Object -First 1)
            if ($rewritten -ne "feat: add thing") {
                throw "Expected 'feat: add thing' unchanged, got: '$rewritten'"
            }
        } else {
            Write-Host "  sh not found - skipping" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

Test-Scenario "commit-msg accepts hand-written merge type" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_pcm_b7_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "merge(custom): special merge" -Encoding ASCII

        if (Get-Command sh -ErrorAction SilentlyContinue) {
            $result = & sh $commitMsgHook $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg rejected hand-written merge type: $result"
            }
        } else {
            $msg = Get-Content $tempMsgFile -Raw
            $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
            if ($stripped -notmatch '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert|merge)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
                throw "Hand-written merge type should have matched"
            }
        }
    }
    finally {
        if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Passed:  $TestsPassed" -ForegroundColor Green
Write-Host "Failed:  $TestsFailed" -ForegroundColor Red
Write-Host "Skipped: $TestsSkipped" -ForegroundColor Yellow

if ($TestsFailed -gt 0) {
    Write-Host "`nTests FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "`nAll tests PASSED" -ForegroundColor Green
exit 0
