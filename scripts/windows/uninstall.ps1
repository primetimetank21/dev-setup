# scripts/windows/uninstall.ps1
#
# Idempotent uninstaller for dev-setup (Windows).
# - Restores dotfile .bak files in $HOME (if any exist)
# - Removes the dev-setup profile block from PowerShell profiles
# - Does NOT remove installed tools (uv, nvm, gh, vim, copilot, etc.)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/windows/uninstall.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok   { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "[SKIP] $Msg" -ForegroundColor Yellow }
function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

# -- Restore dotfile .bak files ------------------------------------------------
# Restores the newest timestamped backup (.bak.YYYYMMDD-HHmmss).
# The newest backup is the state just before the most recent install run.
# To recover the original-original, look for the oldest .bak.* file manually.
function Restore-DotfileBackup {
    param([string]$Target)
    # Prefer newest timestamped backup; fall back to legacy .bak
    $tsBaks = Get-ChildItem "$Target.bak.*" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending
    if ($tsBaks) {
        $newest = $tsBaks[0]
        Move-Item -Path $newest.FullName -Destination $Target -Force
        Write-Ok "Restored $Target from $($newest.Name)"
    } elseif (Test-Path "$Target.bak") {
        Move-Item -Path "$Target.bak" -Destination $Target -Force
        Write-Ok "Restored $Target from $Target.bak (legacy)"
    } else {
        Write-Skip "No backup found for $Target"
    }
}

Write-Host ""
Write-Info "dev-setup uninstaller (Windows)"
Write-Host ""

# Check for any .bak files in USERPROFILE (dotfiles install may or may not exist yet)
$dotfiles = @(
    (Join-Path $HOME '.gitconfig'),
    (Join-Path $HOME '.npmrc'),
    (Join-Path $HOME '.editorconfig'),
    (Join-Path $HOME '.aliases'),
    (Join-Path $HOME '.vimrc')
)

$foundAny = $false
foreach ($dotfile in $dotfiles) {
    if ((Test-Path "$dotfile.bak") -or (Get-ChildItem "$dotfile.bak.*" -ErrorAction SilentlyContinue)) {
        $foundAny = $true
        break
    }
}

if ($foundAny) {
    foreach ($dotfile in $dotfiles) {
        Restore-DotfileBackup -Target $dotfile
    }
} else {
    Write-Skip "No dotfiles to restore"
}

# -- Remove dev-setup profile block from PowerShell profiles -------------------
function Remove-DevSetupProfileBlock {
    param([string]$ProfilePath)

    if (-not (Test-Path $ProfilePath)) {
        Write-Skip "Profile not found: $ProfilePath"
        return
    }

    $content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($content)) {
        Write-Skip "Profile is empty: $ProfilePath"
        return
    }

    $beginMarker = '# BEGIN dev-setup profile'
    $endMarker   = '# END dev-setup profile'

    if ($content -notmatch [regex]::Escape($beginMarker)) {
        Write-Skip "No dev-setup block in $ProfilePath"
        return
    }

    # Strip the managed block (handles both LF and CRLF)
    $pattern = "(?s)\r?\n?" + [regex]::Escape($beginMarker) + ".*?" + [regex]::Escape($endMarker) + "\r?\n?"
    $cleaned = $content -replace $pattern, ''

    # Avoid writing an empty file with only whitespace
    if ([string]::IsNullOrWhiteSpace($cleaned)) {
        Remove-Item $ProfilePath -Force
        Write-Ok "Removed profile (was only dev-setup block): $ProfilePath"
    } else {
        Set-Content $ProfilePath $cleaned -NoNewline -Encoding ASCII
        Write-Ok "Removed dev-setup block from $ProfilePath"
    }
}

# Resolver functions (inlined for self-containment -- uninstall must work without the repo)
function Invoke-HostQuery {
    param([string]$Exe)
    & $Exe -NoProfile -NonInteractive -NoLogo -Command '$PROFILE' 2>$null
}

function Resolve-ProfilePath {
    param([string]$HostExe, [string]$FallbackPath)
    if (-not (Get-Command $HostExe -ErrorAction SilentlyContinue)) {
        Write-Info "$HostExe not found - fallback: $FallbackPath"
        return $FallbackPath
    }
    try {
        $raw = Invoke-HostQuery -Exe $HostExe
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$HostExe exited $LASTEXITCODE - fallback: $FallbackPath"
            return $FallbackPath
        }
        $resolved = ($raw.Trim() -split '\r?\n' | Where-Object { $_ } | Select-Object -Last 1).Trim()
        if ([string]::IsNullOrEmpty($resolved)) { return $FallbackPath }
        if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }
        Write-Info "Resolved $HostExe profile: $resolved"
        return $resolved
    } catch {
        Write-Warn "Query failed for $HostExe - fallback: $FallbackPath"
        return $FallbackPath
    }
}

# Target resolved profile paths (OneDrive/KFM-aware) plus legacy fallbacks (deduped)
$ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1')
$ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')

$profilePaths = @(
    (Resolve-ProfilePath 'powershell' $ps51Fallback),
    (Resolve-ProfilePath 'pwsh' $ps7Fallback),
    $ps51Fallback,
    $ps7Fallback
) | Sort-Object { $_.ToLower() } -Unique

foreach ($p in $profilePaths) {
    Remove-DevSetupProfileBlock -ProfilePath $p
}

# -- Unset core.hooksPath ------------------------------------------------------
& git config --unset-all core.hooksPath 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "core.hooksPath unset (git falls back to per-repo .git/hooks)"
} elseif ($LASTEXITCODE -in @(1, 5)) {
    Write-Skip "core.hooksPath was not set (nothing to unset)"
} else {
    Write-Warn "git config --unset-all exited $LASTEXITCODE (unexpected; proceeding)"
}
$global:LASTEXITCODE = 0

# -- Summary -------------------------------------------------------------------
Write-Host ""
Write-Ok "Uninstalled. Tools remain."
Write-Host ""
