# Mickey's Grill -- Plan for #441
**Date:** 2026-05-27
**Verdict:** Revise

## Holes Found

1. **$PROFILE vs $PROFILE.CurrentUserAllHosts -- plan contradicts issue.**
   Issue #441 explicitly specifies `$PROFILE.CurrentUserAllHosts` in both the proposed fix and acceptance criteria. Goofy's plan uses `$PROFILE` (CurrentUserCurrentHost). This is flagged as an "open question" but treated as decided in the pseudo-code. This is a BLOCKING discrepancy -- the stakeholder (Earl) must confirm which file to target before implementation. Do not start coding until this is resolved.

2. **Cold-start scenario underdefined -- fallback writes to a never-sourced path.**
   E3/E4 say "fallback used for PS 7+ path (write is benign no-op if dir absent)" -- but that's wrong. The code CREATES the directory and writes the file. On a brand-new machine with only PS 5.1 and no pwsh, the script writes to `$HOME\Documents\PowerShell\...` which will NEVER be sourced (PS 7+ isn't installed). That's benign clutter, not a no-op. Explicit decision needed: should we skip the write entirely when host is absent, or write anyway as "pre-provisioning"? The plan glosses over this.

3. **Idempotency of legacy cleanup -- runs every time, not once.**
   The cleanup pass probes legacy paths on EVERY install run. If `$HOME\Documents\WindowsPowerShell\...` exists and differs from the resolved path, we strip it every time. That's wasteful I/O and creates log noise on every run. Better: write a one-time marker file (e.g., `.dev-setup-migrated`) or check if the legacy file actually contains the sentinel before logging "Removing stale dev-setup block". The pseudo-code DOES check `Select-String`, but the log line "Removing stale dev-setup block" will print every run if the file still exists (empty or with other content). Clarify intent.

4. **Deduplication is case-sensitive -- Windows paths are case-insensitive.**
   `$profilePaths | Select-Object -Unique` uses default equality, which is case-sensitive for strings. If pwsh returns `C:\Users\Earl\OneDrive\Documents\PowerShell\...` and powershell returns `c:\users\earl\onedrive\documents\WindowsPowerShell\...`, deduplication fails to collapse them when it should. Risk R4 notes this but offers no concrete fix. Add `-Unique` with a custom comparer or normalize to lowercase before deduplication.

5. **Invoke-HostQuery wrapper not mentioned in production code section.**
   Section 5 (Test Plan) proposes Pattern B using an `Invoke-HostQuery` wrapper for testability. But Section 3 (pseudo-code) directly calls `& $HostExe -NoProfile ...`. If we want Pattern B, the PRODUCTION code must use the wrapper, not just tests. The plan doesn't commit to refactoring `Resolve-ProfilePath` to use `Invoke-HostQuery`. Clarify: is Pattern B adopted for production, or is it test-only mocking?

6. **Uninstall lib dependency is a breaking change -- needs migration strategy.**
   Open Question #6 flags this but doesn't resolve it. Currently `uninstall.ps1` is standalone (no dot-source dependencies). Adding `lib/profile-path.ps1` as a dependency means uninstall breaks if the user deletes the repo after install. The plan recommends Option B (shared lib) but doesn't address the portability regression. Either: (a) inline the resolver in uninstall.ps1 (Option A), or (b) embed the resolver logic directly in the profile block itself so uninstall doesn't need external deps.

7. **Test case GG-6 logs "not found" but doesn't verify fallback is USED.**
   GG-6 says "Verify Write-Info called with 'not found' substring". That proves the log line fired, not that the fallback path was actually used for the write. Add an assertion that the written file path equals the fallback.

8. **Static test GG-S1 is fragile -- pattern match on string literal.**
   Searching for `$HOME, 'Documents'` to prevent regression is clever but brittle. A refactor that changes quote style (`$HOME, "Documents"`) or whitespace would bypass the guard. Consider a more robust approach: parse the AST and verify no `[System.IO.Path]::Combine` call with literal 'Documents' outside the designated fallback variable.

9. **No test for E17 (non-ASCII username / Unicode path).**
   Edge case E17 is documented but no corresponding test case in Group GG. Add GG-11: mock `Invoke-HostQuery` to return a path with non-ASCII chars (e.g., `C:\Users\Muller\...` with umlaut) and verify write succeeds without mojibake.

10. **Missing acceptance criterion check: diagnostic log shows resolved path.**
    Issue #441 acceptance criterion 4 requires "Diagnostic log lines show the resolved path (not the constructed one)". The plan mentions this in Section 3, and GG-9 covers it -- but only for the OneDrive case. Add a test that verifies the hardcoded fallback is NOT logged when resolution succeeds (i.e., no leakage of `$HOME\Documents\...` in output when resolved path differs).

## Strong Points

- **Root cause analysis is thorough.** Scenarios A-E cover the real-world configurations that break the current code. OneDrive KFM is the primary driver, but the plan correctly identifies registry redirects, symlinks, and `$HOME` overrides.

- **Edge case table is comprehensive.** E1-E20 is a solid enumeration. The plan anticipates Constrained Language Mode, UNC paths, trailing CRLF, and WSL interop -- these are non-obvious.

- **Backward compat strategy is sound.** Probing both legacy paths AND resolved paths on install/uninstall handles the migration case where old installs wrote to the wrong location.

- **Files Touched section is explicit.** The plan clearly lists which files change and why. No hidden changes.

- **Group GG naming is correct.** Tests go A-Z, then AA, DD, EE, FF -- GG is the next slot. (Note: BB/CC appear to be skipped in the existing file, but GG follows FF correctly.)

- **Deduplicate-before-write is necessary.** If both hosts resolve to the same file (rare but possible), double-injecting the block would corrupt the profile. Plan handles this.

## Decisions That Need Explicit Capture

1. **$PROFILE vs $PROFILE.CurrentUserAllHosts** -- Which one? Issue says AllHosts; plan says CurrentHost. Get Earl's ruling before implementation.

2. **Skip write when host is absent, or pre-provision?** -- If pwsh is not installed, should we write to the PS 7+ profile path anyway (pre-provisioning for when pwsh is installed later) or skip entirely? Current code writes; plan preserves that behavior but calls it a "no-op", which it isn't.

3. **Inline resolver in uninstall.ps1 (Option A) or shared lib (Option B)?** -- Plan recommends B but doesn't close on it. If B, document that uninstall requires the lib to be present.

4. **Case-insensitive deduplication on Windows** -- Commit to normalizing paths to lowercase before `Select-Object -Unique`.

5. **Invoke-HostQuery wrapper in production code** -- If we want Pattern B testability, the wrapper must exist in `profile-path.ps1`, not just tests.

## If This Goes To Revision

**Revision owner:** Donald (Shell Dev)
**Required changes:**

1. Resolve the $PROFILE vs CurrentUserAllHosts question with Earl and update pseudo-code accordingly.
2. Add explicit decision on skip-vs-pre-provision for absent hosts; update E3/E4 descriptions.
3. Fix case-insensitive deduplication -- add `-ToLower()` or use `[System.IO.Path]::GetFullPath()` normalization.
4. Commit to Option A (inline resolver in uninstall.ps1) OR Option B (shared lib) -- close the open question.
5. If Pattern B for testing, refactor pseudo-code to use `Invoke-HostQuery` in production `Resolve-ProfilePath`.
6. Add test GG-11 for Unicode path handling.
7. Add test GG-12 verifying fallback path does NOT appear in logs when resolution succeeds.
8. Clarify idempotency of legacy-cleanup pass (log only if sentinel actually removed, not on every run).

## Final Verdict

This plan demonstrates solid research and covers the problem space well. The edge-case enumeration, backward-compat strategy, and test scaffolding are all strong. However, there are two blocking issues that prevent approval:

First, the plan contradicts the issue on a fundamental design choice ($PROFILE vs CurrentUserAllHosts) and treats it as an open question while simultaneously embedding the opposite choice in the pseudo-code. This must be resolved with Earl before anyone writes code.

Second, the plan has several implicit assumptions masquerading as decisions: case-sensitive deduplication, pre-provisioning for absent hosts, and the uninstall lib dependency. These need explicit team sign-off.

**Verdict: REVISE.** Donald should take over, resolve the open questions with Earl, and tighten the implementation spec. Once the CurrentUserAllHosts question is answered and the deduplication/idempotency issues are addressed, this plan will be ready for implementation.
