# Scribe History

**Role:** Session Logger, Memory Manager & Decision Merger  
**Mode:** Always spawned as background task. Never blocks user conversation.

---

> Compressed 2026-05-17 per #319. Archived Sprint 12-14 entries to history-archive.md (2026-05-18).

## Learnings

- git add .squad/ stages everything under .squad/ including pre-existing untracked rogue files. Before staging, run git status --porcelain -- .squad/ and confirm only intended files appear. If rogues exist, escalate to coordinator (do not auto-commit them).
- Decision inbox path (.squad/decisions/inbox/) is gitignored by design (.gitignore:4). Inbox files are drop-box drains, never committed. Drain by reading, merging content into decisions.md, then deleting the inbox file.
- Canonical squad write locations only: gents/{name}/charter.md|history.md, decisions.md|decisions-archive.md, decisions/inbox/*.md, orchestration-log/*.md, log/*.md, skills/{name}/SKILL.md, 	emplates/*.md, casting/*.json, identity/*.md, plugins/*.json, 	eam.md|routing.md|ceremonies.md|config.json. Any other path is rogue; flag to Jiminy.
- 2026-05-27 dual-governance chore batching: when Mickey pre-reviews disjoint .squad-only chores with the same executor/reviewer, one branch + one PR is acceptable if each issue keeps independent verification and closing keywords.

## 2026-05-17 Sprint 15 -- Release 0.9.5

- **Scope:** 6 issues, 6 work PRs + 2 release PRs, 0.9.5 shipped (post-#357/#358 sprint-letter normalization + Doc history fold + release fold).
- **Ledger:** #355 (CHANGELOG normalization, reassigned Scribe->Mickey mid-flight per charter catch), #356 (Doc legacy non-ASCII sweep), #357 (Sprint letter normalization, Mickey), #358-#361 (Doc history fold + release fold + develop->main merge).
- **Key wins:** Scribe charter scope catch prevented root-file write violation (CHANGELOG.md routed to Mickey, not Scribe, per explicit charter line 36). Doc dual-worktree pattern applied cleanly (dev-setup-356 + dev-setup-doc). Worktree-remove-FIRST held 4-of-4 (lifetime 25-of-25). Branch ancestry hook caught stale sprint branch; recovery pattern validated. Silent background-agent success detected via filesystem state (PR exists, branch pushed).
- **Lessons (8 key items):** (1) Charter scope overrides memory -- root-file edits route to Mickey, never Scribe. (2) gh squash-merge stray tmp branch quirk -- after merge, HEAD moved to auto-generated squad/355-tmp; recovery: checkout develop, pull --ff-only, branch -D. (3) Silent success on background spawn (669s completion) -- verify via list_agents, PR creation, branch push. (4) Doc dual-worktree pattern works; one fold PR per sprint. (5) Doc "self-documenting non-ASCII" trap (2nd sprint): decision files contained literal non-ASCII chars IN documentation about non-ASCII; pre-commit rejected correctly; recovery: re-convert to codepoint-name-only references. (6) Branch ancestry hook + stale-branch recovery: save staged files, reset hard origin/develop, restore, re-stage. (7) Atomic inbox drain forward-fix (per Sprint 12 W2) applied cleanly. (8) Worktree-remove-FIRST: 4-of-4 this sprint (lifetime 25-of-25).
- **Skill candidates:** ascii-docs-about-non-ascii (NEW, medium confidence, 2 applications Sprint 14 + 15), worktree-base-refresh (NEW, low confidence, 1 application), worktree-remove-first (confirm HIGH, no change). Doc decision file at .squad/decisions/doc-356-ascii-sweep.md initially failed pre-commit hook due to literal em-dashes in table documenting em-dash replacement; this is 2nd occurrence (Sprint 14 #340 had arrow chars). Formalization prevents repeat.
- **Release:** 0.9.5 shipped. Retro written to .squad/retros/2026-05-17-sprint-15-retro.md (~11.7 KB, ~230 lines). 0 non-ASCII bytes verified. All 8 lessons captured. Develop at 0c8d710 (post-0.9.5 release commit).

## 2026-05-17 Sprint 16 -- Release 0.9.6

- **Scope:** 6 issues, 1 follow-up filed (#371 decisions.md hard gate policy review). 0.9.6 shipped.
- **Ledger:** #362 (ascii-docs-about-non-ascii skill, PR #369), #363 (partial decisions.md archival, hard gate NOT met), #364 (worktree-base-refresh skill, PR #370), #365 (tag drift audit, 14/14 bare X.Y.Z pass), #366 (skill graduation audit, no-op close), #367 (skill drift watchlist audit, PR #368 -> main accidentally -> forward-merged to develop at d102a7c).
- **Key wins:** 2 new skills formalized (ascii-docs-about-non-ascii medium, worktree-base-refresh low). 30 skills audited, 0 graduation candidates. Tag drift 0/14 (clean). Skill confidence calibration steady (no churn).
- **Lessons (6 key items):** (1) PR base=main mishap -- Pluto-5 PR #368 created with --base main instead of --base develop, landed on main outside release cut; recovery: git checkout develop && git merge origin/main --no-ff --no-verify -m "chore(merge): forward-port #368 from main to develop"; prevention: hardcode --base develop in spawn prompts. (2) decisions.md hard gate structurally unmeetable mid-sprint (recurring) -- 51200 B gate cannot be met during active sprint because 7-day archive rule keeps recent entries live; follow-up #371 filed. (3) 0-graduation-candidates legitimate outcome -- audit correctly closed with no-op comment when data shows nothing to do (27 unused + 3 sub-threshold). (4) Skill confidence calibration in practice -- new skills match lifecycle rule, zero churn on existing values. (5) .copilot/skills/ convention reinforced -- match 30 existing foundational skills, .squad/skills/ remains empty. (6) gh label list default limit applied without incident (area:meta, squad:* available, priority:p3 used).
- **Release:** 0.9.6 shipped. Retro written to .squad/retros/2026-05-17-sprint-16-retro.md (4666 bytes, 48 lines). 0 non-ASCII bytes verified. All 6 lessons + key wins + follow-ups captured. Develop at 0ff7d79 (post-retro merge).

## 2026-05-18 Sprint 17 -- Retro & Inbox Drain

- **Scope:** 6 PRs (Wave 1: #385-#390), 5 issues closed (#371, #381, #382, #383, #384). Retro + inbox drain (2 files). Per-sprint decisions.md sub-folders live.
- **Retro:** written to .squad/retros/2026-05-18-sprint-17-retro.md (5392 bytes, 95 lines). 0 non-ASCII bytes verified. Merged as PR #391 @ 97760a7.
- **Inbox drain:** 2 files drained: skill-formalization-wave (Pluto worktree-remove-first + gh-pr-base-develop) + sprint-end-labels (Donald gh-label-verify-retry SKILL). Content merged into decisions.md.
- **Key learning:** Per-sprint decisions.md sub-folder model (Option 3+5 hybrid) met gate immediately (65737 -> 7228 B). Sustainable architecture validated.
## 2026-05-18 Sprint 18 -- Retro & Inbox Drain
- **Scope:** 4 issues closed (#397-#400), 7 PRs merged (#401-#407; 4 work + 3 audit/fixup). Retro + inbox drain (4 files).
- **Retro:** written to .squad/retros/2026-05-18-sprint-18-retro.md (6609 bytes, 135 lines). 0 non-ASCII bytes verified. Merged as PR #408 @ TBD.
- **Inbox drain:** 4 files archived into .squad/decisions/sprint-18.md: Mickey hygiene tail directive (PR #401), Jiminy post-batch audit (PR #404), Donald label automation live (PR #403 primary + #407 fixup), Pluto skill formalization (PR #402 + #406 fixup). Pluto misplaced file moved from root to inbox per archival policy.
- **Key learning:** Mandatory hygiene tail template effective post-deployment. Same-wave agents need template embedded directly in spawn prompts, not linked. Coordinator memory stored: inject template verbatim into every spawn.
## 2026-05-18 Sprint 18 -- Legacy Decisions One-Shot Dump (Option 2)

- **Scope:** Archived 16 pre-Sprint-17 orphan decision files to decisions-legacy.md per Earl Option 2 (one-shot dump vs Option 1 sprint bucketing).
- **What:** Consolidated 16 orphans into .squad/decisions/decisions-legacy.md (85661 B, 0 non-ASCII), deleted orphans, per-sprint archives (sprint-12/15/18) untouched.
- **Decisions archived:** changelog-retro-placement, copilot-directive-2026-05-17-label-automation-live-run, doc-356-ascii-sweep, doc-and-jiminy-automation, doc-readme-audit-2026-05-17, goofy-ascii-sweep, label-taxonomy-2026-05-17, mickey-architecture-entry-point, mickey-hook-policy, mickey-release-process, pluto-dotfiles, pluto-skill-drift-2026-05-17, readme-edit-decisions-2026-05-17, release-094-2026-05-17, scribe-history-compression, sync-workflow-followups-2026-05-17.
- **Outcome:** .squad/decisions/ now contains 4 canonical files (sprint-12.md, sprint-15.md, sprint-18.md, decisions-legacy.md). ASCII verified 0 non-ASCII bytes in archive.

## 2026-05-27 Sprint 19 -- #441 Planning Ceremony Commit

- **Scope:** Batch commit + push + issue creation for #441 profile-path planning ceremony. Branch: squad/441-profile-path-fix.
- **Commit:** 47b16b83c02a06f3128a8a9cad5dd3c135015b5c -- 22 files (15 grill reports, plan v5.2, grill SKILL, 5 agent history appends). Rebased onto local develop (954d8a5) to satisfy branch-ancestry hook. ASCII-fix applied to 5 files (non-ASCII arrows/checkmarks from agent outputs). chip/history.md compressed (17648 B -> 13557 B; removed duplicate Sprint 12 FF full-detail block since compressed version existed at line 110-114).
- **Push:** squad/441-profile-path-fix -> origin (new branch). Tracking set.
- **Issue #442:** Created "[IMPL] #441 profile path fix -- v5.2 plan implementation" with plan summary, IN-scope list, acceptance criteria checklist, known limitations table, and review-gate note. Labels: type:enhancement, platform:windows.
- **Comment on #441:** Posted link to #442 + implementation gate reminder.
- **Inbox drain:** 14 inbox files drained to decisions.md (2026-05-27 #441 ceremony section). Combined 26437 B + 11583 B = 38020 B < 51200 B gate -- drained.
- **Key lessons:** (1) Local develop can diverge from origin/develop when commits land directly on develop (worktree/background sessions). Rebase feature branch onto local develop before commit to satisfy ancestry hook; flag divergence to Earl. (2) Non-ASCII output from agent sessions (arrows, checkmarks) triggers ASCII pre-commit hook -- must sanitize staged .md files before commit. (3) history.md size gate fires on staged blob bytes, not working-tree bytes; compress before re-staging.

## 2026-05-27 PR #457 Follow-Up -- Grill Ceremony Description Restoration

- 2026-05-27: PR #457 follow-up restore. Initial "dedupe" deletion for #455 was a misread -- the line removed was the entire body of the decision entry, not a duplicated phrase. Lesson: when an acceptance criterion says "dedupe", verify the matches are actual duplicates (not heading + body + cross-refs) BEFORE deleting. Read the surrounding structure first.
