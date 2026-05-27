# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Pluto (Platform Architect -- architecture/algorithm correctness)
**Plan reviewed:** docs/plans/441-profile-path.md (v4, Jiminy revision)
**Date:** 2026-05-27
**Verdict:** SHIP

**Grilling against:** docs/plans/441-grill-pluto.md (own v3 grill)
**Cross-reference:** docs/plans/441-grill-chip-v3.md

---

## v3 Blocking Concern Regression Check

### P1 / Finding 5 (empty foreach loop stub) -- RESOLVED

v3 defect: the legacy cleanup loop body contained only the placeholder comment
`# Strip block from orphaned legacy file`. GG-4 asserted both legacy files
stripped, but Section 4 had no stripping code -- a plan-internal contradiction.

v4 fix (Jiminy P1): loop body now contains explicit, executable implementation:

    $content = Get-Content $legacy -Raw
    $stripped = $content -replace "(?s)$([regex]::Escape($beginMarker)).+?$([regex]::Escape($endMarker))\r?\n?", ''
    Set-Content $legacy $stripped.TrimEnd() -NoNewline
    Write-Info "Stripped orphaned block from legacy path: $legacy"

Real code, not a stub. GG-4 assertion is directly implementable from the plan.
Status: RESOLVED.

---

### P2 / Finding 6 (scope ambiguity -- top-level vs. function) -- RESOLVED

v3 defect: Section 4 pseudocode showed $profilePaths and the foreach loop as bare
top-level statements. If placed at file scope, dot-sourcing profile.ps1 runs the
resolution immediately -- before any test mock is defined. All GG tests would call
the real Invoke-HostQuery rather than the mock. GG-1 through GG-7 would silently
test the wrong thing.

v4 fix (Jiminy P2): Section 4 wraps the entire algorithm in
`function Write-PowerShellProfile { }`. An explicit comment block states:

    # ALL path-resolution and write logic lives inside this function.
    # Dot-sourcing profile.ps1 only defines the three functions above; it does NOT
    # execute resolution or writes. Tests can define mock Invoke-HostQuery AFTER
    # dot-sourcing and BEFORE calling Write-PowerShellProfile.

The comment is unambiguous. Dot-source safety guarantee is explicit and architecturally
correct. Production profile.ps1 line 11 confirms this is the pre-existing pattern.
Status: RESOLVED.

---

## New Architectural Findings

### [MEDIUM] A-1: $ps51Fallback and $ps7Fallback referenced without definition in scope

plan:Section 4, Write-PowerShellProfile body:

    $profilePaths = @(
        (Resolve-ProfilePath 'powershell' $ps51Fallback),
        (Resolve-ProfilePath 'pwsh' $ps7Fallback)
    ) | Sort-Object { $_.ToLower() } -Unique

    $legacyPaths = @($ps51Fallback, $ps7Fallback)

Neither $ps51Fallback nor $ps7Fallback is:
  (a) a parameter of Write-PowerShellProfile
  (b) defined as a local variable in the function body shown in Section 4
  (c) defined at file scope anywhere in Section 4

Production profile.ps1 defines equivalent hardcoded paths INSIDE Write-PowerShellProfile
at lines 17-19 (they are the $profilePaths array itself). v4 needs two separate fallback
constants. Under Set-StrictMode -Version Latest (active, production line 6), referencing
an undefined variable throws VariableIsUndefined immediately at runtime.

The plan must specify WHERE these constants are defined. Three valid options:
  (A) Define at top of Write-PowerShellProfile as local constants -- consistent with
      the production pattern (lines 12-19), no file-scope pollution.
  (B) Add as parameters with default values.
  (C) Define at file scope before the three function definitions.

Option A is architecturally consistent with the existing file. This is not a
show-stopper -- any StrictMode-aware implementer will catch it -- but the plan has
a gap that directly causes a runtime error if missed.

Post-#441 deferral: NO. Must be addressed before coding starts.
Severity: MEDIUM.

---

### [LOW] A-2: Write loop shown as comment stub -- variable alignment unconfirmed

plan:Section 4, end of Write-PowerShellProfile:

    # Write to each resolved path (existing strip+re-inject logic)

This comment defers to production code at profile.ps1 lines 262-309, which runs
`foreach ($profilePath in $profilePaths)`. The new algorithm also names the resolved
array $profilePaths. Names align; the existing writer loop should operate correctly
on the dynamically resolved array. However, the plan does not explicitly confirm this.

Interaction check (performed here as review):
  - Legacy cleanup fires only for paths NOT in $profilePaths ($isOrphan = true).
  - Writer loop fires only for paths IN $profilePaths.
  - Mutual exclusivity is structurally enforced by the $isOrphan guard.
  - No double-strip path exists; no conflict with production lines 22-29.

One sentence confirming the variable-name alignment and the mutual-exclusivity
guarantee would close this. As-is, an implementer must infer the integration.

Post-#441 deferral: YES. Implementation note only.
Severity: LOW.

---

### [LOW] A-3: Regex divergence between legacy cleanup and writer-loop strip

Legacy cleanup (Section 4):
    $content -replace "(?s)$([regex]::Escape($beginMarker)).+?$([regex]::Escape($endMarker))\r?\n?", ''

Production writer-loop strip (profile.ps1 line 27):
    $raw -replace "(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?", ''

Two differences:

1. Production includes `\r?\n` prefix before $beginMarker; legacy cleanup omits it.
   Effect: production consumes the newline that precedes BEGIN, leaving no blank line
   at the strip site. Legacy cleanup does not -- a blank line may remain if other
   content exists after the END marker in the legacy file (e.g., user's own aliases
   appended below the dev-setup block).

2. Production uses `.*?` (zero or more chars); legacy cleanup uses `.+?` (one or more).
   Practical effect: negligible for normal blocks. A hypothetical corrupted empty block
   (BEGIN followed immediately by END) is stripped by production but not by legacy cleanup.

The missing `\r?\n` prefix is the more material gap. Legacy profiles often have
user content below the dev-setup block; the orphaned blank line is cosmetically wrong.
TrimEnd() in the legacy cleanup Set-Content call partially mitigates this only when
the block is at the end of the file.

Post-#441 deferral: YES. Functional result is correct in all non-edge cases.
Severity: LOW.

---

### [LOW] A-4: Empty $profilePaths guard absent -- contingent on A-1

plan:Section 4 algorithm uses Resolve-ProfilePath which always returns $FallbackPath
as its last resort. If $ps51Fallback and $ps7Fallback are non-empty (A-1 resolved),
$profilePaths will always contain at least one entry. No empty-array guard is needed
once A-1 is addressed.

If A-1 is NOT resolved (undefined variables, StrictMode throw), the function aborts
before reaching the Sort-Object line. This finding is subsumed by A-1.

Post-#441 deferral: YES. Contingent on A-1.
Severity: LOW.

---

## Composability and Failure-Mode Analysis

### Idempotency

GG-5 (3 runs, one block) covers this. Algorithm decomposition:
  1. Resolve paths: deterministic given same environment (same hosts installed).
  2. Legacy cleanup: idempotent -- Test-Path + Select-String guards; no file touched
     unless it exists AND contains the marker.
  3. Writer loop: strips then injects -- existing production pattern (lines 22-29).
     Strip-then-inject is idempotent by construction.

Structural guarantee: on repeated runs against a correctly-written profile, the strip
finds the existing block, removes it, and re-injects. Net result: one block. Correct.

### Both Hosts Fail

Both Resolve-ProfilePath calls fall back to $ps51Fallback and $ps7Fallback respectively.
$profilePaths = @($ps51Fallback, $ps7Fallback) | Sort-Object -Unique (two distinct paths;
WindowsPowerShell vs. PowerShell subdir -- they are never equal under standard PS).
Legacy cleanup: neither path is orphaned (both are in $profilePaths, $isOrphan = false).
Writer loop: writes to both paths. Behavior identical to current production.
Correct.

### Null / Empty Paths (contingent on A-1)

Resolve-ProfilePath always returns $FallbackPath as last resort. If $ps51Fallback /
$ps7Fallback are properly defined (A-1 resolved), no null/empty path can reach the
writer loop. No additional guard is architecturally needed.

### Mid-Run Throw

Under ErrorActionPreference = Stop (production line 7), a Set-Content failure propagates
immediately. Partial-write window: legacy orphan may have been stripped but resolved path
not yet written, leaving the user with no dev-setup block anywhere. Re-running setup
(idempotent) recovers. The window is narrow and self-healing. Acceptable for #441 scope.

### Interaction with Production Lines 250-307 Writer Logic

The existing writer loop (lines 262-309) iterates over $profilePaths. In v4,
$profilePaths is dynamically resolved rather than hardcoded -- but the loop code is
unchanged. Variable name matches. Legacy cleanup and writer-loop strip are mutually
exclusive by the $isOrphan guard. No conflict, no duplication.

---

## API Surface

function Write-PowerShellProfile:
  Parameters:   none (fire-and-forget side-effectful function -- consistent with
                production pattern and correct for this use case)
  Return value: none documented (void)
  Side effects: file writes to resolved PS profile paths; log output via
                Write-Info / Write-Warn / Write-Err
  Implicit dependencies (undocumented in plan):
    - $ps51Fallback, $ps7Fallback (see A-1 -- must be defined before use)
    - Write-Info, Write-Warn, Write-Err (dot-sourced from logging.ps1, production line 9)
    - Invoke-HostQuery (file-scope mockability seam -- correct architectural choice)

The zero-parameter API is appropriate for the #441 vertical slice. A future refactor
requiring path injection can add parameters without breaking callers. No change needed.

---

## Drift Analysis: v3 -> v4

Jiminy's patches are surgical and architecturally non-regressive.

  P1 (foreach body): fills the stub with self-contained inline code. Consistent with
     Option A identified in Pluto's v3 grill as most compatible with D3 self-containment.
     Uses the same Set-Content -NoNewline -TrimEnd() pattern as the writer loop.
     Minor regex inconsistency noted in A-3 -- not introduced by Jiminy; the v3 plan
     silently implied the same gap, and v4 does not make it worse.

  P2 (function wrapper): adds the Write-PowerShellProfile boundary and explicit dot-source
     safety comment. Consistent with production file structure. No new top-level code
     introduced. No global-state leakage.

  P3-P7 (Chip's items): test-plan changes outside Pluto's lens.

Error handling style: Invoke-HostQuery and Resolve-ProfilePath continue to use
$LASTEXITCODE for external-process failures and try/catch for PS exceptions. Consistent
between both functions. No style mixing introduced by v4.

---

## Summary Matrix

| # | Concern | v3 Status | v4 Status |
|---|---------|-----------|-----------|
| P1 | foreach stub empty | BLOCKING | RESOLVED |
| P2 | scope ambiguity | BLOCKING | RESOLVED |
| A-1 | $ps51Fallback/$ps7Fallback undefined in fn | new | MEDIUM -- plan fix before code |
| A-2 | write-loop comment stub, alignment unconfirmed | new | LOW -- impl note |
| A-3 | regex divergence legacy cleanup vs writer loop | new | LOW -- impl note |
| A-4 | empty $profilePaths guard | new | LOW -- contingent on A-1 |

---

## Verdict

SHIP.

Both v3 blocking concerns are genuinely resolved. The explicit function-boundary wrapper
with dot-source safety comment closes the scope ambiguity hole completely. The foreach
body contains real, executable strip code that directly satisfies GG-4's dual-orphan
assertion.

Finding A-1 ($ps51Fallback/$ps7Fallback undefined) is the only concern of meaningful
severity. It is a plan documentation gap, not an algorithmic error. The natural
resolution -- define both constants as local variables at the top of Write-PowerShellProfile
(matching production lines 12-19) -- requires one or two lines of implementation code.
A StrictMode-aware implementer will encounter this immediately. The plan should carry an
implementation note, but it does not invalidate the architecture.

The algorithm is architecturally sound:
  - One clear entry point (Write-PowerShellProfile)
  - Dot-source safe (no top-level execution)
  - Idempotent (strip-then-inject pattern)
  - Correct dual-host failure fallback
  - Mutually exclusive cleanup paths (no double-strip)
  - Clean mockability seam (Invoke-HostQuery at file scope)
  - No global-state leakage
  - No interaction conflict with existing writer loop

SHIP with implementation note: define $ps51Fallback and $ps7Fallback at the top of
Write-PowerShellProfile before the Resolve-ProfilePath calls (consistent with production
lines 17-19).
