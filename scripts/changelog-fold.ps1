# scripts/changelog-fold.ps1 -- CHANGELOG fold automation (Issue #415)
#
# Owner: Donald
# Closes: #415 (Windows mirror of scripts/changelog-fold.sh)
#
# Enumerates all PRs merged and issues closed since the last release tag,
# categorizes them by label/title-prefix, compares with [Unreleased], and
# either prints the proposed [X.Y.Z] section (-DryRun, default) or folds
# CHANGELOG.md in-place (-Apply).
#
# Usage (PowerShell naming convention -- same logic as changelog-fold.sh):
#   scripts/changelog-fold.ps1 -ReleaseVersion X.Y.Z [options]
#
# Required:
#   -ReleaseVersion X.Y.Z
#
# Optional:
#   -LastTag TAG              (default: git describe --tags --abbrev=0 origin/main)
#   -ReleaseDate YYYY-MM-DD   (default: today)
#   -ChangelogPath PATH       (default: .\CHANGELOG.md)
#   -DryRun                   (default -- print proposed section to stdout)
#   -Apply                    (in-place fold; mutually exclusive with -DryRun)
#
# Examples:
#   # Dry-run (default):
#   scripts/changelog-fold.ps1 -ReleaseVersion 0.9.9 -LastTag 0.9.8
#
#   # Apply (in-place):
#   scripts/changelog-fold.ps1 -ReleaseVersion 0.9.9 -LastTag 0.9.8 -Apply

[CmdletBinding(DefaultParameterSetName = 'DryRun')]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseVersion,

    [string]$LastTag = '',

    [string]$ReleaseDate = '',

    [string]$ChangelogPath = '.\CHANGELOG.md',

    [Parameter(ParameterSetName = 'DryRun')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Mode = if ($Apply) { 'apply' } else { 'dry-run' }

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

function Write-Log   { param([string]$Msg) Write-Host "[changelog-fold] $Msg" }
function Write-Warn  { param([string]$Msg) Write-Host "[changelog-fold] WARN: $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "[changelog-fold] ERROR: $Msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

foreach ($tool in @('gh', 'jq')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Err "$tool not found on PATH"
        exit 127
    }
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if ($ReleaseVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Err "-ReleaseVersion must be X.Y.Z (e.g. 0.9.9), got: $ReleaseVersion"
    exit 2
}

if ($ReleaseDate -ne '' -and $ReleaseDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Write-Err "-ReleaseDate must be YYYY-MM-DD, got: $ReleaseDate"
    exit 2
}

if (-not (Test-Path -LiteralPath $ChangelogPath)) {
    Write-Err "CHANGELOG not found at: $ChangelogPath"
    exit 2
}

# ---------------------------------------------------------------------------
# Resolve defaults
# ---------------------------------------------------------------------------

if ($LastTag -eq '') {
    Write-Log "resolving last tag via git describe ..."
    $LastTag = (git describe --tags --abbrev=0 origin/main 2>$null) `
             ?? (git describe --tags --abbrev=0 2>$null)
    if (-not $LastTag) {
        Write-Err "could not resolve last tag; use -LastTag TAG"
        exit 1
    }
    Write-Log "last tag: $LastTag"
}

if ($ReleaseDate -eq '') {
    $ReleaseDate = (Get-Date -Format 'yyyy-MM-dd')
}

# ---------------------------------------------------------------------------
# Idempotency gate: reject if version already folded
# ---------------------------------------------------------------------------

$changelogContent = Get-Content -LiteralPath $ChangelogPath -Raw
if ($changelogContent -match "(?m)^## \[$([regex]::Escape($ReleaseVersion))\]") {
    Write-Err "version [$ReleaseVersion] is already present in $ChangelogPath -- already folded (idempotency gate)"
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve last tag SHA and date
# ---------------------------------------------------------------------------

Write-Log "resolving tag SHA for: $LastTag ..."
$lastTagSha = (git rev-parse "$LastTag^{commit}" 2>$null) `
            ?? (git rev-parse $LastTag 2>$null)
if (-not $lastTagSha) {
    Write-Err "could not resolve SHA for tag: $LastTag"
    exit 1
}
$lastTagDate = ((git log -1 --format='%ci' $lastTagSha) -split ' ')[0]
Write-Log "last tag SHA : $lastTagSha"
Write-Log "last tag date: $lastTagDate"

# ---------------------------------------------------------------------------
# Enumerate merged PRs
# ---------------------------------------------------------------------------

Write-Log "enumerating PRs merged since $lastTagDate ..."
$prsJson = (gh pr list `
    --state merged `
    --search "merged:>=$lastTagDate" `
    --json number,title,labels,mergedAt `
    --limit 200) -replace '\r', ''
$prCount = ($prsJson | jq 'length')
Write-Log "found $prCount merged PR(s)"

# ---------------------------------------------------------------------------
# Enumerate closed issues (excluding PR numbers)
# ---------------------------------------------------------------------------

Write-Log "enumerating issues closed since $lastTagDate ..."
$issuesJson = (gh issue list `
    --state closed `
    --search "closed:>=$lastTagDate" `
    --json number,title,labels,closedAt `
    --limit 200) -replace '\r', ''

$prNumbersArr = $prsJson | jq '[.[].number]'
$issuesFiltered = $issuesJson | jq `
    --argjson prnums $prNumbersArr `
    '[.[] | select(.number as $n | ($prnums | index($n)) == null)]'
$issueCount = ($issuesFiltered | jq 'length')
Write-Log "found $issueCount closed issue(s) (after PR dedup)"

# ---------------------------------------------------------------------------
# Categorize
# ---------------------------------------------------------------------------

function Get-Category {
    param([string]$Number, [string]$Title, [string]$LabelsCsv)

    $csv = ",$LabelsCsv,"
    if ($csv -match ',type:feature,') { return 'Added' }
    if ($csv -match ',type:bug,')     { return 'Fixed' }
    if ($csv -match ',type:chore,')   { return 'Changed' }
    if ($csv -match ',type:docs,')    { return 'Changed' }

    if ($Title -match '^feat[:(]')                                      { return 'Added' }
    if ($Title -match '^fix[:(]')                                       { return 'Fixed' }
    if ($Title -match '^(chore|docs|refactor|perf|style)[:(]')         { return 'Changed' }

    Write-Warn "#${Number} '${Title}': no label/prefix match -- categorized as Changed"
    return 'Changed'
}

# ---------------------------------------------------------------------------
# Build categorized entry lines
# ---------------------------------------------------------------------------

$addedLines   = [System.Collections.Generic.List[string]]::new()
$changedLines = [System.Collections.Generic.List[string]]::new()
$fixedLines   = [System.Collections.Generic.List[string]]::new()
$removedLines = [System.Collections.Generic.List[string]]::new()

$allItems = (jq -rn `
    --argjson prs $prsJson `
    --argjson issues $issuesFiltered `
    '($prs + $issues | sort_by(.number)) | .[] | [(.number|tostring), .title, ([.labels // [] | .[].name] | join(","))] | @tsv') `
    -replace '\r', ''

foreach ($line in ($allItems -split "`n")) {
    if ($line -eq '') { continue }
    $parts      = $line -split "`t", 3
    $num        = $parts[0]
    $title      = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $labelsCsv  = if ($parts.Count -gt 2) { $parts[2] } else { '' }
    $cat        = Get-Category -Number $num -Title $title -LabelsCsv $labelsCsv
    $entry      = "- $title (#$num)"
    switch ($cat) {
        'Added'   { $addedLines.Add($entry) }
        'Changed' { $changedLines.Add($entry) }
        'Fixed'   { $fixedLines.Add($entry) }
        'Removed' { $removedLines.Add($entry) }
    }
}

# ---------------------------------------------------------------------------
# Check for missing entries in [Unreleased]
# ---------------------------------------------------------------------------

$changelogLines   = Get-Content -LiteralPath $ChangelogPath
$inUnreleased     = $false
$unreleasedLines  = [System.Collections.Generic.List[string]]::new()
foreach ($cl in $changelogLines) {
    if ($cl -match '^## \[Unreleased\]') { $inUnreleased = $true; continue }
    if ($inUnreleased -and $cl -match '^## \[')  { break }
    if ($inUnreleased) { $unreleasedLines.Add($cl) }
}
$unreleasedText = $unreleasedLines -join "`n"

$missingNums = [System.Collections.Generic.List[string]]::new()
$allNums = (jq -rn `
    --argjson prs $prsJson `
    --argjson issues $issuesFiltered `
    '($prs + $issues | sort_by(.number)) | .[].number') -replace '\r', ''
foreach ($n in ($allNums -split "`n")) {
    if ($n -eq '') { continue }
    if ($unreleasedText -notmatch "\(#$n\)") {
        $missingNums.Add("#$n")
    }
}
if ($missingNums.Count -gt 0) {
    Write-Warn "Missing from [Unreleased]: $($missingNums -join ', ')"
}

# ---------------------------------------------------------------------------
# Build new [X.Y.Z] section
# ---------------------------------------------------------------------------

function Build-Section {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$ReleaseVersion] - $ReleaseDate")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('### Added')
    foreach ($e in $addedLines)   { [void]$sb.AppendLine($e) }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('### Changed')
    foreach ($e in $changedLines) { [void]$sb.AppendLine($e) }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('### Fixed')
    foreach ($e in $fixedLines)   { [void]$sb.AppendLine($e) }
    [void]$sb.AppendLine()
    [void]$sb.Append('### Removed')
    foreach ($e in $removedLines) {
        [void]$sb.AppendLine()
        [void]$sb.Append($e)
    }
    return $sb.ToString()
}

$newSection = Build-Section

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Log "mode        : $Mode"
Write-Log "version     : $ReleaseVersion"
Write-Log "date        : $ReleaseDate"
Write-Log "last tag    : $LastTag ($lastTagDate)"
Write-Log "entries     : Added=$($addedLines.Count) Changed=$($changedLines.Count) Fixed=$($fixedLines.Count) Removed=$($removedLines.Count)"

# ---------------------------------------------------------------------------
# Dry-run: print proposed section and exit
# ---------------------------------------------------------------------------

if ($Mode -eq 'dry-run') {
    Write-Host ""
    Write-Host "=== Proposed [$ReleaseVersion] section (dry-run) ==="
    Write-Host $newSection
    Write-Host "=== End proposed section ==="
    exit 0
}

# ---------------------------------------------------------------------------
# Apply: fold CHANGELOG.md in-place
# ---------------------------------------------------------------------------

$unreleasedIdx = -1
for ($i = 0; $i -lt $changelogLines.Count; $i++) {
    if ($changelogLines[$i] -match '^## \[Unreleased\]') {
        $unreleasedIdx = $i
        break
    }
}
if ($unreleasedIdx -lt 0) {
    Write-Err "## [Unreleased] not found in $ChangelogPath"
    exit 1
}

$nextVersionIdx = -1
for ($i = $unreleasedIdx + 1; $i -lt $changelogLines.Count; $i++) {
    if ($changelogLines[$i] -match '^## \[') {
        $nextVersionIdx = $i
        break
    }
}
if ($nextVersionIdx -lt 0) {
    Write-Err "no versioned section found after [Unreleased] in $ChangelogPath"
    exit 1
}

$freshUnreleased = @(
    '## [Unreleased]',
    '',
    '### Added',
    '',
    '### Changed',
    '',
    '### Fixed',
    '',
    '### Removed'
)

$newLines = [System.Collections.Generic.List[string]]::new()

# Lines before ## [Unreleased]
for ($i = 0; $i -lt $unreleasedIdx; $i++) {
    $newLines.Add($changelogLines[$i])
}

# Fresh empty [Unreleased] block
foreach ($l in $freshUnreleased) { $newLines.Add($l) }
$newLines.Add('')

# New [X.Y.Z] section
foreach ($l in ($newSection -split "`r?`n")) { $newLines.Add($l) }
$newLines.Add('')

# Rest of file from previous version header
for ($i = $nextVersionIdx; $i -lt $changelogLines.Count; $i++) {
    $newLines.Add($changelogLines[$i])
}

# Write with LF line endings (Unix-style -- same as the source file)
$output = ($newLines -join "`n")
[System.IO.File]::WriteAllText(
    (Resolve-Path $ChangelogPath).Path,
    $output,
    [System.Text.Encoding]::ASCII
)

Write-Log "CHANGELOG.md updated: [Unreleased] folded to [$ReleaseVersion]"
Write-Log "fresh [Unreleased] block restored above [$ReleaseVersion]"
