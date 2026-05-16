# scripts/windows/lib/path.ps1
# Shared PATH refresh helper (dot-sourced by setup.ps1 and tool scripts).
# Re-reads Machine + User PATH from the registry into the current session.
# Source with: . "$PSScriptRoot\..\lib\path.ps1"  (from tools/)
#          or: . "$PSScriptRoot\lib\path.ps1"      (from scripts/windows/)

function Refresh-SessionPath {
    # Merge Machine + User registry PATH into the current $env:Path,
    # preserving session-only entries (e.g., GitHub Actions tool-cache
    # injections, profile-set entries, manual session additions).
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')

    $existing = $env:Path
    $combined = @($existing, $machinePath, $userPath) -join ';'
    $env:Path = ($combined -split ';' |
                 Where-Object { $_ -ne '' } |
                 Select-Object -Unique) -join ';'
}

function Wait-ForNvmInstall {
    # Poll for nvm.exe after winget install of nvm-windows.
    # winget returns before the inner installer finishes writing files,
    # so we must wait. Returns the discovered NVM_HOME directory, or $null.
    param([int]$TimeoutSeconds = 90)

    $candidates = @(
        (Join-Path $env:USERPROFILE 'AppData\Roaming\nvm'),
        (Join-Path $env:APPDATA 'nvm'),
        'C:\Program Files\nvm',
        'C:\ProgramData\nvm',
        'C:\nvm4w\nvm'
    ) | Where-Object { $_ } | Select-Object -Unique

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($dir in $candidates) {
            $exe = Join-Path $dir 'nvm.exe'
            if (Test-Path $exe) {
                $symlink = if (Test-Path 'C:\Program Files\nodejs') {
                    'C:\Program Files\nodejs'
                } else {
                    Join-Path (Split-Path $dir -Parent) 'nodejs'
                }
                if (-not $env:NVM_HOME) { $env:NVM_HOME = $dir }
                if (-not $env:NVM_SYMLINK) { $env:NVM_SYMLINK = $symlink }
                if ($env:Path -notlike "*$dir*") { $env:Path = "$dir;$env:Path" }
                if ($env:Path -notlike "*$symlink*") { $env:Path = "$symlink;$env:Path" }
                return $dir
            }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}
