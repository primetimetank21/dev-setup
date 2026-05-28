# Decision: #451 Vertical Slice Plan -- PowerShell Parity Gaps

**Date:** 2026-05-28T02:56:01-04:00  
**Author:** Chip (Tester)  
**Issue:** #451  
**Status:** Ready for Team Grill

---

## Summary

Close three pre-existing parity gaps in `tests/test_sprint_end_labels_pwsh.ps1` (single-file, tests-domain change):

1. **T_C:** Missing `--release-label` alone -- mirrors bash Test C argument validation
2. **T_D:** Bad `--release-label` prefix (e.g., `type:bogus`) -- mirrors bash Test D validation
3. **T7:** CRLF-in-launcher regression test -- validates PR #438 fix (launcher written as LF-only, not CRLF)

Test count increases from 6 (T1-T6) to 9 (T1-T7, T_C, T_D), achieving parity with bash peer test suite (A-G, 7 tests covering same ground).

---

## Scope

**IN:**
- Two missing argument-validation test cases for PowerShell script
- One regression test for CRLF fix (byte-level inspection, no encoding transformation)
- Single file: `tests/test_sprint_end_labels_pwsh.ps1`
- CI: No new jobs, existing `validate.yml` pwsh jobs run expanded suite

**OUT:**
- No script behavior changes
- No helper function additions
- No framework extensions (reuse Test-Scenario, Invoke-ScriptRun, New-TestEnv)

---

## Implementation Plan

**Order:** T_C (quick), T_D (quick), T7 (careful byte-level assertion)

**Fixture approach:**
- T_C / T_D: No setup, direct Invoke-ScriptRun on bare script
- T7: Minimal test state via New-TestEnv (empty issues/prs, copy launcher logic)

**T7 detail:**
- Read launcher file via `[System.IO.File]::ReadAllBytes()` (binary, no encoding transform)
- Assert no 0x0D (CR) bytes present
- Assert shebang valid
- Cleanup via finally block

**Estimated effort:** 30 minutes (5 min T_C, 5 min T_D, 20 min T7 byte-logic design)

---

## Risk Assessment

**T_C / T_D (LOW):** Pure argument parsing, no side effects, no fixtures.
- Risk: Error message wording stability (but already tested in bash peer, so parity keeps both in sync)

**T7 (MEDIUM):** Byte-level assertion requires precise encoding handling.
- Risk: `[System.IO.File]::ReadAllBytes()` MUST be used; `Get-Content` applies encoding and may hide CR bytes
- Mitigation: Use established ASCII safety pattern from chip/history.md
- Dependencies: None new (reuses New-TestEnv)

---

## Relation to PR #438

PR #438 fixed CRLF-in-launcher bug by applying `.Replace("\`r", '')` in New-TestEnv line 314. T7 regression test locks this fix: any future refactor removing the Replace call will fail T7, preventing silent re-introduction of the bug.

---

## Open Questions for Grill

1. **PS 5.1 coverage:** Does validate-ps51 job run this test file? (Affects test assertion compatibility)
2. **Launcher byte determinism:** Is shim content identical across runs? (Affects T7 idempotency)
3. **Error message stability:** Is script error-message wording a backwards-compat contract? (Affects test assertion maintenance burden)

---

## Done Criteria

- [ ] T_C added and passing (locally + CI validate-ps job)
- [ ] T_D added and passing
- [ ] T7 added and passing; CRLF regression confirmed
- [ ] Test count: 6 -> 9
- [ ] Parity: PowerShell = Bash coverage
- [ ] CI: All validate.yml pwsh jobs green
