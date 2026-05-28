# Squad Decisions

## Decision Records

(Sprint archives -- see .squad/decisions/ for per-sprint history:
  sprint-12.md -- Sprint 12 decisions (2026-05-14 to 2026-05-16) + Sprint 12 Wave 2 fold
  sprint-15.md -- Sprint 15 dispatch and retrospective (2026-05-17)
  sprint-17.md -- Sprint 17 decisions (2026-05-18+)
  sprint-19.md -- Sprint 19 decisions (2026-05-17 to 2026-05-18)
  decisions-archive.md -- pre-Sprint 12 archive (entries dated <= 2026-05-04)
Policy: at each sprint wrap, Scribe moves all entries for that sprint to
  .squad/decisions/sprint-NN.md and resets the live file to Sprint 16+ content.
Hard gate: 51200 bytes (50 KB). Gate checked at each commit via pre-commit hook.
Active: Sprint 16+ entries below.)

## Active Rules (Policy Directives)

### 2026-05-18T01:20:31-04:00: Commit trailer convention -- Copilot identity collapse

**By:** Earl Tankard (via Copilot)

**What:** All squad agent commits use the following Co-authored-by trailer:

  Co-authored-by: Copilot <copilot@github.com>

This matches the @copilot coding-agent bot identity that GitHub displays on autonomous PRs. Eliminates the dual-Copilot contributor count caused by the noreply form `223556219+Copilot@users.noreply.github.com`.

**Scope:**
- Applies to all new squad agent spawn prompts -- coordinator must use `copilot@github.com` in the embedded trailer instruction.
- Applies to Scribe commits (history.md, decisions.md, session logs).
- Applies to direct release commits and tag-author messages where applicable.
- Does NOT apply to historical commits -- no git history rewrite.
- Does NOT apply to commits the Copilot CLI itself produces under its own system-mandated trailer (rare; mostly the coordinator runs `gh pr merge` or `git commit` indirectly via spawned agents).

**Why:** User request -- captured for team memory. Earl noticed GitHub showing 3 contributors (self + 2 Copilots) and wants the bot attribution unified.

**Implementation note for future sessions:** Update `.squad/templates/spawn-prompt-hygiene.md` or a dedicated `.copilot/skills/commit-trailer/SKILL.md` so this isn't lost when the inbox drains. (Optional follow-up issue.)

## Sprint 17 Decisions (2026-05-18+)

### Skill Formalization Wave -- worktree-remove-first + gh-pr-base-develop (Issues #383, #384)

**Date:** 2026-05-17  
**Author:** Pluto (Copilot, Sprint 17 Wave 1)  
**PR:** #386 (merged @ 17c940b)  

#### Skills formalized

**worktree-remove-first (update)**
- Confidence: medium (29+ applications across Sprints 12-16, lifecycle rules)
- Primary rationale: hygiene harvest (step 1) first, gh CLI quirk (step 4) second
- New citations: Sprint 15 PRs #357-360, Sprint 16 PRs #368-370

**gh-pr-base-develop (new)**
- Confidence: high (binary rule: flag either present or absent)
- Trigger: every gh pr create by squad agents
- Rule: always pass --base develop unless release cut (develop->main)
- Pre-flight: echo target base before gh pr create; verify with gh pr view <N> --json baseRefName after
- Recovery: git merge origin/main --no-ff --no-verify + chore(merge) type
- Citing: Sprint 16 PR #368 incident (Pluto-5 --base main mishap)

#### routing.md update

Added "Spawn-Prompt Hygiene" section. Coordinators must include --base develop snippet in every spawn that creates a PR.

#### Decision standing

Both skills now active team standards. Mandatory in every spawn prompt that invokes gh pr create. worktree-remove-first remains mandatory for all squad PR merge sequences.

---

### Sprint-End Label Automation with Verification-Retry Pattern (Issue #382)

**Date:** 2026-05-17  
**PR:** #389 (merged @ 400f9ac)  
**Author:** Donald (Copilot, Sprint 17 Wave 1)  

#### Delivery

Hybrid (script + workflow + SKILL):
- `scripts/sprint-end-labels.sh` -- runnable locally; --dry-run, --repo, --sprint, --release-label flags; idempotent via pre-fetched label-list keying
- `.github/workflows/sprint-end-labels.yml` -- workflow_dispatch with dry_run input (default true)
- `.squad/skills/gh-label-verify-retry/SKILL.md` -- write-then-verify pattern with retry backoff (1s, 2s, 4s) and reusable bash snippet
- `tests/test_sprint_end_labels.ps1` -- 6 tests, 2 exercise retry loop via function override

#### Verification approach

1. Pre-fetch candidate issues' labels in one gh issue list call
2. For each issue, drive has_label / verify_with_retry per operation
3. On mismatch, re-query only (not re-write) with exponential backoff
4. On final failure, print actual label set and exit 1

#### SKILL status

`gh-label-verify-retry` now formal SKILL (high confidence). Reusable for future label/state automations.

#### Follow-ups

- sprint:N labels not yet in use; retire release:backlog as de facto search key once adopted
- Consider workflow_run trigger on release PR merge if Mickey standardizes release workflow name
- squad-history-check workflow expects squad:donald PRs to modify .squad/agents/donald/history.md; #389 deferred append to follow-up per task spec

---
## 2026-05-17 Sprint 16 wrap (decisions fold)

### Sprint 16 EOS Audit Summary

**Conducted by:** Jiminy (Hygiene Auditor)  
**Date:** 2026-05-17T20:08:00-04:00  
**Verdict:** DIRTY (2 blockers resolved post-audit, 3 findings noted)

#### Blockers (resolved)

1. **Inbox drained** -- 4 files merged into decisions.md (this section)
2. **pluto/history.md compressed** -- reduced from 15694 B to under 15360 B hard gate

#### Findings (non-blocking)

1. **No Sprint 16 orchestration log entries** -- Only 1 entry exists (2026-05-17T19-20-00Z-mickey.md), documenting Sprint 15 dispatch. 8 Sprint 16 spawns have zero coverage. Scribe accepted gap.

2. **3 stale remote squad/* branches** -- origin/squad/367-skill-drift-audit, origin/squad/s16-retro, origin/squad/scribe-s16-history-append. Ralph cleanup pending.

3. **Squash-merge policy mismatch** -- Charter specifies "No squash merges on develop or main." Sprint 16 PRs #368, #369, #370, #372, #374, #375, #376 all squash-merged to develop. Only #373 (release merge) was correctly a regular merge. Follow-up: #371 should address this or charter needs update.

#### Audit passes

- Working tree: clean
- develop in sync: HEAD = origin/develop @ aba8332
- Tag 0.9.6: annotated tag 38c0942 -> commit 10d203f (correct)
- PR #373: regular merge (2 parents). Confirmed.
- 128218a on main: documented mistake, recovered via d102a7c forward-merge
- Issue #371: open, labels correct (type:chore, area:meta, squad:scribe, priority:p3)
- Open PRs: 0
- history.md timestamps: all 9 agents updated 2026-05-17
- All Sprint 16 commits on develop match manifest SHAs

#### Agent history.md sizes (HARD GATE 15360 B)

| Agent  | Bytes | Status |
|--------|-------|--------|
| chip   | 12446 | PASS   |
| doc    | 13420 | PASS   |
| donald | 12688 | PASS   |
| goofy  | 10925 | PASS   |
| jiminy | 12494 | PASS   |
| mickey | 11914 | PASS   |
| pluto  | <15360 | PASS (compressed) |
| ralph  | 13147 | PASS   |
| scribe | 13729 | PASS   |

### Sprint 16 Issue Dispatch

**Conducted by:** Mickey (Triage Lead)  
**Issues filed:** 6

1. **#363** -- Scribe: decisions.md archival (decisions.md 60270 B -> 51200 B hard gate)
2. **#362** -- Pluto: ascii-docs-about-non-ascii SKILL.md (prevents self-documenting pitfall)
3. **#364** -- Pluto: worktree-base-refresh SKILL.md (recovery recipe for branch ancestry bleed)
4. **#367** -- Pluto: skill drift watchlist audit (confidence freshness check)
5. **#366** -- Pluto: skill graduation audit (promote low->medium, medium->high per thresholds)
6. **#365** -- Mickey: tag prefix sanity check (verify X.Y.Z bare convention)

**Wave A (parallel):** #363, #362, #364, #365
- #363: Scribe direct-push (develop, --no-verify)
- #362, #364: Pluto skills (disjoint paths, parallel-safe)
- #365: Mickey comment-only (no repo writes)

**Wave B (serialized after Wave A):** #367, then #366
- #367: drift audit, reads-only, writes pluto-skill-drift-2026-05-17.md
- #366: graduation audit, reads #367 findings, writes to SKILL.md

Charter alignment: No conflicts identified. Scribe direct-push pattern matches Sprint 15 workflow.

### Sprint 16 Work Completion

**Issues closed:** 6

1. **#362 (PR #369)** -- ascii-docs-about-non-ascii/SKILL.md -- medium confidence, 2 observations (Sprint 14 #340, Sprint 15 #356/#359)

2. **#363 (direct push 5f07514)** -- decisions.md archival pass -- 1 stale 2025-07-14 entry moved to decisions-archive.md. Hard gate (51200 B) not met mid-sprint; follow-up #371 filed for policy review.

3. **#364 (PR #370)** -- worktree-base-refresh/SKILL.md -- low confidence, 1 observation (Sprint 15 #359)

4. **#365 (comment-close)** -- Tag prefix sanity check -- 14/14 tags conform to bare X.Y.Z convention. No drift.

5. **#366 (comment-close)** -- Skill graduation audit -- 0 candidates eligible. Closed as no-op per #367 findings.

6. **#367 (PR #368)** -- Skill drift watchlist audit -- 30 skills audited, 0 graduation candidates, 27 with zero observed applications, 3 low-confidence under threshold. Report at pluto-skill-drift-2026-05-17.md.

### Forward-Merge Recovery Context

PR #368 (skill drift audit) landed on main by mistake at commit 128218a. Forward-merged back to develop via merge commit d102a7c. main was an ancestor of develop at release time; the develop->main PR #373 brought main forward via regular merge.

### Release SHAs (0.9.6)

- Squash commit (develop, PR #372): 7172ae7f31e6c3a0099313c198558db122186439
- Merge commit (main, PR #373): 10d203fd023077ec3526d8b1bdc17defadd2ace4
- Tag 0.9.6: 38c0942f1959299cfccd084710da90379ff46d59
- GitHub release: https://github.com/primetimetank21/dev-setup/releases/tag/0.9.6

### decisions.md Archival Pass

**Issue:** #363  
**Scope:** decisions.md exceeded hard gate (51200 bytes); archival per 2026-05-10 cutoff rule  
**Cutoff date:** 2026-05-10 (7 days before 2026-05-17)  
**Criterion:** Entries dated 2026-05-09 or earlier

**Entries moved:** 1 (2025-07-14 -- Gitconfig editor literal value + override comment, Issue #184, 1153 bytes)

**File sizes after archival:**

| File | Before | After | Change |
|------|--------|-------|--------|
| decisions.md | 60270 B | 59116 B | -1154 B |
| decisions-archive.md | 121949 B | 123171 B | +1222 B |

**Acceptance criteria:**

- [x] Entry count: 6 + 9 (combined)
- [x] No entries lost in transit
- [ ] decisions.md < 51200 bytes: FAIL (59116 B, 7916 B over gate)
- [x] ASCII-only in additions: 0 non-ASCII bytes
- [x] Header marker updated: "2026-05-04 fold" -> "2026-05-09 second fold"

**Note:** Hard gate not met. Only 1 entry before cutoff date 2026-05-10. Earliest remaining live entry is 2026-05-14 (5 days after cutoff). No entries exist in 2026-05-05 through 2026-05-13 range. Follow-up #371 filed for policy review.

### Decision

Accept all Sprint 16 work as complete. Acknowledge decisions.md gate breach (#371 tracks policy review). Scribe compression of pluto/history.md resolves blocker #2.

---

## 2026-05-17T20:30 Earl directive -- squash-merge policy clarification

**By:** Earl (via Coordinator, Sprint 16 EOS Q&A)
**What:** Squash merges to `develop` ARE the standing policy. Regular merges apply ONLY to `develop -> main` release cuts (and any back-merge recovery). Jiminy's charter line 41 ("No squash merges on develop or main") was outdated -- update to clarify.
**Why:** Sprint 16 squash-merge mismatch surfaced by Jiminy-4 EOS audit. Earl confirmed via choice "Charter is outdated -- squash to develop is what I want."
**Impact:**
- Jiminy charter line 41 needs rewrite
- No retroactive changes to past sprints (no history rewriting)
- This memory should be stored for future sessions

---

## 2026-05-27 -- Formalized grill ceremony as a SKILL (Issue #441)

**By:** Pluto (Copilot, Grill Wave 1)

Formalized grill ceremony as a SKILL on 2026-05-27. The "grill" skill (`.squad/skills/grill/SKILL.md`) documents the adversarial pre-implementation plan review pattern observed informally in prior sprints and applied formally for the first time on issue #441 (2026-05-27). The skill captures triggers, roles, lockout rule, spawn pattern, output convention, verdict synthesis rules, and anti-patterns. Canonical example: issue #441, four participants (Goofy as plan author, Mickey/Chip/Doc as parallel grillers). Confidence: low -- bumps to medium on next independent application.

---

## 2026-05-27 -- #441 Plan Ceremony Decisions (Sprint 19 Drain)

**Drained by:** Scribe
**Files:** 15 inbox items (14 grill/revision drops + 1 Scribe ceremony record)
**Context:** Issue #441 profile-path fix -- 6 plan revisions, 5 grill rounds, v5.2 SHIP verdict

### Round Summary

| Round | Griller(s) | Verdict | Key Finding |
|-------|-----------|---------|-------------|
| v2 grill | Jiminy | REVISE | GG-6 direction bug (Select-Object -First 1 -> -Last 1); GG-7 added ($LASTEXITCODE check) |
| v3 plan | Doc | PROCEED | 10 factual claims verified; Section 4 algorithm structurally sound |
| v3 plan | Mickey | REVISE | $PROFILE.CurrentUserAllHosts contradiction; 5 test spec gaps |
| v3 plan | Chip | REVISE | 4 test gaps (GG-7 HIGH false-green, C-2/C-3 skip-as-pass) |
| v4 grill | Pluto | SHIP | v3 blockers resolved; A-1 MEDIUM: $ps51/$ps7Fallback undefined under StrictMode |
| v4 grill | Chip | REVISE | 2 MEDIUMs: GG-7 exe unspecified; TestDrive/real-$HOME write risk |
| v4 grill | Donald | REVISE | F-1 HIGH: -Encoding ASCII missing (silent UTF-16 corruption on PS5.1) |
| v4 -> v5 | Jiminy (revision) | -- | P1-P7 patched: foreach stub, scope wrap, GG-7 mock, C-2/C-3 skip, mock isolation, GG-4 dedup, $PROFILE read-only note |
| v5 -> v5 | Donald (revision) | -- | H1-H5 + F-4/F-5: -Encoding ASCII, LASTEXITCODE reset, TestDrive removed, GG-7 exe spec, StrictMode fallbacks |
| v5.1 grill | Pluto | SHIP | A-1 resolved; no new blockers |
| v5.1 grill | Chip | SHIP | C-1/C-2/F-3 resolved; 4 new LOWs (non-blocking) |
| v5.1 grill | Jiminy | REVISE | JN-1 MEDIUM: $local vars shadow test overrides; GG-1/4/5 write to real $HOME |
| v5.1 -> v5.2 | Mickey (revision) | -- | JN-1: parameterized Write-PowerShellProfile (-Ps51Fallback/-Ps7Fallback); JN-2: Write-Warning |
| v5.2 grill | Pluto | SHIP | JN-1 resolved; mechanism sound; 1 LOW (GG-3 invocation target) |
| v5.2 grill | Chip | SHIP | All MEDIUMs resolved; 4 carry-forward LOWs (non-blocking); impl-ready YES |
| v5.2 grill | Jiminy (verify) | SHIP | JN-1/JN-2 resolved; no new MEDIUMs; v5.2 approved |

### Final Verdict: v5.2 SHIP (Pluto, Chip, Jiminy consensus)

- Tracking issue: #442 "[IMPL] #441 profile path fix -- v5.2 plan implementation"
- Implementation gate: #442 review approval required before coding starts
- Plan file: docs/plans/441-profile-path.md (branch squad/441-profile-path-fix)

### Key Standing Decisions from Ceremony

- **$PROFILE scope:** Use `$PROFILE` (CurrentUserCurrentHost), not AllHosts. Earl ratified 2026-05-27.
- **Test harness:** Existing `Test-Scenario` + `Invoke-HostQuery` mock pattern. No Pester (scope creep).
- **Write-PowerShellProfile parameter contract (v5.2-D1):** Optional `-Ps51Fallback`/`-Ps7Fallback` params with production defaults. Tests pass temp paths; production callsites unchanged.
- **Inline uninstall resolver:** `uninstall.ps1` inlines the path resolver (~30 lines). Self-contained.
- **Scribe ceremony note:** Local develop (954d8a5) is 1 commit ahead of origin/develop and not in remote ancestry. Earl to address before #442 implementation PR.
---

## 2026-05-26 -- NVM Bootstrap in Tool Scripts (Issue #436)

**By:** Donald (Copilot)

Formalized nvm sourcing pattern in npm-dependent installer scripts. Both `scripts/linux/tools/copilot-cli.sh` and `scripts/linux/tools/squad-cli.sh` now bootstrap nvm in a subshell-safe manner using the standard non-interactive block:

```bash
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh" --no-use
  nvm use default 2>/dev/null || true
fi
```

Also changed `squad-cli.sh` missing-npm behavior from hard failure to graceful skip with warning. Rationale: `setup.sh` launches each tool in its own subshell, so nvm.sh PATH mutations don't propagate across siblings. Each tool must source nvm independently. Tested via shellcheck and functional subshell verification. Confidence: high (pattern replicates existing npm-install idempotency model).

---

## 2026-05-27 -- PR #438 Review (Sprint-End Labels PowerShell Test)

**By:** Chip (Tester, domain-aligned reviewer)

APPROVE verdict on PR #438 (test_sprint_end_labels_pwsh.ps1). One-line bugfix: strip CRLF from bash launcher shim before writing (here-strings on Windows emit CRLF; bash requires LF). Fix uses established pattern from peer bash test. T1-T6 scenarios match bash A-G tests with appropriate implementation diffs. Flagged pre-existing parity gaps for follow-up (missing coverage for --release-label edge cases and CRLF regression test). Routing: domain match (tests/**) per routing.md line 43. Comment posted to PR.

---

## 2026-05-27 -- PR #443 Review (Governance Log & Grill SKILL)

**By:** Mickey (Lead, governance reviewer)

APPROVE verdict on PR #443 (session log for grill ceremony #441). All .squad/** governance entries (session log, 5 orchestration logs, 5 history appends, decisions.md update) pass checklist. Notes: mickey/history.md in warning zone (14794 B, over 14336 B warn threshold but under 15360 B hard gate). Trim planned separately under issue #450. Grill reports and SKILL.md correctly deferred to impl PR. Pre-existing decisions/inbox directory created as part of review. Routing: governance match per routing.md section on .squad/** changes.

---

## 2026-05-27 -- Chore Plan: Issues #455 and #456 Governance

**Prepared by:** Mickey (Lead)
**Date:** 2026-05-27T06:19:33-04:00
**Scope:** `.squad/**` governance chores (placeholder leak in orchestration-log + decisions.md dedup)

### Summary

Plan for two atomic chores:
- **#456:** Fix `{issue-number}` placeholder in `.squad/orchestration-log/2026-05-27T05-25-33Z-mickey-review-443.md` (replace with `443`)
- **#455:** Deduplicate "Formalized grill ceremony as a SKILL" phrase in `.squad/decisions.md` (rephrase body paragraph to remove echo of header)

Both changes in single branch `squad/455-456-scribe-governance-chores`, single PR, reviewed by Mickey. Executor: Scribe (domain match per charter).

### Decisions from Plan

- **#456 replacement:** Use PR number `443` (best approximation; real comment ID unavailable)
- **#455 rephrase:** Change body opening from "Formalized grill ceremony as a SKILL on 2026-05-27" to "Pluto formalized the grill ceremony pattern on 2026-05-27"
- **Branch/PR strategy:** Single PR, both files, squash-merge to develop
- **Risk gates:** decisions.md current size 17533 B (well under 51200 B hard gate); no gate breach expected

Status: Plan prepared 2026-05-27T06:19:33-04:00; PR #457 merged 2026-05-27 (7bb05a0); this record retained for audit trail.

---

## 2026-05-27 -- Session: #451 Vertical Slice Plan (Grill Rounds 1-4)

### Planning Context

**Issue:** #451 (PowerShell parity gaps -- sprint-end-labels tests on PS 5.1)  
**Branch:** squad/451-pwsh-parity-gaps  
**Final PR:** #462 (draft)  
**Plan file:** docs/plans/451-pwsh-parity-gaps.md  
**Follow-up issue:** #461 ($IsWindows PS 5.1 defensiveness)

### Plan Evolution

| Round | Author | Verdict | Status |
|-------|--------|---------|--------|
| R1 (v1) | Jiminy + Mickey + Goofy | 3x REVISE + APPROVE-W/-CHANGES | Blocking CI gap, PS 5.1 coverage unclar |
| R2 (v2) | Mickey | APPROVE | CI gap resolved, caveat identified ($IsWindows fragility) |
| R2 (v2) | Goofy | APPROVE-W/-MINOR-CAVEATS | $IsWindows check fragile but acceptable |
| R3 (v3) | Mickey | APPROVE | All R2 notes tracked; implementation-ready |
| R3 (v3) | Goofy | APPROVE | Caveat deferred to #461; scope boundary sound |
| R4 | Jiminy | DIRTY->CLEAN | Trailer format fixed via doc commit rebase |

### Key Plan Decisions

- **Scope:** Add 3 tests (T_C, T_D, T7) + 1 YAML step to validate-ps51 job
- **T_C:** `--release-label` alone, missing `--sprint` -> asserts exit != 0
- **T_D:** Bad `--release-label` prefix (not "release:shipped-") -> asserts exit != 0 + substring match
- **T7:** Regression test for PR #438 CRLF fix -> assert no 0x0D bytes + shebang 0x23 0x21
- **CI:** Add step to `.github/workflows/validate.yml` validate-ps51 job (line 369+)
- **$IsWindows caveat:** Pre-existing code at line 320; PS 5.1 fragility acknowledged and deferred to #461

### Grill Panel Verdicts (Consensus)

**Mickey (Architecture Lead):** APPROVE (all BLOCKING and MAJOR findings resolved in v2->v3)  
**Goofy (Cross-Platform Dev):** APPROVE (PS 5.1 compatibility sound; caveat out-of-scope but tracked)  
**Jiminy (Hygiene):** CLEAN (trailer format corrected; plan location moved to docs/plans/)  
**Chip (Tester/Author):** SHIP-READY (all acceptance criteria met; v5.2 profile-path analog)

### Implementation-Phase Tracking

**Done Criteria Highlights:**
- [ ] T_C/T_D/T7 added to `tests/test_sprint_end_labels_pwsh.ps1`
- [ ] YAML step added to validate-ps51 job (remove TODO at line 285)
- [ ] PR description documents "release:shipped-" error-message contract
- [ ] Both validate-powershell and validate-ps51 jobs green in CI

**Out-of-Scope (Tracked #461):**
- Replace `$IsWindows` check with explicit `$PSVersionTable.Platform` check (PS 5.1 defensiveness)

### Drained Inbox Files (13 total)

| File | Verdict | Finder |
|------|---------|--------|
| goofy-451-grill.md | APPROVE-W/-CHANGES | Goofy R1 |
| goofy-451-grill-r2.md | APPROVE-W/-MINOR-CAVEATS | Goofy R2 |
| goofy-451-grill-r3.md | APPROVE | Goofy R3 |
| mickey-451-grill.md | APPROVE-W/-CHANGES | Mickey R1 |
| mickey-451-grill-r2.md | APPROVE | Mickey R2 |
| mickey-451-grill-r3.md | APPROVE | Mickey R3 |
| jiminy-451-grill.md | DIRTY | Jiminy R1 |
| jiminy-451-grill-r2.md | CLEAN | Jiminy R2 |
| jiminy-451-grill-r3.md | DIRTY | Jiminy R3 |
| jiminy-451-grill-r4.md | CLEAN | Jiminy R4 |
| chip-pr458-review.md | APPROVED | Chip (parallel to #451) |
| donald-nvm-path-subshell-fix.md | APPROVED | Donald (parallel) |
| mickey-pr458-review.md | APPROVE | Mickey (parallel) |

### Related Parallel Work (Drained from Inbox)

**PR #458 (Profile-Path Fix, #441/#442):**
- Chip review: APPROVED (all 7 GG acceptance gates pass; 4 carry-forward LOWs non-blocking)
- Mickey review: APPROVE (plan design elements verified; inline resolver pattern sound)
- Status: Ready to merge (human approval required per Copilot self-review block)

**PR #436 (NVM Bootstrap Fix):**
- Donald decision: Formalized nvm sourcing in npm-dependent tool scripts
- Pattern: subshell-safe via standard NVM_DIR bootstrap block + graceful npm-missing fallback
- Confidence: high (matches existing npm-install idempotency model)

---

## 2026-05-28 -- PR #462 Grill Cycle (Issue #451 Revision & Reviews)

### Goofy Review #1 -- CHANGES REQUESTED

**Date:** 2026-05-28T03:02:58-04:00 (posted)  
**PR:** #462  
**Issue:** #451  
**Verdict:** CHANGES REQUESTED

#### Findings

1. **IMPORTANT** -- `tests/test_sprint_end_labels_pwsh.ps1:422-427` -- T_C only asserts "non-zero" for missing `--release-label`. The bash peer pins exit `2` and the production script emits a specific validation message. T_C would pass on any non-zero failure (gh missing, runtime error).
   - **Fix:** Assert `ExitCode -eq 2` and output contains `--release-label <label> is required`.

2. **IMPORTANT** -- `tests/test_sprint_end_labels_pwsh.ps1:429-436` -- T_D checks guidance but accepts any non-zero exit. Bash peer requires exit `2`; PowerShell script implements that.
   - **Fix:** Change assertion to require `ExitCode -eq 2` before `release:shipped-` substring.

#### Verified Good

- PS 5.1 compatibility clean (no ternary/null-coalesce/AsByteStream/$IsWindows); 0 non-ASCII bytes
- T7 byte-level correct (0x0D rejection, 0x23 0x21 shebang verification)
- Fixture isolation preserved (New-TestEnv creates unique .test-tmp dirs; clean in finally blocks)
- CI placement correct (validate-ps51 step after git-hooks PS 5.1 step)
- Test parity count right: 9 pwsh vs 7 bash (semantic coverage aligned once T_C/T_D pin validation)
- PR conventions correct (squash-merge, --base develop, Co-authored-by trailers)

---

### Mickey Review #1 (LEAD) -- CHANGES REQUESTED

**Date:** 2026-05-28T02:38:27-04:00 (posted)  
**PR:** #462  
**Issue:** #451  
**Verdict:** CHANGES REQUESTED (LEAD)

#### Recommendation

Remove out-of-scope `.squad/**` changes from PR #462 or move to separate hygiene PR. After cleanup, if Goofy's technical review passes and CI is green, Earl should approve and merge.

#### Finding

**Scope gate failed:** PR touches `.squad/agents/chip/history.md`, `.squad/identity/now.md`, and `.squad/skills/ps51-byte-launcher-regression/SKILL.md` (outside approved test/workflow/optional-plan slice).

#### Verified Good

- In-scope contract delivered: T_C, T_D, T7, validate-ps51 workflow step present
- Test count verified: 6 -> 9 scenarios
- Branch/base correct: squad/451-pwsh-parity-gaps -> develop
- CI recheck: all checks passed
- Reviewer lockout: comment-only lead review; Chip/Copilot cannot self-approve; Earl approval required

---

### Goofy Revision -- SCOPE DRIFT REMOVAL

**Date:** 2026-05-28 (session timestamp)  
**Branch:** squad/451-pwsh-parity-gaps  
**Commits:** 8870abe (scope cleanup), 93b339f (T_C/T_D assertion pin)

#### Scope Cleanup (8870abe)

Removed:
- `.squad/agents/chip/history.md` append
- `.squad/identity/now.md` update
- `.squad/skills/ps51-byte-launcher-regression/SKILL.md` creation

Retained in-scope:
- T_C, T_D, T7 test assertions
- validate-ps51 workflow step
- docs/plans/451-pwsh-parity-gaps.md

#### Assertion Revision (93b339f)

- T_C line 424: Assert exit 2 (not just non-zero)
- T_C line 427: Assert output contains `--release-label <label> is required`
- T_D line 434: Assert exit 2 (prior: any non-zero)
- T_D line 437: Assert substring `release:shipped-` (unchanged; now after exit pin)

**Evidence:** Clean detached worktree at PR head passed local test run: 9 passed, 0 failed, 0 skipped.

---

### Mickey Re-Review (LEAD) -- APPROVED

**Date:** 2026-05-28T03:02:58-04:00 (session timestamp)  
**PR:** #462  
**Issue:** #451  
**Verdict:** APPROVED (LEAD)

#### Verification

- `gh pr view 462` confirmed base develop, head squad/451-pwsh-parity-gaps, all checks passed
- `git diff origin/develop...origin/squad/451-pwsh-parity-gaps --stat` showed exactly three paths:
  - `.github/workflows/validate.yml`
  - `docs/plans/451-pwsh-parity-gaps.md`
  - `tests/test_sprint_end_labels_pwsh.ps1`
- No `.squad/**`, `scripts/**`, `src/**` or unrelated workflow drift
- T_C, T_D, T7 assertions intact
- validate-ps51 step included
- Goofy's revision tightened T_C/T_D to exit 2 + message/guidance assertions

#### Reviewer Gate

Lockout remains enforced. Chip (author) + Goofy (revision) + Mickey (lead review) + Goofy (re-review). Comment-only approvals posted; Earl/human final approver and merger.

#### Recommendation

Earl should perform final human approval and merge PR #462.

---

### Goofy Re-Review -- APPROVED

**Date:** 2026-05-28T03:02:58-04:00 (session timestamp)  
**PR:** #462  
**Issue:** #451  
**Verdict:** APPROVED

#### Evidence

- `tests/test_sprint_end_labels_pwsh.ps1` at PR head asserts T_C exit 2 + message at lines 424, 427
- T_D asserts exit 2 at line 434 + substring at line 437
- Production validation: `--release-label <label> is required` exit 2 at lines 114-117; bad prefix `release:shipped-` guidance exit 2 at lines 120-122
- Bash peer: same exit-code contracts at C (130-135) and D (142-149)
- Commit 93b339f touched only T_C/T_D assertion hunk; T7/CRLF logic unchanged
- Clean detached worktree at PR head: 9 passed, 0 failed, 0 skipped

#### Traps Avoided

- Local working copy had unrelated dirty state (failed T3-T6); not used as PR-head evidence
- Tightened assertions use only PS 5.1-safe constructs (-ne, -notmatch, strings); no PS 7+ syntax

---

