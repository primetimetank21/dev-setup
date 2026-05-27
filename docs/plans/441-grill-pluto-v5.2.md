# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Pluto (Platform Architect -- architecture/algorithm correctness)
**Plan reviewed:** docs/plans/441-profile-path.md (v5.2, Mickey revision)
**Date:** 2026-05-27
**Session:** 441-grill-v5.2
**Prior grills:** 441-grill-pluto-v4.md (v4), 441-grill-pluto-v5.md (v5.1 -- I shipped SHIP; missed JN-1)

---

## Verdict

**SHIP.**

JN-1 is fully resolved. Parameter design is sound, backward-compatible, and scope-leak free.
No HIGH or MEDIUM findings. Two INFO-level observations, neither blocking.

I shipped SHIP on v5.1 and missed JN-1 -- the $local: shadow that made test overrides inoperable.
Mickey's param solution is cleaner than Option A in Jiminy's JN-1 writeup: no intermediate
$local: reassignment layer, params are used directly throughout the function body. I missed the
plan-internal contradiction between H5 and H3. I am not re-litigating that; I am verifying the
fix is correct.

---

## 1. Parameter Design Assessment

### 1a. Names and types

| Param           | Type     | Name valid? | PS convention? |
|-----------------|----------|-------------|----------------|
| `-Ps51Fallback` | `[string]` | YES         | ACCEPTABLE (see PV-2) |
| `-Ps7Fallback`  | `[string]` | YES         | ACCEPTABLE (see PV-2) |

Both are valid PowerShell parameter names. `[string]` is the correct type for file path
arguments that will be consumed by `Test-Path`, `Get-Content`, `Set-Content`, and
`Select-String` -- all of which accept `[string]` natively.

### 1b. Defaults: constants vs evaluated expressions

Both defaults use `[System.IO.Path]::Combine($HOME, ...)` -- the same expression form as
production lines 17-18. These are evaluated expressions, not compile-time constants. In
PowerShell, parameter default expressions are evaluated at invocation time in the calling
scope. `$HOME` is an automatic variable set by PowerShell from the OS environment; it is
always defined, even under `Set-StrictMode -Version Latest`. No scenario in the plan scope
(Section 2 OUT list excludes UNC/CLM/long-path edge cases) can produce a null `$HOME`.

Production lines 17-18 use the SAME expression form inside the function body -- the defaults
are not more or less safe than the production literals were. Match confirmed. PASS.

### 1c. Parameter validation

No `[ValidateNotNullOrEmpty()]` or `[ValidateScript()]` applied. Assessment:

- `[ValidateNotNullOrEmpty()]` would reject an explicit empty-string call. The production
  caller never passes empty strings; tests pass valid temp paths. Adding it is defensive but
  not necessary for correctness. The plan explicitly defers input-sanitation edge cases
  (Section 2 OUT). Not scope creep to add; not a defect to omit. PASS as-is.
- `[ValidateScript()]` for path format would duplicate the `'^[A-Za-z]:\\'` check that
  already lives inside `Resolve-ProfilePath`. Redundancy without benefit. PASS as-is.

### 1d. Markers: $beginMarker / $endMarker

`$local:beginMarker` and `$local:endMarker` remain `$local:` constants inside the function
body (v5.1-F5). These require no test override -- tests control where files are written, not
what markers they contain. There is no calling-scope variable named `$beginMarker` or
`$endMarker` in the test harness. No shadowing conflict in either direction. Under
`Set-StrictMode -Version Latest`, declaring `$local:beginMarker = '...'` and then reading
`$beginMarker` (without qualifier) resolves correctly to the local binding -- StrictMode
only fires on reads of unassigned variables, not on unqualified reads of locally-assigned
ones. PASS.

---

## 2. Function Signature Stability

### 2a. Production callsite impact

The new params are optional with defaults. Any existing caller that invokes
`Write-PowerShellProfile` with no arguments continues to receive the same default path
values as production lines 17-18. Zero callsite changes required. v5.2-D1 confirms this.
PASS.

### 2b. Single entry point / global state

- Function has one entry point. No top-level execution on dot-source (comment preserved
  in Section 4 algorithm). PASS.
- No `$global:` or `$env:` mutations introduced in production code. `$global:LASTEXITCODE`
  reset is test-setup only (Section 5 header). PASS.
- No new file-scope variables. All declarations are parameter-bound or `$local:` inside the
  function. PASS.

---

## 3. Scope Leak Regression

Full variable audit of `Write-PowerShellProfile` under `Set-StrictMode -Version Latest`:

| Variable          | How bound                         | Defined before read? | Safe? |
|-------------------|-----------------------------------|----------------------|-------|
| `$Ps51Fallback`   | param (default evaluated at call) | YES -- param         | PASS  |
| `$Ps7Fallback`    | param (default evaluated at call) | YES -- param         | PASS  |
| `$beginMarker`    | `$local:` def at top of body      | YES                  | PASS  |
| `$endMarker`      | `$local:` def at top of body      | YES                  | PASS  |
| `$profilePaths`   | assigned from pipeline result     | YES                  | PASS  |
| `$legacyPaths`    | assigned as array literal         | YES                  | PASS  |
| `$legacy`         | foreach loop variable             | YES (by foreach)     | PASS  |
| `$isOrphan`       | assigned top of each iteration    | YES                  | PASS  |
| `$content`        | assigned inside if-guard          | YES (guarded)        | PASS  |
| `$stripped`       | assigned inside if-guard          | YES (guarded)        | PASS  |

`Resolve-ProfilePath` variables (`$HostExe`, `$FallbackPath`, `$raw`, `$resolved`) are
unchanged from v5.1 -- all verified in my prior grill. No regressions.

**No variable is referenced without prior assignment. StrictMode hazard is fully closed. No
new global-var mutations introduced.**

---

## 4. Idempotency / Failure Mode Check

| Scenario | Outcome | Status |
|----------|---------|--------|
| Both hosts absent | Both `Resolve-ProfilePath` calls return `$Ps51Fallback`/`$Ps7Fallback` (param defaults = production paths). Neither is orphaned. Writer loop writes to both. Behavior identical to current production. | PASS |
| One host absent | That host's `Resolve-ProfilePath` returns its param fallback. Dedup may or may not collapse to 1 path. Write loop handles both entries correctly. | PASS |
| Both hosts fail ($LASTEXITCODE != 0) | Same as both-absent: both fall back to param defaults. | PASS |
| Empty profilePaths | Impossible: `Resolve-ProfilePath` always returns `$FallbackPath`; params are non-empty strings (enforced by defaults). | PASS |
| Regex no-match in orphan-strip | Replace returns `$content` unchanged; `TrimEnd()` is no-op; `Select-String -Quiet` guard prevents reaching replace for block-less files. | PASS |
| Re-callable (idempotency) | Strip-then-inject pattern unchanged; GG-5 (3-run test) exercises this via temp paths. | PASS |
| Mid-run Set-Content throw | Under `$ErrorActionPreference = Stop` (production line 7), propagates immediately. Re-run is safe recovery. Pre-existing risk, unchanged by v5.2. | PASS |
| Test temp-path isolation | GG-1/GG-4/GG-5 pass explicit temp paths via `-Ps51Fallback`/`-Ps7Fallback`. Real `$HOME` paths are never touched during test execution. JN-1 fix confirmed effective. | PASS |

---

## 5. New Findings

### [INFO] PV-2: `Ps51`/`Ps7` casing is non-idiomatic for PS acronyms

**Citation:** Section 4 param block.

PowerShell style conventions (PascalCase) treat acronyms of 3+ chars as PascalCase
(`Xml`, `Http`) and 2-char acronyms as all-caps (`PS`, `IO`). Idiomatic names would be
`-PS51Fallback`/`-PS7Fallback`. Mickey used `Ps51`/`Ps7` (lowercase `s`). This is
functionally harmless -- PowerShell parameter binding is case-insensitive; `-ps51fallback`
and `-PS51FALLBACK` both bind correctly. Internal consistency across plan/decision/test rows
is maintained. No implementer confusion risk.

**Impact on ship decision:** NONE.
**Severity:** INFO. Cosmetic only. Do not revise for this alone.

### [INFO] PV-3: GG-5 mock setup unspecified

**Citation:** Section 5, GG-5 row.

GG-5 specifies "Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7
3x same temp file" but does not specify what `Invoke-HostQuery` mock should return. For the
write to target `$tempPath51`/`$tempPath7`, the mock must either (a) return those paths, or
(b) return invalid/empty output so `Resolve-ProfilePath` falls back to the params. Both
scenarios produce the same result: write lands in the temp files, idempotency holds. A
competent implementer infers this without ambiguity. Pre-existing accepted gap (Pluto A-2
pattern). Not a new hole.

**Impact on ship decision:** NONE.
**Severity:** INFO. No revision needed.

---

## 6. Prior Findings: Full Status Matrix (v5.2)

| # | Griller | Sev | v5.1 Status | v5.2 Status |
|---|---------|-----|-------------|-------------|
| P1 | Pluto | BLOCKING | RESOLVED | HOLDS |
| P2 | Pluto | BLOCKING | RESOLVED | HOLDS |
| A-1 | Pluto | MEDIUM | RESOLVED (H5) | HOLDS -- but H5 introduced JN-1 |
| A-2 | Pluto | LOW | Deferred | Still deferred (write-loop stub); no regression |
| A-3 | Pluto | LOW | RESOLVED (F-4) | HOLDS |
| A-4 | Pluto | LOW | RESOLVED (subsumed) | HOLDS |
| H1-H5 | Donald | HIGH/MED | RESOLVED | HOLDS |
| F-4/F-5 | Donald | MED/LOW | RESOLVED | HOLDS |
| C-1/C-2 | Chip | MEDIUM | RESOLVED | HOLDS |
| NF-3v4 | Chip | LOW | OPEN (PV-1) | RESOLVED (JN-2: Write-Warning applied) |
| NF-4v4 | Chip | LOW | RESOLVED | HOLDS |
| JN-1 | Jiminy | MEDIUM | OPEN (introduced by H5) | **RESOLVED (v5.2 params)** |
| JN-2 | Jiminy | LOW | OPEN | **RESOLVED (Write-Warning applied)** |
| PV-1 | Pluto | LOW | OPEN (carry-over) | RESOLVED via JN-2 |
| PV-2 | Pluto | INFO | N/A | NEW (see above; non-blocking) |
| PV-3 | Pluto | INFO | N/A | NEW (see above; non-blocking) |

All BLOCKING, HIGH, and MEDIUM items resolved. No open items above INFO severity.

---

## Architectural Readiness Verdict

v5.2 is architecturally ship-ready:

- **JN-1 fix correct:** Parameterizing fallback paths is the right pattern. Parameters are
  bound before any function body code executes -- StrictMode-safe, no shadow risk, no scope
  pollution. Cleaner than Jiminy's Option A (no intermediate $local: reassignment needed).
- **Backward-compatible:** Zero-arg production call unchanged; defaults guarantee same
  behavior as lines 17-18.
- **Scope-leak free:** All 10 function-body variables confirmed defined before read.
- **Test isolation correct:** Real $HOME files unreachable during test execution.
- **Idempotency preserved:** Strip-then-inject pattern unchanged; all failure-mode paths
  handled.

**SHIP.**

---

**Grilled by:** Pluto (Platform Architect)
**Date:** 2026-05-27
**Session:** 441-grill-v5.2
