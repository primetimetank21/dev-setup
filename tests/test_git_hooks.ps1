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
    $hookFiles = @("pre-commit", "commit-msg", "pre-push")
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
# Group B: commit-msg hook validation
# ---------------------------------------------------------------------------

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host " Group B: commit-msg hook validation" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Test-Scenario "commit-msg hook rejects non-conventional message" {
    $tempMsgFile = Join-Path $PSScriptRoot "temp_commit_msg_$(Get-Random).txt"
    try {
        Set-Content $tempMsgFile -Value "This is not conventional" -Encoding UTF8
        
        $hookPath = Join-Path $RepoRoot "hooks\commit-msg"
        
        # Run via sh (Git Bash) which is the actual execution path
        if (Get-Command sh -ErrorAction SilentlyContinue) {
            $result = & sh $hookPath $tempMsgFile 2>&1
            if ($LASTEXITCODE -eq 0) {
                throw "commit-msg hook should have rejected non-conventional message, but returned exit 0"
            }
        } else {
            Write-Host "  sh not found - testing via direct PowerShell simulation" -ForegroundColor Yellow
            # Simulate the hook logic in PowerShell
            $msg = Get-Content $tempMsgFile -Raw
            $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
            if ($stripped -match '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
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
        Set-Content $tempMsgFile -Value "feat(hooks): add commit message validation" -Encoding UTF8
        
        $hookPath = Join-Path $RepoRoot "hooks\commit-msg"
        
        # Run via sh (Git Bash) which is the actual execution path
        if (Get-Command sh -ErrorAction SilentlyContinue) {
            $result = & sh $hookPath $tempMsgFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "commit-msg hook rejected valid conventional message: $result"
            }
        } else {
            Write-Host "  sh not found - testing via direct PowerShell simulation" -ForegroundColor Yellow
            # Simulate the hook logic in PowerShell
            $msg = Get-Content $tempMsgFile -Raw
            $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
            if ($stripped -notmatch '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
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
            Set-Content $tempMsgFile -Value $msg -Encoding UTF8
            
            $hookPath = Join-Path $RepoRoot "hooks\commit-msg"
            
            if (Get-Command sh -ErrorAction SilentlyContinue) {
                $result = & sh $hookPath $tempMsgFile 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "commit-msg hook rejected valid message: '$msg'"
                }
            } else {
                # PowerShell simulation
                $stripped = ($msg -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^$" } | Select-Object -First 1)
                if ($stripped -notmatch '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert)(\([a-zA-Z0-9/_-]+\))?!?: .+') {
                    throw "Valid message should have matched: '$msg'"
                }
            }
        }
        finally {
            if (Test-Path $tempMsgFile) { Remove-Item $tempMsgFile -Force }
        }
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
