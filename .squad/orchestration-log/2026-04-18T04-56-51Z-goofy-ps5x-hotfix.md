# Orchestration: Goofy — PS 5.x Hotfix

**Timestamp:** 2026-04-18T04:56:51Z  
**Agent:** Goofy  
**Status:** ✅ Completed  

## Scope

Fix two PS 5.x compatibility bugs in `setup.ps1`:
1. `$MyInvocation.MyCommand.Path` → `$PSScriptRoot`
2. `$IsLinux`/`$IsMacOS`/`$IsWindows` must be version-guarded on PS 5.x

## Outcome

Both fixes committed to `main` (direct push, Earl override). Decision record: `goofy-ps5-isvars-fix.md` merged to decisions.md.

## Related Issues

- None created by Goofy. New issues #107, #108 created by Mickey during retro triage.
