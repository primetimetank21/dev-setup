# scripts/windows/tools/profile.ps1 - PowerShell profile writer
#
# Owner: Goofy (#2)
# Writes dev-setup shortcuts to PowerShell profile (both PS 5.1 and PS 7+)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

function Write-PowerShellProfile {
    $beginMarker = '# BEGIN dev-setup profile'
    $endMarker   = '# END dev-setup profile'

    # Write to BOTH PS 5.1 and PS 7+ profile paths explicitly
    $profilePaths = @(
        [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'),  # PS 5.1
        [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')          # PS 7+
    )

    foreach ($profilePath in $profilePaths) {
        # If the managed block already exists, strip it out so we can re-inject fresh
        if ((Test-Path $profilePath) -and (Select-String -Path $profilePath -Pattern ([regex]::Escape($beginMarker)) -Quiet)) {
            Write-Info "Updating PowerShell profile shortcuts in $profilePath..."
            $raw = Get-Content $profilePath -Raw
            # Strip the managed block (handles both LF and CRLF)
            $raw = $raw -replace "(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?", ''
            Set-Content $profilePath $raw -NoNewline -Encoding ASCII
        }
    }

    $profileContent = @'
# BEGIN dev-setup profile
# -- Linux-compatible commands --------------------------------------------------

function Remove-CustomItem {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )
    Remove-Item -Path $Path -Recurse -Force
}
Remove-Item -Force Alias:\rm -ErrorAction SilentlyContinue
Set-Alias -Name rm -Value Remove-CustomItem -Force -Scope Global

function Set-FileTimestamp {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}
Set-Alias -Name touch -Value Set-FileTimestamp -Force -Scope Global

# -- Git shortcuts --------------------------------------------------------------

function Get-GitStatus { git status -sb $args }   # short branch status
Set-Alias -Name gs -Value Get-GitStatus -Force -Scope Global

function Invoke-GitCommit { git commit $args }
Remove-Item -Force Alias:\gc -ErrorAction SilentlyContinue
Set-Alias -Name gc -Value Invoke-GitCommit -Force -Scope Global

function Get-GitBranch { git branch $args }
Set-Alias -Name gb -Value Get-GitBranch -Force -Scope Global

function Add-GitFiles { git add $args }
Set-Alias -Name ga -Value Add-GitFiles -Force -Scope Global

function Get-GitLogPretty { git log --graph --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' $args }
Remove-Item -Force Alias:\gl -ErrorAction SilentlyContinue
Set-Alias -Name gl -Value Get-GitLogPretty -Force -Scope Global

function Get-GitLog { git log $args }
Set-Alias -Name glog -Value Get-GitLog -Force -Scope Global

function Invoke-GitFetch { git fetch $args }
Set-Alias -Name gf -Value Invoke-GitFetch -Force -Scope Global

function Invoke-GitFetchPrune { git fetch --prune $args }
Set-Alias -Name gfp -Value Invoke-GitFetchPrune -Force -Scope Global

function Invoke-GitStash { git stash $args }
Set-Alias -Name ggs -Value Invoke-GitStash -Force -Scope Global

function Get-GitStashList { git stash list $args }
Set-Alias -Name ggsls -Value Get-GitStashList -Force -Scope Global

function Add-GitAllFiles { git add --all $args }            # stage all changes
Set-Alias -Name gaa -Value Add-GitAllFiles -Force -Scope Global

function Invoke-GitCommitMessage { git commit -m $args }    # commit with inline message
Remove-Item -Force Alias:\gcm -ErrorAction SilentlyContinue
Set-Alias -Name gcm -Value Invoke-GitCommitMessage -Force -Scope Global

function New-GitBranch { git checkout -b $args }            # create and switch to new branch
Remove-Item -Force Alias:\gcb -ErrorAction SilentlyContinue
Set-Alias -Name gcb -Value New-GitBranch -Force -Scope Global

function Invoke-GitCheckout { git checkout $args }          # switch branch or restore file
Set-Alias -Name gco -Value Invoke-GitCheckout -Force -Scope Global

function Get-GitDiff { git diff $args }                     # show unstaged diff
Set-Alias -Name gd -Value Get-GitDiff -Force -Scope Global

function Get-GitDiffStaged { git diff --staged $args }      # show staged diff
Set-Alias -Name gds -Value Get-GitDiffStaged -Force -Scope Global

function Invoke-GitStashPop { git stash pop $args }         # pop most recent stash
Set-Alias -Name ggsp -Value Invoke-GitStashPop -Force -Scope Global

function Invoke-GitPush { git push $args }                  # push to remote
Remove-Item -Force Alias:\gp -ErrorAction SilentlyContinue
Set-Alias -Name gp -Value Invoke-GitPush -Force -Scope Global

function Invoke-GitPushForce { git push --force-with-lease $args }  # safe force push
Set-Alias -Name gpf -Value Invoke-GitPushForce -Force -Scope Global

function Invoke-GitPull { git pull $args }                  # pull from remote
Set-Alias -Name gpl -Value Invoke-GitPull -Force -Scope Global

function Invoke-GitRebase { git rebase $args }              # rebase onto branch
Remove-Item -Force Alias:\grb -ErrorAction SilentlyContinue
Set-Alias -Name grb -Value Invoke-GitRebase -Force -Scope Global

function Invoke-GitRebaseInteractive { git rebase -i $args }  # interactive rebase
Set-Alias -Name grbi -Value Invoke-GitRebaseInteractive -Force -Scope Global

function Invoke-GitRestore { git restore $args }            # discard working tree changes
Remove-Item -Force Alias:\grs -ErrorAction SilentlyContinue
Set-Alias -Name grs -Value Invoke-GitRestore -Force -Scope Global

function Invoke-GitRestoreStaged { git restore --staged $args }  # unstage a file
Set-Alias -Name grss -Value Invoke-GitRestoreStaged -Force -Scope Global

# -- GitHub CLI shortcuts -------------------------------------------------------

function New-GhPR { gh pr create $args }                    # open a pull request
Set-Alias -Name ghpr -Value New-GhPR -Force -Scope Global

function Get-GhPRList { gh pr list $args }                  # list pull requests
Set-Alias -Name ghprl -Value Get-GhPRList -Force -Scope Global

function Get-GhPRView { gh pr view $args }                  # view a pull request
Set-Alias -Name ghprv -Value Get-GhPRView -Force -Scope Global

function Get-GhIssueList { gh issue list $args }            # list issues
Set-Alias -Name ghis -Value Get-GhIssueList -Force -Scope Global

function Get-GhIssueView { gh issue view $args }            # view an issue
Set-Alias -Name ghiv -Value Get-GhIssueView -Force -Scope Global

# -- Dev shortcuts --------------------------------------------------------------

function Invoke-UvRun { uv run $args }                      # run with uv
Set-Alias -Name uvr -Value Invoke-UvRun -Force -Scope Global

function Invoke-UvSync { uv sync $args }                    # sync uv environment
Set-Alias -Name uvs -Value Invoke-UvSync -Force -Scope Global

function Invoke-NpmInstall { npm install $args }            # npm install
Remove-Item -Force Alias:\ni -ErrorAction SilentlyContinue
Set-Alias -Name ni -Value Invoke-NpmInstall -Force -Scope Global

function Invoke-NpmRun { npm run $args }                    # npm run <script>
Set-Alias -Name nr -Value Invoke-NpmRun -Force -Scope Global

function Invoke-NpmRunDev { npm run dev $args }             # npm run dev
Set-Alias -Name nrd -Value Invoke-NpmRunDev -Force -Scope Global

function Invoke-NpmRunTest { npm run test $args }           # npm run test
Set-Alias -Name nrt -Value Invoke-NpmRunTest -Force -Scope Global

function Invoke-Python { python $args }                     # python shorthand
Set-Alias -Name py -Value Invoke-Python -Force -Scope Global

Set-Alias -Name c -Value Clear-Host -Force -Scope Global    # clear the screen

# -- Utility --------------------------------------------------------------------

function Get-MyIp { curl.exe -s ifconfig.me $args }         # show public IP
Set-Alias -Name myip -Value Get-MyIp -Force -Scope Global

function Invoke-PingBing { ping bing.com $args }            # quick connectivity check
Set-Alias -Name pb -Value Invoke-PingBing -Force -Scope Global

Remove-Item -Force Alias:\h -ErrorAction SilentlyContinue
Set-Alias -Name h -Value Get-History -Force -Scope Global   # command history

function Edit-Profile { notepad $PROFILE }  # open PS profile in editor
Remove-Item -Force Alias:\ep -ErrorAction SilentlyContinue
Set-Alias -Name ep -Value Edit-Profile -Force -Scope Global

# -- psmux (tmux for Windows) -----------------------------------------------

function Invoke-PsmuxList { psmux ls $args }                    # list active psmux sessions
Set-Alias -Name tls -Value Invoke-PsmuxList -Force -Scope Global

function Invoke-PsmuxKillServer { psmux kill-server $args }     # kill all psmux sessions
Set-Alias -Name tks -Value Invoke-PsmuxKillServer -Force -Scope Global

function Invoke-PsmuxNewSession { psmux new-session -s tank_dev $args }  # create new named psmux session
Set-Alias -Name tt -Value Invoke-PsmuxNewSession -Force -Scope Global

function Invoke-PsmuxAttach { psmux attach $args }              # attach to most recent psmux session
Set-Alias -Name ta -Value Invoke-PsmuxAttach -Force -Scope Global

# Create or attach to the tank_dev psmux session (Windows equivalent of create_tmux)
function New-PsmuxSession {
    $session = 'tank_dev'
    $exists = psmux ls 2>$null | Select-String -Pattern $session -Quiet
    if (-not $exists) {
        psmux new-session -d -s $session
    }
    psmux attach -t $session
}

# -- Shutdown -------------------------------------------------------------------

function Invoke-ShutdownNow {
    # Shut down the machine immediately
    shutdown /s /t 0
}
Set-Alias -Name sdn -Value Invoke-ShutdownNow -Force -Scope Global

function Invoke-TimedShutdown {
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Minutes
    )
    # Schedule shutdown in N minutes (converts minutes to seconds for Windows)
    shutdown /s /t ($Minutes * 60)
}
Set-Alias -Name tsdn -Value Invoke-TimedShutdown -Force -Scope Global

function Invoke-CancelTimedShutdown {
    # Cancel a pending timed shutdown
    $result = shutdown /a 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No pending shutdown to cancel."
    }
}
Set-Alias -Name cancel_tsdn -Value Invoke-CancelTimedShutdown -Force -Scope Global

# END dev-setup profile
'@

    # Diagnostics: log both profile paths being targeted (PS 5.1 vs PS 7+)
    Write-Info "PS 5.1 profile path: $($profilePaths[0])"
    Write-Info "PS 7+  profile path: $($profilePaths[1])"

    # Diagnostics: log execution policy before writing - helps diagnose load failures on PS 5.1
    $execPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Write-Info "Execution policy (CurrentUser): $execPolicy"
    if ($execPolicy -eq 'Restricted' -or $execPolicy -eq 'Undefined') {
        Write-Warn "Execution policy is '$execPolicy' -- profile aliases may not load in new terminals."
        Write-Warn "To fix: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }

    # Write to each profile path
    foreach ($profilePath in $profilePaths) {
        $profileDir = Split-Path $profilePath

        # Diagnostics: log target directory before creation attempt
        Write-Info "Target profile directory: $profileDir"

        # Ensure profile directory exists
        try {
            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
        } catch {
            Write-Err "Failed to create profile directory '$profileDir': $_"
            continue
        }

        # Diagnostics: confirm directory exists after creation
        if (Test-Path $profileDir) {
            Write-Info "Profile directory confirmed: $profileDir"
        } else {
            Write-Err "Profile directory does not exist after creation attempt: $profileDir"
            continue
        }

        # Diagnostics: log the profile file path being written
        Write-Info "Writing profile content to: $profilePath"

        # Append to profile (create if absent).
        # Always prepend a blank line so we don't concatenate onto any existing last line.
        try {
            if (Test-Path $profilePath) {
                Add-Content -Path $profilePath -Value "" -Encoding ASCII
            }
            Add-Content -Path $profilePath -Value $profileContent -Encoding ASCII
        } catch {
            Write-Err "Failed to write profile to '$profilePath': $_"
            continue
        }

        # Post-write validation: confirm file exists and log size in bytes
        if (Test-Path $profilePath) {
            $fileSize = (Get-Item $profilePath).Length
            Write-Ok "Profile written: $profilePath ($fileSize bytes)"
        } else {
            Write-Err "Profile write failed - file not found after write: $profilePath"
        }
    }
}
