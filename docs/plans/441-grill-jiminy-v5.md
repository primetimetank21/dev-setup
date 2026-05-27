# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Jiminy (Quality Auditor -- process/quality gate, final grill before ship)
**Plan reviewed:** docs/plans/441-profile-path.md (v5.1, author: Donald)
**Date:** 2026-05-27
**Session:** 441-grill-v5
**Verdict:** REVISE

**Author locked out for this grill:** Donald (v5/v5.1), Jiminy (v4); eligible revisor = Chip or Pluto
**Grill scope:** Vertical-slice integrity, plan-to-implementation contract, internal consistency,
                 convergence of all v4 findings (Donald F-1..F-5, Chip C-1/C-2/NF-3v4/NF-4v4,
                 Pluto A-1). Final gate before handoff to implementer.

---

## Verdict Summary

REVISE. One new MEDIUM finding (JN-1) introduced by Donald's v5 revision: the v5 H5 fix adds
`$local:` bindings inside `Write-PowerShellProfile` that cannot be overridden from test scope,
directly contradicting the v5 H3 test override language. GG-1/GG-4/GG-5 disk-writing tests as
specified will silently target REAL `$HOME` profile paths instead of temp paths. This is a
destructive write risk in CI and on dev machines. All other v4 findings are resolved. One LOW
(NF-3v4 Write-Skip) remains open but is non-blocking.

---

## Task 1: Vertical Slice Integrity

### Scope creep check (v1 -> v5.1)

| Version | Author | IN-scope additions | New tests beyond GG-1..GG-7 | New arch layers/knobs |
|---------|--------|-------------------|-----------------------------|-----------------------|
| v1 | Goofy | Original scope | None | None |
| v2 | Mickey | Fallback + dedup + legacy cleanup + test seam | GG-1..GG-6 (6 tests) | Invoke-HostQuery wrapper |
| v3 | Donald | GG-7 + $LASTEXITCODE + path-shape guard + -NoLogo/-Last1 | GG-7 added (7 total) | Resolve-ProfilePath split out |
| v4 | Jiminy | Precision patches only (P1-P7) | No new tests | No new layers |
| v5 | Donald | Precision patches only (H1-H5) | No new tests | No new layers |
| v5.1 | Donald | Precision patches only (F-4/F-5) | No new tests | No new layers |

PASS. No scope expansion from v4 onward. All 7 GG tests (GG-1..GG-7) are present; no extras.
No new options, parameters, configuration knobs, or architecture layers added in any revision.

### Word count

v5.1 raw word count: ~1839 (counted from plan file). Task brief estimated ~1196 -- brief was
counting prose only, not the changelog tables. Full file including 3 changelog tables (v4, v5,
v5.1) accounts for the delta. Growth is justified: changelog tables are required process
artifacts, not scope additions. PASS.

---

## Task 2: Plan-to-Implementation Contract

### Can the implementer write Write-PowerShellProfile from Section 4 alone?

PARTIAL. The function is nearly fully specified:
- Invoke-HostQuery: fully defined (param, body, 2>$null)
- Resolve-ProfilePath: fully defined (guard, try/catch, LASTEXITCODE check, path-shape filter,
  trim, fallback)
- Write-PowerShellProfile local vars: defined ($local:ps51Fallback, $local:ps7Fallback,
  $local:beginMarker, $local:endMarker)
- Orphan-strip loop: fully defined (isOrphan check, Get-Content, regex, Set-Content with
  -Encoding ASCII, Write-Info)
- Write loop: STUB ("# Write to each resolved path (existing strip+re-inject logic)")

The write-loop stub was accepted as Pluto A-2 LOW (impl note; implementer reads production
lines 262-309). Still present in v5.1. Accepted deferral; a COMPETENT engineer with production
file access can implement it. NOT a new hole.

Verdict: YES with the write-loop caveat (known accepted gap).

### Can the implementer write GG-1..GG-7?

BLOCKED by JN-1 (see Task 3 / new findings). GG-1/GG-4/GG-5 as specified direct the
implementer to "override $ps51Fallback/$ps7Fallback to temp paths" but the function defines
them as $local: -- the override is impossible from test scope. The implementer following both
sections literally will write tests that destructively target real $HOME paths.

GG-2, GG-3, GG-6, GG-7: fully specified and implementable without additional context. PASS.

### Can all 9 decisions (Section 3) be made without ambiguity?

YES. (Note: the task brief counted 11; the plan contains 9: D1-D4 + v3-D1..v3-D5. No count
discrepancy in the actual plan text -- all 9 are unambiguous.)

---

## Task 3: Internal Consistency

### Section 3 decisions vs Section 4 algorithm

| Decision | Algorithm cite | Consistent? |
|----------|---------------|-------------|
| D1: $PROFILE (CurrentUserCurrentHost) | Invoke-HostQuery calls 'powershell'/'pwsh' | YES |
| D2: Test-Scenario harness | Section 5 uses Test-Scenario | YES |
| D3: Inline in uninstall.ps1 | Section 4 comment "(and inlined in uninstall.ps1)" | YES |
| D4: Mandate Invoke-HostQuery | function defined in Section 4 | YES |
| v3-D1: -Last 1 / -NoLogo | Section 4: Select-Object -Last 1 | YES |
| v3-D2: $LASTEXITCODE check | Section 4: if ($LASTEXITCODE -ne 0) | YES |
| v3-D3: GG-4 dual-orphan | GG-4 row: both hosts return same $oneDrivePath | YES |
| v3-D4: C-2/C-3 guarded | Section 3 text: if/Write-Host/return; Section 7 AC#6 | YES |
| v3-D5: Sort-Object dedup | Section 4: Sort-Object { $_.ToLower() } -Unique | YES |

All 9 decisions consistent with algorithm. PASS.

### Section 5 tests vs Section 4 algorithm -- branch coverage

| Algorithm branch | Covered by | Status |
|-----------------|------------|--------|
| Get-Command fails -> fallback | GG-2 | YES |
| $LASTEXITCODE -ne 0 -> fallback + warn | GG-7 | YES |
| IsNullOrEmpty -> fallback | (subset of GG-7 via empty return) | IMPLICIT |
| -notmatch '^[A-Za-z]:\\' -> fallback | No dedicated test | GAP (accepted LOW -- Pluto A-3) |
| Normal resolved path -> write | GG-1 | YES |
| Case-insensitive dedup | GG-3 | YES |
| Orphan strip (both paths) | GG-4 | YES (but blocked by JN-1) |
| Idempotency | GG-5 | YES (but blocked by JN-1) |
| Multi-line output | GG-6 | YES |

Branch coverage is complete except for path-shape validation negative case (accepted gap from
prior grills). PASS with known LOW gap.

### v5/v5.1 changelog accuracy

| Entry | Claim | Plan text | Match? |
|-------|-------|-----------|--------|
| H1 | Set-Content -Encoding ASCII added | Section 4 orphan Set-Content has -Encoding ASCII | YES |
| H2 | $global:LASTEXITCODE = 0 reset before each test | Section 5 header states it | YES |
| H3 | TestDrive replaced with Join-Path $env:TEMP New-Guid | Section 5 header and GG-4 row | YES |
| H4 | GG-7: $HostExe = 'powershell' specified | GG-7 row | YES |
| H5 | $local:ps51Fallback/$ps7Fallback defined in Write-PowerShellProfile | Section 4 | YES |
| F-4 | Regex: \r?\n prefix + .*? | Section 4 regex matches production line 27 | YES |
| F-5 | $local:beginMarker/$endMarker defined | Section 4 | YES |

Changelog is accurate. However: the BeforeEach removal (Chip NF-4v4 fix) is present in
Section 5 text ("not a BeforeEach block -- Test-Scenario has none") but is NOT listed as a
named H-entry in the v5 changelog. Minor documentation gap in changelog; the fix is present.

### Orphaned version references

None found. "v3-D1" etc. are intentional decision-naming conventions, not stale citations.

---

## Task 4: Convergence Table

All findings from v4 grill cycle (Donald F-1..F-5, Chip C-1/C-2/NF-3v4/NF-4v4/NF-5v4,
Pluto A-1).

| Finding | Griller | Sev | Resolution | Status |
|---------|---------|-----|------------|--------|
| F-1: Set-Content missing -Encoding ASCII | Donald | HIGH | v5 H1: added -Encoding ASCII | RESOLVED |
| F-2: TestDrive contradicts D2 | Donald | MEDIUM | v5 H3: replaced with $env:TEMP New-Guid | RESOLVED |
| F-3: $LASTEXITCODE stale contamination | Donald | MEDIUM | v5 H2: reset $global:LASTEXITCODE = 0 | RESOLVED |
| F-4: Regex diverges from production | Donald | MEDIUM | v5.1: \r?\n prefix + .*? aligned to prod | RESOLVED |
| F-5: $beginMarker/$endMarker undefined | Donald | LOW | v5.1: $local:beginMarker/endMarker added | RESOLVED |
| C-1 (NF-1v4): GG-7 exe unspecified | Chip | MEDIUM | v5 H4: $HostExe = 'powershell' stated | RESOLVED |
| C-2 (NF-2v4): TestDrive / temp file pattern | Chip | MEDIUM | v5 H3: $env:TEMP New-Guid + cleanup | RESOLVED |
| NF-3v4: C-2/C-3 skip-as-pass (Write-Skip) | Chip | LOW | NOT addressed; still uses Write-Host | OPEN (LOW) |
| NF-4v4: BeforeEach reference | Chip | LOW | Fixed in text (not in changelog) | RESOLVED |
| NF-5v4: $global:LASTEXITCODE alt suggestion | Chip | INFO | N/A (informational; $env:ComSpec kept) | N/A |
| A-1: $ps51Fallback/$ps7Fallback undefined | Pluto | MEDIUM | v5 H5: $local: defs added | RESOLVED* |

*A-1 resolution (v5 H5) introduces JN-1 (see below).

CONVERGENCE COMPLETE for all HIGH + MEDIUM items. One LOW (NF-3v4) open, non-blocking.

---

## New Findings

### [MEDIUM] JN-1: H5 $local: definitions make Section 5 test override inoperable

**Citation:** Section 4, Write-PowerShellProfile body (v5 H5):
```
$local:ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', ...)
$local:ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', ...)
```

**Contradicts:** Section 5 header (v5 H3):
"GG tests that write to disk (GG-1, GG-4, GG-5) create a unique temp dir via
`Join-Path $env:TEMP "gg-test-441-$(New-Guid)"`, override `$ps51Fallback`/`$ps7Fallback`
to paths within it, and clean up in a `finally` block"

**Root cause:** In PowerShell, assigning a variable inside a function (with or without the
`$local:` qualifier) creates a function-local binding that shadows any variable of the same
name in the calling scope. When the test sets `$ps51Fallback = $tempPath` before calling
`Write-PowerShellProfile`, the function immediately overwrites it with its own `$local:`
definition pointing to the real `$HOME` path. The test override has NO effect.

**Impact:** GG-1, GG-4, and GG-5 as specified will:
1. Construct `$legacyPaths = @($ps51Fallback, $ps7Fallback)` using REAL $HOME paths
2. The orphan-strip loop (if legacy files exist) will TARGET REAL PRODUCTION PROFILE FILES
3. The write loop will WRITE TO REAL $HOME PROFILE PATHS in CI or on the developer's machine
4. The test passes but the side-effects are destructive and non-idempotent in the real env

This is a plan-internal contradiction introduced when H5 (Pluto A-1 fix) and H3 (Chip C-2
fix) were authored in the same v5 revision without a consistency check between them.

**Severity:** MEDIUM. Results in destructive test writes to real profile files. Not a false
green per se -- the test exercises real code -- but it violates the "no real $HOME writes in
test" safety requirement that H3 was added to establish.

**Fix (one of three options; reviser chooses):**

Option A (PREFERRED -- aligns with Pluto's architecture intent):
Add fallback-path parameters with defaults to Write-PowerShellProfile:
```powershell
function Write-PowerShellProfile {
    param(
        [string]$PS51FallbackOverride = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'),
        [string]$PS7FallbackOverride  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
    )
    $local:ps51Fallback = $PS51FallbackOverride
    $local:ps7Fallback  = $PS7FallbackOverride
```
Tests call: `Write-PowerShellProfile -PS51FallbackOverride $tempPath1 -PS7FallbackOverride $tempPath2`
Production callers: `Write-PowerShellProfile` (defaults apply, no change to callsites).

Option B: Define fallback paths at file scope (outside all functions). Tests set them via
`$script:ps51Fallback = $tempPath` before each call. Function reads from scope chain. Less
explicit than Option A; pollutes file scope.

Option C: Test creates temp copies of the REAL profile files, runs Write-PowerShellProfile,
inspects real files, restores from copies. Brittle and cannot run in CI safely.

Option A is recommended: adds two optional parameters, zero impact on production callers, and
closes the override gap cleanly without file-scope pollution.

---

### [LOW] JN-2: NF-3v4 (Write-Skip) remains open

**Citation:** Section 3 v3-D4: "Write-Host 'SKIP C-2: PS7+ -- $PROFILE conceptually read-only'"
**Issue:** Chip NF-3v4 requested Write-Skip to increment skip counter (not pass counter).
**Impact:** On PS7+ CI, C-2/C-3 appear as green passes; skip count understated.
**Status:** Not addressed in v5 or v5.1. LOW -- does not affect GG tests. Non-blocking.
**Recommendation:** Address in the same revision pass that fixes JN-1 (one-word change).

---

## Required Fixes for v6

1. **JN-1 [MEDIUM]:** Choose Option A (parameters) or Option B (file scope) and update
   Section 4 to reflect. Update Section 5 to show how the test passes the temp paths.
   Option A recommended: add two optional params to Write-PowerShellProfile with default
   $HOME-derived values; tests pass temp paths explicitly.

2. **JN-2 [LOW]:** Section 3 v3-D4: replace `Write-Host 'SKIP C-2: ...'` with
   `Write-Skip 'C-2' 'PS7+ -- $PROFILE conceptually read-only; covered by GG tests'`
   (or equivalent skip-counter call per harness convention).

---

## What v5.1 Got Right

- **F-1 through F-5:** All Donald's findings resolved. Encoding, regex, markers, LASTEXITCODE
  contamination -- all closed. The orphan-strip code now matches production line by line.
- **H4 (GG-7 exe spec):** `$HostExe = 'powershell'` is the correct answer; the rationale for
  rejecting 'pwsh' (not-installed early-exit masks mock invocation) is documented.
- **H3 intent:** The INTENT of overriding fallback paths to temp dirs is correct and necessary.
  The gap is purely in the mechanism (local var shadowing), not the safety strategy.
- **BeforeEach removal:** "not a BeforeEach block -- Test-Scenario has none" is present and
  correct. NF-4v4 is substantively closed.
- **v5.1 regex:** Matches production line 27 exactly. F-4 resolved cleanly.
- **Vertical slice discipline:** 6 revisions; scope held. Zero drift. Earl's constraint honored.

---

**Grilled by:** Jiminy (Quality Auditor)
**Date:** 2026-05-27
**Session:** 441-grill-v5
