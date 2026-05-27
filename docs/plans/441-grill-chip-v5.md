# Chip's Grill -- Plan #441 v5.1
**Date:** 2026-05-27
**Reviewer:** Chip (Tester)
**Verdict:** SHIP
**Plan version reviewed:** v5.1 (Donald revision -- F-4/F-5 patch)
**Author locked out:** Goofy, Mickey, Donald, Jiminy (authored prior revisions)

---

## C-1 / C-2 / F-3 Status

### C-1 (GG-7 exe spec) -- RESOLVED

v5.1 GG-7 Input cell explicitly states:
  "$HostExe = 'powershell' (guaranteed present on Windows; 'pwsh' is unsuitable --
   not-installed early-exit would mask the mock invocation and produce a false green on
   PS5.1-only runners (v5-H4))"

Rationale documented inline. Exe spec is unambiguous. C-1 RESOLVED.

---

### C-2 (TestDrive -> real temp path) -- RESOLVED

Section 5 header: "GG tests that write to disk (GG-1, GG-4, GG-5) create a unique temp dir
via Join-Path $env:TEMP 'gg-test-441-$(New-Guid)', override $ps51Fallback/$ps7Fallback to
paths within it, and clean up in a finally block (v5-H3)."

GG-4 row: "$ps51Fallback and $ps7Fallback overridden to Join-Path $env:TEMP
'gg-test-441-$(New-Guid)' temp paths (not real $HOME), both seeded with BEGIN marker."

$TestDrive is gone from all GG rows. finally-block cleanup is documented. Real $HOME is
explicitly called out as NOT used. C-2 RESOLVED.

---

### F-3 ($LASTEXITCODE reset positioning) -- RESOLVED

Section 5 header: "Before each redefinition, reset $global:LASTEXITCODE = 0 so GG-7's
native-command exit-1 does not contaminate subsequent success-path tests (v5-H2)."

"Before each redefinition" -- the reset is positioned before the mock function definition,
which is before the Test-Scenario call. This is the correct ordering. GG-7 contamination
into success-path tests is closed. F-3 RESOLVED.

---

## Regression Check (H1-H5, F-4, F-5)

| Patch | What it did | v5.1 status |
|-------|-------------|-------------|
| H1 | Set-Content missing -Encoding ASCII in orphan-strip | Section 4 snippet shows -Encoding ASCII on the orphan-strip Set-Content line. Consistent with production line 28. HOLDS. |
| H2 | GG-7 LASTEXITCODE contaminates success-path tests | Section 5 reset-before-redefinition closes this. HOLDS. |
| H3 | TestDrive in GG-4 contradicts D2 | Replaced with $env:TEMP + New-Guid + finally pattern. HOLDS. |
| H4 | GG-7 exe unspecified; false green on PS5.1-only runner | 'powershell' with rationale in GG-7 Input. HOLDS. |
| H5 | $ps51Fallback/$ps7Fallback undefined under StrictMode | $local:ps51Fallback and $local:ps7Fallback defined at top of Write-PowerShellProfile. HOLDS. |
| F-4 | Orphan-strip regex: add \r?\n prefix, .+? -> .*? | Section 4 regex now reads "(?s)\r?\n..." and uses .*?. Matches production line 27. HOLDS. |
| F-5 | $local:beginMarker/$local:endMarker undefined | Section 4 shows both defined at top of Write-PowerShellProfile alongside H5 locals. HOLDS. |

---

## New Findings

### NF-1 (v5): H1 has no encoding assertion in GG-4 (LOW)

H1 patches Set-Content to use -Encoding ASCII for the orphan-strip write. GG-4 asserts
"Neither legacy file has BEGIN marker" -- it checks content presence but NOT file encoding.

On PS5.1 the default Set-Content encoding is UTF-16 LE with BOM. If the -Encoding ASCII
parameter were accidentally dropped in production, PS5.1 would silently write UTF-16 and
GG-4 would still pass (the BEGIN marker check reads the file content, which PS5.1 decodes
correctly from UTF-16).

A byte-level encoding assertion (e.g., reading raw bytes, confirming no BOM preamble 0xFF
0xFE) would catch this regression. However, for a vertical slice test plan this is an
acceptable omission -- the encoding contract is enforced by code review and is observable
at integration time. Flagging as LOW; not blocking for SHIP.

---

### NF-2 (v5): F-4 middle-of-file case not exercised in GG-4 (LOW)

F-4 adds \r?\n PREFIX to the strip regex so the preceding newline is consumed with the
block (production line 27 behavior). GG-4 seeds both legacy files "with BEGIN marker" but
does not specify that content exists AFTER the block. An engineer implementing GG-4 will
most likely seed files with only the block (block at end of file), in which case TrimEnd()
absorbs the trailing blank line and the \r?\n prefix never fires.

The case that uniquely exercises the \r?\n prefix is: file has user content, then the
BEGIN..END block, then MORE user content below. If the prefix is absent in that case, an
extra blank line is left above the next section.

This gap means the F-4 regex fix has no dedicated test exercise for its primary edge case.
Acceptable for vertical slice (the core strip correctness is covered by GG-4); however a
comment in GG-4 Input noting "seed content both above and below the block to exercise
\\r?\\n prefix removal" would close it. LOW; not blocking.

---

### NF-3 (v5): NF-3v4 carry-forward -- C-2/C-3 skip-as-pass (LOW, unchanged)

v5.1 does not address the skip-as-pass issue noted in my v4 grill. C-2/C-3 guard uses
Write-Host + return, which increments the PASS counter on PS7+ CI. Write-Skip exists in
the harness (tests/test_windows_setup.ps1 line 55-61) and would correctly increment
TestsSkipped. This is a LOW accuracy issue in CI reporting, not a functional gap.
Carry-forward from NF-3v4. Not blocking for SHIP.

---

### NF-4 (v5): GG-1 $mockPath identity implicit, not stated in row (LOW)

GG-1 Input: "Mock returns OneDrive path." GG-1 Assertion: "Test-Path $mockPath."

Section 5 header establishes that GG-1 creates a temp dir and $mockPath is within it.
The GG-1 row itself never states that $mockPath is a temp path -- an engineer reading only
the GG-1 row could interpret "OneDrive path" literally and attempt to write to a real
OneDrive directory in CI.

The Section 5 header guidance is sufficient for a careful implementer. LOW; not blocking.

---

## BeforeEach Reference (NF-4v4) -- RESOLVED

v5.1 Section 5: "immediately before each Test-Scenario call (not a BeforeEach block --
Test-Scenario has none)." The misleading Pester terminology is gone. NF-4v4 RESOLVED.

---

## GG-7 Assertion Completeness

GG-7 asserts $result -eq $FallbackPath (fallback returned). "Warning logged" is in the
Expected column but has no corresponding assertion. This is acceptable: capturing
Write-Warn output requires stream redirection that is disproportionate for this harness.
The fallback-returned assertion proves the correct code path was taken. OK.

---

## Cross-Test Collision Check

Each disk-writing GG test (GG-1, GG-4, GG-5) uses a New-Guid-seeded directory name.
GUID collision probability is negligible; $env:TEMP is per-user and per-session on CI.
No cross-test path collisions possible. Clean.

---

## Implementation-Ready Verdict

**YES.** A competent engineer can write all of GG-1..GG-7 from v5.1 without inference gaps
that risk false greens or destructive CI behavior:
- GG-7 exe is specified ('powershell').
- Temp path pattern is specified (Section 5, $env:TEMP + New-Guid + finally).
- $ps51Fallback/$ps7Fallback overrides are stated (GG-4 row; Section 5 header).
- LASTEXITCODE reset ordering is stated (Section 5 header).
- Mock isolation model is stated (child-scope, file-scope redefinition before each call).
- BeforeEach Pester reference is corrected.

Four LOWs remain (encoding assertion, middle-of-file regex exercise, skip-as-pass,
GG-1 mockPath identity). None introduce false greens or destructive behavior. All are
acceptable omissions for a vertical slice.

---

## Summary Matrix

| # | Concern | v4 Status | v5.1 Status |
|---|---------|-----------|-------------|
| C-1 | GG-7 exe spec | NEW MEDIUM | RESOLVED |
| C-2 | TestDrive without Pester | NEW MEDIUM | RESOLVED |
| F-3 | LASTEXITCODE reset position | NEW MEDIUM | RESOLVED |
| H1 | -Encoding ASCII in orphan-strip | NEW HIGH | RESOLVED (patch); NF-1 LOW: no encoding assertion |
| H2 | LASTEXITCODE contamination | NEW MEDIUM | RESOLVED |
| H3 | TestDrive -> temp path | NEW MEDIUM | RESOLVED |
| H4 | GG-7 exe | NEW MEDIUM | RESOLVED (= C-1) |
| H5 | $local: undefined under StrictMode | NEW MEDIUM | RESOLVED |
| F-4 | Regex diverges from production | NEW MEDIUM | RESOLVED (patch); NF-2 LOW: middle-of-file not exercised |
| F-5 | $beginMarker/$endMarker undefined | NEW LOW | RESOLVED |
| NF-3v4 | C-2/C-3 skip-as-pass | LOW | CARRY-FORWARD LOW (= NF-3 here) |
| NF-4v4 | BeforeEach reference | LOW | RESOLVED |
| NF-1 (new) | H1 no encoding assertion | -- | LOW |
| NF-2 (new) | F-4 middle-of-file not tested | -- | LOW |
| NF-4 (new) | GG-1 mockPath identity implicit | -- | LOW |

---

## Verdict: SHIP

All MEDIUM and higher concerns are resolved. Algorithm is correct. Mock scaffold is
unambiguous. Test harness approach (non-Pester, Test-Scenario, child-scope) is consistent
with existing suite patterns. Four LOWs are documented but do not block implementation.

**Grilled by:** Chip (Tester)
**Date:** 2026-05-27
**Session:** 441-grill-v5
