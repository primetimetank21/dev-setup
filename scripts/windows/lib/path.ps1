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

function Add-NvmWindowsPaths {
    # Defensive: nvm-windows installer registry PATH update may not be readable
    # immediately after winget install completes. Inject known install paths.
    $nvmDir  = Join-Path $env:USERPROFILE 'AppData\Roaming\nvm'
    $nodeDir = 'C:\Program Files\nodejs'
    if (Test-Path (Join-Path $nvmDir 'nvm.exe')) {
        if ($env:Path -notlike "*$nvmDir*")  { $env:Path = "$nvmDir;$env:Path" }
        if ($env:Path -notlike "*$nodeDir*") { $env:Path = "$nodeDir;$env:Path" }
    }
}
