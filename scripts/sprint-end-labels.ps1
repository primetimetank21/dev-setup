#!/usr/bin/env pwsh
# scripts/sprint-end-labels.ps1 -- Sprint-end label automation (Issue #423)
#
# Owner: Mickey
# Closes: #423
#
# Applies sprint-end label transitions to all issues and PRs carrying a given
# sprint label. For each match:
#   1. Remove release:backlog (if present)
#   2. Add release:shipped-X.Y.Z (if missing)
#
# Verification (HARD REQUIREMENT per Earl directive):
#   After every gh issue edit --add-label or --remove-label, re-query the
#   issue via `gh issue view <N> --json labels` and assert the desired state.
#   Retry up to 3 times with exponential backoff (1s, 2s, 4s).
#   Fail loudly if still mismatched after the final retry.
#
# Idempotent: safe to run twice. A second run finds no work to do.
#
# Type/area/squad/priority labels are NEVER touched by this script.
#
# Usage:
#   scripts/sprint-end-labels.ps1 `
#     --sprint sprint:17 `
#     --release-label release:shipped-1.17.0 `
#     [--repo owner/repo] `
#     [--dry-run]
#
# Examples:
#   # Dry-run (no writes):
#   scripts/sprint-end-labels.ps1 --sprint sprint:16 `
#     --release-label release:shipped-1.16.0 --dry-run
#
#   # Live run:
#   scripts/sprint-end-labels.ps1 --sprint sprint:17 `
#     --release-label release:shipped-1.17.0

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Defaults / arg parsing
# ---------------------------------------------------------------------------

$SprintLabel = ""
$ReleaseLabel = ""
$Repo = ""
$DryRun = $false
$BacklogLabel = "release:backlog"

function Show-Usage {
    $lines = Get-Content $PSCommandPath | Select-Object -Skip 1 -First 40
    $lines | ForEach-Object {
        if ($_ -match '^# ?(.*)') {
            Write-Host $matches[1]
        }
    }
    exit 2
}

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        '--sprint' {
            if ($i + 1 -lt $args.Count) {
                $SprintLabel = $args[$i + 1]
                $i += 2
            } else {
                Write-Error "ERROR: --sprint requires a value"
                Show-Usage
            }
        }
        '--release-label' {
            if ($i + 1 -lt $args.Count) {
                $ReleaseLabel = $args[$i + 1]
                $i += 2
            } else {
                Write-Error "ERROR: --release-label requires a value"
                Show-Usage
            }
        }
        '--repo' {
            if ($i + 1 -lt $args.Count) {
                $Repo = $args[$i + 1]
                $i += 2
            } else {
                Write-Error "ERROR: --repo requires a value"
                Show-Usage
            }
        }
        '--dry-run' {
            $DryRun = $true
            $i++
        }
        { $_ -in '-h', '--help' } {
            Show-Usage
        }
        default {
            Write-Error "ERROR: unknown argument: $($args[$i])"
            Show-Usage
        }
    }
}

if (-not $SprintLabel) {
    Write-Error "ERROR: --sprint <label> is required (e.g. --sprint sprint:17)"
    exit 2
}

if (-not $ReleaseLabel) {
    Write-Error "ERROR: --release-label <label> is required (e.g. --release-label release:shipped-1.17.0)"
    exit 2
}

if ($ReleaseLabel -notmatch '^release:shipped-') {
    Write-Error "ERROR: --release-label must start with 'release:shipped-' (got: $ReleaseLabel)"
    exit 2
}

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: gh CLI not found on PATH"
    exit 127
}

$GhRepoArgs = @()
if ($Repo) {
    $GhRepoArgs = @('--repo', $Repo)
}

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

function Write-Log {
    param([string]$Message)
    Write-Host "[sprint-end-labels] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[sprint-end-labels] WARN: $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[sprint-end-labels] ERROR: $Message" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Core: verify label state for a single issue/PR number.
#
# Args: <number> <expected_label>
# Returns: $true if label is present, $false otherwise.
# ---------------------------------------------------------------------------

function Test-Label {
    param(
        [int]$Number,
        [string]$Label
    )
    try {
        $json = & gh issue view $Number @GhRepoArgs --json labels | ConvertFrom-Json
        $labels = $json.labels | ForEach-Object { $_.name }
        return $labels -contains $Label
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Verification loop with exponential backoff.
#
# Args: <number> <label> <mode>   (mode: "present" | "absent")
# Retries: up to 3 times, sleeping 1s, 2s, 4s between attempts.
# Exits the script (non-zero) on final failure.
# ---------------------------------------------------------------------------

function Confirm-LabelWithRetry {
    param(
        [int]$Number,
        [string]$Label,
        [string]$Mode
    )
    $delays = @(1, 2, 4)
    $attempt = 0

    while ($true) {
        $hasLabel = Test-Label -Number $Number -Label $Label

        if ($Mode -eq "present") {
            if ($hasLabel) {
                Write-Log "    verified: #$Number has '$Label'"
                return
            }
        } else {
            if (-not $hasLabel) {
                Write-Log "    verified: #$Number no longer has '$Label'"
                return
            }
        }

        if ($attempt -ge $delays.Count) {
            Write-Err "verification FAILED for #$Number after $attempt retries"
            Write-Err "  expected: $Label is $Mode"
            $currentLabels = (& gh issue view $Number @GhRepoArgs --json labels --jq '[.labels[].name] | join(", ")') -join ''
            Write-Err "  current labels: $currentLabels"
            exit 1
        }

        $sleepFor = $delays[$attempt]
        Write-Warn "verification mismatch for #$Number (expected '$Label' $Mode); retry in ${sleepFor}s"
        Start-Sleep -Seconds $sleepFor
        $attempt++
    }
}

# ---------------------------------------------------------------------------
# Apply label changes for a single issue/PR.
#
# Never touches type:, area:, squad:, priority: labels. Only release:* and
# only the two specific labels passed in (release:backlog and the shipped one).
# ---------------------------------------------------------------------------

function Update-IssueLabels {
    param(
        [int]$Number,
        [string]$Title,
        [string]$CurrentLabels
    )

    Write-Log "issue #$Number`: $Title"
    Write-Log "  current labels: $CurrentLabels"

    $hasBacklog = ",$CurrentLabels," -match ",${BacklogLabel},"
    $hasShipped = ",$CurrentLabels," -match ",${ReleaseLabel},"

    # --- step 1: remove release:backlog if present
    if ($hasBacklog) {
        if ($DryRun) {
            Write-Log "  DRY-RUN would remove: $BacklogLabel"
        } else {
            Write-Log "  removing: $BacklogLabel"
            try {
                & gh issue edit $Number @GhRepoArgs --remove-label $BacklogLabel | Out-Null
            } catch {
                Write-Warn "  gh issue edit --remove-label returned non-zero (continuing into verify)"
            }
            Confirm-LabelWithRetry -Number $Number -Label $BacklogLabel -Mode "absent"
        }
    } else {
        Write-Log "  skip remove: $BacklogLabel not present (idempotent)"
    }

    # --- step 2: add release:shipped-X.Y.Z if missing
    if (-not $hasShipped) {
        if ($DryRun) {
            Write-Log "  DRY-RUN would add: $ReleaseLabel"
        } else {
            Write-Log "  adding: $ReleaseLabel"
            try {
                & gh issue edit $Number @GhRepoArgs --add-label $ReleaseLabel | Out-Null
            } catch {
                Write-Warn "  gh issue edit --add-label returned non-zero (continuing into verify)"
            }
            Confirm-LabelWithRetry -Number $Number -Label $ReleaseLabel -Mode "present"
        }
    } else {
        Write-Log "  skip add: $ReleaseLabel already present (idempotent)"
    }
}

# ---------------------------------------------------------------------------
# Main: query issues + PRs carrying the sprint label, then process each.
# ---------------------------------------------------------------------------

function Invoke-Main {
    Write-Log "sprint label   : $SprintLabel"
    Write-Log "release label  : $ReleaseLabel"
    Write-Log "dry-run        : $(if ($DryRun) { 'yes' } else { 'no' })"
    if ($Repo) {
        Write-Log "repo           : $Repo"
    } else {
        Write-Log "repo           : (default from git remote)"
    }

    # gh issue list --search silently appends is:issue, so PRs are excluded.
    # We must query issues and PRs separately and combine them.
    Write-Log "querying issues (state:closed) + PRs (state:merged) with label '$SprintLabel'"

    $issuesJson = & gh issue list @GhRepoArgs --state closed --search "label:`"$SprintLabel`"" --json number,title,labels --limit 200
    $prsJson = & gh pr list @GhRepoArgs --state merged --search "label:`"$SprintLabel`"" --json number,title,labels --limit 200

    # Merge, deduplicate, and sort by number
    $issuesArray = if ($issuesJson) { $issuesJson | ConvertFrom-Json } else { @() }
    $prsArray = if ($prsJson) { $prsJson | ConvertFrom-Json } else { @() }
    $combined = @($issuesArray) + @($prsArray) | Sort-Object -Property number -Unique

    $count = $combined.Count
    Write-Log "found $count issue(s)/PR(s) with label '$SprintLabel'"

    if ($count -eq 0) {
        Write-Log "nothing to do. exiting cleanly."
        return
    }

    $issuesCount = @($issuesArray).Count
    $prsCount = @($prsArray).Count
    if ($issuesCount -ge 200 -or $prsCount -ge 200) {
        Write-Warn "hit the 200-item cap on issues or PRs; re-run with a narrower sprint label if more exist"
    }

    # Iterate and tally
    $total = 0
    $changed = 0
    $skipped = 0

    foreach ($item in $combined) {
        $total++
        $number = $item.number
        $title = $item.title
        $labelsCsv = ($item.labels | ForEach-Object { $_.name }) -join ','
        
        $before = $labelsCsv
        Update-IssueLabels -Number $number -Title $title -CurrentLabels $labelsCsv

        # Tally: did this issue need any change?
        $neededChange = $false
        if (",$before," -match ",${BacklogLabel},") {
            $neededChange = $true
        }
        if (",$before," -notmatch ",${ReleaseLabel},") {
            $neededChange = $true
        }
        if ($neededChange) {
            $changed++
        } else {
            $skipped++
        }
    }

    Write-Log "summary: total=$total changed=$changed already-correct=$skipped dry-run=$(if ($DryRun) { 'yes' } else { 'no' })"
}

Invoke-Main
