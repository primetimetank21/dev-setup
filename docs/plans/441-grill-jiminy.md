# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Jiminy (Hygiene & Governance Reviewer)
**Plan reviewed:** docs/plans/441-profile-path.md (v2 -- vertical slice revision)
**Date:** 2026-05-27
**Verdict:** REVISE

---

## Angle: AC Alignment + Hole Closure + Hygiene

### AC Coverage Matrix

| Acceptance Criterion | Plan Section | Status |
|---|---|---|
| AC#1: Aliases appear in both PS 5.1 and PS 7+ on stock Windows | Section 2 (Decision: Scope, IN item 1) + Section 4 (Algorithm) | IMPLICIT - not listed in Section 7 ACs |
| AC#2: Aliases appear on OneDrive/KFM systems | Section 7, top bullet | COVERED |
| AC#3: On PS 7+-only box, no PS 5.1 write attempted | Section 2 (IN item 2 fallback logic) | IMPLICIT - not listed in Section 7 ACs |
| AC#4: Diagnostic log shows resolved path | Section 7, 4th bullet | COVERED |
| AC#5: uninstall.ps1 mirrors resolution logic | Section 7, 3rd bullet | COVERED |
| AC#6: Test mocks $PROFILE and verifies target | Section 7, 5th bullet | COVERED |

**Finding:** ACs #1 and #3 are implicitly handled but NOT explicitly listed in Section 7. Plan Section 7 redefines scope to migration scenarios (re-running setup on old orphaned block). This is TIGHTER THAN the issue ACs. Mismatch.

### v1 Hole Closure Matrix (Mickey's 10 holes)

| # | Hole from Mickey | v2 Status | Evidence / Citation |
|---|---|---|---|
| 1 | $PROFILE vs CurrentUserAllHosts contradiction | CLOSED BUT MISMATCHED | Section 3.1 DECIDES: use $PROFILE (CurrentUserCurrentHost). Issue spec says CurrentUserAllHosts. v2 picked the OTHER choice. Decision is explicit; rationale cites Doc's H2 feedback. But contradicts issue proposed fix. |
| 2 | Cold-start fallback writes never-sourced path (pre-provision vs skip) | ADDRESSED | Section 2 Scope: "Fallback to hardcoded path when host absent". Section 4 returns fallback when Get-Command fails. Idempotency handled via check-before-strip logic. Not a semantic decision issue, treated as acceptable. |
| 3 | Idempotency legacy cleanup runs every time | ADDRESSED | Section 4 Algorithm checks `Select-String -Path $legacy -Pattern $beginMarker -Quiet` BEFORE stripping. Only strips if sentinel exists. Section 6 Migration strategy confirms probing + conditional strip. |
| 4 | Deduplication case-sensitive on Windows | CLOSED | Section 4 Algorithm: `$profilePaths \| Sort-Object { $_.ToLower() } -Unique`. Explicitly normalizes to lowercase. |
| 5 | Invoke-HostQuery wrapper not in production code | CLOSED | Section 3.4 Decision mandates wrapper in production code. Section 4 Algorithm shows `function Invoke-HostQuery` call inside `Resolve-ProfilePath`. |
| 6 | Uninstall lib dependency breaking change | CLOSED | Section 3.3 Decision: "Inline the resolver in uninstall.ps1 (Option A)". Removes lib dependency. |
| 7 | GG-6 logs "not found" but doesn't verify fallback USED | ADDRESSED | Section 5 Test Plan GG-6: "Mock returns ... Only path extracted | Return value contains no newline". Verifies return value, not log. Assertion checks return type, not usage. Incomplete. |
| 8 | GG-S1 static test fragile (string literal matching) | NOT ADDRESSED | Section 5 mentions GG tests but no GG-S1 listed. Section 1 mentions "STATIC TEST" in risk R4 but no mitigation shown. Still fragile. |
| 9 | No test for Unicode username / non-ASCII path | NOT ADDRESSED | Section 2 Scope lists "Unicode usernames -- if reported, file issue" as OUT-OF-SCOPE. This is explicit deferral, not a hole. Status: N/A (vertical slice). |
| 10 | Missing AC check: diagnostic log shows resolved path (not hardcoded) | PARTIALLY ADDRESSED | Section 7 AC lists "Diagnostic log shows resolved path, not hardcoded path" but no explicit test case in Section 5 that verifies this. AC listed, test not shown. |

**Findings:**
- 6 holes CLOSED (1, 4, 5, 6 fully; 2, 3 functionally)
- 2 holes NOT ADDRESSED in v2 (8, 10)
- 1 hole DEFERRED as out-of-scope (9 -- N/A per vertical slice)
- 1 hole MISMATCHED: Mickey's hole #1 about choosing CurrentUserCurrentHost vs CurrentUserAllHosts -- v2 DECIDED but picked the OPPOSITE of what issue spec says

### v1 Hole Closure Matrix (Chip's 27 issues)

| # | Issue from Chip | v2 Status | Evidence / Note |
|---|---|---|---|
| 1 | $TestDrive reference in test harness | NOT ADDRESSED | Section 5 test cases do not mention $TestDrive. v2 uses existing Test-Scenario harness "with the Invoke-HostQuery mock pattern" -- suggests mock-based pattern. But does not explicitly rewrite the test harness. Chip's underlying issue: Pattern A fails on non-Pester harness. Status: IMPLICIT (test harness redesign needed, not shown). |
| 2 | $PROFILE assignable in test host (PS 7+ blocks it) | NOT ADDRESSED | Section 5 does not mention PS version guard or how to handle PS 7+ $PROFILE immutability. Section 3.2 says "Use existing Test-Scenario harness with Invoke-HostQuery mock pattern" but doesn't resolve the $PROFILE assignment problem in PS 7+ test environment. |
| 3 | Invoke-HostQuery mandated in production | CLOSED | Section 3.4 explicitly mandates it. Section 4 shows it in algorithm. |
| 4 | Select-Object -Unique case-sensitive | CLOSED | Section 4: `Sort-Object { $_.ToLower() } -Unique`. |
| 5 | Write-Info output capturable in harness | NOT ADDRESSED | GG test cases do not specify stream capture (6>&1 or *>&1). Section 5 does not address how Write-Info output is redirected for test assertion. |
| 6 | Resolved path > 260 chars on non-long-path system | N/A | Section 2 Scope OUT: "Long paths > 260 chars -- if reported, file issue". Deferred by Earl's vertical-slice directive. |
| 7 | Case-sensitive contains check legacy cleanup collision | PARTIALLY ADDRESSED | Section 4 uses case-insensitive comparison: `-notcontains` still exists but paired with explicit check: `$legacy.ToLower() -eq $legacy.ToLower()`. Actually looking closer, the pseudocode says: `$profilePaths \| Where-Object { $_.ToLower() -eq $legacy.ToLower() }`. ADDRESSED. |
| 8 | pwsh installed during setup not on PATH | N/A | Section 2 Scope OUT: "pwsh not on PATH after same-session install -- existing #251 pattern applies". Deferred as known issue. |
| 9 | Partial/corrupt block (BEGIN without END) | N/A | Section 2 Scope OUT: "Partial/corrupt blocks (interrupted writes) -- if reported, file issue". Deferred by vertical slice. |
| 10 | Profile file read-only (Group Policy) | N/A | Not mentioned in Section 2 Scope. This is an edge case not explicitly marked as out-of-scope. Chip's issue: no test coverage. Status: OPEN. |
| 11 | Profile directory symlink to disconnected network | N/A | Not mentioned. Out-of-scope by omission. |
| 12 | Multi-line output (banner + path) | ADDRESSED | Section 4 Algorithm: `($resolved -split '\r?\n' \| Where-Object { $_ } \| Select-Object -First 1)`. Explicitly handles multi-line by taking first non-empty line. |
| 13 | Long path > 260 chars | N/A | Section 2 Scope OUT: "Long paths > 260 chars". |
| 14 | ConstrainedLanguage Mode (CLM) blocks write | N/A | Section 2 Scope OUT: "Constrained Language Mode (CLM) -- if reported, file issue". |
| 15 | Legacy orphan + resolved path both exist | NOT ADDRESSED | Section 5 Test Plan lists GG-1 through GG-6 but none explicitly test: legacy path with block + resolved path with different content after run. Section 6 Migration strategy describes the logic but no test case verification shown. |
| 16 | NO TEST FOR LEGACY CLEANUP AT ALL | OPEN | Section 5 lists 6 test cases (GG-1 through GG-6). None of these test the legacy cleanup scenario from Section 6. GG-4 is described in Section 5 table but the actual test case logic is not provided. This is a CRITICAL GAP. |
| 17 | Idempotency tested only twice | OPEN | Section 5 GG-5 says "Idempotency (3 runs)" in the description but the table lists it as: "Exactly one block | $profilePaths.Count -eq 1". Assertion checks array count, not file stability across 3 runs. Test as described does not verify stable file size across runs 1, 2, 3. |
| 18 | Second profile path independent idempotency | OPEN | No test case listed that verifies idempotency on BOTH resolved paths simultaneously. |
| 19 | GG-5 dedup doesn't verify write occurred | OPEN | Section 5 GG-5 checks array count but does not show assertion that written file contains the block. |
| 20 | $HOME empty/null | N/A | Out-of-scope by omission. Not tested, not explicitly deferred. Status: OPEN. |
| 21 | GG-S1 static assertion too narrow | OPEN | Not mentioned in v2 plan. Out-of-scope by omission. |
| 22 | Execution policy Restricted blocks child process | OPEN | Not mentioned in Section 5 test cases. Not explicitly deferred in Section 2 Scope. |
| 23 | UTF-8-with-BOM encoding interaction | OPEN | Not mentioned. Out-of-scope by omission. |
| 24 | CI: OneDrive KFM cannot be simulated on GitHub Actions | N/A | Section 8 Known Limitations does not list manual KFM testing requirement. Chip's rec: add manual gate. Status: OPEN. |
| 25 | CI: process spawning perf (2-6 seconds per run) | N/A | Not mentioned. Out-of-scope by omission. Known limitation candidate but not documented. |
| 26 | CI: PS 5.1 behavior differs from KFM systems | N/A | Not mentioned. Known limitation candidate but not documented. |
| 27 | Test file import guard (lib/profile-path.ps1 may not exist yet) | OPEN | Section 5 mentions "Use Invoke-HostQuery mock pattern" but doesn't show test harness safeguards. If lib import fails at load time, all GG tests crash. |

**Findings:**
- 3 holes CLOSED (3, 4, 12)
- 7 holes N/A by vertical slice (6, 8, 9, 13, 14; #24 implicit)
- 17 holes OPEN or PARTIALLY ADDRESSED (1, 2, 5, 7, 10, 11, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27)
- Critical gap: **LEGACY CLEANUP UNTESTED** (hole #16 repeated from Chip's verdict)

---

## Hygiene Findings

1. **AC#1 and AC#3 missing from Section 7 acceptance criteria list.** Issue #441 has 6 ACs. v2 plan Section 7 lists 5 bullets, but two original ACs are implicit only:
   - AC#1 ("Aliases load on stock Windows with both PS 5.1 and 7+") is mentioned in Section 2 but NOT in Section 7 AC list
   - AC#3 ("Only PS 7+, no PS 5.1 write") is mentioned in Section 2 but NOT in Section 7 AC list
   This creates ambiguity: are these in-scope for acceptance testing or not?

2. **$PROFILE vs CurrentUserAllHosts mismatch.** Issue #441 proposed fix explicitly says `$PROFILE.CurrentUserAllHosts`. v2 Section 3.1 DECIDES to use `$PROFILE` (CurrentUserCurrentHost). Rationale cites "Doc's H2 confirms different hosts have different CurrentHost profiles". This is a valid decision (host-specific aliases belong in host-specific profiles), BUT it contradicts the issue spec. This decision should be called out in an EXPLICIT statement like "Decision: Changed from issue spec's CurrentUserAllHosts to CurrentUserCurrentHost because..." and flagged for Earl's review.

3. **GG-S1 static test mentioned in risks but no mitigation shown.** Section 1 risks list R4 (fragile string literal matching). Section 5 Test Plan lists GG-1 through GG-6 but no GG-S1. Where is the static test? This is mentioned as a risk but the mitigation is not shown in the test list.

4. **Legacy cleanup test completely absent.** Chip's hole #16 is critical: "No test for legacy orphan cleanup at all." Section 6 describes the migration strategy in detail. Section 5 Test Plan lists 6 test cases (GG-1 through GG-6) but NONE explicitly test the legacy cleanup scenario. GG-4 is listed as "Legacy cleanup | Mock returns OneDrive path; create block at hardcoded path | Hardcoded path stripped" but the actual test logic is not shown in the table. This is either (a) incomplete test design, or (b) the test plan table is a summary and full test harness exists elsewhere. If (b), cite the location. If (a), add explicit test cases.

5. **Diagnostic log coverage unclear.** Issue AC#4 requires "Diagnostic log lines show the resolved path (not the constructed one)". Section 7 AC lists this. Section 5 Test Plan: GG-3 is "Case-insensitive dedup" (not log verification). No test case explicitly verifies that resolved path is logged and hardcoded path is NOT logged. This is an acceptance criterion but not tested in the shown test plan.

6. **Test harness compatibility not addressed.** Chip's holes #1, #2, #5: Section 3.2 says "Use existing Test-Scenario harness with Invoke-HostQuery mock pattern" but Section 5 does not show:
   - How $TestDrive is replaced (if used at all)
   - How $PROFILE mutability in PS 7+ is handled
   - How Write-Info output is captured for assertion
   These are implementation details that belong in Section 5 test pseudocode. As written, test cases are ambiguous on execution environment.

7. **Word count (936 total) is genuinely short for this scope.** v2 plan cuts scope to vertical-slice, which is valid. But:
   - Section 3 "Decisions Made" has 4 bullet points labeled as decisions but 3 are basically restatements of v1 questions (#1: which $PROFILE flavor, #2: Pester vs existing harness, #3: inline vs lib). These read as "we decided what Chip/Mickey asked us to decide" rather than NEW judgment calls. Decision #4 (Invoke-HostQuery wrapper) is new.
   - Section 5 Test Plan has 6 test cases described in a compact table. The table shows ID, Name, Input, Expected, Assertion but OMITS test pseudocode or execution details. GG-4 (legacy cleanup) is listed but the implementation logic is not shown.
   - Section 8 Known Limitations lists 5 items but Known Limitations are usually doc'd to users, not buried in a plan. Are these in Section 1 of profile.ps1 module docs? Not stated.

8. **Section 6 Migration Story is one paragraph.** Bullet list describes: install does 4 things (resolve, probe, conditional strip, write). But the paragraph does NOT explicitly say: "If a user upgrades from old version of dev-setup (with orphaned block at hardcoded path), running install on new version will automatically migrate them by stripping the old block and writing to the correct resolved path." This is the actual migration story the user cares about, and it's IMPLIED but not STATED.

9. **Decision #1 ($PROFILE flavor) is mischaracterized as "decided" when Mickey's hole shows it's OPEN.** Section 3.1 says "Doc's H2 confirms..." but Chip's hole #1 explicitly flags this as a BLOCKING discrepancy requiring Earl's ruling. v2 decided without getting Earl's sign-off. This is a governance issue: design decisions that contradict issue spec should be escalated, not embedded in pseudo-code.

10. **No evidence that v2 is actually a revision of v1 vs a rewrite.** The plan does not cite which holes from Mickey/Chip it's addressing. Reading it cold, it looks like Goofy rewrote it from scratch. Best practice: v2 should have a "Revision Notes" section at the top saying "Addressing Mickey's holes #1,4,5,6 and Chip's holes #3,4,7,12. Deferring #9 as out-of-scope (vertical slice). OPEN: #8,10 (test harness). Escalating #1 to Earl for $PROFILE decision."

---

## Self-Consistency Check (Section 2 vs Section 4 vs Section 5)

**Section 2 IN list vs Section 4 Algorithm:**
- Section 2, IN item 1: "Query each host for its $PROFILE" [ok] Section 4 shows `Invoke-HostQuery -Exe $HostExe`
- Section 2, IN item 2: "Fallback to hardcoded path when host absent" [ok] Section 4 shows `if (-not (Get-Command $HostExe...` with fallback return
- Section 2, IN item 3: "Case-insensitive deduplication" [ok] Section 4 shows `Sort-Object { $_.ToLower() } -Unique`
- Section 2, IN item 4: "Legacy cleanup of orphaned blocks at old hardcoded paths" [ok] Section 4 shows cleanup loop
- Section 2, IN item 5: "Test coverage via mocked Invoke-HostQuery" [ok] Section 5 GG tests

**Section 4 Algorithm vs Section 5 Tests:**
- Section 4 has pseudo-code; Section 5 lists 6 GG tests
- Mapping: GG-1 (resolved path used), GG-2 (fallback when host absent), GG-3 (case-insensitive dedup), GG-4 (legacy cleanup), GG-5 (idempotency), GG-6 (multi-line output)
- GAP: Section 4 Algorithm has lines showing `| Where-Object { $_ }` for empty-line filtering. Section 5 GG-6 says "Only path extracted | Return value contains no newline". This matches Section 4 line `($resolved -split '\r?\n' | Where-Object { $_ } | Select-Object -First 1)` [ok]
- CRITICAL GAP: Section 4 legacy cleanup loop is 4 lines of pseudocode. Section 5 GG-4 is listed as a test but the table row does NOT show the test pseudocode or assertion details. Is GG-4 actually implemented? Unclear.

**Verdict on self-consistency: PARTIAL.** The three sections agree on WHAT ships (algorithm matches test cases), but Section 5 test descriptions are too terse to verify the tests will actually prove the algorithm works, especially for legacy cleanup.

---

## Verdict

**REVISE.**

The plan addresses most of Mickey's holes (6/10 closed, 3 N/A by vertical slice) and many of Chip's holes (3 closed, 7 N/A by scope, but 17 remain open or partially addressed). However, three blocking issues prevent approval:

1. **AC#1 and AC#3 are missing from Section 7 acceptance criteria.** v2 redefines scope tighter than issue #441 spec. AC list must either include all 6 original ACs or explicitly state which are deferred and why.

2. **$PROFILE vs CurrentUserAllHosts decision was made without escalating to Earl.** Chip flagged this as a blocking contradiction between issue spec (AllHosts) and Goofy's plan (CurrentHost). v2 decided to go with CurrentHost but called it "Doc's feedback" rather than "decision overriding issue spec requiring Earl's sign-off."

3. **Legacy cleanup is completely untested.** Section 6 describes it, Section 4 pseudo-codes it, but Section 5 does not show actual test pseudocode or assertions for the GG-4 legacy cleanup case. This is the entire value proposition of the backward-compatibility story. Chip called this "critical gap" in hole #16.

**Revision owner:** Mickey (NOT the original author) per lockout rule. Scope of revisions:
- Section 7: Add ACs #1 and #3 OR explicitly defer them with rationale
- Section 3.1: Escalate $PROFILE decision to Earl; show his ruling in plan (e.g., "Per Earl 2026-05-27: use CurrentUserCurrentHost because...") before finalizing decision
- Section 5: Add explicit test pseudocode for GG-4 (legacy cleanup). Show test harness details for PS 7+ $PROFILE mutability, Write-Info capture, multi-test idempotency.

**Re-grill required after revision:** Yes. The $PROFILE decision and legacy cleanup tests are structural changes. Full re-grill (Mickey + Chip angles) required after revision. If Mickey and Chip confirm the revised plan still addresses their original holes, re-grill can be scoped to AC coverage + test harness sections only.

