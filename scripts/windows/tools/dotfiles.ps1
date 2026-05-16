# scripts/windows/tools/dotfiles.ps1 - Dotfile installer for Windows
#
# Owner: Goofy (#2)
# Copies dotfiles to %USERPROFILE% with .bak backup if existing file differs.
# No symlinks -- plain copy for maximum compatibility (no admin/developer mode).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\lib\logging.ps1"

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

            # Back up only if no .bak exists yet
            $bakPath = "$destPath.bak"
            if (-not (Test-Path $bakPath)) {
                Write-Warn "$destPath exists -- backing up to $bakPath"
                Copy-Item -Path $destPath -Destination $bakPath -Force
            }
        }

        Copy-Item -Path $srcPath -Destination $destPath -Force
        Write-Ok "$($mapping.Target) installed"
    }

    Write-Ok "Dotfiles installation complete"
}
