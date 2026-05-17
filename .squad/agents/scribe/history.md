# Scribe History

**Role:** Session Logger, Memory Manager & Decision Merger  
**Mode:** Always spawned as background task. Never blocks user conversation.

---

> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place; no archive file). Re-compressed 2026-05-17 (W2 fold) per #319 gate -- Sprint 12 W2 fold entry condensed; Sprint 13 entries kept verbatim.

## Pre-2026-05-16 Activity (summary)

Compressed; older session logs kept as short bullets.

- **2026-04-07 to 2026-04-18** 12 session logs written to `.squad/log/` covering squad init, issue creation, Sprint 5 retro/close, Sprint 6 kickoff/alias-parity/wrapup, Sprint 7 implementation, PS 5.x hotfix retro, setup.ps1 scriptdir fix.
- **2026-04-18** Merged 6 decision inbox files into `decisions.md` (chip-121-hooks, chip-123-ci-triage, mickey-122-branch-isolation, mickey-bug-issues-124-125, mickey-hotfix-wrap, mickey-review-130). All inbox files deleted post-merge.
- **2026-04-18T20-53-40Z** Per-agent orchestration logs created: hotfix-sprint-wrap (Mickey), 121-git-hooks (Chip), 122-branch-isolation (Mickey), 123-ci-triage (Chip), review-129 (Mickey), review-130 (Mickey), sprint7-wrap (Mickey).
- **2026-04-18** Cross-agent history appended: Chip got Sprint 7 completion summary (#121, #123, PR #130); Mickey got full Sprint 7 execution summary.
- **2026-05-16** PR #200 merge + Issue #197 closed session logged.

---

## Learnings

- `git add .squad/` stages everything under `.squad/` including pre-existing untracked rogue files. Before staging, run `git status --porcelain -- .squad/` and confirm only intended files appear. If rogues exist, escalate to coordinator (do not auto-commit them).
- Decision inbox path (`.squad/decisions/inbox/`) is gitignored by design (`.gitignore:4`). Inbox files are drop-box drains, never committed. Drain by reading, merging content into `decisions.md`, then deleting the inbox file.
- Canonical squad write locations only: `agents/{name}/charter.md|history.md`, `decisions.md|decisions-archive.md`, `decisions/inbox/*.md`, `orchestration-log/*.md`, `log/*.md`, `skills/{name}/SKILL.md`, `templates/*.md`, `casting/*.json`, `identity/*.md`, `plugins/*.json`, `team.md|routing.md|ceremonies.md|config.json`. Any other path is rogue; flag to Jiminy.
- Canonical log dir is `.squad/log/` (singular). The stray `.squad/logs/` (plural) was deprecated 2026-05-16; do not write to `logs/`.
- Append-only convention for `casting/history.json`: mid-assignment additions use new entries with `type: "addendum"` and `parent_assignment_id`. Never mutate prior snapshots.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.


### Session drains 2026-05-16 to 2026-05-17 (summary, compressed)

- 2026-05-16: Sprint 8-hotfix wrap. Drained inbox decisions: mickey-squad-0.9.4-upgrade (#262), mickey-hire-doc (#263), doc-pr-263-fact-check. Log: `.squad/log/2026-05-16-sprint-q-wrap-0.8.0-0.9.4-doc-hire.md`.
- 2026-05-16: Sprint 9 wrap. Created retro (5 PRs #265-#269). Doc caught 2 bugs: autocrlf #267, pipefail #269.
- 2026-05-17: Sprint 10 retro (10 PRs #274-#283). Folded Jiminy history + backfilled Mickey #274.
- 2026-05-17: Sprint 11 retro (6 PRs #296-#302, gate clean twice, `gh --delete-branch` filed #300).
- 2026-05-17: Post-0.9.0 closeout (PR #291 pwsh-lastexitcode skill, PR #293 Doc/Jiminy dispatch pattern).
- 2026-05-17: Sprint 11 retro filed PR #303 (4 issues + 2 Jiminy audits). Renamed via PR #308 minutes later.
- 2026-05-17: Mini-event retro (0.9.1 release, sprint-naming rename, PR #305+#307+#308 Tier 3, backlog #309+#310).

## Learnings (Scribe)

- **Mini-event retros work.** When a session ships work that doesn't fit a full sprint retro (release cut + meta-cleanup + backlog sweep), a smaller-scope retro file is the right home. ~1-2 pages. Reference but don't rewrite any sprint retro it follows.
- **Label-vocab gotcha worth a one-line entry in any retro that hits it.** Future Scribes filing retros mentioning `gh issue create` failures should call out the actual label set. Six area labels: ci, hooks, windows, macos, linux, meta.
- **Sprint rename sweeps require Scribe to think about retro filenames.** When a Tier 3 rename runs in same session as a retro PR (this session: #303 filed -> #308 renamed it), the retro file itself gets `git mv`-ed and the H1 picks up the alias. Not a problem -- just flag so future Scribes don't double-write.
- **`(formerly Sprint X)` aliasing on first-occurrence-per-file** is team convention for historical references. Applied automatically in retros.
- **Sprint 12 Wave 1 fold (2026-05-17).** Folded 5-agent batch with 2 inbox decisions, 5 orchestration-log entries, 1 session log, 1 Jiminy history-rescue. Lessons earned: 5-agent batch fold pattern (one PR per wave, per-agent orchestration logs ~1-2 KB each with ISO 8601 UTC timestamps); Jiminy-history-rescue pattern (stage explicitly with `git add -- <path>`, do NOT broaden glob, note rescue in PR body); obsolete fold-request handling (delete inbox file without re-merging if content is already in place); size-gated 7-day archive cut (>=50 KB triggers rule, cut on trailing `---` separator, use `[System.IO.File]::WriteAllText` with no-BOM UTF8); history-summarization scope tension (defer when 15-KB hard gate fires outside fold scope -- discipline beats sprawl).

### 2026-05-17 -- Sprint 12 W2 fold + retro (summary)

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

- **Scope:** formalized two Scribe skills at medium confidence per Jiminy Sprint 13 EOS audit. One PR closes both #340 and #341.
- **Skills shipped:**
  - `.squad/skills/history-compression/SKILL.md` -- 4-step heuristic (front-matter verbatim, current sprint verbatim, older to dated bullets, preserve skill+incident refs), 13KB compress target with 15360 B hard gate, rebound-problem note. 3 applications cited (PR #319/#332, #333, #336).
  - `.squad/skills/per-topic-inbox-routing/SKILL.md` -- routing decision tree (append / new / delete-stale), atomic-rm model (inbox gitignored -> physical delete IS the atomic action; NOT `git rm`), dual-model coexistence (per-topic `.squad/decisions/*.md` canonical for inbox drains; `.squad/decisions.md` parallel chronological journal; both coexist). 2 applications cited (PR #333, #336) + forward-fix history from PR #323.
- **Dogfood:** applied history-compression skill to this very file post-append to stay under 15360 B gate. Sprint 13 verbose entries (W1 sweep + W1 fold + W2 fold + retro) condensed to dated bullets; Sprint 14 W1 (this entry) kept verbatim per spec.
- **Lesson (skill formalization threshold):** medium confidence at 2-3 applications; high confidence reserved for >=5 applications across distinct contexts. Both skills hit medium this wave.
- **Atomic-drain forward-fix:** N/A this wave (no inbox drops drained; pure skill formalization).

## 2026-05-17 Sprint 14 -- Release 0.9.4

- **Scope:** 6 issues, 7 work PRs + 2 release PRs, 84 GitHub issues migrated (label taxonomy), 0.9.4 shipped.
- **Ledger:** #340/#341 (Scribe skill formalizations), #342 (Doc+Mickey README audit+edit), #343 (Mickey CHANGELOG editorial), #347 (Pluto label 45->32), #350 (Pluto sync-squad-labels follow-ups), release PRs #352/#353 (Mickey+Coordinator).
- **Key wins:** 84-issue label migration with triple-verify protocol (252 verification reads, 0 halts). Both history-compression + per-topic-inbox-routing skills cleared >=5 applications, bumped to high confidence. README cleared 645 non-ASCII bytes via hand-conversion (fenced code block bypass). 5 new canonical decision files, inbox empty post-wave-1. Worktree-remove-FIRST pattern held 7-of-7 (lifetime 21-of-21).
- **Lessons:** GitHub close-keyword parser matches literal `close #N` substring regardless of negation context -- never use in ANY phrasing (broke #342, manually reopened). Pre-commit ASCII scan ignores code fences; pre-existing em-dashes in .yml workflows persist. sync-squad-labels.yml create-only (does not delete orphaned labels). Label taxonomy audit triple-verify model is reusable skill candidate. history-compression rebound persists: every fold followed by hygiene-tails causes rebounce.
- **Skill graduation:** 4th application of history-compression skill (this sprint: Scribe #345, Mickey #344/#348, Pluto #349, Mickey #352 release fold). 5+ applications lifetime (3 Sprint 13 + 5 Sprint 14) + distinct contexts (Scribe, Mickey, Pluto) -> high confidence. Per-topic-inbox-routing: every agent decision filed this sprint chose canonical routing (5+ applications Sprint 14 alone) -> high confidence.
- **Fold:** retro written to .squad/retros/2026-05-17-sprint-14-retro.md (~11.5 KB, ~300 lines). Skill confidence bumps documented in both SKILL.md files. CHANGELOG updated. 0 non-ASCII bytes in all commits (excluding pre-existing YAML em-dashes outside pre-commit scope). Release: 0.9.4 tagged at 008f166 (main).
- **Compression note (5th application this file):** history-compression skill applied post-append (6th application total, 5th this session). Pre-Sprint-14 history.md was 11352 B; post-append crossed 13000 B target (13622 B). Applied compression to session-drains section (lines 32-41 condensed to 7 dated bullets). Post-compression: 11850 B, under 13 KB target. No hard-gate violation.