# Session: Copilot CLI Fix Complete
**Date:** 2026-04-12T02:00:00Z  
**Topic:** copilot-cli-fix-complete  
**Participants:** Donald (Shell Dev), Mickey (Lead), Earl (Admin/Repo Owner)

## Session Overview

This session completed the diagnosis, fix, and merge of a critical idempotency bug in `scripts/linux/tools/copilot-cli.sh`. The underlying issue stems from gh 2.89.0+ promoting `copilot` to a built-in subcommand, breaking extension installation.

## Root Cause Analysis

**Root Cause:** gh 2.89.0+ includes a built-in `copilot` subcommand as a public preview. When the script attempts `gh extension install github/gh-copilot`, the gh CLI now rejects the install with:
```
"copilot" matches the name of a built-in command or alias
```

Additionally, this error goes to stdout (not stderr), so `2>/dev/null` redirection silently masks the error while the extension fails to install. A partial install can leave a stale `copilot` alias that permanently blocks future installs.

## Diagnosis Timeline

### Round 1: Initial Observation
- Script fails silently due to stdout error redirect and alias conflicts
- No explicit idempotency check; script assumes file existence = success
- Post-install verification `$(gh copilot --version)` also triggers alias collision

### Round 2: Root Cause Identified
- gh 2.89.0+ makes copilot a built-in; extension install fails
- Alias conflict requires explicit removal before install attempt
- Post-install check must use `gh extension list | grep` instead of `--version` subshell

## Fix Iterations

### Fix 1: Graceful Error Handler
**By:** Donald  
**Change:** Implemented `set +e / set -e` pattern to capture install errors without hard failure

### Fix 2: Enhanced Idempotency
**By:** Donald  
**Change 1:** Changed idempotency check from file-existence to `gh copilot --help`
**Change 2:** Further refined to `gh copilot -- --help` to probe actual binary (not alias/wrapper)

This critical refinement ensures the script detects partial installs where:
- Alias exists but extension is broken
- Built-in exists but extension is not initialized
- Neither exists and full re-install is needed

### Fix 3: Alias Conflict Removal
**Embedded in install handler:** Remove stale `copilot` alias before calling `gh extension install`

## Review & Approval

### Mickey's Review (Round 1)
- ✅ CI: All 4 checks passing
- ✅ Graceful error handling correct
- ✅ Idempotency concept sound
- 📝 Minor: Recommend documenting gh 2.89.0+ breaking change explicitly

### Mickey's Re-Review (Round 2)
- ✅ Updated `gh copilot -- --help` idempotency check verified correct
- ✅ Properly distinguishes between alias-only, partial, and missing states
- ✅ CI still passing
- **Approval:** Confirmed ready for merge

## Merge & Closure

- **Merged:** 2026-04-12T01:55:00Z
- **Method:** Admin merge (`gh pr merge --admin`)
- **Branch Cleaned:** squad/fix-copilot-cli-alias-conflict deleted
- **PR:** #63 now merged to develop

## Technical Decisions Captured

The following decisions were encoded into the fix and should be added to decisions.md:

1. **Idempotency Check:** `gh copilot -- --help` is the correct probe, not `gh copilot --help`
   - Reason: `--` forces argument pass-through to actual binary, not alias/wrapper
   - Effect: Detects partial installs, broken extensions, stale aliases

2. **Built-in Conflict:** On gh 2.89.0+, `copilot` is built-in; extension install fails
   - Error: `"copilot" matches the name of a built-in command or alias`
   - Error goes to stdout, not stderr (not caught by `2>/dev/null`)
   - Solution: Remove conflicting alias before attempting install

3. **Error Handling Pattern:** Use `set +e / set -e` to gracefully capture stdout errors
   - Reason: gh errors may go to stdout; hard failure obscures diagnosis
   - Pattern: Capture output, detect "matches the name of a built-in", continue gracefully

4. **Post-Install Verification:** Never use `$(gh <extension-cmd> --version)`
   - Problem: Triggers same alias lookup, leaks error into output variables
   - Solution: Use `gh extension list | grep -q <extension-name>`

## Outcome

The `copilot-cli.sh` script is now:
- **Idempotent:** Safe to re-run; detects and repairs partial installs
- **Gh 2.89.0+ Compatible:** Handles built-in command conflicts gracefully
- **Alias-Aware:** Removes stale aliases before install; probes actual binary after
- **Error-Tolerant:** Graceful error capture prevents silent failures and output corruption

Status: ✅ **Complete** — Merged to develop, ready for integration testing and eventual main promotion.
