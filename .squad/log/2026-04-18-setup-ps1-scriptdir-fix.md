# Session Log: setup.ps1 Script Directory Fix

**Date:** 2026-04-18  
**Agent:** Goofy (Cross-Platform Developer)  
**Issue:** Earl Tankard hotfix request — $MyInvocation.MyCommand.Path bug

## Work Completed

✅ Fixed setup.ps1 line 51: Replaced `$MyInvocation.MyCommand.Path` with `$PSScriptRoot` + `$MyInvocation.MyCommand.Definition` fallback  
✅ Decision documented: goofy-scriptroot-fix.md merged to decisions.md  
✅ Goofy's history.md updated  
✅ Changes committed

## Files Modified

- `setup.ps1` — Line 51 fixed
- `.squad/agents/goofy/history.md` — Completion logged

## Decisions Merged

Pattern now applied repo-wide for all .ps1 scripts. Bans `$MyInvocation.MyCommand.Path` due to null in hosted/dot-sourced contexts.

---

**Scribe completed:** 2026-04-18T04:42:00Z
