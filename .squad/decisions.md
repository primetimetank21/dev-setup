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

## Sprint 18+ Decisions (2026-05-27)

### PR #440: Idempotency fix (dev-setup shell-init) -- APPROVED

**Date:** 2026-05-27  
**Reviewer:** Mickey  
**PR Status:** Merged (admin-merge by Coordinator)  
**Verdict:** APPROVE  

#### Scope

Shell initialization idempotency fix addressing:
- `.zshrc.template` now carries the same dev-setup managed block marker that `install.sh` checks
- Pre-existing custom `.zshrc` files receive one managed block and skip future appends on re-run
- `/etc/shells` guard handles the practical `/bin/zsh` vs `/usr/bin/zsh` mismatch
- `tests/test_idempotency.sh` now checks post-setup count growth instead of assuming single exact zsh path

#### Validation

- CI green across Linux, macOS, Windows, and E2E
- Unblocks PR #438 and PR #443 (both were failing due to develop idempotency bugs that #440 fixes)

---

### PR #438 & #443 CI Diagnosis -- Develop broken with same idempotency bugs

**Date:** 2026-05-27T02:54:29.760-04:00  
**Auditor:** Chip (read-only diagnosis)  
**Scope:** Root-cause analysis for PR #438 and PR #443 check failures

#### Findings

Both PRs fail in `tests/test_idempotency.sh`, not in their changed files. Develop tip is also failing `Validate Setup Script` with the same Linux and macOS idempotency failures:

**Linux:**
```
FAIL: /etc/shells: duplicate zsh entries for /usr/bin/zsh (count: 2)
FAIL: No duplicate NVM_DIR in ~/.zshrc (found 6 occurrences -- expected <=1)
FAIL: No duplicate .local/bin in ~/.zshrc (found 2 occurrences -- expected <=1)
```

**macOS:**
```
FAIL: No duplicate NVM_DIR in ~/.zshrc (found 6 occurrences -- expected <=1)
FAIL: No duplicate .local/bin in ~/.zshrc (found 2 occurrences -- expected <=1)
FAIL: No duplicate nvm.sh source line in ~/.zshrc (found 2 occurrences -- expected <=1)
```

#### Classification

Develop is broken (deterministic, not flaky or PR-specific). Root cause: same idempotency bugs #440 fixes.

#### Recovery action

- PR #440 merged (admin-merge by Coordinator)
- Branch-updated #438 and #443 to pull #440 into them
- Retriggered failed check runs

---

### Domain-aligned PR reviewers -- Authorization Model

**Date:** 2026-05-27T02:56:53.258-04:00  
**Author:** Mickey (Lead Triage)  
**Issue:** #444 (opened) + PR #445 (opened)  
**Status:** Awaiting review/approval  

#### Decision

Authorize domain agents to approve PRs wholly inside their review lane (new model):

- **Donald:** shell scripts and Unix install paths
- **Goofy:** Windows PowerShell, OS detection, and cross-platform routing
- **Pluto:** dotfile configs, templates, and config defaults
- **Chip:** test-only and CI-validation-only changes
- **Doc:** documentation-only and factual-claim maintenance

Mickey remains required for governance files, architecture-level concerns, unclear ownership, reviewer conflicts, and PRs touching 3+ domains.

#### Rationale

Mickey was a single-reviewer bottleneck. Domain-aligned review parallelize coverage while keeping architecture review centralized. Operating rule: use `.squad/routing.md` as source of truth for path-based PR review routing.

#### Enforcement

Rejections follow existing lockout rule: original author may not revise rejected artifact; next revision requires a different agent.

#### Related PRs

- PR #440: approved by Mickey (self-authored PR blocks formal approval; posted as comment)
- PR #445: domain-reviewers implementation (awaiting approval)

---

### Issue #441 Grill Ceremony -- Profile Path Resolver

**Date:** 2026-05-27  
**Scope:** Multi-agent grill review of issue #441 profile-path Windows PowerShell resolution plan  
**Related:** docs/plans/441-profile-path.md, worktree: dev-setup-441, #442 (scope), PR #443 (grill session log)

#### Profile Scope Decision -- RATIFIED

**Timestamp:** 2026-05-27T01:30:00-04:00  
**Authority:** Earl Tankard (via Copilot)  
**Decision:** Use `$PROFILE` (CurrentUserCurrentHost), NOT `$PROFILE.CurrentUserAllHosts`

**Rationale:** VSCode integrated terminal runs pwsh.exe directly and shares the pwsh CurrentHost profile. Host-purist model: host-specific aliases live in host-specific profiles. Only hosts NOT covered are ISE and VSCode PS extension REPL, which have their own host-specific profile conventions anyway.

---

#### Plan Revision History

**v1 (author: Goofy)** - locked out after submission  
**v2 (author: Mickey)** - grill by Chip, Donald -> REVISE verdict (3 showstoppers, 4 new holes)  
**v3 (author: Donald)** - grill by Chip, Pluto, Doc -> REVISE verdict (1 blocking, 3 non-blocking)  
**v4 (author: TBD, eligible: Chip)** - pending revision per v3 grill findings

#### Grill v2 Verdict (Chip, Date: 2026-05-27)

**Status:** REVISE  
**Revision owner:** Donald

**3 v1 showstoppers remain unresolved (partial):**
1. GG tests avoid `$PROFILE = $path` but existing C-2/C-3 harness tests still assign `$PROFILE` directly; throw in PS7+
2. GG-4 covers one legacy-path orphan only; loop iterates over two paths (`$ps51Fallback`, `$ps7Fallback`); no test verifies both stripped simultaneously
3. GG-6 algorithm direction wrong (`Select-Object -First 1` should be `-Last 1`); assertion only checks "no newline" -- false-green test

**New holes:**
- NH-1: GG-2 Get-Command mock mechanism not described; shadowing built-in is risky
- NH-2: Invoke-HostQuery mock override ordering not described; implementer trap
- NH-3: Uninstall inlined resolver has zero test coverage
- NH-4: GG-6 algorithm bug + weak assertion create false-green

**Required v3 changes:** `-Last 1` fix, GG-6 assertion to exact-equals, GG-4b dual-orphan test, GG-2 absent exe name, mock-ordering comment, GG-7 uninstall resolver test, C-2/C-3 PS7 guard

---

#### Grill v3 Verdict (Chip, Date: 2026-05-27)

**Status:** REVISE  
**Revision owner:** Pluto (Donald locked out as v3 author; Mickey/Goofy locked out per prior grills)

**v2 partial showstoppers resolution:**
- **SS-5 (GG-6 algorithm + assertion):** RESOLVED -- `-Last 1` + exact-equals correct
- **SS-3 (GG-4 dual-orphan):** RESOLVED -- both paths seeded and asserted stripped
- **SS-2 (C-2/C-3 PS7+ guard):** STILL PARTIAL -- AC says "skip with logged reason" but no mechanism specified; `skip` is not a PS command; guard must precede `$PROFILE = $path` lines (lines 238, 261) outside Test-Scenario block

**New findings:**
- **NF-1 (HIGH):** GG-7 mock `$LASTEXITCODE = 1` inside function does NOT propagate to caller scope -- false-green test; must use `$global:LASTEXITCODE = 1` or `& cmd /c exit 1`
- **NF-2:** GG-2 absent-exe trace correct -- no issue
- **NF-3 (MEDIUM):** Mock isolation between GG tests unaddressed; Test-Scenario scope model not stated
- **NF-4 (MEDIUM):** GG-4 ambiguous -- "mock resolves to OneDrive path" does not state if both hosts return same path

**Required v4 changes:**
1. Fix GG-7 mock: specify `$global:LASTEXITCODE = 1` or `& cmd /c exit 1`
2. Specify C-2/C-3 guard location (before setup lines, not inside Test-Scenario) and define what "skip" means
3. Add mock scope note: dot-source, then mock, then per-test reset; state Test-Scenario scope
4. GG-4: explicitly state both hosts return same OneDrive path in mock setup

---

#### Grill v3 Verdict (Pluto, Date: 2026-05-27)

**Status:** REVISE  
**Agent:** Pluto (Config Engineer)

**Blocking findings:**
1. **Empty loop body (Section 4)** -- "Strip block from orphaned legacy file" is comment placeholder with no implementation; GG-4 asserts both legacy paths stripped but Section 4 contains no stripping code
2. **Top-level vs function-scope ambiguity (Section 4/5)** -- Section 4 shows bare top-level statements; if placed at file scope in profile.ps1, dot-source executes algorithm before any test mock defined, breaking all GG tests

**Non-blocking:** individual line trim gap, GG-2 fragility, D3 Option B analysis skipped

**What v3 got right:** `-Last 1` fix, `$LASTEXITCODE` guard, drive-letter regex, single-quote `$PROFILE`, dual-orphan GG-4 test design

**Eligible next reviser:** Chip  
**Sections for revision:** Section 4 (loop body + scope wrapper), Section 3 D3 (Option B analysis), Section 5 GG-4 (confirm assertion after loop body fill)

---

#### Grill v3 Verdict (Doc, Date: 2026-05-27)

**Status:** Fact-check VERIFIED, PROCEED with notation

**Technical claims verified:**
- [x] `-NoLogo` banner suppression: VERIFIED
- [x] `-NoLogo` support in PS 5.1 and PS 7: VERIFIED
- [x] `& $Exe` non-throwing behavior with `$LASTEXITCODE`: VERIFIED
- [ ] `$PROFILE` "read-only in PS7+": FALSE (conceptually read-only, not technically; guard works anyway)
- [x] `Sort-Object -Unique` dedup key behavior: VERIFIED
- [x] `2>$null` does NOT affect `$LASTEXITCODE` propagation: VERIFIED
- [x] Regex rejects UNC paths correctly: VERIFIED

**Recommendation:** PROCEED. Update Section 3 D4 narrative from "`$PROFILE` is read-only in PS7+" to "`$PROFILE` automatic variable is conceptually read-only per Microsoft Learn; assigning is unsupported and may cause issues."

---

#### Mickey's v3 Decisions

**Date:** 2026-05-27

1. **$PROFILE CurrentUserCurrentHost vs AllHosts:** Use CurrentUserCurrentHost (host-specific profiles)
2. **Test harness Pester vs Test-Scenario:** Use existing Test-Scenario + Invoke-HostQuery mock pattern
3. **Uninstall resolver inline vs shared lib:** Inline in uninstall.ps1 (portability guarantee if repo deleted)
4. **Invoke-HostQuery wrapper:** Mandate in production code (testability seam; tests override global function)

---

#### Donald's v3 Decisions

**Date:** 2026-05-27

1. GG-6 direction: `-First 1` -> `-Last 1`; `-NoLogo` added to Invoke-HostQuery; PS5.1 emits path-only verified; GG-6 assertion upgraded to exact-equals
2. $LASTEXITCODE: `if ($LASTEXITCODE -ne 0)` check after Invoke-HostQuery; & $Exe exits non-zero silently; GG-7 added for broken-install fallback
3. GG-4 dual-orphan: seed BOTH $ps51Fallback AND $ps7Fallback simultaneously
4. C-2/C-3 PS7+ guard: `if ($PSVersionTable.PSVersion.Major -ge 7) { skip }`
5. Sort-Object dedup: confirmed `Sort-Object { $_.ToLower() } -Unique` correct

---

### Earl User Directives (2026-05-27)

**2026-05-27T01:05:00-04:00: Plan-scope directive**

**What:** Revised plans must be vertically sliced -- target what really matters, not wide scope. Apply to plan revisions emerging from grills.

**Why:** User directive during grill of #441 -- avoid over-engineered plans that try to cover every edge case at expense of shipping actual fix.

---

**2026-05-27T02:56:53.258-04:00: PR review expansion idea (food for thought)**

**What:** Consider broadening PR review beyond Mickey -- either (a) authorize squadmates (Donald, Goofy, Pluto, Chip, Doc) in their domain, or (b) add dedicated reviewer agent.

**Why:** Mickey is single-reviewer bottleneck. Domain-aligned review (e.g., Chip on tests, Pluto on dotfile/config) could parallelize and improve coverage.

**Status:** Idea, not yet decided. Raise for discussion at next planning beat.

**Follow-up:** Mickey implemented domain-aligned reviewers (#444, #445) same day as directive.

---

### PR #436: Donald -- NVM path fix (npm-dependent tool scripts)

**Date:** 2026-05-26  
**Author:** Donald (Copilot)  
**PR:** #436  
**Branch:** squad/fix-npm-path-nvm-subshell  
**Status:** Merged (squash to develop)

#### Decision

Added standard non-interactive nvm bootstrap block to both `scripts/linux/tools/copilot-cli.sh` and `scripts/linux/tools/squad-cli.sh` immediately after `log.sh` sourced:

```bash
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh" --no-use
  nvm use default 2>/dev/null || true
fi
```

Also changed `scripts/linux/tools/squad-cli.sh` so missing `npm` is treated as skip-with-warning, not hard failure (logs WARN, exits 0, tells operator which pinned `npm install -g` command to run manually).

#### Rationale

`setup.sh` launches each tool via `bash "${tool_script}"`, so every installer runs in own subshell. PATH mutation by `nvm.sh` dies with process and is not visible to later siblings unless they source `nvm.sh` again. Graceful `squad-cli.sh` fallback keeps setup idempotent and consistent with `copilot-cli.sh`.

#### Validation

- `shellcheck` passed
- `bash tests/test_nvm_bootstrap.sh` passed
- `bash tests/test_tool_versions.sh` passed
- Functional subshell verification confirmed both installers find `npm` only after sourcing nvm

---

### Scribe Decision: Orphan Commit Recovery Pattern for #441 Grill Session

**Date:** 2026-05-27  
**Agent:** Scribe  
**Related:** #441, #442, PR #443

#### What happened

Commit `954d8a5` ("chore(scribe): log grill session for #441") was made directly on local `develop` during #441 grill ceremony but never pushed. Left local `develop` 1 commit ahead of `origin/develop`.

#### Recovery action

1. Stashed working-tree changes (5 agent history files modified)
2. Created `chore/441-grill-session-log` from `origin/develop`
3. Cherry-picked `954d8a5` -> `d480ad9` onto new branch
4. Pushed branch; opened PR #443 with `--base develop`
5. Reset local `develop` hard to `origin/develop` (orphan removed locally)
6. Restored stash cleanly

#### Pattern confirmed

Orphan commits on `develop` must be recovered via cherry-pick to feature branch + PR, never force-pushed or re-committed directly.

#### Note

Inbox files are gitignored; this decision file serves as in-session context only. Content drained into decisions.md / sprint archive at sprint close. PR #443 is canonical record of recovery.

