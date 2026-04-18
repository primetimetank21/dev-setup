# Session Log: PS 5.x Hotfix & Retro — 2026-04-18

**Date:** 2026-04-18  
**Session Type:** Hotfix + Triage + Retro  
**Requested by:** Earl Tankard  
**Branches:** `main` (direct push, Earl override)  

---

## What Was Fixed

### Bug #1: `$MyInvocation.MyCommand.Path` in Hosted Contexts
**File:** `setup.ps1` — `Get-Platform` function  
**Issue:** Variable returns `$null` when script is dot-sourced or hosted; breaks under `Set-StrictMode`.  
**Fix:** Replaced with `$PSScriptRoot` (available PS 3+).  
**Agent:** Goofy  

### Bug #2: PS 6+ Auto-Variables (`$IsLinux`/`$IsMacOS`/`$IsWindows`) Undefined on PS 5.x
**File:** `setup.ps1` — `Get-Platform` function  
**Issue:** Variables don't exist on Windows PowerShell 5.x; strict mode hard-fails on undefined refs.  
**Fix:** Added version-guarded short-circuit: `($PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux) -or ...`  
**Agent:** Goofy  
**Decision record:** `.squad/decisions/inbox/goofy-ps5-isvars-fix.md`

---

## Issues Created

- **#107** — Install vim on Windows via winget (assign: Goofy, P2)
- **#108** — Add `.aliases` to Windows PowerShell profile (assign: Pluto/Goofy, P2)

Both require Sprint 6 planning inclusion.

---

## Retro Completed

**Facilitated by:** Mickey  
**Outcomes:**
1. PS 5.x compat checklist needed in CONTRIBUTING.md
2. CI should add PS 5.1 validation (Chip)
3. Direct-push-to-main policy needs documentation
4. Windows .aliases coverage gap identified
5. Sprint 6 planning candidate issues confirmed

Full retro: `.squad/log/retro-2026-04-18.md`
