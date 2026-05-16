# scripts/windows/tools/nvm.ps1 - nvm-windows + Node.js installer
#
# Owner: Goofy (#2)
# Installs nvm-windows (Node Version Manager for Windows), then auto-installs
# the pinned Node.js version from .tool-versions so node/npm are usable in
# the same setup session.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

function Install-Nvm {
    # Load pinned versions from .tool-versions
    # Two levels up: tools -> windows -> scripts, then into shared lib/
    $libDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'lib'
    if (-not (Test-Path $libDir)) {
        throw "Shared lib directory not found at $libDir"
    }
    $readToolVersion = Join-Path $libDir 'Read-ToolVersion.ps1'
    if (-not (Test-Path $readToolVersion)) {
        throw "Read-ToolVersion.ps1 not found at $readToolVersion"
    }
    . $readToolVersion
    $pinnedNode = Get-ToolVersion -Name 'nodejs'

    # -- Check if Node is already installed at the pinned version -----------
    $existingNode = Get-Command node -ErrorAction SilentlyContinue
    if ($existingNode) {
        $currentVer = (& node --version 2>&1).ToString().TrimStart('v')
        if ($currentVer -eq $pinnedNode) {
            Write-Ok "Node $pinnedNode already installed -- skipping"
            return
        }
        Write-Info "Node $currentVer found but pinned version is $pinnedNode"
    }

    # -- Install nvm-windows if missing ------------------------------------
    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
        $nvmVersion = Get-ToolVersion -Name 'nvm-windows'
        $nvmHome    = Join-Path $env:USERPROFILE 'nvm'
        $nodeDir    = Join-Path $env:USERPROFILE 'nodejs'

        # If portable nvm is already extracted, just put it on PATH.
        if (Test-Path (Join-Path $nvmHome 'nvm.exe')) {
            Write-Info "nvm-windows already extracted at $nvmHome"
        } else {
            Write-Info "Installing nvm-windows (portable, pinned: $nvmVersion)..."
            Install-NvmPortable -Version $nvmVersion -NvmHome $nvmHome -NodeDir $nodeDir
        }

        # Configure runtime env: NVM_HOME, NVM_SYMLINK, PATH (session + User scope).
        Set-NvmEnvironment -NvmHome $nvmHome -NodeDir $nodeDir

        if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
            Write-Warn "nvm not on PATH after portable install (NVM_HOME=$nvmHome)"
            return
        }
        Write-Ok "nvm-windows installed at $nvmHome"
    } else {
        Write-Ok "nvm already installed: $(nvm version)"
    }

    # -- Install and activate pinned Node version --------------------------
    Write-Info "Installing Node.js $pinnedNode via nvm..."
    & nvm install $pinnedNode
    & nvm use $pinnedNode
    Refresh-SessionPath

    # -- Verify node/npm are on PATH ---------------------------------------
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        Write-Ok "node $(& node --version) ready"
    } else {
        Write-Warn "node not found on PATH after nvm install -- try opening a new terminal"
    }
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        Write-Ok "npm $(& npm --version) ready"
    } else {
        Write-Warn "npm not found on PATH after nvm install -- try opening a new terminal"
    }
}

function Install-NvmPortable {
    # Download nvm-noinstall.zip from GitHub releases and extract to $NvmHome.
    # Writes settings.txt so nvm knows where to symlink node.
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$NvmHome,
        [Parameter(Mandatory)][string]$NodeDir
    )
    $zipUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$Version/nvm-noinstall.zip"
    $zipPath = Join-Path $env:TEMP "nvm-noinstall-$Version.zip"

    New-Item -ItemType Directory -Path $NvmHome -Force | Out-Null
    Write-Info "Downloading $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $NvmHome -Force
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $settingsPath = Join-Path $NvmHome 'settings.txt'
    @"
root: $NvmHome
path: $NodeDir
"@ | Out-File -FilePath $settingsPath -Encoding ascii -NoNewline
}

function Set-NvmEnvironment {
    # Set NVM_HOME / NVM_SYMLINK at User scope (persistent) and in current session.
    # Also persist $NvmHome and $NodeDir in the User PATH so fresh shells see nvm.
    param(
        [Parameter(Mandatory)][string]$NvmHome,
        [Parameter(Mandatory)][string]$NodeDir
    )
    [System.Environment]::SetEnvironmentVariable('NVM_HOME',    $NvmHome, 'User')
    [System.Environment]::SetEnvironmentVariable('NVM_SYMLINK', $NodeDir, 'User')
    $env:NVM_HOME    = $NvmHome
    $env:NVM_SYMLINK = $NodeDir
    if ($env:Path -notlike "*$NvmHome*") { $env:Path = "$NvmHome;$env:Path" }
    if ($env:Path -notlike "*$NodeDir*") { $env:Path = "$NodeDir;$env:Path" }

    # Persist into User PATH so fresh shells see nvm and node without re-running setup.
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $entries = $userPath -split ';' | Where-Object { $_ -ne '' }
    $added = $false
    foreach ($dir in @($NvmHome, $NodeDir)) {
        if ($entries -notcontains $dir) {
            $entries = @($dir) + $entries
            $added = $true
        }
    }
    if ($added) {
        $newUserPath = ($entries | Select-Object -Unique) -join ';'
        [System.Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    }
}
