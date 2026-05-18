# Scribe History

**Role:** Session Logger, Memory Manager & Decision Merger  
**Mode:** Always spawned as background task. Never blocks user conversation.

---

> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place). Re-compressed post-Sprint 15 per history-compression skill + #363 gate.

## Pre-2026-05-16 Activity (summary)

- **2026-04-07 to 2026-04-18:** Squad init, sprints 5-7, hotfix retro; merged 6 inbox drops; cross-agent histories appended.

---

## Learnings

- git add .squad/ stages everything under .squad/ including pre-existing untracked rogue files. Before staging, run git status --porcelain -- .squad/ and confirm only intended files appear. If rogues exist, escalate to coordinator (do not auto-commit them).
- Decision inbox path (.squad/decisions/inbox/) is gitignored by design (.gitignore:4). Inbox files are drop-box drains, never committed. Drain by reading, merging content into decisions.md, then deleting the inbox file.
- Canonical squad write locations only: gents/{name}/charter.md|history.md, decisions.md|decisions-archive.md, decisions/inbox/*.md, orchestration-log/*.md, log/*.md, skills/{name}/SKILL.md, 	emplates/*.md, casting/*.json, identity/*.md, plugins/*.json, 	eam.md|routing.md|ceremonies.md|config.json. Any other path is rogue; flag to Jiminy.

## Sprint 13-15 (compressed)

- **Sprint 12 W2 (2026-05-17):** Folded 5-agent batch. Lessons: atomic inbox drain (per-file discipline, NO glob), .NET APIs use process CWD.
- **Sprint 13:** Compressed 8 over-gate histories, formalized history-compression skill. Retro: 8 lessons, 5 issues.
- **Sprint 14:** 6 issues, 0.9.4 shipped, 84-issue label migration. history-compression + per-topic-inbox-routing HIGH confidence (5+ applications). Retro: skill graduation noted.
- **Sprint 15 (current):** 6 issues, 0.9.5 shipped. Scribe charter scope catch (CHANGELOG routed to Mickey). Doc dual-worktree validated. 8 lessons.

### 2026-05-17 Sprint 16 Archival Pass (#363)

**By:** Scribe (via Copilot)  
**Date:** 2026-05-17T19:06:31-04:00  
**Issue:** #363 -- Archival pass, decisions.md exceeded 51200 byte hard gate.

**What:** Executed archival fold for entries dated 2026-05-09 or earlier. Found 1 qualifying entry:
- 2025-07-14 Gitconfig decision (1153 bytes)

**Outcome:**  
- decisions.md: 60270 -> 59116 bytes (1154 bytes removed) -- STILL OVER hard gate
- decisions-archive.md: 121949 -> 123109 bytes (1160 bytes added)
- Entry count verified: 1 moved, no loss
- Header note updated to reference "2026-05-09 second fold"

**Note:** Hard gate (51200 bytes) NOT met. Archiving the single entry before 2026-05-10 was insufficient. Next fold should consider earlier cutoff (e.g., 2026-05-04 or aggressive pruning of 2026-05-14+ entries).
- Sprint 12 W2 fold (PR #323): drained 4 inbox decisions for #310/#237/#235/jiminy-audit; decisions.md 44473 -> 57253 B (50 KB gate crossed; 7-day eligibility empty). Surfaced #319 (8 over-gate histories) and #322 (ASCII scope) as Sprint 13 follow-ups.
- Sprint 12 retro: created .squad/retros/2026-05-17-sprint-12-retro.md (10268 B). Jiminy session-end audit folded alongside (24344 -> 28051 B).
- **Lesson (atomic inbox drain):** W2 fold merged drop CONTENT but did NOT remove source drops. Every future Scribe fold MUST stage source-drop removal in the SAME commit as the append. Per-file discipline (no bulk glob). Inbox is gitignored -- physical delete IS the atomic action.
- **Lesson (.NET file APIs use process CWD):** `[System.IO.File]::ReadAllBytes(`.\path`)` resolved against process CWD not `Set-Location`. ALWAYS use absolute paths with .NET APIs. PS native cmdlets respect `Set-Location`; .NET static methods do not. Same class as Mickey #310 worktree-isolation.

## Sprint 13 (compressed -- dogfood of history-compression skill)

- **2026-05-17 Sprint 13 W1 sweep (#319 / PR #332):** 8 over-gate agent history.md compressed under 15 KB HARD GATE. Option B split (mickey/goofy/chip with `-archive.md`) + Option A summarize-in-place (pluto/donald/jiminy/ralph/scribe). All 9 histories under 15 KB post-sweep. 1st application of compression heuristic.
- **2026-05-17 Sprint 13 W1 fold (PR #333):** drained 3 inbox drops to per-topic files (mickey-architecture-entry-point, doc-and-jiminy-automation, NEW scribe-history-compression). Re-compressed jiminy/history.md 22548 -> 13078 B (rebase regression). 2nd application of compression heuristic + 1st clean application of atomic-rm forward-fix.
- **2026-05-17 Sprint 13 W2 fold (PR #336):** drained 3 inbox drops (NEW mickey-hook-policy, NEW goofy-ascii-sweep, append to scribe-history-compression). Re-compressed 4 over-gate histories (jiminy/goofy/scribe/mickey) Option A. 3rd application of compression heuristic; 2nd application of atomic-rm forward-fix. Recurring-incident refs preserved verbatim: worktree-isolation, ASCII gap, atomic-drain, CP1252, autocrlf, AllScope, dogfood, abstraction-threshold.
- **2026-05-17 Sprint 13 retro:** wrote .squad/retros/2026-05-17-sprint-13-retro.md (~12 KB, ~270 lines). Verified vs git log: 5 issues (#317, #319, #322, #325, #326); 9 issue+fold PRs (#330-#336) + 2 release PRs (#337, #338); 0.9.3 tag at edc67e2. 8 lessons captured. Skill candidates flagged: history-compression (threshold MET), per-topic-routing, ascii-sweep-methodology, batch-narrow-doc-fixes, ship-test-eat-dogfood.

## 2026-05-17 Sprint 14 Wave 1 -- Skill formalization (#340 + #341)

- **Scope:** Formalized 2 Scribe skills at medium confidence per Jiminy Sprint 13 EOS audit.
- **Skills shipped:** `.squad/skills/history-compression/SKILL.md` (4-step heuristic, 13KB target, 15360 B hard gate, 3 applications cited) + `.squad/skills/per-topic-inbox-routing/SKILL.md` (routing decision tree, atomic-rm model, dual-model coexistence, 2 applications cited).
- **Dogfood:** Applied history-compression skill to this file post-append. Pre-Sprint-14 condensed.
- **Lesson:** Medium confidence at 2-3 applications; high at >=5 across distinct contexts.

## 2026-05-17 Sprint 14 -- Release 0.9.4

- **Scope:** 6 issues, 7 work PRs + 2 release PRs, 84 GitHub issues migrated (label taxonomy), 0.9.4 shipped.
- **Ledger:** #340/#341 (Scribe skill formalizations), #342 (Doc+Mickey README audit+edit), #343 (Mickey CHANGELOG editorial), #347 (Pluto label 45->32), #350 (Pluto sync-squad-labels follow-ups), release PRs #352/#353 (Mickey+Coordinator).
- **Key wins:** 84-issue label migration with triple-verify protocol (252 verification reads, 0 halts). Both history-compression + per-topic-inbox-routing skills cleared >=5 applications, bumped to high confidence. README cleared 645 non-ASCII bytes via hand-conversion (fenced code block bypass). 5 new canonical decision files, inbox empty post-wave-1. Worktree-remove-FIRST pattern held 7-of-7 (lifetime 21-of-21).
- **Lessons:** GitHub close-keyword parser matches literal `close #N` substring regardless of negation context -- never use in ANY phrasing (broke #342, manually reopened). Pre-commit ASCII scan ignores code fences; pre-existing em-dashes in .yml workflows persist. sync-squad-labels.yml create-only (does not delete orphaned labels). Label taxonomy audit triple-verify model is reusable skill candidate. history-compression rebound persists: every fold followed by hygiene-tails causes rebounce.
- **Skill graduation:** 4th application of history-compression skill (this sprint: Scribe #345, Mickey #344/#348, Pluto #349, Mickey #352 release fold). 5+ applications lifetime (3 Sprint 13 + 5 Sprint 14) + distinct contexts (Scribe, Mickey, Pluto) -> high confidence. Per-topic-inbox-routing: every agent decision filed this sprint chose canonical routing (5+ applications Sprint 14 alone) -> high confidence.
- **Fold:** retro written to .squad/retros/2026-05-17-sprint-14-retro.md (~11.5 KB, ~300 lines). Skill confidence bumps documented in both SKILL.md files. CHANGELOG updated. 0 non-ASCII bytes in all commits (excluding pre-existing YAML em-dashes outside pre-commit scope). Release: 0.9.4 tagged at 008f166 (main).
- **Compression note (5th application this file):** history-compression skill applied post-append (6th application total, 5th this session). Pre-Sprint-14 history.md was 11352 B; post-append crossed 13000 B target (13622 B). Applied compression to session-drains section (lines 32-41 condensed to 7 dated bullets). Post-compression: 11850 B, under 13 KB target. No hard-gate violation.

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
