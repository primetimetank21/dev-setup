# Chip's Grill -- Plan for #441 v4
**Date:** 2026-05-27
**Reviewer:** Chip (Tester)
**Verdict:** REVISE
**Plan version reviewed:** v4 (Jiminy revision)
**Author locked out:** Goofy, Mickey, Donald, Jiminy (authored v4 revision)

---

## v3-Concern Regression Check

### SS-5 (GG-6 inversion) -- RESOLVED

No regression. GG-6 row in v4 is unchanged from v3: `-Last 1`, `-NoLogo`, assertion
`$result -eq $mockPath`. Trace confirmed correct in v3 grill; v4 does not touch it.

---

### SS-3 (GG-4 dual-orphan) -- RESOLVED

v4 GG-4 row now explicitly states: "Both Invoke-HostQuery mock calls (for powershell and
pwsh) return the SAME $oneDrivePath; dedup produces 1 entry in $profilePaths; BOTH
$ps51Fallback AND $ps7Fallback files exist in TestDrive seeded with BEGIN marker."

Both-hosts-same-path is stated. Both legacy files must be stripped. Loop-break-after-first
bug remains catchable. SS-3 remains RESOLVED.

---

### SS-2 (C-2/C-3 PS7+ guard) -- RESOLVED

My v3 sub-items:
1. "`skip` is not valid PowerShell" -- FIXED: v4 P4 replaces with `if/Write-Host/return`.
2. "$PROFILE = $path assignment is OUTSIDE Test-Scenario block" -- FIXED: v4 P4 moves the
   assignment INSIDE the Test-Scenario body.
3. "What generates the skip log entry?" -- FIXED: `Write-Host 'SKIP C-2: PS7+...'` stated.

All three sub-items addressed. SS-2 RESOLVED per my v3 criteria.

New concern filed under new findings below (skip appears as silent PASS). That is a v4-new
finding, not a regression of my v3 items.

---

### GG-7 HIGH (NF-1: $LASTEXITCODE mock broken) -- RESOLVED

v4 P3 fix: mock calls `& $env:ComSpec /c "exit 1"`.

Mechanism verification:
- `& $env:ComSpec /c "exit 1"` launches cmd.exe, which exits with code 1.
- PowerShell runtime sets `$LASTEXITCODE = 1` at global scope on native-command exit.
  This is NOT a local variable -- it is the same global that Resolve-ProfilePath reads
  immediately after Invoke-HostQuery returns.
- After the mock function returns, caller's `$LASTEXITCODE` IS 1. Fallback branch fires.
  Assertion `$result -eq $FallbackPath` exercises the correct code path. FIXED.

$env:ComSpec availability: always defined on Windows (set before any user shell
customization; resolves to C:\Windows\System32\cmd.exe). Safe to rely on.

Idiomatic alternative: `$global:LASTEXITCODE = 1` inside the mock function is lighter
(no child process) and equally correct within the Test-Scenario harness (no Pester Mock
infrastructure). Not a blocking difference; `& $env:ComSpec` is more authentic to
production semantics. Suggest as optional simplification.

NF-1 HIGH: RESOLVED.

---

### NF-3 MEDIUM (Mock isolation between GG tests) -- RESOLVED

v4 Section 5 header now states: "redefine mock Invoke-HostQuery at the start of each
individual test (or in a BeforeEach block) so no mock state leaks between tests.
Test-Scenario runs its block in a child scope -- mocks defined in the enclosing (file)
scope are visible inside but are reset between tests by explicit redefinition."

Scope model is now stated (child scope). The pattern -- define mock in file scope, redefine
before each Test-Scenario call -- is workable: Test-Scenario's `& $block` creates a child
scope that inherits the file-scope function definition; Write-PowerShellProfile called from
within that child scope will look up `Invoke-HostQuery` through the scope chain and find the
mock. [ok]

Caveat: "or in a BeforeEach block" is misleading -- Test-Scenario has no BeforeEach
mechanism. Filed under new findings (LOW).

NF-3 MEDIUM: RESOLVED.

---

### NF-4 MEDIUM (GG-4 mock ambiguity) -- RESOLVED

v4 GG-4 row eliminates ambiguity. Both calls return the same $oneDrivePath; dedup -> 1
entry; both legacy paths are orphaned. Interpretation (b) is no longer possible.
NF-4 MEDIUM: RESOLVED.

---

## New Findings

### NF-1 (v4): GG-7 -- Exe spec missing; test may exercise wrong branch (MEDIUM)

Resolve-ProfilePath has TWO early-exit paths:
  (A) Get-Command $HostExe fails -> exe-not-found fallback (no Invoke-HostQuery call)
  (B) Invoke-HostQuery runs; $LASTEXITCODE -ne 0 -> exit-code fallback (what GG-7 targets)

For GG-7 to reach path (B), the exe passed to Resolve-ProfilePath must be present on PATH
so that Get-Command succeeds, allowing execution to reach the Invoke-HostQuery call.

v4 GG-7 row: "Mock calls `& $env:ComSpec /c 'exit 1'`" -- but DOES NOT specify which exe
name is passed to Resolve-ProfilePath. If the engineer passes 'pwsh' and pwsh is not
installed on the test runner (PS 5.1 only CI), Get-Command returns null; path (A) fires;
Invoke-HostQuery is never called; $LASTEXITCODE is not set by the mock; the test returns
$FallbackPath for the WRONG reason and passes as a false green.

GG-7 must specify: "pass an exe known to be present on the test runner (e.g., 'powershell'
which is guaranteed on any Windows system, or 'cmd' / 'cmd.exe')." Without this, the test
is environment-dependent.

Required fix: add to GG-7 Input cell: "Pass $HostExe = 'powershell' (always present on
Windows) so Get-Command succeeds and the LASTEXITCODE path is exercised."

Severity: MEDIUM. Results in a false green on PS-5.1-only runners.

---

### NF-2 (v4): GG-1/GG-4/GG-5 -- "TestDrive" without Pester; no temp file pattern (MEDIUM)

GG-4 row: "BOTH $ps51Fallback AND $ps7Fallback files exist in TestDrive seeded with BEGIN
marker."
GG-1: "Block at OneDrive path."
GG-5: "Idempotency (3 runs) -- same file."

None of these tests can run without writing to disk. The test harness does NOT use Pester;
`$TestDrive` is a Pester-only automatic variable. In this harness, `$TestDrive` is null or
undefined, so any path like `Join-Path $TestDrive '...'` silently resolves to a relative path
from the cwd -- or throws under strict mode.

The existing C-2/C-3 tests use:
  `$c2Profile = Join-Path $PSScriptRoot "temp_profile_c2_$(Get-Random).ps1"`
  and clean up with `if (Test-Path $c2Profile) { Remove-Item $c2Profile -Force }` AFTER the
  Test-Scenario block.

GG-1, GG-4, and GG-5 have no equivalent. An engineer reading the plan will either:
  (a) Use $TestDrive (undefined -- test fails or writes to bad path), or
  (b) Infer the PSScriptRoot + Get-Random pattern from C-2/C-3 (reasonable but undocumented
      for GG group), or
  (c) Use hard-coded temp paths (not CI-safe).

Additionally, GG-4 seeds BOTH legacy files. In the existing pattern, legacy paths
($ps51Fallback, $ps7Fallback) are derived from $HOME. The test must either use a fake $HOME
(like FF-6..FF-10 sandbox pattern in the existing suite) or override $ps51Fallback and
$ps7Fallback to point to temp files. The plan does not address this -- writing to real
$HOME paths in a test is destructive.

Required fix: Section 5 must add a note on the temp file pattern for GG-1/GG-4/GG-5:
  - Use Join-Path $PSScriptRoot "temp_gg_$(Get-Random).ps1" for the "mock path."
  - Override $ps51Fallback/$ps7Fallback test variables to point to temp files, not real HOME.
  - Clean up after each Test-Scenario block with Remove-Item.

Severity: MEDIUM. Tests that touch $HOME paths in CI are destructive and non-idempotent.
A skilled engineer will notice this gap but the plan should not require such inference.

---

### NF-3 (v4): C-2/C-3 skip-as-pass; PS7+ CI shows green with no logic executed (LOW)

v4 P4: `if ($PSVersionTable.PSVersion.Major -ge 7) { Write-Host 'SKIP C-2: ...'; return }`.

`return` inside the Test-Scenario scriptblock causes the block to complete without throwing.
Test-Scenario's pass/fail counter sees no throw -> records PASS. On PS7+ CI, C-2 and C-3
appear as two green passes in the test tally even though zero lines of their actual logic ran.

A developer reviewing CI output will see "63 passed" and not notice that C-2/C-3 silently
skipped. Future regressions in those test branches are invisible.

The Write-Host message provides traceability in the raw log, but the pass count is inflated.

Mitigation (within vertical slice): the existing harness has a Write-Skip helper (see
history.md "Conditional skip pattern: Get-Command -ErrorAction SilentlyContinue outside test
block, call Write-Skip if found"). If Write-Skip exists, the guard should call Write-Skip
('C-2', 'PS7+ -- $PROFILE conceptually read-only; covered by GG tests') before return.
This correctly increments the skip counter rather than the pass counter.

Severity: LOW. Does not cause a false green in GG tests. Does cause inflated pass counts and
invisible test gaps on PS7+ runners.

---

### NF-4 (v4): BeforeEach reference in non-Pester harness (LOW)

Section 5 header: "or in a BeforeEach block."

BeforeEach is a Pester keyword. The Test-Scenario harness has no BeforeEach. This reference
will confuse engineers unfamiliar with the project test harness. They may attempt to use
BeforeEach and get a "command not found" error or silently skip mock setup.

Fix: replace "or in a BeforeEach block" with "or in file scope immediately before each
Test-Scenario call."

Severity: LOW. Terminology error; likely caught at implementation time.

---

### NF-5 (v4): GG-7 suggestion -- $global:LASTEXITCODE is lighter (INFORMATIONAL)

`& $env:ComSpec /c "exit 1"` is correct but spawns a real child process (adds latency,
depends on cmd.exe being functional). An equivalent approach within the Test-Scenario
harness is:

  function Invoke-HostQuery { $global:LASTEXITCODE = 1; return "" }

This is idiomatic for non-Pester mocks: explicit global scope qualifier overrides the
variable at global scope, visible to all callers. No child process needed.

Either approach is correct. Suggesting $global:LASTEXITCODE as an optional simplification
for documentation quality. Not blocking.

---

## Summary Matrix

| # | Concern | v3 Status | v4 Status |
|---|---------|-----------|-----------|
| SS-5 | GG-6 inversion | RESOLVED | HOLDS -- no regression |
| SS-3 | GG-4 dual-orphan | RESOLVED | HOLDS -- no regression |
| SS-2 | C-2/C-3 PS7+ guard | STILL PARTIAL | RESOLVED (all 3 sub-items) |
| NF-1 | GG-7 LASTEXITCODE mock | HIGH (new in v3) | RESOLVED |
| NF-2 | Mock isolation | MEDIUM (new in v3) | RESOLVED |
| NF-3 | GG-4 mock ambiguity | MEDIUM (new in v3) | RESOLVED |
| NF-1v4 | GG-7 exe spec missing | -- | NEW MEDIUM |
| NF-2v4 | TestDrive without Pester | -- | NEW MEDIUM |
| NF-3v4 | C-2/C-3 skip-as-pass | -- | NEW LOW |
| NF-4v4 | BeforeEach reference | -- | NEW LOW |
| NF-5v4 | LASTEXITCODE alt suggestion | -- | INFORMATIONAL |

---

## Implementation-Ready Verdict

**Can a competent engineer write Pester (Test-Scenario) code for GG-1..GG-7 today?**

NO -- not without inferring two non-trivial decisions:

1. **GG-7:** Which exe to use so the mock is invoked (not the exe-not-found branch).
   Without guidance, a PS-5.1-only CI run can produce a false green.

2. **GG-1/GG-4/GG-5:** How to create and clean up temp files without $TestDrive. Without
   the PSScriptRoot+Get-Random pattern (or explicit fake-$HOME sandbox) stated in the plan,
   the engineer either writes to real $HOME or produces undefined-variable errors.

The algorithm and mock mechanism are sound. The two new MEDIUMs are purely test-plan
specification gaps. A targeted v5 pass fixing GG-7 input spec and the temp file pattern
note would close all open items.

---

## Required Fixes for v5

1. **GG-7 exe spec (MEDIUM):** Add to GG-7 Input: "Use $HostExe = 'powershell' (always
   present on Windows) so Get-Command succeeds and the mock is invoked."

2. **Temp file pattern (MEDIUM):** Add one-sentence note to Section 5: "GG tests that write
   to disk (GG-1, GG-4, GG-5) must use Join-Path $PSScriptRoot 'temp_gg_$(Get-Random).ps1'
   for mock paths and override $ps51Fallback/$ps7Fallback to temp paths, not $HOME paths;
   clean up with Remove-Item after each Test-Scenario block."

3. **BeforeEach reference (LOW):** Change "or in a BeforeEach block" to "or in file scope
   immediately before each Test-Scenario call."

4. **Skip-as-pass (LOW):** Change C-2/C-3 guard to call Write-Skip rather than a bare
   Write-Host + return, so the skip counter is incremented correctly.

---

## Recommendation

REVISE. Algorithm is sound; all v3 concerns closed. Two new MEDIUMs (GG-7 exe spec and
TestDrive temp file pattern) prevent implementation-readiness. Both are small, targeted
spec additions -- v5 should be a quick pass.

Suggested reviser: Jiminy (authored v4; not locked out for v5). Alternatively: any eligible
agent not yet holding a lockout on this plan.
