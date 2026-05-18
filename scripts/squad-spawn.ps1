#Requires -Version 5.1
<#
.SYNOPSIS
    Assembles a coordinator spawn prompt by appending the hygiene tail template.
.DESCRIPTION
    Reads a spawn-prompt body from --body <path> or stdin, appends the verbatim
    contents of .squad/templates/spawn-prompt-hygiene.md (with {name}, {N}, and
    {worktree-path} substituted), and writes the assembled prompt to stdout.
    Idempotent: if the body already contains all 6 hygiene tail markers the
    template is not appended again.
    Exit 0 on success, exit 1 on error.
.EXAMPLE
    pwsh -File scripts\squad-spawn.ps1 --body prompt.md --name donald --issue 123 --worktree C:\Coding\dev-setup-123
    echo "body text" | pwsh -File scripts\squad-spawn.ps1 --name donald --issue 123 --worktree C:\Coding\dev-setup-123
.PARAMETER body
    Path to a file containing the spawn-prompt body. If omitted, body is read from stdin.
.PARAMETER template
    Path to the hygiene tail template. Defaults to .squad\templates\spawn-prompt-hygiene.md
    relative to the repo root (parent of the scripts\ directory).
.PARAMETER name
    Agent name. Replaces {name} in the template.
.PARAMETER issue
    Issue number. Replaces {N} in the template.
.PARAMETER worktree
    Worktree path. Replaces {worktree-path} in the template.
#>

$ErrorActionPreference = 'Stop'

$bodyPath     = $null
$templatePath = $null
$agentName    = ''
$issueNum     = ''
$worktreePath = ''

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--body'     { $i++; $bodyPath     = $args[$i] }
        '--template' { $i++; $templatePath = $args[$i] }
        '--name'     { $i++; $agentName    = $args[$i] }
        '--issue'    { $i++; $issueNum     = $args[$i] }
        '--worktree' { $i++; $worktreePath = $args[$i] }
        default {
            Write-Host "ERROR: Unknown argument: $($args[$i])" -ForegroundColor Red
            exit 1
        }
    }
    $i++
}

# Resolve template path (default: .squad\templates\spawn-prompt-hygiene.md at repo root)
if (-not $templatePath) {
    $repoRoot     = Split-Path $PSScriptRoot -Parent
    $templatePath = Join-Path $repoRoot '.squad\templates\spawn-prompt-hygiene.md'
}

if (-not (Test-Path -LiteralPath $templatePath)) {
    Write-Host "ERROR: Template not found: $templatePath" -ForegroundColor Red
    exit 1
}

# Read body
if ($bodyPath) {
    if (-not (Test-Path -LiteralPath $bodyPath)) {
        Write-Host "ERROR: Body file not found: $bodyPath" -ForegroundColor Red
        exit 1
    }
    $bodyText = [System.IO.File]::ReadAllText($bodyPath)
} elseif ([System.Console]::IsInputRedirected) {
    $bodyText = [System.Console]::In.ReadToEnd()
} else {
    Write-Host "ERROR: No body provided. Use --body <path> or pipe body text via stdin." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($bodyText)) {
    Write-Host "ERROR: Body is empty. Provide --body <path> or pipe body text via stdin." -ForegroundColor Red
    exit 1
}

# Read template and perform substitutions
$templateText = [System.IO.File]::ReadAllText($templatePath)
if ($agentName)    { $templateText = $templateText.Replace('{name}', $agentName) }
if ($issueNum)     { $templateText = $templateText.Replace('{N}', $issueNum) }
if ($worktreePath) { $templateText = $templateText.Replace('{worktree-path}', $worktreePath) }

# Idempotency: skip re-append if all 6 hygiene tail markers are already present
$markers = @(
    'CWD-pin',
    'base=develop discipline',
    'ASCII discipline',
    'history.md pre-size-check',
    'Worktree-remove-FIRST',
    'Hygiene tail completion'
)
$allPresent = $true
foreach ($m in $markers) {
    if ($bodyText.IndexOf($m) -lt 0) { $allPresent = $false; break }
}

if ($allPresent) {
    [System.Console]::Write($bodyText)
} else {
    [System.Console]::Write($bodyText + "`n`n---`n`n" + $templateText)
}
