# Grill Report: #441 -- v5.2 Verification (JN-1 / JN-2 patch by Mickey)

**Griller:** Jiminy (Quality Auditor)
**Plan reviewed:** docs/plans/441-profile-path.md (v5.2, author: Mickey)
**Date:** 2026-05-27
**Session:** 441-grill-v5.2
**Verdict:** SHIP

---

## Verdict Summary

SHIP. JN-1 is fully resolved: `Write-PowerShellProfile` is parameterized; defaults match
production lines 17-18 exactly; no `$local:` shadowing of the fallback values; GG-1/GG-4/GG-5
all invoke with explicit `-Ps51Fallback`/`-Ps7Fallback` temp paths; v5.2-D1 states the contract.
JN-2 is resolved for C-2; C-3 is implied but not spelled out (LOW gap, non-blocking). Two new
LOW findings documented below. No blocking issues.

---

## JN-1 Verification

### [JN-1-1] param() block contains -Ps51Fallback AND -Ps7Fallback with defaults

- [x] PASS

Section 4 `Write-PowerShellProfile`:

```
param(
    [string]$Ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'),
    [string]$Ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
)
```

Both parameters present with defaults. PASS.

---

### [JN-1-2] Defaults exactly match production lines 17-18

- [x] PASS

Production `profile.ps1`:

```
line 17: [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1')  # PS 5.1
line 18: [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')          # PS 7+
```

`$Ps51Fallback` default = line 17 verbatim. `$Ps7Fallback` default = line 18 verbatim.
Exact match confirmed. PASS.

---

### [JN-1-3] NO $local:ps51Fallback / $local:ps7Fallback redefinition inside function body

- [x] PASS

Section 4 function body has ONLY:

```
$local:beginMarker = '# BEGIN dev-setup profile'
$local:endMarker   = '# END dev-setup profile'
```

No `$local:ps51Fallback` or `$local:ps7Fallback` anywhere in the body.
The v5/H5 `$local:` definitions are gone; params replace them entirely.
No shadow bug. PASS.

---

### [JN-1-4] GG-1, GG-4, GG-5 show explicit named-parameter invocation

- [x] PASS

| Test | Invocation in Section 5 |
|------|------------------------|
| GG-1 | `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` |
| GG-4 | `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` |
| GG-5 | `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` 3x |

All three disk-writing tests redirect to temp paths via named parameters. PASS.

---

### [JN-1-5] Section 3 v5.2-D1 explains the parameter contract

- [x] PASS

Section 3 v5.2-D1 (verbatim):

> `Write-PowerShellProfile` accepts optional `-Ps51Fallback`/`-Ps7Fallback` parameters.
> Defaults equal production lines 17-18. Production: call with no arguments (defaults apply;
> zero callsite changes). Tests: pass explicit temp-dir paths to redirect all disk writes
> away from real `$HOME` profile files. `$beginMarker`/`$endMarker` require no test override
> and remain `$local:` constants inside the function.

Contract is stated. PASS.

---

### [JN-1-6] v5/H5 supersession documented

- [x] PASS (with minor cosmetic gap -- see NF-J3)

The v5.2 changelog table JN-1 row documents the patch. Section 4 algorithm shows only the
parameterized form; `$local:ps51Fallback`/`$local:ps7Fallback` are absent from the current
algorithm. The Section 4 comment `# v5.2-JN-1: optional params allow test override; defaults
mirror production lines 17-18` confirms intent.

Minor: the v5 changelog H5 entry still reads "Two `$local:` definitions added" without an
explicit "superseded by v5.2/JN-1" annotation. Cosmetic only -- see NF-J3 below.

Functional supersession is complete. PASS.

---

## JN-2 Verification

### [JN-2-1] Write-Warning '[SKIPPED] ...' used in BOTH C-2 and C-3

- [ ] PARTIAL (C-2 explicit; C-3 inferred only)

v3-D4 (updated for v5.2) explicitly shows:

```
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Warning '[SKIPPED] C-2: PS7+ -- $PROFILE conceptually read-only; covered by GG tests'
    return
}
```

C-3 is mentioned by name in "Guard C-2 and C-3 with proper skip" and in Section 7 AC#6
("C-2 and C-3 guarded against PS7+ assignment error"), but no explicit
`Write-Warning '[SKIPPED] C-3: ...'` example appears in the plan. Implementer must infer C-3
from C-2 pattern. Low risk (pattern established); flagged as NF-J4 below.

---

### [JN-2-2] Message includes [SKIPPED] prefix so it is grep-able

- [x] PASS

v3-D4 explicit text: `'[SKIPPED] C-2: PS7+ -- $PROFILE conceptually read-only; covered by GG tests'`

`[SKIPPED]` prefix present. PASS.

---

### [JN-2-3] D2 (no Pester) preserved

- [x] PASS

Section 3 D2 unchanged: "Use the existing `Test-Scenario` harness with the `Invoke-HostQuery`
mock pattern. `$PROFILE` is read-only in PS 7+ and `$TestDrive` is Pester-specific. Adding
Pester is scope creep." No Pester dependency introduced. PASS.

---

## Holistic Check

### StrictMode satisfied

PASS. Parameters declared in `param()` are auto-defined on function entry regardless of
whether the caller passes arguments. Defaults initialize `$Ps51Fallback` and `$Ps7Fallback`
on every call. `$local:beginMarker`/`$local:endMarker` are defined immediately in the body.
No variable referenced before assignment under `Set-StrictMode -Version Latest`. PASS.

### No new shadow / scope bugs introduced

PASS. The only `$local:` bindings remaining in `Write-PowerShellProfile` are `$beginMarker`
and `$endMarker`. These are explicitly NOT expected to be test-overridable (v5.2-D1 states
so). No other function-local shadows observed. The outer functions (`Invoke-HostQuery`,
`Resolve-ProfilePath`) are unchanged. PASS.

### Vertical slice intact

PASS. 7 GG tests (GG-1..GG-7), no extras. 9+1 decisions (D1-D4, v3-D1..v3-D5, v5.2-D1).
No new architecture layers, no new configuration knobs. Section 3 v5.2-D1 is the only
addition -- scoped correctly to document the JN-1 fix contract. PASS.

### Production callsite impact

PASS. `Write-PowerShellProfile` is called with no arguments in production (Section 4 comment
confirms zero callsite changes). Defaults mirror lines 17-18. Behavior on KFM/OneDrive systems
is unchanged. PASS.

---

## New Findings

### [LOW] NF-J3: H5 entry in v5 changelog now historically misleading

**Citation:** docs/plans/441-profile-path.md, v5 Changes table, H5 row:
"Two `$local:` definitions added at top of `Write-PowerShellProfile` in Section 4"

**Issue:** This entry has no "superseded by v5.2/JN-1" annotation. A reader scanning the
changelog table top-to-bottom (v5 before v5.2) could believe `$local:ps51Fallback`/
`$local:ps7Fallback` are still in the function body. The current Section 4 algorithm is
correct (they are absent); the risk is reader confusion only.

**Impact:** Documentation cosmetic. No implementation risk.
**Recommendation:** Add "(superseded by v5.2/JN-1)" note to H5 entry in a future pass.
**Blocking:** NO.

---

### [LOW] NF-J4: C-3 skip not explicitly specified

**Citation:** Section 3 v3-D4; v5.2 changelog JN-2 row; Section 7 AC#6.

**Issue:** v3-D4 and the JN-2 changelog entry only show the C-2 `Write-Warning` example
explicitly. C-3 appears in "Guard C-2 and C-3" prose and in AC#6 but has no corresponding
`Write-Warning '[SKIPPED] C-3: ...'` example in the plan.

**Risk:** Implementer could ship C-3 without a `[SKIPPED]`-prefixed warning, or omit the
PS7+ guard entirely for C-3. AC#6 provides a backstop but is an acceptance criterion, not
a specification.

**Recommendation:** Add one line to v3-D4: `Write-Warning '[SKIPPED] C-3: ...'` mirroring
the C-2 example.
**Blocking:** NO.

---

## Convergence Table (v5.2 scope)

| Finding | Sev | Status in v5.2 |
|---------|-----|----------------|
| JN-1: $local: shadow makes test override inoperable | MEDIUM | RESOLVED |
| JN-2: Write-Host skip increments pass not skip | LOW | RESOLVED (C-2); C-3 inferred (NF-J4) |
| NF-J3: H5 entry no supersession note | LOW | NEW (cosmetic) |
| NF-J4: C-3 skip not explicit | LOW | NEW (non-blocking) |

---

**Grilled by:** Jiminy (Quality Auditor)
**Date:** 2026-05-27
**Session:** 441-grill-v5.2
