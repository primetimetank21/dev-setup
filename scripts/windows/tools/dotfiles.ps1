# scripts/windows/tools/dotfiles.ps1 - Dotfile installer for Windows
#
# Owner: Pluto (Config Engineer)
# Copies dotfiles to %USERPROFILE% with timestamped .bak backup on change.
# No symlinks -- plain copy for maximum compatibility (no admin/developer mode).
#
# Backup strategy: <file>.bak.YYYYMMDD-HHmmss
# Keeps the $KeepLast most recent backups (default 5; override with
# $env:DOTFILE_BACKUP_KEEP). Older backups are deleted automatically.
# Uninstall restores the newest backup (= state before last install run).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

# Backs up $Target with a timestamp suffix and trims old backups.
# $KeepLast is overridden by $env:DOTFILE_BACKUP_KEEP when set.
function Backup-File {
    param(
        [string]$Target,
        [int]$KeepLast = 5
    )
    if (-not (Test-Path $Target)) { return }
    if ($env:DOTFILE_BACKUP_KEEP -match '^\d+$') { $KeepLast = [int]$env:DOTFILE_BACKUP_KEEP }
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $bakPath = "$Target.bak.$ts"
    Copy-Item -Path $Target -Destination $bakPath -Force
    Write-Info "Backed up $Target -> $bakPath"
    # Remove oldest timestamped backups beyond the keep limit
    Get-ChildItem "$Target.bak.*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepLast |
        Remove-Item -Force
}

function Install-Dotfiles {
    Write-Info "Installing dotfiles..."

    $dotfilesDir = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) 'config\dotfiles'
    $home_ = $env:USERPROFILE

    # Mapping: source filename -> target filename under USERPROFILE
    $fileMappings = @(
        @{ Source = '.editorconfig';       Target = '.editorconfig' }
        @{ Source = '.gitconfig.template'; Target = '.gitconfig' }
        @{ Source = '.npmrc.template';     Target = '.npmrc' }
        @{ Source = '.vimrc';              Target = '_vimrc' }
    )

    foreach ($mapping in $fileMappings) {
        $srcPath = Join-Path $dotfilesDir $mapping.Source
        $destPath = Join-Path $home_ $mapping.Target

        if (-not (Test-Path $srcPath)) {
            Write-Warn "Source not found: $srcPath - skipping"
            continue
        }

        Write-Info "Installing $($mapping.Source) to $destPath"

        if (Test-Path $destPath) {
            $srcContent = Get-Content $srcPath -Raw
            $destContent = Get-Content $destPath -Raw

            if ($srcContent -eq $destContent) {
                Write-Ok "$($mapping.Target) already up to date - skipped"
                continue
            }

            Backup-File -Target $destPath
        }

        Copy-Item -Path $srcPath -Destination $destPath -Force
        Write-Ok "$($mapping.Target) installed"
    }

    Write-Ok "Dotfiles installation complete"
}
