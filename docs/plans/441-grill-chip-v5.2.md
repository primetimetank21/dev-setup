# Chip's Grill -- Plan #441 v5.2
**Date:** 2026-05-27
**Reviewer:** Chip (Tester)
**Verdict:** SHIP
**Plan version reviewed:** v5.2 (Mickey revision -- JN-1/JN-2 patch)
**Author locked out:** Goofy, Mickey, Donald, Jiminy (authored prior revisions)

---

## Verdict: SHIP

All MEDIUM+ concerns resolved. JN-1 closed cleanly by parameterization. JN-2 improved
(visibility gap closed; skip counter accuracy is a residual LOW). Four carry-forward LOWs
and one new LOW are documented but do not block implementation or introduce silent
destructive writes.

---

## 1. Parameter Override Pattern Assessment (JN-1)

### Mechanism soundness

`Write-PowerShellProfile` now declares:

    param(
        [string]$Ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', ...),
        [string]$Ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', ...)
    )

These parameters feed:
1. `Resolve-ProfilePath 'powershell' $Ps51Fallback` and `Resolve-ProfilePath 'pwsh' $Ps7Fallback`
   (fallback arg when host query fails)
2. `$legacyPaths = @($Ps51Fallback, $Ps7Fallback)` (orphan-strip targets)

Passing temp paths via `-Ps51Fallback`/`-Ps7Fallback` redirects BOTH the fallback path
returned by `Resolve-ProfilePath` AND the orphan-strip loop targets away from real `$HOME`.
The `$local:` shadowing bug (JN-1) is eliminated. MECHANISM SOUND. [PASS]

### Per-test verification

| Test | Both params present? | Temp path pattern stated? | finally cleanup stated? |
|------|---------------------|--------------------------|------------------------|
| GG-1 | YES -- `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` | Implicit via Section 5 header | Section 5 header |
| GG-4 | YES -- same pattern | EXPLICIT in row: `Join-Path $env:TEMP "gg-test-441-$(New-Guid)"` | Section 5 header |
| GG-5 | YES -- same pattern | Implicit via Section 5 header | Section 5 header |

All three disk-writing tests pass both parameters. [PASS]

### Do tests now DEMONSTRATE the override works?

YES. With parameters operative, `$legacyPaths` in GG-1/GG-4/GG-5 = temp paths (not real
`$HOME`). The orphan-strip loop and fallback-path branches operate on temp dirs. Tests no
longer silently write to real `$HOME` profile files. [PASS]

---

## 2. GG-2/3/6/7 -- Destructive Write Risk

**Risk: NO.** Section 5 header explicitly names the disk-writing tests: "GG tests that write
to disk (GG-1, GG-4, GG-5)". By explicit exclusion, GG-2/3/6/7 are not disk-writing tests.

### Per-test analysis

**GG-2** -- Input: absent exe. Assertion: `$result -eq $FallbackPath`.
  `$result` is a captured return value. `Resolve-ProfilePath` returns a string; it writes
  no files. No disk writes. NO DESTRUCTIVE RISK.

**GG-3** -- Input: mock returns same path, different case. Assertion: `$profilePaths.Count -eq 1`.
  `$profilePaths` is a local var inside `Write-PowerShellProfile`; it is not directly
  accessible from test scope. The assertion pattern is consistent with the engineer
  constructing the dedup array in-line:
    `$profilePaths = @('Path', 'PATH') | Sort-Object { $_.ToLower() } -Unique`
  and asserting `Count -eq 1`. This tests the dedup expression in isolation -- no call to
  `Write-PowerShellProfile`, no disk writes. NO DESTRUCTIVE RISK.
  [LOW-CLARITY: row does not explicitly state "test dedup logic in isolation, not via
  Write-PowerShellProfile." An engineer calling Write-PowerShellProfile without -Ps51Fallback
  / -Ps7Fallback would write to real $HOME fallback paths. The Section 5 "write to disk"
  grouping mitigates but does not close this ambiguity. LOW; not blocking.]

**GG-6** -- Input: mock returns `"banner\n$mockPath"`. Assertion: `$result -eq $mockPath`.
  `$result` is a captured return value from `Resolve-ProfilePath`. No disk writes.
  NO DESTRUCTIVE RISK.

**GG-7** -- Input: mock sets `$LASTEXITCODE = 1`. Assertion: `$result -eq $FallbackPath`.
  `$result` from `Resolve-ProfilePath`. No disk writes. NO DESTRUCTIVE RISK.

---

## 3. JN-2 Status (NF-3v4 carry-forward)

v5.2 change: `Write-Host 'SKIP C-2: ...'` -> `Write-Warning '[SKIPPED] C-2: ...'`

| Sub-concern | Status | Evidence |
|-------------|--------|----------|
| Visible in PS console / CI | RESOLVED | `Write-Warning` writes to warning stream; PS prepends `WARNING:` prefix; always visible |
| "[SKIPPED]" tag grep-able | RESOLVED | Literal `[SKIPPED]` in warning message; grep-able in CI logs |
| Doesn't increment pass count on PS7+ | PARTIAL -- see below | -- |
| D2 (no Pester) preserved | HOLDS | `Write-Warning` has no Pester dependency |

**Skip counter gap (residual LOW):** `Write-Warning` + `return` does NOT call `Write-Skip`
(the harness function on line 55-61 of `test_windows_setup.ps1` that increments
`$TestsSkipped`). On PS7+, C-2/C-3 exit their Test-Scenario block via `return` with no
assertion result. Whether Test-Scenario counts this as a pass depends on harness
implementation (not shown in plan). The concern originally raised in NF-3v4 -- that skips
appear as passes in CI tallies -- is NOT fully resolved by `Write-Warning`. The visibility
gap IS resolved. Residual: skip counter accuracy. LOW; non-blocking.

**Summary:** JN-2 = PARTIAL. Visibility: RESOLVED. Skip counter: OPEN (LOW).

---

## 4. Implementation-Ready Check

### Mock signatures

`Invoke-HostQuery` mock: defined in file scope, returns a string path. Signature is the
same single-parameter function pattern used across the test group. CLEAR. [PASS]

### Test invocation pattern (Pester-free, per D2)

Disk-writing tests (GG-1/4/5): `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7`.
Parameter names match function signature in Section 4. CLEAR. [PASS]

Non-disk tests (GG-2/6/7): `$result = Resolve-ProfilePath -HostExe ... -FallbackPath ...`.
Assertion pattern `$result -eq $FallbackPath` is straightforward. CLEAR. [PASS]

GG-3: Engineer must infer "test dedup in isolation" from assertion syntax. LOW clarity gap
(see Section 2, GG-3 note).

### Cleanup pattern

Section 5 header: `finally` block. Explicit. CLEAR. [PASS]

### LASTEXITCODE reset positioning (F-3 hold)

Section 5 header: "Before each redefinition, reset `$global:LASTEXITCODE = 0`."
"Before redefinition" = before mock redefinition = before Test-Scenario call. Ordering
preserved. F-3 HOLDS. [PASS]

**Implementation-ready: YES.** Minor LOW gaps (GG-3 invocation target, GG-1/4 resolved-path
identity) do not block an engineer from writing correct, non-destructive tests.

---

## 5. Carry-Forward LOWs (from v5.1)

| # | Finding | v5.2 Status |
|---|---------|-------------|
| NF-1 | H1 no encoding assertion in GG-4 | CARRY-FORWARD (unchanged) |
| NF-2 | F-4 middle-of-file case not exercised in GG-4 | CARRY-FORWARD (unchanged) |
| NF-3 / JN-2 | C-2/C-3 skip-as-pass | PARTIAL RESOLUTION (visibility fixed; skip counter open) |
| NF-4 | GG-1 $mockPath identity implicit (resolved path not stated as temp) | CARRY-FORWARD; see NF-4-v5.2 below |

---

## 6. New Finding

### [LOW] NF-4-v5.2 (NF-4 extended): Resolved-path write target not redirected to temp

**Citation:** Section 5, GG-1 Input: "Mock returns OneDrive path"; GG-4 Input: "both
`Invoke-HostQuery` mock calls return the SAME `$oneDrivePath`."

**Root cause:** `-Ps51Fallback`/`-Ps7Fallback` redirect the FALLBACK paths and
`$legacyPaths` (orphan-strip targets) to temp. They do NOT redirect the RESOLVED path
(mock return value). The write loop writes to entries in `$profilePaths`, which are the
paths returned by `Invoke-HostQuery` mock -- i.e., the "OneDrive path" or `$oneDrivePath`
from the mock. If the engineer supplies a real OneDrive path string as the mock return
value, the write loop targets a real profile file.

**Why it stays LOW:**
1. GG-1 asserts `Test-Path $mockPath` -- this only passes if the write succeeded. On CI
   there is no real OneDrive directory; write would fail or `Test-Path` returns false.
   Test failure reveals the issue; it is NOT silent destruction.
2. A competent engineer would return a temp path as the mock's "OneDrive path" to make
   `Test-Path $mockPath` pass on CI. This is the natural implementation.
3. GG-4 asserts "OneDrive file has BEGIN marker" -- same reasoning applies.

**Recommendation:** Add one sentence to GG-1 and GG-4 Input cells: "Mock returns a path
within the temp dir (e.g., `Join-Path $tempDir 'OneDrive\Documents\...\profile.ps1'`) so
the write loop targets temp, not real OneDrive." Closes the ambiguity without blocking
implementation.

---

## 7. Summary Matrix

| # | Concern | v5.1 Status | v5.2 Status |
|---|---------|-------------|-------------|
| JN-1 | $local: prevents test override; GG-1/4/5 write to real $HOME | N/A (introduced by v5) | RESOLVED -- parameterization |
| JN-2 / NF-3 | C-2/C-3 skip-as-pass (Write-Host -> Write-Warning) | OPEN LOW | PARTIAL -- visibility resolved; skip counter open LOW |
| NF-1 | No encoding assertion in GG-4 | LOW | CARRY-FORWARD LOW |
| NF-2 | F-4 middle-of-file regex not exercised | LOW | CARRY-FORWARD LOW |
| NF-4 (extended) | Resolved-path write target not stated as temp in GG-1/4 | LOW (GG-1 only) | CARRY-FORWARD LOW (GG-1 + GG-4) |
| GG-3 clarity | Invocation target ambiguous | N/A | NEW LOW |
| All H-patches | H1-H5, F-4, F-5 regression | ALL HOLD | ALL HOLD |
| F-3 | LASTEXITCODE reset positioning | RESOLVED | HOLDS |

---

**Grilled by:** Chip (Tester)
**Date:** 2026-05-27
**Session:** 441-grill-v5.2
