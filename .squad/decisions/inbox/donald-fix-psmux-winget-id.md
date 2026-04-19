# Decision: Fix winget install psmux to use --id flag

**Issue:** #139
**Agent:** Donald (Shell Developer)
**Date:** 2025-07-17

## Context

PR #141 was rejected in code review because the `winget install psmux` call in `Install-Psmux` was missing the `--id` flag. Every other winget call in `setup.ps1` uses `--id` for explicit package identification.

Additionally, PR #142 (psmux aliases) was merged to develop, creating a Group H collision in the test file.

## Decisions

### 1. Add --id flag to winget install psmux
**Choice:** `winget install --id psmux` instead of `winget install psmux`.
**Why:** Consistency with all other winget calls in the file and explicit package identification.

### 2. Rename psmux install tests from Group H to Group I
**Choice:** Our install tests become Group I; develop's alias tests keep Group H.
**Why:** PR #142 claimed Group H first (merged to develop). Next available letter is I.

## Outcome

winget install is now consistent across all functions. Test groups don't conflict.
