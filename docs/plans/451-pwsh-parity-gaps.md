# Plan: #451 Vertical Slice -- PowerShell Parity Gaps

**Date:** 2026-05-28T02:56:01-04:00  
**Revised:** 2026-05-27T23:12:03-04:00  
**Author:** Chip (Tester)  
**Issue:** #451  
**Status:** v2 -- Post-Grill Revision

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
- CI: One new step in `validate-ps51` job (see CI Integration section below)

**OUT:**
- No script behavior changes
- No helper function additions
- No framework extensions (reuse Test-Scenario, Invoke-ScriptRun, New-TestEnv)

---

## CI Integration (v2 addition -- resolves Mickey BLOCKING-1/BLOCKING-2, Goofy Finding-1)

The `validate-ps51` job (`.github/workflows/validate.yml` lines 287-369) does NOT currently run
`test_sprint_end_labels_pwsh.ps1`. The `validate-powershell` job (line 282-283) runs only the
bash peer (`test_sprint_end_labels.ps1`) under PS 7+. A TODO comment at line 285 calls out the
missing PowerShell test.

**Decision:** Add the test to `validate-ps51` (option a -- 2-line YAML change).

The test file uses only PS 5.1-compatible constructs: `[System.IO.File]::ReadAllBytes()` is
available on .NET Framework 4.5+ (PS 5.1+), no ternary/null-coalesce/parallel operators present,
no `$IsWindows` dependency in test logic. T_C/T_D use `Invoke-ScriptRun` and string matching --
identical pattern to the existing PS 5.1 test suite.

**YAML change to make during implementation:**

After `.github/workflows/validate.yml` line 369 (end of "Run git hooks tests (PS 5.1)" step),
add:

```yaml
      - name: Run sprint-end labels tests (PS 5.1)
        shell: powershell
        run: |
          powershell -ExecutionPolicy Bypass -File tests\test_sprint_end_labels_pwsh.ps1
```

This follows the exact same `shell: powershell` + `powershell -ExecutionPolicy Bypass -File`
pattern used at line 359 and line 369. The TODO comment at line 285 should be removed as
resolved-by this step.

**Scope note:** Adding this YAML step expands the "single file" scope by one YAML line block.
The primary deliverable remains `tests/test_sprint_end_labels_pwsh.ps1`. The validate.yml edit
is a prerequisite to close the CI gap and is explicitly in-scope for this issue.

---

## Implementation Plan

**Order:** T_C (quick), T_D (quick), T7 (careful byte-level assertion), then validate.yml step

**Fixture approach:**
- T_C / T_D: No setup, direct Invoke-ScriptRun on bare script
- T7: Minimal test state via New-TestEnv (empty issues/prs, copy launcher logic)

**T7 detail (v2 -- replaces vague "assert shebang valid", resolves Mickey MAJOR-2):**
- Read launcher file via `[System.IO.File]::ReadAllBytes()` (binary, no encoding transform)
- Assert no 0x0D (CR) bytes present (primary regression invariant)
- Assert file starts with bytes 0x23 0x21 (the ASCII codes for `#!`) -- this is the shebang
  check. Rationale: confirms the CRLF-strip did not corrupt the first two bytes and the file
  remains a valid POSIX script. Both assertions together are required: the CR check ensures
  no embedded 0x0D anywhere; the 0x23/0x21 check ensures the leading bytes survived the Replace.
  The "no 0x0D" check alone does NOT cover header corruption from a bad Replace call.
- Include inline doc comment: regression scope, PR #438 reference, launcher determinism note
  (content is session-deterministic via $PowerShellPath but not identical across independent
  CI runs -- acceptable for a regression test, not an idempotency test)
- Cleanup via finally block

**T7 assertion code sketch:**
```powershell
# T7: Regression test for PR #438 CRLF fix.
# Launcher is a POSIX bash script; requires LF-only line endings.
# Note: launcher content is deterministic within a session but NOT across
# independent runs (PowerShellPath differs). This is a regression test,
# not an idempotency test -- byte-identity across runs is not required.
$bytes = [System.IO.File]::ReadAllBytes($launcherPath)
if ($bytes -contains 0x0D) {
    throw "launcher contains CR bytes (0x0D); must be LF-only for POSIX bash"
}
if ($bytes[0] -ne 0x23 -or $bytes[1] -ne 0x21) {
    throw "launcher missing shebang bytes 0x23 0x21 (#!); file header may be corrupted"
}
```

**Estimated effort:** 30 minutes (5 min T_C, 5 min T_D, 20 min T7 byte-logic design, 5 min YAML step)

---

## Risk Assessment

**T_C / T_D (LOW):** Pure argument parsing, no side effects, no fixtures.

- Risk: Error message wording is coupled to implementation strings in `scripts/sprint-end-labels.ps1`
  and `scripts/sprint-end-labels.sh`. (v2 decision -- resolves Mickey MAJOR-1 / Goofy T_C/T_D note)
- **Decision:** Use substring/regex match assertions (not full-string equality). T_C asserts
  exit code != 0 only (mirrors bash Test C which checks exit code = 2, no message assertion).
  T_D asserts exit code != 0 AND output contains `"release:shipped-"` (mirrors bash Test D).
  This minimizes coupling surface while preserving behavioral coverage.
- **Contract note (required in Done Criteria):** The `"release:shipped-"` substring in T_D is a
  known error-message contract between `scripts/sprint-end-labels.ps1`, `scripts/sprint-end-labels.sh`,
  and both test files. Any wording change to this string requires coordinated updates to:
  `tests/test_sprint_end_labels_pwsh.ps1` (T_D), `tests/test_sprint_end_labels.ps1` (Test D),
  and the producing script(s). Document this in the PR description.

**T7 (MEDIUM):** Byte-level assertion requires precise encoding handling.
- Risk: `[System.IO.File]::ReadAllBytes()` MUST be used; `Get-Content` applies encoding and
  may hide CR bytes
- Mitigation: Use established ASCII safety pattern from chip/history.md
- Dependencies: None new (reuses New-TestEnv)

---

## Relation to PR #438

PR #438 fixed CRLF-in-launcher bug by applying `.Replace("`r", '')` in New-TestEnv line 314.
T7 regression test locks this fix: any future refactor removing the Replace call will fail T7,
preventing silent re-introduction of the bug.

---

## Open Questions (Resolved)

1. **PS 5.1 coverage:** RESOLVED. validate-ps51 does NOT currently run this test file. Plan
   includes a 2-step YAML addition to close the gap (see CI Integration section above).

2. **Launcher byte determinism:** RESOLVED (by Goofy). Launcher content is session-deterministic
   (same $PowerShellPath within a run) but not identical across independent CI runs. T7 is a
   regression test, not an idempotency test -- this is acceptable. See T7 detail above.

3. **Error message stability:** RESOLVED. T_C uses exit-code-only assertion; T_D uses substring
   match on `"release:shipped-"`. Both follow the bash peer test pattern. Contract documented
   in Risk Assessment and Done Criteria.

---

## Done Criteria

- [ ] T_C added and passing (locally + CI validate-ps51 + validate-powershell): asserts exit != 0
      for `--release-label` provided without `--sprint`; no message assertion (mirrors bash Test C)
- [ ] T_D added and passing: asserts exit != 0 AND output contains `"release:shipped-"` for bad
      label prefix (mirrors bash Test D); substring match, not full-string equality
- [ ] T7 added and passing; CRLF regression confirmed: no 0x0D bytes + starts with 0x23 0x21
- [ ] Test count: 6 -> 9
- [ ] Parity: PowerShell = Bash coverage (T_C=C, T_D=D, T7 regression lock)
- [ ] `.github/workflows/validate.yml`: new step added after line 369 in validate-ps51 job;
      TODO comment at line 285 removed
- [ ] CI: validate-powershell AND validate-ps51 jobs green
- [ ] PR description documents the `"release:shipped-"` error-message contract

---

## Revision History

- **v1 (2026-05-28T02:56:01-04:00):** Initial plan committed to `.squad/decisions/451-vertical-slice.md`.
  Three parity gaps identified (T_C, T_D, T7). Open questions deferred to grill.
- **v2 (2026-05-27T23:12:03-04:00):** Addressed grill panel findings (Mickey/Goofy/Jiminy).
  - BLOCKING (Mickey/Goofy): Added CI Integration section; test wired into validate-ps51 job
    (YAML step at line 369+); TODO comment at line 285 marked for removal.
  - MAJOR (Mickey #4): Replaced vague "assert shebang valid" with precise two-assertion spec:
    no 0x0D bytes (CR regression) + file starts with 0x23 0x21 (#! shebang bytes); both
    assertions required and rationale documented.
  - MAJOR (Mickey #3): T_C/T_D assertion strategy defined as substring/regex match; T_C is
    exit-code-only; T_D uses "release:shipped-" substring; error-message contract documented
    in Risk Assessment and Done Criteria.
  - MEDIUM (Jiminy): Plan moved from `.squad/decisions/451-vertical-slice.md` to
    `docs/plans/451-pwsh-parity-gaps.md` per PR #441 precedent.
