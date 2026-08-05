# scripts/windows/setup.ps1 - Core Windows installer orchestrator (#468 flags-first)
#
# Called by: setup.ps1 (root entry point)
#
# Usage (direct):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1 [OPTIONS]
#
# Flags:
#   -List           Print available tools (alphabetical), exit 0. No install.
#   -Help           Print usage, exit 0.
#   -Only "a,b,c"   Install ONLY the listed tools (comma-separated).
#   -Skip "a,b,c"   Install all default tools EXCEPT the listed ones.
#   -Interactive     Show the tool picker when a console is available.
#   -NonInteractive  Never show the tool picker.
#   -Only and -Skip are mutually exclusive.
#
# Hidden test seam (not in -Help):
#   -ToolsDir <path>   Override the tools directory (test use only).
#   -SelectionFile <path>
#                      Read selected tools from a file (test use only).
#
# PS 5.1 ASCII-only: no smart quotes, em-dashes, or non-ASCII characters.

[CmdletBinding()]
param(
    [string]$Only    = '',
    [string]$Skip    = '',
    [switch]$List,
    [switch]$Help,
    [switch]$Interactive,
    [switch]$NonInteractive,
    [string]$ToolsDir = '',
    [string]$SelectionFile = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\logging.ps1"
. "$PSScriptRoot\lib\path.ps1"
. "$PSScriptRoot\lib\tui.ps1"

# Dot-source all tool installer modules
. "$PSScriptRoot\tools\winget-check.ps1"
. "$PSScriptRoot\tools\git.ps1"
. "$PSScriptRoot\tools\uv.ps1"
. "$PSScriptRoot\tools\nvm.ps1"
. "$PSScriptRoot\tools\gh.ps1"
. "$PSScriptRoot\tools\vim.ps1"
. "$PSScriptRoot\tools\psmux.ps1"
. "$PSScriptRoot\tools\copilot.ps1"
. "$PSScriptRoot\tools\squad-cli.ps1"
. "$PSScriptRoot\tools\dotfiles.ps1"
. "$PSScriptRoot\tools\profile.ps1"
. "$PSScriptRoot\tools\auth.ps1"
. "$PSScriptRoot\tools\git-hook.ps1"
. "$PSScriptRoot\tools\delta.ps1"
. "$PSScriptRoot\tools\lazygit.ps1"

# ---------------------------------------------------------------------------
# $DefaultTools -- single ordered source of truth for a no-arg default run.
# Adding a .ps1 file to tools/ + a registry entry makes it AvailableTools
# (selectable via -Only) but does NOT add it here.
# ---------------------------------------------------------------------------
$DefaultTools = @(
    'winget-check'
    'git'
    'uv'
    'nvm'
    'gh'
    'auth'
    'vim'
    'psmux'
    'copilot'
    'squad-cli'
    'dotfiles'
    'profile'
    'git-hook'
)

# $ToolRegistry maps logical tool names to their install scriptblock.
# copilot-cli is aliased to copilot so both platforms accept the same name.
$ToolRegistry = [ordered]@{
    'winget-check' = { Invoke-WingetGate }
    'git'          = { Install-Git }
    'uv'           = { Install-Uv }
    'nvm'          = { Install-Nvm }
    'gh'           = { Install-GhCli }
    'auth'         = { Invoke-GhAuth }
    'vim'          = { Install-Vim }
    'psmux'        = { Install-Psmux }
    'copilot'      = { Install-CopilotCli }
    'copilot-cli'  = { Install-CopilotCli }
    'squad-cli'    = { Install-SquadCli }
    'dotfiles'     = { Install-Dotfiles }
    'profile'      = { Write-PowerShellProfile }
    'git-hook'     = { Install-GitHook }
    'delta'        = { Install-Delta }
    'lazygit'      = { Install-Lazygit }
}

# ---------------------------------------------------------------------------
# Test seam: when -ToolsDir is set, build a dynamic registry from stub files
# and load DefaultTools from defaults.txt in that directory.
# ---------------------------------------------------------------------------
if ($ToolsDir) {
    $ToolRegistry = [ordered]@{}
    foreach ($f in (Get-ChildItem "$ToolsDir\*.ps1" | Sort-Object Name)) {
        $name = $f.BaseName
        $path = $f.FullName
        $ToolRegistry[$name] = [scriptblock]::Create(". '$path'")
    }
    $defaultsFile = Join-Path $ToolsDir 'defaults.txt'
    if (Test-Path $defaultsFile) {
        $DefaultTools = Get-Content $defaultsFile | Where-Object { $_ -ne '' }
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-AvailableTool {
    return ($ToolRegistry.Keys | Sort-Object)
}

function Split-ToolList {
    param([string]$ToolList)
    if ([string]::IsNullOrEmpty($ToolList)) {
        Write-Err "Flag requires at least one tool name."
        exit 1
    }
    $tools = $ToolList.Split(',')
    foreach ($t in $tools) {
        if ([string]::IsNullOrEmpty($t)) {
            Write-Err "Empty tool name in list (check commas)."
            exit 1
        }
    }
    return $tools
}

function Invoke-Tool {
    param([string]$Name)
    if (-not $ToolRegistry.Contains($Name)) {
        Write-Warn "Tool not in registry, skipping: $Name"
        return
    }
    Write-Info "Installing: $Name"
    & $ToolRegistry[$Name]
    Write-Ok "$Name -- done"
}

function Show-Help {
    Write-Output "Usage: setup.ps1 [OPTIONS]"
    Write-Output ""
    Write-Output "Install developer tools on Windows."
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -List           Print available tools (alphabetical order), exit 0."
    Write-Output "  -Help           Print this help message, exit 0."
    Write-Output "  -Only 'a,b,c'  Install ONLY the listed tools (comma-separated)."
    Write-Output "  -Skip 'a,b,c'  Install all default tools EXCEPT the listed ones."
    Write-Output "  -Interactive    Show the tool picker when a console is available."
    Write-Output "  -NonInteractive Never show the tool picker."
    Write-Output ""
    Write-Output "Notes:"
    Write-Output "  -Only and -Skip are mutually exclusive."
    Write-Output "  Unknown tool names exit with an error and print the available list."
    Write-Output "  A no-arg run installs all default tools in the defined order."
}

# ---------------------------------------------------------------------------
# --help / --list handling
# ---------------------------------------------------------------------------
if ($Help) {
    Show-Help
    exit 0
}

if ($List) {
    Get-AvailableTool | ForEach-Object { Write-Output $_ }
    exit 0
}

# ---------------------------------------------------------------------------
# Mutual exclusion
# ---------------------------------------------------------------------------
if ($PSBoundParameters.ContainsKey('Only') -and $PSBoundParameters.ContainsKey('Skip')) {
    Write-Err "-Only and -Skip are mutually exclusive."
    exit 1
}

if ($Interactive -and $NonInteractive) {
    Write-Err "-Interactive and -NonInteractive are mutually exclusive."
    exit 1
}

if ($NonInteractive -and $PSBoundParameters.ContainsKey('SelectionFile')) {
    Write-Err "-NonInteractive and -SelectionFile are mutually exclusive."
    exit 1
}

# ---------------------------------------------------------------------------
# Interactive guard. Slice 1 only detects whether a future menu may run.
# No menu is invoked until Slice 3.
# ---------------------------------------------------------------------------
function Test-ShouldShowMenu {
    param(
        [bool]$NonInteractiveRequested,
        [bool]$OnlySet,
        [bool]$SkipSet,
        [bool]$InteractiveRequested,
        [bool]$SelectionFileSet
    )
    # ponytail: test seam -- remove when TTY simulation available in CI
    if ($env:_PS_TUI_TEST_MENU -eq '1') { return $true }
    if ($NonInteractiveRequested -or $OnlySet -or $SkipSet) { return $false }
    # -Interactive + -SelectionFile: bypass CI/TTY detection so CI can test the menu path.
    if ($InteractiveRequested -and $SelectionFileSet) { return $true }
    if ($env:SETUP_NON_INTERACTIVE -eq '1' -or $env:CI -or $env:GITHUB_ACTIONS) { return $false }
    if ([Console]::IsInputRedirected -or -not [Environment]::UserInteractive) { return $false }
    if ($null -eq $Host.UI.RawUI) { return $false }
    return $true
}

# ---------------------------------------------------------------------------
# Determine final toolset: menu path (interactive) or flag path (non-interactive)
# ---------------------------------------------------------------------------
$Available   = Get-AvailableTool
[string[]]$FinalTools = @()

if (Test-ShouldShowMenu `
        -NonInteractiveRequested $NonInteractive.IsPresent `
        -OnlySet ($PSBoundParameters.ContainsKey('Only')) `
        -SkipSet ($PSBoundParameters.ContainsKey('Skip')) `
        -InteractiveRequested $Interactive.IsPresent `
        -SelectionFileSet ($PSBoundParameters.ContainsKey('SelectionFile'))) {

    # Interactive path: selection-file seam (CI/test) or live menu
    if ($PSBoundParameters.ContainsKey('SelectionFile') -and $SelectionFile) {
        [string[]]$selectedNames = @(Get-Content -LiteralPath $SelectionFile |
            Where-Object { -not [string]::IsNullOrEmpty($_) })
    } else {
        [string[]]$selectedNames = Show-ToolMenu -DefaultTools $DefaultTools -Available $Available
    }

    if ($null -eq $selectedNames) {
        Write-Output 'Install cancelled.'
        exit 0
    }
    if ($selectedNames.Count -eq 0) {
        Write-Output 'Nothing selected, exiting.'
        exit 0
    }
    $FinalTools = Resolve-FinalToolset -DefaultTools $DefaultTools `
        -Only ($selectedNames -join ',') -OnlySet $true

} else {
    # Non-interactive path: validate tool names then resolve
    if ($PSBoundParameters.ContainsKey('Only')) {
        $names = Split-ToolList -ToolList $Only
        foreach ($name in $names) {
            if ($Available -notcontains $name) {
                Write-Err "Unknown tool: $name"
                Write-Err "Available tools: $($Available -join ', ')"
                Write-Err "Use -List to see all available tools."
                exit 1
            }
        }
        $FinalTools = Resolve-FinalToolset -DefaultTools $DefaultTools `
            -Only $Only -OnlySet $true
    } elseif ($PSBoundParameters.ContainsKey('Skip')) {
        $names = Split-ToolList -ToolList $Skip
        foreach ($name in $names) {
            if ($Available -notcontains $name) {
                Write-Err "Unknown tool: $name"
                Write-Err "Available tools: $($Available -join ', ')"
                exit 1
            }
        }
        $FinalTools = Resolve-FinalToolset -DefaultTools $DefaultTools `
            -Skip $Skip -SkipSet $true
    } else {
        $FinalTools = Resolve-FinalToolset -DefaultTools $DefaultTools
    }
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
function Main {
    Write-Info "Starting Windows setup..."

    foreach ($tool in $FinalTools) {
        Invoke-Tool -Name $tool
    }

    Write-Ok ""
    Write-Ok "Setup complete!"
    Write-Info "Next steps:"
    Write-Info "  1. Restart your terminal to apply PATH changes"
    Write-Info "  2. Run: gh auth login"
}

Main
