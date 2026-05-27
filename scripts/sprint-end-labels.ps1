#Requires -Version 5.1
<#
.SYNOPSIS
    Applies sprint-end label transitions to issues and PRs with a sprint label.
.DESCRIPTION
    For every issue or PR carrying the requested sprint label:
      1. Remove release:backlog (if present)
      2. Add the requested release:shipped-X.Y.Z label (if missing)

    After every gh issue edit, re-query labels and verify the expected state.
    Retry verification reads up to 3 times with exponential backoff: 1s, 2s, 4s.

    Idempotent: safe to run twice.

    Type/area/squad/priority labels are never touched.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SprintLabel  = ''
$ReleaseLabel = ''
$Repo         = ''
$DryRun       = $false
$BacklogLabel = 'release:backlog'

function Write-Log  { param([string]$Message) Write-Host "[sprint-end-labels] $Message" }
function Write-Warn { param([string]$Message) [System.Console]::Error.WriteLine("[sprint-end-labels] WARN: $Message") }
function Write-Err  { param([string]$Message) [System.Console]::Error.WriteLine("[sprint-end-labels] ERROR: $Message") }

function Show-Usage {
    param([int]$ExitCode)

    $usage = @'
scripts/sprint-end-labels.ps1 - Sprint-end label automation (Issue #423)

Applies sprint-end label transitions to all issues and PRs carrying a given
sprint label. For each match:
  1. Remove release:backlog (if present)
  2. Add release:shipped-X.Y.Z (if missing)

Verification:
  After every gh issue edit --add-label or --remove-label, re-query the
  issue via `gh issue view <N> --json labels` and assert the desired state.
  Retry up to 3 times with exponential backoff (1s, 2s, 4s).
  Fail loudly if still mismatched after the final retry.

Idempotent: safe to run twice. A second run finds no work to do.

Type/area/squad/priority labels are NEVER touched by this script.

Usage:
  scripts/sprint-end-labels.ps1 --sprint sprint:17 --release-label release:shipped-1.17.0 [--repo owner/repo] [--dry-run]

Examples:
  pwsh -File scripts/sprint-end-labels.ps1 --sprint sprint:16 --release-label release:shipped-1.16.0 --dry-run
  pwsh -File scripts/sprint-end-labels.ps1 --sprint sprint:17 --release-label release:shipped-1.17.0
'@

    Write-Host $usage
    exit $ExitCode
}

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--sprint' {
            if (($i + 1) -ge $args.Count) {
                Write-Err '--sprint requires a label value'
                Show-Usage 2
            }
            $i++
            $SprintLabel = [string]$args[$i]
        }
        '--release-label' {
            if (($i + 1) -ge $args.Count) {
                Write-Err '--release-label requires a label value'
                Show-Usage 2
            }
            $i++
            $ReleaseLabel = [string]$args[$i]
        }
        '--repo' {
            if (($i + 1) -ge $args.Count) {
                Write-Err '--repo requires an owner/repo value'
                Show-Usage 2
            }
            $i++
            $Repo = [string]$args[$i]
        }
        '--dry-run' {
            $DryRun = $true
        }
        '--help' {
            Show-Usage 0
        }
        '-h' {
            Show-Usage 0
        }
        default {
            Write-Err ("unknown argument: {0}" -f $args[$i])
            Show-Usage 2
        }
    }
    $i++
}

if ([string]::IsNullOrWhiteSpace($SprintLabel)) {
    Write-Err '--sprint <label> is required (e.g. --sprint sprint:17)'
    Write-Host 'Hint: use --help for usage.'
    exit 2
}

if ([string]::IsNullOrWhiteSpace($ReleaseLabel)) {
    Write-Err '--release-label <label> is required (e.g. --release-label release:shipped-1.17.0)'
    Write-Host 'Hint: use --help for usage.'
    exit 2
}

if ($ReleaseLabel -notlike 'release:shipped-*') {
    Write-Err ("--release-label must start with 'release:shipped-' (got: {0})" -f $ReleaseLabel)
    exit 2
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Err 'gh CLI not found on PATH'
    exit 127
}

$GhRepoArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Repo)) {
    $GhRepoArgs = @('--repo', $Repo)
}

function ConvertFrom-JsonArray {
    param([string]$JsonText)

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return @()
    }

    $parsed = $JsonText | ConvertFrom-Json
    if ($null -eq $parsed) {
        return @()
    }

    return @($parsed)
}

function Invoke-GhJson {
    param([string[]]$Arguments)

    $output = & gh @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Err ("gh {0} failed with exit {1}" -f ($Arguments -join ' '), $exitCode)
        exit $exitCode
    }

    if ($null -eq $output) {
        return ''
    }

    return ((($output | Out-String) -replace "`r", '') -replace "`n$", '')
}

function Get-LabelNamesFromObject {
    param($Item)

    $names = @()
    if ($null -eq $Item) {
        return $names
    }

    foreach ($label in @($Item.labels)) {
        if ($null -ne $label -and $null -ne $label.name) {
            $names += [string]$label.name
        }
    }

    return $names
}

function Get-LabelNamesForNumber {
    param([string]$Number)

    $json = Invoke-GhJson (@('issue', 'view', $Number) + $GhRepoArgs + @('--json', 'labels'))
    $items = ConvertFrom-JsonArray -JsonText $json
    if (@($items).Count -eq 0) {
        return @()
    }

    return @(Get-LabelNamesFromObject -Item $items[0])
}

function Get-CurrentLabelsCsv {
    param([string]$Number)

    $labelNames = @(Get-LabelNamesForNumber -Number $Number)
    if ($labelNames.Count -eq 0) {
        return ''
    }

    return [string]::Join(', ', $labelNames)
}

function Test-HasLabel {
    param(
        [string]$Number,
        [string]$Target
    )

    $labelNames = @(Get-LabelNamesForNumber -Number $Number)
    return ($labelNames -contains $Target)
}

function Verify-WithRetry {
    param(
        [string]$Number,
        [string]$Label,
        [string]$Mode
    )

    $delays = @(1, 2, 4)
    $attempt = 0

    while ($true) {
        $hasLabel = Test-HasLabel -Number $Number -Target $Label
        if ($Mode -eq 'present') {
            if ($hasLabel) {
                Write-Log ("    verified: #{0} has '{1}'" -f $Number, $Label)
                return
            }
        }
        else {
            if (-not $hasLabel) {
                Write-Log ("    verified: #{0} no longer has '{1}'" -f $Number, $Label)
                return
            }
        }

        if ($attempt -ge $delays.Count) {
            Write-Err ("verification FAILED for #{0} after {1} retries" -f $Number, $attempt)
            Write-Err ("  expected: {0} is {1}" -f $Label, $Mode)
            Write-Err ("  current labels: {0}" -f (Get-CurrentLabelsCsv -Number $Number))
            exit 1
        }

        $sleepFor = $delays[$attempt]
        Write-Warn ("verification mismatch for #{0} (expected '{1}' {2}); retry in {3}s" -f $Number, $Label, $Mode, $sleepFor)
        Start-Sleep -Seconds $sleepFor
        $attempt++
    }
}

function Invoke-GhEdit {
    param(
        [string]$Number,
        [string]$Option,
        [string]$Label
    )

    $null = & gh issue edit $Number @GhRepoArgs $Option $Label
    return $LASTEXITCODE
}

function Process-Issue {
    param(
        [string]$Number,
        [string]$Title,
        [string[]]$LabelNames
    )

    $currentLabels = [string]::Join(',', $LabelNames)
    Write-Log ("issue #{0}: {1}" -f $Number, $Title)
    Write-Log ("  current labels: {0}" -f $currentLabels)

    $hasBacklog = ($LabelNames -contains $BacklogLabel)
    $hasShipped = ($LabelNames -contains $ReleaseLabel)

    if ($hasBacklog) {
        if ($DryRun) {
            Write-Log ("  DRY-RUN would remove: {0}" -f $BacklogLabel)
        }
        else {
            Write-Log ("  removing: {0}" -f $BacklogLabel)
            $editExitCode = Invoke-GhEdit -Number $Number -Option '--remove-label' -Label $BacklogLabel
            if ($editExitCode -ne 0) {
                Write-Warn '  gh issue edit --remove-label returned non-zero (continuing into verify)'
            }
            Verify-WithRetry -Number $Number -Label $BacklogLabel -Mode 'absent'
        }
    }
    else {
        Write-Log ("  skip remove: {0} not present (idempotent)" -f $BacklogLabel)
    }

    if (-not $hasShipped) {
        if ($DryRun) {
            Write-Log ("  DRY-RUN would add: {0}" -f $ReleaseLabel)
        }
        else {
            Write-Log ("  adding: {0}" -f $ReleaseLabel)
            $editExitCode = Invoke-GhEdit -Number $Number -Option '--add-label' -Label $ReleaseLabel
            if ($editExitCode -ne 0) {
                Write-Warn '  gh issue edit --add-label returned non-zero (continuing into verify)'
            }
            Verify-WithRetry -Number $Number -Label $ReleaseLabel -Mode 'present'
        }
    }
    else {
        Write-Log ("  skip add: {0} already present (idempotent)" -f $ReleaseLabel)
    }
}

Write-Log ("sprint label   : {0}" -f $SprintLabel)
Write-Log ("release label  : {0}" -f $ReleaseLabel)
Write-Log ("dry-run        : {0}" -f $(if ($DryRun) { 'yes' } else { 'no' }))
if (-not [string]::IsNullOrWhiteSpace($Repo)) {
    Write-Log ("repo           : {0}" -f $Repo)
}
else {
    Write-Log 'repo           : (default from git remote)'
}

Write-Log ("querying issues (state:closed) + PRs (state:merged) with label '{0}'" -f $SprintLabel)

$issuesJson = Invoke-GhJson (@('issue', 'list') + $GhRepoArgs + @('--state', 'closed', '--search', ('label:"{0}"' -f $SprintLabel), '--json', 'number,title,labels', '--limit', '200'))
$prsJson    = Invoke-GhJson (@('pr', 'list') + $GhRepoArgs + @('--state', 'merged', '--search', ('label:"{0}"' -f $SprintLabel), '--json', 'number,title,labels', '--limit', '200'))

$issues = @(ConvertFrom-JsonArray -JsonText $issuesJson)
$prs    = @(ConvertFrom-JsonArray -JsonText $prsJson)

$itemsByNumber = @{}
foreach ($item in @($issues + $prs)) {
    if ($null -ne $item -and $null -ne $item.number) {
        $itemsByNumber[[string]$item.number] = $item
    }
}

$allItems = @($itemsByNumber.Values | Sort-Object { [int]$_.number })
$count = $allItems.Count

Write-Log ("found {0} issue(s)/PR(s) with label '{1}'" -f $count, $SprintLabel)

if ($count -eq 0) {
    Write-Log 'nothing to do. exiting cleanly.'
    exit 0
}

if (@($issues).Count -ge 200 -or @($prs).Count -ge 200) {
    Write-Warn 'hit the 200-item cap on issues or PRs; re-run with a narrower sprint label if more exist'
}

$total = 0
$changed = 0
$skipped = 0
foreach ($item in $allItems) {
    $total++
    $labelNames = @(Get-LabelNamesFromObject -Item $item)
    Process-Issue -Number ([string]$item.number) -Title ([string]$item.title) -LabelNames $labelNames

    $neededChange = $false
    if ($labelNames -contains $BacklogLabel) {
        $neededChange = $true
    }
    if (-not ($labelNames -contains $ReleaseLabel)) {
        $neededChange = $true
    }

    if ($neededChange) {
        $changed++
    }
    else {
        $skipped++
    }
}

Write-Log ("summary: total={0} changed={1} already-correct={2} dry-run={3}" -f $total, $changed, $skipped, $(if ($DryRun) { 'yes' } else { 'no' }))
exit 0
