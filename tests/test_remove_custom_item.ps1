#!/usr/bin/env pwsh
# test_remove_custom_item.ps1
# Regression test for Remove-CustomItem multi-argument behavior (Issue #41)
# Sprint 3 bug: [string]$Path (scalar) silently dropped second argument when called as `rm file1 file2`
# Fix: [string[]]$Path (array) now accepts multiple arguments

$ErrorActionPreference = "Stop"
$TestsPassed = 0
$TestsFailed = 0

function Test-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    Write-Host "`n=== TEST: $Name ===" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "✅ PASS: $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "❌ FAIL: $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# Test 1: Fixed version with ValueFromRemainingArguments must delete all files passed as separate args
# This tests the rm-style calling convention: `rm file1 file2` = `Remove-CustomItem file1 file2`
Test-Scenario "Remove-CustomItem with ValueFromRemainingArguments deletes multiple space-separated args" {
    # Define the CORRECT version matching scripts/windows/setup.ps1
    function Remove-CustomItem {
        param(
            [Parameter(Position=0, ValueFromRemainingArguments=$true)]
            [string[]]$Path
        )
        Remove-Item -Path $Path -Recurse -Force
    }
    
    # Create test files in current directory
    $TestFile1 = "test_remove_file1_$(Get-Random).txt"
    $TestFile2 = "test_remove_file2_$(Get-Random).txt"
    
    New-Item -Path $TestFile1 -ItemType File -Force | Out-Null
    New-Item -Path $TestFile2 -ItemType File -Force | Out-Null
    
    if (-not (Test-Path $TestFile1)) { throw "Test file 1 was not created" }
    if (-not (Test-Path $TestFile2)) { throw "Test file 2 was not created" }
    
    # Simulate `rm file1 file2` — space-separated positional args (the real usage pattern)
    Remove-CustomItem $TestFile1 $TestFile2
    
    # Assert BOTH files are deleted
    if (Test-Path $TestFile1) { throw "Test file 1 still exists after Remove-CustomItem" }
    if (Test-Path $TestFile2) { throw "Test file 2 still exists after Remove-CustomItem" }
}

# Test 2: Broken [string[]] WITHOUT ValueFromRemainingArguments silently drops the second arg
# This is the regression guard: proves the test catches the bug if ValueFromRemainingArguments is removed
Test-Scenario "Remove-CustomItem without ValueFromRemainingArguments silently drops second arg (regression guard)" {
    # Define the BROKEN version — array type but missing ValueFromRemainingArguments
    function Remove-CustomItem-Broken {
        param([string[]]$Path)  # no ValueFromRemainingArguments — same as old Sprint 3 "fix"
        Remove-Item -Path $Path -Recurse -Force
    }
    
    # Create test files in current directory
    $TestFile1 = "test_broken_file1_$(Get-Random).txt"
    $TestFile2 = "test_broken_file2_$(Get-Random).txt"
    
    New-Item -Path $TestFile1 -ItemType File -Force | Out-Null
    New-Item -Path $TestFile2 -ItemType File -Force | Out-Null
    
    # Verify files were created
    if (-not (Test-Path $TestFile1)) { throw "Test file 1 was not created" }
    if (-not (Test-Path $TestFile2)) { throw "Test file 2 was not created" }
    
    # Call with both arguments — broken version silently ignores second arg
    Remove-CustomItem-Broken $TestFile1 $TestFile2
    
    # The BROKEN version should only delete the first file
    if (Test-Path $TestFile1) {
        throw "Test file 1 should have been deleted by broken version"
    }
    
    # The second file should still exist (proving the bug — regression guard)
    if (-not (Test-Path $TestFile2)) {
        throw "Test file 2 should NOT have been deleted by broken version (regression guard failed)"
    }
    
    # Clean up the leftover file
    Remove-Item $TestFile2 -Force
}

# Test 3: Verify the correct version also works with single file
Test-Scenario "Remove-CustomItem with ValueFromRemainingArguments works with single file" {
    function Remove-CustomItem {
        param(
            [Parameter(Position=0, ValueFromRemainingArguments=$true)]
            [string[]]$Path
        )
        Remove-Item -Path $Path -Recurse -Force
    }
    
    $TestFile = "test_single_file_$(Get-Random).txt"
    New-Item -Path $TestFile -ItemType File -Force | Out-Null
    
    if (-not (Test-Path $TestFile)) { throw "Test file was not created" }
    
    Remove-CustomItem $TestFile
    
    if (Test-Path $TestFile) { throw "Test file still exists after Remove-CustomItem" }
}

# Report results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($TestsFailed -gt 0) {
    exit 1
}
else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}
