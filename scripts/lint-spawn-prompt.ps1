#Requires -Version 5.1
<#
.SYNOPSIS
    Checks a coordinator spawn prompt for all 6 mandatory hygiene tail markers.
.DESCRIPTION
    Reads a candidate spawn-prompt from --file <path> or stdin. Scans for the
    6 mandatory hygiene tail markers. Exit 0 if all 6 are present. Exit 1 with
    a list of missing markers if any are absent. Side-effect-free and idempotent.
.EXAMPLE
    pwsh -File scripts\lint-spawn-prompt.ps1 --file prompt.md
    cat prompt.md | pwsh -File scripts\lint-spawn-prompt.ps1
.PARAMETER file
    Path to the spawn-prompt file to lint. If omitted, reads from stdin.
#>

$ErrorActionPreference = 'Stop'

$filePath = $null

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--file' { $i++; $filePath = $args[$i] }
        default {
            Write-Host "ERROR: Unknown argument: $($args[$i])" -ForegroundColor Red
            exit 1
        }
    }
    $i++
}

# Read input
if ($filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) {
        Write-Host "ERROR: File not found: $filePath" -ForegroundColor Red
        exit 1
    }
    $promptText = [System.IO.File]::ReadAllText($filePath)
} elseif ([System.Console]::IsInputRedirected) {
    $promptText = [System.Console]::In.ReadToEnd()
} else {
    Write-Host "ERROR: No input provided. Use --file <path> or pipe prompt via stdin." -ForegroundColor Red
    exit 1
}

# The 6 mandatory hygiene tail markers (in order from spawn-prompt-hygiene.md)
$markers = @(
    @{ Name = 'CWD-pin';                   Text = 'CWD-pin -- before every file write' },
    @{ Name = 'base=develop discipline';   Text = 'base=develop discipline' },
    @{ Name = 'ASCII discipline';          Text = 'ASCII discipline -- after every file write' },
    @{ Name = 'history.md pre-size-check'; Text = 'history.md pre-size-check -- before every append' },
    @{ Name = 'Worktree-remove-FIRST';     Text = 'Worktree-remove-FIRST cleanup -- after PR merges' },
    @{ Name = 'Hygiene tail completion';   Text = 'Hygiene tail completion' }
)

$missing = @()
foreach ($m in $markers) {
    if ($promptText.IndexOf($m.Text) -lt 0) {
        $missing += $m.Name
    }
}

if ($missing.Count -eq 0) {
    Write-Host "OK: All 6 hygiene tail markers present." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL: Missing $($missing.Count) of 6 hygiene tail markers:" -ForegroundColor Red
    foreach ($name in $missing) {
        Write-Host "  - $name" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Run scripts\squad-spawn.ps1 to assemble prompts with the hygiene tail auto-injected." -ForegroundColor Yellow
    exit 1
}
