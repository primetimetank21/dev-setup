# scripts/windows/tools/vim.ps1 - Vim text editor installer
#
# Owner: Goofy (#2)
# Installs vim with PATH registration (winget doesn't reliably add it to PATH)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"
. "$PSScriptRoot\..\lib\path.ps1"

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
        Refresh-SessionPath
        Write-Ok "vim installed"
    } else {
        Write-Ok "vim installed"
        Write-Warn "vim not found on PATH -- restart your terminal or verify C:\Program Files\Vim"
    }
}
