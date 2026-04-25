# scripts/windows/setup.ps1 - Core Windows installer
#
# Called by: setup.ps1 (root entry point)
# Owner:     Goofy (#2)
#
# Installs developer tools on Windows using winget as the primary package manager.
# Each install function is idempotent - safe to run multiple times.
# Requires: Windows 10 1709+ with App Installer (winget) available.
#
# Usage (direct):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

# Windows has no native zsh. Git for Windows ships Git Bash (MinGW bash),
# which is the practical unix-shell equivalent on Windows.
function Install-GitBash {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git (and Git Bash) already installed: $(git --version)"
        return
    }
    Write-Info "Installing Git for Windows (includes Git Bash)..."
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "Git for Windows installed"
    Write-Info "Git Bash available at: C:\Program Files\Git\bin\bash.exe"
}

function Install-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Ok "uv already installed: $(uv --version)"
        return
    }
    Write-Info "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    Write-Ok "uv installed"
}

function Install-Nvm {
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        Write-Ok "nvm already installed: $(nvm version)"
        return
    }
    Write-Info "Installing nvm-windows..."
    winget install --id CoreyButler.NVMforWindows --silent --accept-source-agreements --accept-package-agreements
    # Reload PATH so nvm is usable in the current session without restarting
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Ok "nvm-windows installed"
    Write-Warn "Run 'nvm install lts && nvm use lts' in a new terminal to install Node.js"
}

function Install-GhCli {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh already installed: $(gh --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "gh CLI installed"
}

# Vim - modal text editor; used by vb/vz aliases and general terminal editing.
function Install-Vim {
    if (Get-Command vim -ErrorAction SilentlyContinue) {
        Write-Ok "vim already installed: $(vim --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing vim..."
    winget install --id vim.vim --silent --accept-source-agreements --accept-package-agreements
    # winget does not reliably add vim to PATH -- find and register it manually
    $vimExe = Get-ChildItem 'C:\Program Files*\Vim\*\vim.exe' -ErrorAction SilentlyContinue |
              Sort-Object -Property FullName -Descending |
              Select-Object -First 1
    if ($vimExe) {
        $vimDir = $vimExe.DirectoryName
        $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($userPath -notlike "*$vimDir*") {
            [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$vimDir", 'User')
        }
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        Write-Ok "vim installed"
    } else {
        Write-Ok "vim installed"
        Write-Warn "vim not found on PATH -- restart your terminal or verify C:\Program Files\Vim"
    }
}

# psmux - tmux equivalent for Windows PowerShell terminal multiplexer.
function Install-Psmux {
    if (Get-Command psmux -ErrorAction SilentlyContinue) {
        Write-Ok "psmux already installed: $(psmux --version 2>&1)"
        return
    }
    Write-Info "Installing psmux..."
    winget install --id psmux --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "psmux installed"
}

function Install-CopilotCli {
    # Accept either the standalone binary (winget) or the legacy gh extension
    if (Get-Command copilot -ErrorAction SilentlyContinue) {
        Write-Ok "GitHub Copilot CLI already installed"
        return
    }
    try {
        $extensions = gh extension list 2>&1
        if ($extensions -match "gh-copilot") {
            Write-Ok "GitHub Copilot CLI (gh extension) already installed"
            return
        }
    } catch {
        Write-Verbose "gh extension check skipped: $_"
    }

    Write-Info "Installing GitHub Copilot CLI..."
    # Mirrors the official install script (https://gh.io/copilot-install) on Windows:
    # on Windows it routes to `winget install GitHub.Copilot` (standalone binary).
    winget install --id GitHub.Copilot --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "Copilot CLI installed"
}

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
            Set-Content $profilePath $raw -NoNewline
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

# END dev-setup profile
'@

    # Write to each profile path
    foreach ($profilePath in $profilePaths) {
        # Ensure profile directory exists
        $profileDir = Split-Path $profilePath
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        # Append to profile (create if absent).
        # Always prepend a blank line so we don't concatenate onto any existing last line.
        if (Test-Path $profilePath) {
            Add-Content -Path $profilePath -Value ""
        }
        Add-Content -Path $profilePath -Value $profileContent
        Write-Ok "PowerShell profile shortcuts installed to $profilePath"
    }

    # Check execution policy and warn if restricted
    $execPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($execPolicy -eq 'Restricted' -or $execPolicy -eq 'Undefined') {
        Write-Warn "Execution policy is '$execPolicy' -- profile aliases may not load in new terminals."
        Write-Warn "To fix: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }
}

# install squad-cli globally via npm
function Install-SquadCli {
    if (Get-Command squad -ErrorAction SilentlyContinue) {
        Write-Ok "squad-cli already installed: $(squad --version 2>&1)"
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "npm not found -- skipping squad-cli install"
        return
    }
    Write-Info "Installing squad-cli..."
    npm install -g "@bradygaster/squad-cli"
    Write-Ok "squad-cli installed"
}

function Install-GitHook {
    Write-Info "Configuring git hooks..."
    & git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git config core.hooksPath hooks
        Write-Ok "Git hooks configured (core.hooksPath=hooks)"
    } else {
        Write-Warn "Not inside a git repo - skipping hooks config"
    }
}

function Main {
    Write-Info "Starting Windows setup..."
    Write-Info "Checking for winget..."
    if (-not (Test-WingetAvailable)) {
        Write-Err "winget not found. Please install App Installer from the Microsoft Store."
        Write-Err "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1"
        exit 1
    }

    Install-GitBash
    Install-Uv
    Install-Nvm
    Install-GhCli
    Install-Vim
    Install-Psmux
    Install-CopilotCli
    Install-SquadCli
    Write-PowerShellProfile
    Install-GitHook

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: nvm install lts && nvm use lts"
    Write-Info "  3. Run: gh auth login"
}

Main
