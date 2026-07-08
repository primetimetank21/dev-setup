# scripts/windows/tools/git-hook.ps1 - Configure git hooks
#
# Extracted from Install-GitHook in scripts/windows/setup.ps1.
# Called by the dispatcher as a normal tool step.
# Self-guards: exits 0 cleanly when git is not present.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

function Install-GitHook {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn "git not present -- skipping hooks configuration"
        return
    }
    Write-Info "Configuring git hooks..."
    & git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git config core.hooksPath hooks
        Write-Ok "Git hooks configured (core.hooksPath=hooks)"
    } else {
        Write-Warn "Not inside a git repo -- skipping hooks config"
    }
    $global:LASTEXITCODE = 0
}
