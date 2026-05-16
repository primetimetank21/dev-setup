# scripts/windows/lib/logging.ps1
# Shared logging helpers (dot-sourced by setup.ps1 and tool scripts).
# Defines: Write-Info, Write-Ok, Write-Warn, Write-Err
# Source with: . "$PSScriptRoot\..\lib\logging.ps1"

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

# Assert-LastExit: call immediately after any external install command.
# Throws if $LASTEXITCODE is not in AllowedExitCodes.
# Winget ALREADY_INSTALLED (0x8A15002B) = -1978335189 -- treat as success.
function Assert-LastExit {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [int[]]$AllowedExitCodes = @(0)
    )
    if ($AllowedExitCodes -notcontains $LASTEXITCODE) {
        Write-Err "$ToolName install failed (exit code $LASTEXITCODE)"
        throw "$ToolName install failed"
    }
}
