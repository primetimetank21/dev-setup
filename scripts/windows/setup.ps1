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
    $sentinel = '# BEGIN dev-setup profile'

    # Idempotency check - skip if already written
    if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern ([regex]::Escape($sentinel)) -Quiet)) {
        Write-Ok "PowerShell profile shortcuts already installed"
        return
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
Set-Alias -Name rm -Value Remove-CustomItem

function Set-FileTimestamp {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}
Set-Alias -Name touch -Value Set-FileTimestamp

# -- Git shortcuts --------------------------------------------------------------

function Get-GitStatus { git status -sb $args }   # short branch status
Set-Alias -Name gs -Value Get-GitStatus

function Invoke-GitCommit { git commit $args }
Remove-Item -Force Alias:\gc -ErrorAction SilentlyContinue
Set-Alias -Name gc -Value Invoke-GitCommit

function Get-GitBranch { git branch $args }
Set-Alias -Name gb -Value Get-GitBranch

function Add-GitFiles { git add $args }
Set-Alias -Name ga -Value Add-GitFiles

function Get-GitLogPretty { git log --graph --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' $args }
Remove-Item -Force Alias:\gl -ErrorAction SilentlyContinue
Set-Alias -Name gl -Value Get-GitLogPretty

function Get-GitLog { git log $args }
Set-Alias -Name glog -Value Get-GitLog

function Invoke-GitFetch { git fetch $args }
Set-Alias -Name gf -Value Invoke-GitFetch

function Invoke-GitFetchPrune { git fetch --prune $args }
Set-Alias -Name gfp -Value Invoke-GitFetchPrune

function Invoke-GitStash { git stash $args }
Set-Alias -Name ggs -Value Invoke-GitStash

function Get-GitStashList { git stash list $args }
Set-Alias -Name ggsls -Value Get-GitStashList

function Add-GitAllFiles { git add --all $args }            # stage all changes
Set-Alias -Name gaa -Value Add-GitAllFiles

function Invoke-GitCommitMessage { git commit -m $args }    # commit with inline message
Set-Alias -Name gcm -Value Invoke-GitCommitMessage

function New-GitBranch { git checkout -b $args }            # create and switch to new branch
Set-Alias -Name gcb -Value New-GitBranch

function Invoke-GitCheckout { git checkout $args }          # switch branch or restore file
Set-Alias -Name gco -Value Invoke-GitCheckout

function Get-GitDiff { git diff $args }                     # show unstaged diff
Set-Alias -Name gd -Value Get-GitDiff

function Get-GitDiffStaged { git diff --staged $args }      # show staged diff
Set-Alias -Name gds -Value Get-GitDiffStaged

function Invoke-GitStashPop { git stash pop $args }         # pop most recent stash
Set-Alias -Name ggsp -Value Invoke-GitStashPop

function Invoke-GitPush { git push $args }                  # push to remote
Remove-Item -Force Alias:\gp -ErrorAction SilentlyContinue
Set-Alias -Name gp -Value Invoke-GitPush

function Invoke-GitPushForce { git push --force-with-lease $args }  # safe force push
Set-Alias -Name gpf -Value Invoke-GitPushForce

function Invoke-GitPull { git pull $args }                  # pull from remote
Set-Alias -Name gpl -Value Invoke-GitPull

function Invoke-GitRebase { git rebase $args }              # rebase onto branch
Remove-Item -Force Alias:\grb -ErrorAction SilentlyContinue
Set-Alias -Name grb -Value Invoke-GitRebase

function Invoke-GitRebaseInteractive { git rebase -i $args }  # interactive rebase
Set-Alias -Name grbi -Value Invoke-GitRebaseInteractive

function Invoke-GitRestore { git restore $args }            # discard working tree changes
Remove-Item -Force Alias:\grs -ErrorAction SilentlyContinue
Set-Alias -Name grs -Value Invoke-GitRestore

function Invoke-GitRestoreStaged { git restore --staged $args }  # unstage a file
Set-Alias -Name grss -Value Invoke-GitRestoreStaged

# -- GitHub CLI shortcuts -------------------------------------------------------

function New-GhPR { gh pr create $args }                    # open a pull request
Set-Alias -Name ghpr -Value New-GhPR

function Get-GhPRList { gh pr list $args }                  # list pull requests
Set-Alias -Name ghprl -Value Get-GhPRList

function Get-GhPRView { gh pr view $args }                  # view a pull request
Set-Alias -Name ghprv -Value Get-GhPRView

function Get-GhIssueList { gh issue list $args }            # list issues
Set-Alias -Name ghis -Value Get-GhIssueList

function Get-GhIssueView { gh issue view $args }            # view an issue
Set-Alias -Name ghiv -Value Get-GhIssueView

# -- Dev shortcuts --------------------------------------------------------------

function Invoke-UvRun { uv run $args }                      # run with uv
Set-Alias -Name uvr -Value Invoke-UvRun

function Invoke-UvSync { uv sync $args }                    # sync uv environment
Set-Alias -Name uvs -Value Invoke-UvSync

function Invoke-NpmInstall { npm install $args }            # npm install
Remove-Item -Force Alias:\ni -ErrorAction SilentlyContinue
Set-Alias -Name ni -Value Invoke-NpmInstall

function Invoke-NpmRun { npm run $args }                    # npm run <script>
Set-Alias -Name nr -Value Invoke-NpmRun

function Invoke-NpmRunDev { npm run dev $args }             # npm run dev
Set-Alias -Name nrd -Value Invoke-NpmRunDev

function Invoke-NpmRunTest { npm run test $args }           # npm run test
Set-Alias -Name nrt -Value Invoke-NpmRunTest

function Invoke-Python { python $args }                     # python shorthand
Set-Alias -Name py -Value Invoke-Python

Set-Alias -Name c -Value Clear-Host                         # clear the screen

# -- Utility --------------------------------------------------------------------

function Get-MyIp { curl -s ifconfig.me $args }             # show public IP
Set-Alias -Name myip -Value Get-MyIp

function Invoke-PingBing { ping bing.com $args }            # quick connectivity check
Set-Alias -Name pb -Value Invoke-PingBing

Remove-Item -Force Alias:\h -ErrorAction SilentlyContinue
Set-Alias -Name h -Value Get-History                        # command history

# END dev-setup profile
'@

    # Ensure profile directory exists
    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Append to profile (create if absent).
    # Always prepend a blank line so we don't concatenate onto any existing last line.
    if (Test-Path $PROFILE) {
        Add-Content -Path $PROFILE -Value ""
    }
    Add-Content -Path $PROFILE -Value $profileContent
    Write-Ok "PowerShell profile shortcuts installed to $PROFILE"
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
    Install-CopilotCli
    Install-SquadCli
    Write-PowerShellProfile

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: nvm install lts && nvm use lts"
    Write-Info "  3. Run: gh auth login"
}

Main
