# setup.ps1 - Entry point for dev-setup on Windows (PowerShell)
#
# This script detects the Windows environment and routes to the correct
# platform-specific installer. It does NOT install any tools itself.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#
# Supported platforms:
#   Windows (native PowerShell)
#
# For Linux/macOS/WSL, use setup.sh instead.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Logging helpers -----------------------------------------------------------

function Write-Info  { param([string]$Msg) Write-Output "[INFO]  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Output "[OK]    $Msg" }
function Write-Warn  { param([string]$Msg) Write-Output "[WARN]  $Msg" }
function Write-Err   { param([string]$Msg) Write-Output "[ERROR] $Msg" }

# -- OS Detection -------------------------------------------------------------

function Get-Platform {
  if ($IsLinux -or $IsMacOS) {
    # Unlikely to be reached via PowerShell on Linux/macOS in most setups,
    # but handle gracefully if pwsh is installed there.
    return 'unix'
  }

  if ($IsWindows) {
    # Detect WSL from within PowerShell (edge case: pwsh running inside WSL)
    $procVersion = '/proc/version'
    if (Test-Path $procVersion) {
      $content = Get-Content $procVersion -Raw
      if ($content -match 'microsoft') {
        return 'wsl'
      }
    }
    return 'windows'
  }

  return 'unknown'
}

# -- Routing -------------------------------------------------------------------

function Main {
  # $PSScriptRoot is the reliable automatic variable for the script's directory (PS 3.0+).
  # Fallback to $MyInvocation.MyCommand.Definition for dot-sourced or hosted execution contexts
  # where $PSScriptRoot may be empty. Avoid .Path — it is null in several common host environments.
  $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
  $platform  = Get-Platform

  Write-Info "dev-setup - entry point (PowerShell)"
  Write-Info "Detected platform: $platform"

  switch ($platform) {
    'windows' {
      Write-Ok "Platform: Windows"
      Invoke-WindowsSetup -ScriptDir $ScriptDir
    }
    'wsl' {
      Write-Warn "Detected WSL inside PowerShell. For best results, run setup.sh in your WSL terminal."
      Invoke-WindowsSetup -ScriptDir $ScriptDir
    }
    'unix' {
      Write-Warn "PowerShell detected on a Unix-like system. Consider using setup.sh instead."
      Invoke-WindowsSetup -ScriptDir $ScriptDir
    }
    default {
      Write-Err "Unrecognised platform. Cannot continue."
      Write-Err "For Linux/macOS/WSL, use: bash setup.sh"
      exit 1
    }
  }
}

function Invoke-WindowsSetup {
  param([string]$ScriptDir)

  $windowsScript = Join-Path $ScriptDir 'scripts\windows\setup.ps1'

  if (-not (Test-Path $windowsScript)) {
    Write-Err "Platform script not found: $windowsScript"
    Write-Err "The repository may be incomplete. Please re-clone and try again."
    exit 1
  }

  Write-Info "Handing off to: scripts\windows\setup.ps1"
  & $windowsScript
}

Main
