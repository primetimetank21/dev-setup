# Jiminy's History

## Core Context

- **Project:** dev-setup - Replicable setup scripts for Dev Containers and Codespaces
- **Owner:** Earl Tankard, Jr., Ph.D.
- **Universe:** Disney Classic
- **Role:** Squad Hygiene Auditor (reviewer-gate)
- **Joined:** 2026-05-16
- **Charter:** `.squad/agents/jiminy/charter.md`
- **Model:** `claude-opus-4.6` (premium - reviewer-gate role)

## Day-1 context (summary; full hand-off at 2026-05-16 hire)

Hired 2026-05-16 to close 5 recurring squad-hygiene gaps Earl caught manually: (1) branch ancestry bleed (Sprint 7, 3x), (2) squash merges (Sprint 2/3, Ralph), (3) uncommitted histories (recurring -- Coordinator forgets Scribe), (4) rogue file paths (Verifier batch 2026-05-16 -- Source of Truth Hierarchy), (5) stale `squad/*` branches post-sprint (now Ralph EOS). Standing directives: caveman speak, em-dashes / non-ASCII FORBIDDEN in PS literals (CP1252 0x94 trap), ALL merges regular (no squash), branches from `develop` only, EOS branch cleanup mandatory, bad commit messages hard-reject, Verifier batches use SoT-Hierarchy paths only. Roster at hire: Mickey lead, Donald, Goofy, Pluto, Chip, Scribe, Ralph, Jiminy + Doc (hired 2026-05-16). Open issues at hire: 19 filed 2026-05-16 (#221-#239); P0s = #221 (nvm.ps1 path), #222 (tag hygiene 0.1.0-0.8.0), #239 (E2E CI smoke). No first task -- Jiminy auto-runs on Coordinator return-to-user.

## Learnings

> Re-compressed 2026-05-17 (W2 fold) per #319 gate. Sprint 13+ entries kept verbatim; older summarized. (W1 fold re-compress prior.)

- **2026-05-16 -- Audit runs 1-3 (summary).** First-audit baseline: clean tree, 10 pre-Sprint-5 main-direct commits accepted as historical, 2 rogue files cleaned, duplicate log dirs reconciled to singular `.squad/log/`, Scribe got Learnings section. Post-retro audit #2: 1 minor SKILL.md size finding + 1 false-positive label flag. Hygiene retro shipped 4 items (pre-spawn-checklist skill, squad-history-check CI gate, PR template, 6 standing rules). Post-batch audit #3 (4-PR sprint #243-#246): 4 findings (type-label, PR body, area-label, tmux assertion).
- **2026-05-16 to 2026-05-18 -- Sprint 10 audits.** Mid-sprint: Doc history.md modified (deferred to Scribe), `bradygaster-squad-sdk-0.9.4.tgz` rogue (PR #280: `*.tgz` to .gitignore + delete). Gap: Coordinator manual dispatch vs charter "auto-trigger after 3+ batches". EOS: clean tree, 4 known inbox drops pending Scribe drain, Mickey PR #274 missing history.md entry, 6 stale `squad/*` remote branches (Ralph EOS scope).
- **2026-05-19 -- Sprint 11 Wave 1 + session-end audits (first under #293 SOP).** All 11 lanes clean across PRs #296-#298 (Mickey #229, Goofy #230, Pluto #233). Session-end + bonus PRs #299/#301/#302: clean, `Jiminy clear`. Pattern: `gh pr merge --delete-branch` ghost-branch recurrence 75%, tracked as #300.
- **2026-05-17 -- Sprint 12 Wave 1 audits.** Closed #300 (Option A, 6-for-6 clean post-filing #299/#301/#302/#303/#311/#312); Ralph EOS `git push --delete` fallback retained. Post-batch audit after 4 merges (#313/#314/#315/#316): 11-lane clean, label gap on #317 flagged. Verdict: `0 fixes, 1 minor flag`.
- **2026-05-17 -- Sprint 12 Wave 2 post-batch audit.** 3-agent batch (Mickey #310/PR #321, Donald #237/PR #320, Goofy #235 NOT_PLANNED Case B). Findings: (i) **CRITICAL worktree-isolation violation by Mickey** -- inbox drop landed in MAIN checkout instead of `dev-setup-310`; 2nd distinct write-to-wrong-CWD event same run. Root cause: dispatch prompt didn't pin CWD; tooling resolved against process CWD. Donald's parallel spawn wrote correctly -- non-deterministic. Remediation drop filed. (ii) **MEDIUM pre-commit ASCII-scan scope gap** -- `hooks/pre-commit` Check 2 globs only `*.ps1`; ARCH/README/CONTRIBUTING have 200+ non-ASCII hits (em-dash U+2014, box-drawing U+2500/U+2502/U+251C/U+2514, smart-arrow U+2192). Filed as #322. (iii) Auto-fixed: PR #321 + #320 full label sets, `go:yes` removed from closed #235. Verdict: `3 fixes, 2 flags`.
- **2026-05-17 -- Sprint 12 session-end audit (develop `5dfc476`).** All 9 Sprint 12 issues closed across 3 waves + 2 fold PRs (10 PRs: #313/#314/#315/#316/#318/#320/#321/#323/#324). Tree clean, 0 worktree orphans, 4-5 stale `origin/squad/*` tracking refs (Ralph EOS). Label state: 8 squad:* present, `squad:scribe` MISSING (#319 gap). PR labels: only #320/#321 carry full set among Sprint 12 merges -- process gap. History-tails: ALL agents compliant. Skills: `label-hygiene` + `test-harness-pattern` template-compliant; `abstraction-threshold` not formalized. **Scribe inbox-drain bug surfaced:** decisions.md grew 44473->57253 B (drain content done) but 4 inbox files NOT deleted. CHANGELOG `[Unreleased]`: 9 entries -- 0.9.2 cut justified.
- **Lesson (Scribe inbox-drain bug):** When folding inbox decisions, the per-topic-file `git add` AND `git rm -- decisions/inbox/*.md` MUST land in the SAME commit so drain is atomic with merge. Forward-fix expectation for next Scribe cycle (PR #319 spec; re-tested in Sprint 13 W1 fold).
- **Lesson (squad: label set incomplete):** Standard label set covers 8 engineering agents but omits `squad:scribe`. Service-role follow-ups force routing miss. Recommend next label sweep create `squad:scribe` (and audit `squad:ralph` usage; precedent exists for service-role labels).
- **Recurring incident references preserved:** worktree-isolation (Sprint 4 race condition + Sprint 12 W2 CWD-resolution variant), ASCII scope gap (#322, `*.ps1`-only pre-commit), CP1252 byte 0x94 trap in PowerShell string literals, `autocrlf` and `AllScope` alias hazards, atomic-drain (PR #323 bug).

## 2026-05-17 Sprint 13 Wave 1

- **2026-05-17 -- Sprint 13 Wave 1: formalized worktree-remove-FIRST as a Squad skill (issue #317).** Created `.squad/skills/worktree-remove-first/SKILL.md` (full frontmatter: `confidence: high`, `source: earned (issue #317)`, `domain: repo-meta, release-flow`) capturing the five-step merge sequence proven 5-of-5 in Sprint 12 Wave 2: harvest -> `git worktree remove --force` -> `git branch -D` -> `gh pr merge --admin --squash --delete-branch` -> verify. Documented the `--merge` swap for release PRs (PRs #328 / 0.9.2), the recovery path for "forgot and merged with worktree attached" (Ralph EOS fallback from PR #295), and the precise reason the order matters (gh's local pre-flight aborts the remote-delete step when a worktree owns the branch). Cited 5 successful applications: PRs #320, #321, #323, #324, #327 plus release #328. Cross-linked to the existing `worktree-isolation` skill (spawn-head concern) and to issue #300 (the prematurely-closed earlier tracker -- this skill is the actual fix).
- **Decision: new skill over extending `worktree-isolation`.** Reviewed `.squad/skills/worktree-isolation/SKILL.md` -- it documents the Sprint 4 agent-dispatch race condition (spawn-time concern). The merge tail is a distinct teardown-time concern with a different trigger surface, different mitigation, and different audience (coordinator/Ralph vs spawning dispatcher). Separate skills stay tightly scoped and independently citeable; the new skill's References section cross-links back. Format follows the `label-hygiene` SKILL convention (YAML frontmatter + Context/Patterns/Examples/Anti-Patterns sections) since `worktree-isolation` predates the template.
- **Companion doc edits:** appended a 2-line "Merging Squad PRs from worktrees" subsection to CONTRIBUTING.md under "Parallel Agent Work" pointing readers at the new skill (full content stays in the skill file, not duplicated). CHANGELOG `[Unreleased]` -> `### Added` notes the skill addition.
- **Hygiene tail:** this history entry + decision drop at `.squad/decisions/inbox/jiminy-w1-2026-05-17-issue-317-skill.md`. No code changed (skill formalization is pure docs). Stayed in custodian voice -- codifying a proven pattern is hygiene formalization, not feature work.

## 2026-05-17 Sprint 13 Wave 1 Post-Batch Audit (summary)

- **Scope:** PRs #330 (Mickey #325+#326), #331 (Jiminy #317), #332 (Scribe #319). Develop @ 114ea63.
- **Result:** 0 auto-fixes, 3 flags (doc roster gap, jiminy/history.md over-gate at 19852 B, stale remote `origin/squad/319-history-archival`). All 4-label sets full. All 3 hygiene-tails compliant. GO recommendation for Wave 2 (#322 fan-out).
- **Skill drift watch:** Mickey "batch narrow doc fixes" 2nd application (not yet formalized); Scribe "history-compression heuristic" 1st application.
- **Forward-fix:** Scribe history W1 entry re-confirmed PR #323 atomic-rm pattern. (Superseded by W2 audit below.)

## 2026-05-17 Sprint 13 Wave 2 Post-Batch Audit (summary)

- **Scope:** PRs #335 (Goofy #322A ASCII sweep) + #334 (Mickey #322B hook glob extension). Develop @ ed3f4cb.
- **Findings:** 3 histories OVER 15 KB gate (goofy 15158, scribe 15076, mickey 15034 post-catch-up) -- flagged for Scribe W2 fold. Stale `origin/squad/319-history-archival` (Ralph EOS scope). ASCII outside fences = 0 across swept `.md`. `.copilot/skills/*/SKILL.md` NOT swept (e.g., external-comms 158 hits); hook now guards `.md` so future edits block -- Sprint 14 candidate. `scripts/lib/ascii-sweep.py` not yet CONTRIBUTING-linked (defer until 2nd application).
- **Mickey dogfood incident:** own pre-commit hook blocked own commit on legacy non-ASCII debt; Mickey deferred history-tail per PR #334 body. Jiminy auto-fix: appended Mickey W2 catch-up entry post-Goofy-sweep (1230 B sourced from PR #334 body per charter scope).
- **Recurring-incident references preserved:** worktree-isolation, ASCII-scope gap, atomic-drain, CP1252 trap, autocrlf, AllScope, dogfood, abstraction-threshold.
- **Verdict:** 1 auto-fix, 6 flags, GO recommendation for 0.9.3 (deferred to coordinator post-Scribe-W2-fold).

## 2026-05-17 Sprint 13 Session-End Audit (compressed)

- post-0.9.3 close. main @ edc67e2, develop @ a930540. 9 PRs merged, 5 issues closed. All 8 sections PASS (1 CONCERN: stale remote branch Ralph EOS scope). 1 auto-fix commit (prune + inbox drain + compress + tail). Verdict: GO.

## 2026-05-17 Sprint 14 Session-End Audit

- **Scope:** post-0.9.4 release. main @ 008f166, develop @ 331c99b.
- **Sec 1 (inbox):** Empty. PASS.
- **Sec 2 (history sizes):** Doc 13023B NEAR -- compressed to 12200B. All others OK. PASS (after fix).
- **Sec 3 (ASCII gate):** 60+ .md files carry non-ASCII (legacy debt pre-dating #334 hook expansion). ARCHITECTURE.md 1368B worst. CONCERN -- dedicated sweep needed Sprint 15.
- **Sec 4 (decisions):** All 6 Sprint 14 drops present. 13 canonical total. decisions.md 57096B. PASS.
- **Sec 5 (labels):** 32 total. priority:p3, platform:{linux,macos,windows} all present. PASS.
- **Sec 6 (worktree/branches):** Single worktree (develop). Local: develop + main only. 2 stale remote (release/0.9.4, squad/sprint14-retro) -- Ralph EOS scope. PASS with CONCERN.
- **Sec 7 (tag/release):** 0.9.4 tag exists, release published 2026-05-17. PASS.
- **Sec 8 (CHANGELOG):** [Unreleased] present, [0.9.4] - 2026-05-17 present. PASS.
- **Auto-fixes:** (1) Doc history compression 13023->12200B, (2) Sprint 13 EOS entry compressed.
- **CONCERNs (not auto-fixed):** (a) 60+ legacy non-ASCII .md files -- Sprint 15 sweep candidate, (b) 2 stale remote branches -- Ralph EOS.
- **Verdict:** PASS with CONCERNs (no blockers).



## 2026-05-17 Sprint 15 Session-End Audit

- **Scope:** post-0.9.5 release. main @ 49545ad, develop @ 2dadf58.
- **Sec 1 (inbox):** 1 file (scribe-sprint-15-retro-2026-05-17.md, 1457 B). Drained to decisions.md chronological journal. PASS.
- **Sec 2 (history sizes):** scribe 14491B NEAR gate (869B headroom, under 14800 threshold -- monitor only). Doc 13420B, Donald 12688B. All others under 12.5 KB. PASS.
- **Sec 3 (rogue files):** No _tmp_*, *.tmp, or leftover artifacts at repo root. git status clean. PASS.
- **Sec 4 (branches):** Local: develop + main only. Remote: origin/develop + origin/main only. No stale squad/* branches. PASS (clean).
- **Sec 5 (decisions.md size):** 60270 B post-drain. Over 60 KB threshold -- recommend archival next sprint. CONCERN.
- **Sec 6 (skill candidates):** 2 NEW flagged for Pluto follow-up: ascii-docs-about-non-ascii (medium, 2 apps), worktree-base-refresh (low, 1 app). No Jiminy action needed.
- **Auto-fixes:** (1) Inbox drain to decisions.md.
- **CONCERNs:** (a) decisions.md at 60270 B exceeds 60 KB -- archival recommended Sprint 16, (b) scribe history.md at 14491 B (869 B headroom) -- monitor next session.
- **Verdict:** PASS with CONCERNs (no blockers). Sprint 15 hygiene state is clean.

### Sprint 16 EOS Audit (2026-05-17T20:08:00-04:00)

- **Scope:** post-0.9.6 release. main @ 10d203f, develop @ aba8332. Tag 0.9.6 @ 38c0942.
- **Manifest:** 8 spawns (mickey-10, scribe-6, pluto-3/4/5, mickey-11/12, scribe-7).
- **Sec 1 (inbox):** 3 undrained files (mickey-s16-dispatch, mickey-s16-wrap, scribe-363-archival). FAIL -- Scribe drain needed.
- **Sec 2 (history sizes):** pluto 15694B OVER 15360B HARD GATE. All others pass. FAIL.
- **Sec 3 (rogue files):** None. Working tree clean. PASS.
- **Sec 4 (branches):** 3 stale remote squad/* branches (367-skill-drift-audit, s16-retro, scribe-s16-history-append). Ralph cleanup needed. CONCERN.
- **Sec 5 (orchestration-log):** No Sprint 16 entries. Only Sprint 15 log exists. CONCERN.
- **Sec 6 (git):** develop in sync. Tag correct. #373 regular merge confirmed. #368 on main = documented recovery. PASS.
- **Sec 7 (process):** 0 open PRs. Issue #371 labels correct. PASS.
- **Sec 8 (squash policy):** Charter says no squash on develop. Sprint 16 used squash for 6 PRs. Mismatch. FINDING (no auto-fix, history rewrite forbidden).
- **Auto-fixes:** (1) Wrote jiminy-s16-eos.md to inbox. (2) History append via branch PR.
- **Verdict:** DIRTY -- 2 blockers (inbox undrained, pluto gate breach). Session close BLOCKED pending Scribe action.
