# scripts/windows/lib/logging.ps1
# Shared logging helpers (dot-sourced by setup.ps1 and tool scripts).
# Defines: Write-Info, Write-Ok, Write-Warn, Write-Err
# Source with: . "$PSScriptRoot\..\lib\logging.ps1"

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }
