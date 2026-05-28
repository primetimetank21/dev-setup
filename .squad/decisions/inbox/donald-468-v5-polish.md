# Decision: 468-v5-polish (Donald)

**Date:** 2026-05-30
**Author:** Donald
**PR:** #470
**Commit:** 863671e

## Decisions Made

1. **Baseline format: option (a) -- bare tool names.**
   Stubs log tool name only (no prefix). `defaults.txt` is both dispatch input
   and expected test output. Simplest option, zero transform at assert time.

2. **Git-hook self-guard in tool script (not dispatcher).**
   `command -v git` / `Get-Command git` at top of git-hook script. Works
   regardless of invocation path. Simpler than flag-combo disallow rules.

3. **`--skip` validates against AvailableTools (silent no-op for opt-in tools).**
   Matches POSIX semantics. Documented in UX Caveats.

4. **Real-defaults drift test uses `--check` mode on existing regeneration script.**
   No new tooling; extends `scripts/dev/regenerate-baseline-fixtures.sh` with
   a diff-and-exit-1 mode. Runs in CI alongside mock-dispatcher test.
