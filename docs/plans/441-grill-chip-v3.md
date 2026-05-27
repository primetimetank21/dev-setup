# Chip's Re-Grill -- Plan for #441 v3
**Date:** 2026-05-27
**Reviewer:** Chip (Tester)
**Verdict:** REVISE
**Author locked out:** Goofy, Mickey, Donald

---

## Context

v2 grill returned REVISE with 3 partial showstoppers (SS-2, SS-3, SS-5) and 4 new holes
(NH-1 through NH-4). Donald revised to v3. This re-grill is scoped to:
  (a) did the 3 partials land?
  (b) are the new findings from the task brief real?

---

## v2 Partial-Resolution Status

### SS-5 (GG-6 inverted) -- RESOLVED

v2 defect: algorithm used `Select-Object -First 1`, returning the banner. Assertion checked
only "no newline" -- passed on wrong value (false-green).

v3 fix: `-Last 1` with `-NoLogo`; assertion upgraded to `$result -eq $expectedMockPath`.

Trace through the full pipeline:
  Mock returns `"banner`n$mockPath"`
  -> `$raw.Trim()` -- no leading/trailing whitespace; internal `\n` preserved: `"banner`n$mockPath"`
  -> `-split '\r?\n'` -- produces array: `["banner", "$mockPath"]`
  -> `Where-Object { $_ }` -- both non-empty, both kept
  -> `Select-Object -Last 1` -- returns `"$mockPath"` (correct)
  -> Assertion `$result -eq $mockPath` passes for the right reason

Edge case: trailing newline in raw output (e.g., `"banner`n$mockPath`n"`):
  `$raw.Trim()` strips the trailing `\n` on the full string first -> `"banner`n$mockPath"`
  Same result. Handled.

Edge case: path with trailing space before `\n` (e.g., `"banner`n$mockPath `n"`):
  `Trim()` strips trailing space + newline from the whole string -> `"banner`n$mockPath"`
  (The space after `$mockPath` is removed because it is the rightmost whitespace on the full
  string.) Result is still `$mockPath`. Handled.

No missed edge case found. SS-5 is RESOLVED.

---

### SS-3 (Legacy cleanup dual orphan, GG-4) -- RESOLVED

v2 defect: GG-4 seeded only ONE legacy path. A loop-break-after-first bug would pass.

v3 fix (v3-D3): Section 5 table cell explicitly reads:
  Input:     "Seed BOTH `$ps51Fallback` AND `$ps7Fallback` with block; mock resolves to
             OneDrive path"
  Assertion: "Neither legacy file has BEGIN marker; OneDrive file has BEGIN marker"

The dual assertion is sufficient: if the cleanup loop breaks after the first match, one legacy
file retains the BEGIN marker and the assertion fails. SS-3 is RESOLVED.

Caveat filed under New Finding 4 below (GG-4 mock ambiguity does not re-open SS-3 but is a
separate coverage gap).

---

### SS-2 (C-2/C-3 PS7+ guard) -- STILL PARTIAL

v2 defect: existing lines 238 and 261 of `test_windows_setup.ps1` do `$PROFILE = $path`,
read-only in PS7+. v2 plan did not address them.

v3 decision v3-D4: "Guard C-2 and C-3 with `if ($PSVersionTable.PSVersion.Major -ge 7) { skip }`"
v3 AC item: "C-2 and C-3 guarded against PS7+ `$PROFILE` assignment error (skip with logged reason)"

Why still partial:

1. `skip` is not a valid PowerShell command. The Test-Scenario harness (no Pester) has no
   native skip mechanism. The plan does not define what `skip` resolves to: early return from
   the enclosing block? A `return` before the `$PROFILE = $path` line? A wrapper guard around
   the entire setup + Test-Scenario? Without a code snippet, the implementer must invent this.

2. The `$PROFILE = $path` assignment at line 238 is OUTSIDE the Test-Scenario block (it is
   setup code that runs before the block). If a PS7+ guard is placed only inside the
   Test-Scenario block, the assignment still fires during setup and throws. The guard must wrap
   the setup lines, not just the Test-Scenario body.

3. "Skip with logged reason" -- what generates the log entry? `Write-Host`? The harness's own
   pass/skip counter? The plan does not say. A future PS7-only CI run might see zero output
   for C-2 and C-3 with no indication whether they were skipped or never reached.

Evidence: `tests/test_windows_setup.ps1` lines 235-253 (C-2), 258-276 (C-3). Both show
`$PROFILE = $path` outside the Test-Scenario block. The guard logic must precede those lines.
The plan acknowledges the constraint (v3-D4) but does not specify WHERE or HOW the guard is
inserted into the existing file structure.

SS-2 remains STILL PARTIAL. The intent is correct; the implementation spec is incomplete.

---

## New Findings

**NF-1: GG-7 mock cannot set `$LASTEXITCODE` as described -- broken test.**

The test table says: "Mock `Invoke-HostQuery` sets `$LASTEXITCODE = 1`, returns empty."

In PowerShell, `$LASTEXITCODE` is scoped. A plain assignment inside a function creates a
LOCAL variable:

  function Invoke-HostQuery { $LASTEXITCODE = 1; return "" }

When this function returns, the caller's `$LASTEXITCODE` is NOT updated. It retains its
previous value (typically 0 or whatever the last native command set). The production code
immediately after the call does:

  $raw = Invoke-HostQuery -Exe $HostExe
  if ($LASTEXITCODE -ne 0) { ... fallback ... }

With the mock as described, `$LASTEXITCODE` in the caller scope is 0, the condition is false,
and the fallback branch is never taken. GG-7 silently fails to test what it claims.

To propagate `$LASTEXITCODE` from mock to caller, the mock must use one of:
  (a) `$global:LASTEXITCODE = 1` (scope override)
  (b) `& cmd /c exit 1` or `& $env:ComSpec /c exit 1` (invoke a real native command)
  (c) The production code must be changed so the mock returns a sentinel value that the
      algorithm interprets as failure (rather than relying on `$LASTEXITCODE`).

Option (b) is most portable and least surprising. The plan must specify the mechanism.
As described, GG-7 is a false-green test -- it passes while the fallback branch is untested.
Severity: HIGH (same category as v2 SS-5).

---

**NF-2: GG-2 trace -- OK.**

`Resolve-ProfilePath 'powershell-notexist' $fb` calls `Get-Command 'powershell-notexist'
-EA SilentlyContinue`, which returns `$null`. `-not $null` is `$true`. Function returns
`$FallbackPath`. Assertion `$result -eq $FallbackPath` passes for the right reason.
`Invoke-HostQuery` is never called. This is correct -- GG-2 tests the "host not found" path;
GG-7 is intended to test the "host exits non-zero" path. No issue here.

---

**NF-3: Mock isolation between GG tests is unaddressed.**

Section 5 header note: "Mock must be defined AFTER dot-sourcing `profile.ps1` or the
dot-source overwrites it."

This addresses the ordering trap (NH-2 from v2 grill -- noted, partial credit). But it does
not address mock STATE BETWEEN tests.

If `Test-Scenario` runs its block in the current scope (dot-source pattern `. $block`), then
a function defined inside GG-1's block persists into GG-2, GG-3, etc. Each test must
explicitly redefine its mock. If `Test-Scenario` runs in a child scope (`& $block`), mocks
defined inside do NOT persist -- and then mocks that need to be active during a
`Write-PowerShellProfile` call (which dot-sources production code) may not be visible.

The plan gives no code example and does not state which scope model `Test-Scenario` uses.
The existing harness at lines 240-251 (C-2) and 263-273 (C-3) show that setup code runs
outside the Test-Scenario block, in the file's top scope. This implies Test-Scenario uses
child or dot-source scope. The GG test implementer needs to know this to avoid:
  (a) GG-1 mock leaking into GG-2 (wrong path returned for "fallback" test)
  (b) GG-4 mock not visible when Write-PowerShellProfile resolves paths

Severity: MEDIUM. A note with one code skeleton would close this.

---

**NF-4: GG-4 mock ambiguity -- combined dedup + dual-legacy scenario not explicitly specified.**

GG-4 description: "mock resolves to OneDrive path" -- does this mean:
  (a) Both `powershell` and `pwsh` mock calls return the same OneDrive path (dedup -> 1 entry)?
  (b) Only one host mock returns the OneDrive path; the other falls back to a legacy path?

If (b): the second legacy path is NOT orphaned (it IS the current resolved path for one host)
and should NOT be stripped. Seeding it with a dev-setup block and asserting it is stripped
would test the WRONG behavior.

If (a): dedup reduces `$profilePaths` to 1 entry; both legacy paths are orphaned; both should
be stripped. This is the intended scenario -- but the description does not say it explicitly.

The implementer must guess. If they choose interpretation (b), GG-4 would assert that a
non-orphaned legacy path is stripped, which contradicts the algorithm's guard condition. The
test would fail for the wrong reason. Severity: MEDIUM.

---

## Summary Matrix

| # | Concern | Status |
|---|---------|--------|
| SS-2 | C-2/C-3 PS7+ guard | STILL PARTIAL -- skip mechanism unspecified |
| SS-3 | GG-4 dual-orphan | RESOLVED |
| SS-5 | GG-6 algorithm + assertion | RESOLVED |
| NF-1 | GG-7 $LASTEXITCODE mock broken | NEW HIGH -- false-green test |
| NF-2 | GG-2 absent-exe trace | OK -- confirmed correct |
| NF-3 | Mock isolation between GG tests | NEW MEDIUM -- scope model undocumented |
| NF-4 | GG-4 both-hosts-same-path ambiguity | NEW MEDIUM -- implementer must guess |

---

## Required Fixes for v4

1. **GG-7 mock mechanism (HIGH).** Specify `$global:LASTEXITCODE = 1` OR `& cmd /c exit 1`
   inside the mock. Alternatively, change the mock to use a sentinel return value and update
   the production guard accordingly. Plain `$LASTEXITCODE = 1` inside a function does not
   propagate to the caller scope.

2. **C-2/C-3 guard spec (MEDIUM).** Show WHERE the guard goes in the existing test file
   (before the `$PROFILE = $path` setup lines, not only inside the Test-Scenario block).
   Define what "skip" means: e.g., a `Write-Host "SKIP C-2: PS7+ $PROFILE read-only"` and
   `continue` (or `return` if wrapped in a function). One pseudocode snippet closes this.

3. **Mock scope note (MEDIUM).** Add one code skeleton to Section 5 showing:
     (a) Dot-source profile.ps1 at top of test group
     (b) Define mock function immediately after in top scope
     (c) Reset or redefine mock before each GG test
   Note which scope `Test-Scenario` uses so implementer knows whether mock persists.

4. **GG-4 mock spec (MEDIUM).** Explicitly state: "Both `Invoke-HostQuery` mock calls return
   `$oneDrivePath` so `$profilePaths` deduplicates to 1 entry." Remove ambiguity.

---

## Recommendation

REVISE. One v2 partial still open (SS-2, skip mechanism underspecified). One new HIGH finding
(NF-1, GG-7 mock broken -- false-green). Two new MEDIUM findings (NF-3, NF-4).

Suggested reviser: Pluto (Donald and Mickey locked out; Goofy locked out as v1 author;
Donald locked out as v3 author per grill-reviewer constraint).

If Pluto is unavailable: escalate to Mickey to decide reviser assignment.

The algorithm itself (v3-D1 through v3-D5) is sound. GG-6 and GG-4 are fixed. The remaining
work is test-plan spec quality: two mechanism descriptions and two ambiguity resolutions.
This is targeted; a v4 pass should close all open items.
