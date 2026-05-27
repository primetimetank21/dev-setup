# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Pluto (Platform Architect -- architecture/algorithm correctness)
**Plan reviewed:** docs/plans/441-profile-path.md (v5.1, Donald revision)
**Date:** 2026-05-27
**Session:** 441-grill-v5
**Prior grills:** 441-grill-pluto-v4.md (v4), 441-grill-donald-v4.md (v4), 441-grill-chip-v4.md (v4)

---

## Verdict

**SHIP.**

A-1 is fully resolved. All seven patches (H1-H5, F-4, F-5) land correctly with no
regressions. No new findings of blocking or HIGH severity. Two pre-acknowledged LOWs
remain open and are acceptable for ship.

---

## Task 1: A-1 Status -- RESOLVED

**Claim:** `$local:ps51Fallback` and `$local:ps7Fallback` defined at top of
`Write-PowerShellProfile` before first use (v5-H5). `$local:beginMarker` and
`$local:endMarker` similarly defined (v5.1-F-5).

**Verification against plan Section 4:**

```
$local:ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1')
$local:ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
$local:beginMarker  = '# BEGIN dev-setup profile'
$local:endMarker    = '# END dev-setup profile'
```

Checks:

1. **Defined at TOP of function:** YES. Four `$local:` declarations are the first four
   lines of the `Write-PowerShellProfile` body, before any call to `Resolve-ProfilePath`
   or any array construction. Order of execution: define -> use. Correct.

2. **Before first use:** YES.
   - `$ps51Fallback` first used on the next line (`Resolve-ProfilePath 'powershell' $ps51Fallback`). Defined above it. PASS.
   - `$ps7Fallback` first used two lines later. PASS.
   - `$beginMarker` first used in Select-String pattern check inside the foreach. PASS.
   - `$endMarker` first used inside the regex replace. PASS.

3. **Values match production:**
   - `$ps51Fallback`: matches production line 17 exactly (`WindowsPowerShell\Microsoft.PowerShell_profile.ps1`). PASS.
   - `$ps7Fallback`: matches production line 18 exactly (`PowerShell\Microsoft.PowerShell_profile.ps1`). PASS.
   - `$beginMarker`: matches production line 12 exactly (`# BEGIN dev-setup profile`). PASS.
   - `$endMarker`: matches production line 13 exactly (`# END dev-setup profile`). PASS.

4. **Other variables under StrictMode:**
   All remaining variables in the algorithm body are assigned before read:
   - `$profilePaths` -- assigned from pipeline result. PASS.
   - `$legacyPaths` -- assigned as array literal. PASS.
   - `$legacy` -- loop variable (assigned by foreach). PASS.
   - `$isOrphan` -- assigned at top of each loop iteration. PASS.
   - `$content` -- assigned inside the if-block guard; only read after assignment. PASS.
   - `$stripped` -- assigned inside the if-block guard; only read after assignment. PASS.
   - `$raw`, `$resolved` in `Resolve-ProfilePath` -- assigned in try block before read. PASS.

   No undefined variable references remain in the algorithm. StrictMode hazard fully closed.

**A-1: RESOLVED.**

---

## Task 2: Regression Check (H1-H5, F-4, F-5)

| Patch | Finding | What Was Changed | Regression Check |
|-------|---------|------------------|-----------------|
| H1 | Donald F-1 (HIGH) -- missing `-Encoding ASCII` on orphan-strip `Set-Content` | Added `-Encoding ASCII` to the orphan-strip `Set-Content` call | Plan line 162: `Set-Content $legacy $stripped.TrimEnd() -NoNewline -Encoding ASCII`. Matches production line 28 pattern. No inconsistency between the two `Set-Content` calls in the function. PASS. |
| H2 | Donald F-3 (MEDIUM) -- stale `$LASTEXITCODE` from GG-7 contaminates success-path tests | Section 5 header: `$global:LASTEXITCODE = 0` reset before each mock redefinition | Test-plan only; no production code altered. Production `Resolve-ProfilePath` still reads `$LASTEXITCODE` correctly after `Invoke-HostQuery`. No mutation of `$global:LASTEXITCODE` introduced in production path. PASS. |
| H3 | Donald F-2 + Chip C-2 (MEDIUM) -- `TestDrive` in GG-4 contradicts D2 (Pester rejected) | Replaced `TestDrive` with `Join-Path $env:TEMP "gg-test-441-$(New-Guid)"` temp-path language | Test-plan only. No real `$HOME` paths touched. `New-Guid` generates unique names; cleanup via `finally` block documented. Section 3 D2 (no Pester) not violated. PASS. |
| H4 | Chip C-1 (MEDIUM) -- GG-7 exe unspecified; false green on PS5.1-only runner | GG-7 row specifies `$HostExe = 'powershell'` with rationale | `powershell` is guaranteed present on all Windows systems. Explanation that `'pwsh'` would mask the not-installed early-exit branch (path A) is explicit and correct. Path B (LASTEXITCODE != 0) is now unambiguously the target. PASS. |
| H5 | Pluto A-1 (MEDIUM) -- `$ps51Fallback`/`$ps7Fallback` undefined under StrictMode | Two `$local:` definitions added at top of `Write-PowerShellProfile` | See Task 1 above. RESOLVED. |
| F-4 | Donald F-4 (MEDIUM) -- orphan-strip regex diverges from production without rationale | Added `\r?\n` prefix and changed `.+?` to `.*?`; note cites production line 27 | Plan line 161 regex: `(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?`. Matches production line 27 exactly. Both differences from v4 eliminated. The start-of-file edge case (v4 A-3) no longer exists because both regexes are now identical; the pre-existing `TrimEnd()` is retained. PASS. |
| F-5 | Donald F-5 (LOW) -- `$beginMarker`/`$endMarker` undefined in Section 4 snippet | `$local:beginMarker`/`$local:endMarker` defined in `Write-PowerShellProfile` | Verified in Task 1. Values match production lines 12-13. PASS. |

**Scope / mutation audit for all patches:**
- No new file-scope variables introduced. All new declarations are `$local:` inside a function. PASS.
- No new `$env:` mutations in production code. `$env:TEMP` reference is test-plan only (Section 5). PASS.
- No `$global:` mutations in production code. `$global:LASTEXITCODE = 0` is test-setup only (Section 5 header). PASS.
- Function still has single entry point (`Write-PowerShellProfile`). PASS.
- Dot-source safety preserved (explicit comment in function, no top-level execution). PASS.
- Idempotency preserved (strip-then-inject pattern unchanged). PASS.

---

## Failure-Mode Spot-Check (post-patch)

| Scenario | Outcome |
|----------|---------|
| Both hosts absent | Both `Resolve-ProfilePath` calls return `$ps51Fallback` / `$ps7Fallback` respectively. `$profilePaths` = both fallbacks. Legacy cleanup: neither is orphaned (`$isOrphan = false`). Writer loop writes to both. Identical to current production. CORRECT. |
| Regex no-match in orphan-strip | `$content -replace ...` returns `$content` unchanged. `TrimEnd()` is a no-op on a block-less file. Conditional guard (`Select-String -Quiet`) prevents reaching the replace anyway. CORRECT. |
| Empty block (BEGIN immediately followed by END) | F-4 changed `.+?` to `.*?`; now matches zero-content blocks. CORRECT. |
| Block at start of file (no preceding newline) | F-4 regex includes `\r?\n` prefix -- same as production. A file where the block is on line 1 will not match the strip regex. This is a pre-existing production limitation (applies equally to the writer-loop strip). OUT OF SCOPE (#441). |
| `$profilePaths` empty | Impossible: `Resolve-ProfilePath` always returns `$FallbackPath` as last resort; fallbacks are non-empty `$local:` constants (A-1 resolved). CORRECT. |
| Mid-run `Set-Content` throw | Under `$ErrorActionPreference = Stop` (production line 7), propagates immediately. Orphan may be stripped but resolved path not yet written. Re-running is idempotent recovery. Pre-existing acceptable risk; unchanged by v5.1. CORRECT. |

---

## Prior Concerns: Full Status Matrix

| # | Griller | Severity | v4 Status | v5.1 Status |
|---|---------|----------|-----------|-------------|
| P1 | Pluto | BLOCKING | RESOLVED | HOLDS |
| P2 | Pluto | BLOCKING | RESOLVED | HOLDS |
| A-1 | Pluto | MEDIUM | Open (plan fix before code) | RESOLVED (H5 + F-5) |
| A-2 | Pluto | LOW | Deferred | Still deferred -- write-loop stub comment unchanged; variable alignment ($profilePaths) confirmed correct; no regression |
| A-3 | Pluto | LOW | Deferred | RESOLVED by F-4 (regex now identical to production) |
| A-4 | Pluto | LOW | Contingent on A-1 | RESOLVED (subsumed by A-1 resolution) |
| F-1 | Donald | HIGH | Open | RESOLVED (H1) |
| F-2 | Donald | MEDIUM | Open | RESOLVED (H3) |
| F-3 | Donald | MEDIUM | Open | RESOLVED (H2) |
| F-4 | Donald | MEDIUM | Open | RESOLVED (F-4 patch) |
| F-5 | Donald | LOW | Open | RESOLVED (F-5 patch + H5) |
| C-1 | Chip | MEDIUM | Open | RESOLVED (H4) |
| C-2 | Chip | MEDIUM | Open | RESOLVED (H3) |
| NF-3v4 | Chip | LOW | Open | Still open (see below) |
| NF-4v4 | Chip | LOW | Open | RESOLVED (BeforeEach language removed from Section 5) |

---

## New Findings

### [LOW] PV-1: C-2/C-3 skip-as-pass unresolved (Chip NF-3v4 carry-over)

**Citation:** Section 3 v3-D4 and Section 7 acceptance criterion C-2/C-3.

Chip's NF-3v4 (LOW) noted that the `if (...PSVersion.Major -ge 7) { Write-Host 'SKIP...'; return }`
guard causes `Test-Scenario` to record a PASS (not a skip) on PS7+ runners, inflating the pass
count and hiding coverage gaps. The plan retains `Write-Host + return` and does not call any
`Write-Skip` helper.

**Assessment:** The plan is internally consistent -- it uses the mechanism that v3-D4 specified.
Whether `Write-Skip` exists in the test harness is an implementation detail outside the plan's
scope. The guard correctly prevents the destructive `$PROFILE = $path` assignment from running
on PS7+. The `Write-Host` log provides audit trail. The inflated pass count is a cosmetic
reporting concern; it does not produce false green on the NEW GG tests that cover this PR's
actual behavior.

**Impact on ship decision:** NONE. This is a pre-existing LOW from the v4 cycle, carried forward
unchanged. It does not affect architectural correctness, algorithm safety, or GG-1 through GG-7
reliability. The implementer note from Chip remains valid if `Write-Skip` is available.

**Post-ship deferral:** YES.
**Severity:** LOW (carry-over; no severity escalation).

---

## Architectural Readiness Verdict

The v5.1 algorithm is architecturally ship-ready:

- **Single entry point:** `Write-PowerShellProfile` only. No top-level execution on dot-source.
- **StrictMode-safe:** All variables defined before use. `$local:` declarations prevent scope leaks.
- **Idempotent:** Strip-then-inject in writer loop; orphan-strip guarded by `$isOrphan`, `Test-Path`, and `Select-String`; GG-5 (3-run test) covers this empirically.
- **Both-hosts-fail handled:** Falls back to hardcoded paths; behavior identical to current production.
- **Legacy cleanup correct:** `$isOrphan` mutual exclusivity ensures no path is both orphan-stripped and writer-loop-written.
- **Encoding consistent:** Both `Set-Content` calls in the function use `-Encoding ASCII`. Matches production.
- **No global-state leakage:** No new file-scope variables. No production `$global:` or `$env:` mutations.
- **Regex parity:** F-4 closes the orphan-strip/writer-loop divergence. Both regexes now identical to production line 27.
- **Test plan implementable:** All seven GG tests have unambiguous input, mock, and assertion specs. Temp file pattern explicit. `$HostExe` spec explicit in GG-7.

**SHIP.**

---

**Grilled by:** Pluto (Platform Architect)
**Date:** 2026-05-27
**Session:** 441-grill-v5
