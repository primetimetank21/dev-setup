# Chip's Re-Grill -- Plan for #441 v2
**Date:** 2026-05-27
**Reviewer:** Chip (Tester)
**Verdict:** REVISE
**Author locked out:** Mickey, Goofy

---

## Context

v1 grill raised 27 issues (5 showstoppers). Mickey authored v2 addressing them.
This re-grill is scoped to: did the 5 showstoppers land? Plus any new holes v2 introduces.

---

## v1 Showstopper Resolution Matrix

| # | v1 Concern | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Pester `$TestDrive` removed | RESOLVED | Section 3 Decision 2 explicitly drops Pester. "Adding Pester is scope creep for a single fix." No `$TestDrive` anywhere in the v2 test table. GG tests use `Invoke-HostQuery` mock only. |
| 2 | `$PROFILE = $path` read-only in PS7 | PARTIAL | GG tests never assign `$PROFILE` directly -- correct. BUT: existing C-2 (`test_windows_setup.ps1` line 238) and C-3 (line 261) still do `$PROFILE = $c2Profile` / `$PROFILE = $c3Profile`. v2 plan adds GG tests, does not fix C-2/C-3. These still throw in PS7+. The new tests are clean; the existing harness is not. |
| 3 | Legacy orphan cleanup coverage | PARTIAL | GG-4 added. It seeds ONE hardcoded path with the dev-setup block and asserts it is stripped. The algorithm loops over `$legacyPaths = @($ps51Fallback, $ps7Fallback)` -- two paths. GG-4 does not test the case where BOTH legacy paths carry orphaned blocks simultaneously. A loop-break bug after first match would pass GG-4 and silently leave the second orphan. One test is not sufficient coverage here. |
| 4 | Case-insensitive dedup (`Select-Object -Unique`) | RESOLVED | Algorithm changed to `Sort-Object { $_.ToLower() } -Unique`. Script-block key lowers both candidates to the same string; `-Unique` retains one. Returns the original (un-lowercased) path, which is correct for Windows. GG-3 asserts `$profilePaths.Count -eq 1`. This is technically sound. |
| 5 | Multi-line `$PROFILE` output | PARTIAL | GG-6 added. Mock returns `"banner\npath"`. Algorithm uses `Select-Object -First 1` -- this returns the BANNER, not the path. Assertion is only "Return value contains no newline." That assertion PASSES on "banner" (no newline present) even though the wrong value was extracted. Two defects: (a) algorithm direction is wrong (`-First 1` should be `-Last 1` -- `& powershell -Command '$PROFILE'` prints the path last; any banner precedes it); (b) assertion does not verify the return value equals the expected mock path. GG-6 as described would pass silently while the algorithm returns garbage. |

---

## New Holes v2 Introduces

**NH-1: GG-2 mock mechanism for `Get-Command` not described.**

The plan says "Mock `Get-Command` returns `$null`" but provides no code showing how. In the
custom `Test-Scenario` harness (no Pester), shadowing the `Get-Command` built-in at the
right scope level is non-trivial. The correct approach -- pass a provably-absent exe name
(e.g., `'powershell-fake-notexist'`) so `Get-Command` naturally returns nothing -- is simple
and reliable, but it is NOT what the plan says. If an implementer tries to redefine
`function Get-Command { return $null }` in the test scope, dot-sourced production code in
the same scope may resolve the mock or the built-in depending on scope ordering, producing
unpredictable behavior. The plan must describe the mechanism explicitly.

**NH-2: `Invoke-HostQuery` mock ordering is unspecified.**

v2 mandates `Invoke-HostQuery` in production code (Section 3 Decision 4 -- correct). But the
test plan never shows HOW the test overrides it. In PowerShell, a function defined AFTER a
dot-source overwrites the earlier definition in the same scope. The test must:
1. Dot-source `profile.ps1` (defines the real `Invoke-HostQuery`)
2. Redefine `function Invoke-HostQuery { return $mockPath }` in the same scope AFTER dot-source

If the mock is placed BEFORE the dot-source, the dot-source overwrites it and the real child
process is called. This subtlety is not documented. Risk: first implementer gets it backwards,
wonders why the mock is not active, and adds a workaround that breaks CI.

**NH-3: Uninstall inlined resolver has zero test coverage.**

Section 3 Decision 3 inlines the ~15-line resolver in `uninstall.ps1`. No GG test exercises
the uninstall code path. A copy-paste error in the inlined resolver (e.g., wrong fallback
path, missing `Select-Object -First 1`, wrong case comparison) means uninstall silently
removes the block from the HARDCODED path only, leaving the OneDrive block in place. The
acceptance criterion says "Uninstall removes block from all locations (resolved + legacy)" --
there is no automated test verifying this. At minimum, one test should call the uninstall
logic (or the inlined resolver function) and assert that an OneDrive-path block is stripped.

**NH-4 (restatement with specifics): GG-5 algorithm direction bug amplified by weak assertion.**

This is an extension of showstopper #5. The algorithm bug (`-First 1` vs `-Last 1`) will
cause `Resolve-ProfilePath` to return a corporate banner string whenever a host emits any
console output before printing the path. The weak assertion (`no newline`) means GG-6 is a
false-green test -- it passes while the function is broken. This combination (wrong algorithm
+ wrong assertion) is worse than no test: it provides false confidence.

Repro for the bug: define `Invoke-HostQuery` to return `"Microsoft Banner`n$mockPath"`. Call
`Resolve-ProfilePath`. Assert return value `eq $mockPath`. The current algorithm fails this
assertion; the current GG-6 assertion does not.

---

## Summary of Remaining Showstoppers

| # | Severity | Description |
|---|----------|-------------|
| 2 | Medium | C-2 and C-3 harness still use `$PROFILE = $path`; broken in PS7+ |
| 3 | Medium | GG-4 covers one-legacy-path only; dual-orphan loop not tested |
| 5 | High | GG-6 algorithm is directionally wrong (`-First 1`) AND assertion is too weak to catch it |

Showstoppers 1 and 4 are fully resolved. Three of five remain at medium/high severity.

---

## Required Fixes for v3

1. **GG-6 algorithm fix:** Change `Select-Object -First 1` to `Select-Object -Last 1` in
   `Resolve-ProfilePath`. The path is the return value of `$PROFILE` and is always the last
   line of output; any console banner precedes it.

2. **GG-6 assertion fix:** Assert `$result -eq $expectedMockPath`, not just "no newline."

3. **GG-4b: dual-orphan test.** Seed BOTH `$ps51Fallback` and `$ps7Fallback` with the
   dev-setup block. Resolve to a different (OneDrive) path. Call `Write-PowerShellProfile`.
   Assert neither legacy file contains the BEGIN marker. Assert only the OneDrive path does.

4. **GG-2: describe mechanism.** Change "Mock `Get-Command` returns `$null`" to use an
   absent exe name: `Resolve-ProfilePath -HostExe 'powershell-notexist' -FallbackPath $fb`.
   No Get-Command shadowing required or desired.

5. **Invoke-HostQuery mock ordering note.** Add a code comment in GG-1 showing dot-source
   BEFORE mock definition. One line; prevents the most common implementer trap.

6. **Uninstall test.** Add GG-7: dot-source the inlined uninstall resolver, create a block
   at an OneDrive-style mock path, call the strip logic, assert block is gone.
   (Or add to Group FF if the group letter scheme assigns uninstall tests there.)

7. **C-2 / C-3 harness fix (deferred but required before PS7 CI).** These are pre-existing
   but v2 does not fix them. Must be addressed before the PR can claim it "runs clean in PS7."
   Suggested fix: replace `$PROFILE = $path` with `Invoke-HostQuery` mock pattern matching
   what the new GG tests do, so all profile tests run cleanly on both 5.1 and 7+.
   This fix is in scope because v2 explicitly acknowledges the PS7 read-only constraint.

---

## Recommendation

REVISE. Revision owner: Donald.
(Mickey locked out per grill-reviewer constraint. Goofy locked out as original v1 author.
Donald is the appropriate next implementer for targeted algorithm + test plan surgery.)

The v2 plan is structurally sound -- Invoke-HostQuery seam, case-insensitive dedup, and the
Pester removal are all correct. The remaining work is small: one algorithm direction fix,
two test assertion fixes, two additional test cases, and one uninstall test. This is not a
full redesign. A v3 with just these six items resolves all showstoppers.
