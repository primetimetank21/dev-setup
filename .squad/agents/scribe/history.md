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


### Session drains 2026-05-16 to 2026-05-17 (summary)

- **2026-05-16 Sprint 8-hotfix wrap.** Drained 3 inbox decisions (mickey-squad-0.9.4-upgrade PR #262, mickey-hire-doc-fact-checker PR #263, doc-pr-263-fact-check). Doc's first-run reflections + Mickey's PR #262 audit reflection appended to respective history.md files. Session log: `.squad/log/2026-05-16-sprint-q-wrap-0.8.0-0.9.4-doc-hire.md`.
- **2026-05-16 Sprint 9 wrap + retro + agent histories.** Drained 1 inbox (doc-sprint-r-batch-fact-check). Created `.squad/retros/2026-05-16-sprint-r-retro.md`: 5 PRs (#265-#269), follow-up #271 filed, Doc verdicts caught 2 real bugs pre-merge (autocrlf #267, pipefail #269). Appended Sprint 9 entries to chip/goofy/pluto histories.
- **2026-05-17 Sprint 10 retro + agent histories fold.** Created `.squad/retros/2026-05-17-sprint-s-retro.md` covering 10 PRs (#274-#283). Folded Jiminy's modified history (couldn't direct-commit per pre-commit Check 5). Backfilled Mickey Sprint 10 entry for PR #274 (Mickey shipped without writing -- gap caught by Jiminy). Drained 2 inbox decisions locally (already folded into doc/history.md via PRs #281+#283; inbox gitignored). Skipped Ralph (not dispatched for Sprint 10 EOS yet).
- **2026-05-17 Sprint 11 retrospective.** Created `.squad/retros/2026-05-17-sprint-t-retro.md` covering 6 PRs (#296-#302). First exercise of #293 SOPs (post-batch Jiminy gate fired clean twice). Sequential Goofy pattern validated. Group EE test addition. `gh --delete-branch` quirk filed as #300. Renamed via `git mv` in PR #308 minutes later.
- **2026-05-17 Post-0.9.0 Action Items Closeout.** Amended Sprint 10 retro in-place with closures for PR #291 (pwsh-lastexitcode skill + #292 spillover) and PR #293 (Doc worktree Option B + Jiminy auto-dispatch Option A; replaces #281+#283 dual-fold pattern). No new retro file -- 3-PR follow-up too small. CONTRIBUTING.md already updated by #291+#293; CHANGELOG references intact.
- **2026-05-17 Sprint 11 retro filed (PR #303).** Filed retro covering 4 work PRs (#296/#297/#298/#301) closing 4 issues + 2 bonus Jiminy audit PRs (#299/#302). Merged 04:16 UTC before 0.9.1 cut. Filename `git mv`-renamed via PR #308 Tier 3 sprint-naming sweep minutes later.
- **2026-05-17 Mini-event retro: 0.9.1 release + sprint naming rename.** Created `.squad/retros/2026-05-17-sprint-11-release-and-rename-retro.md` covering work after PR #303 in same session (0.9.1 PRs #305+#307, tag, GH release, Tier 3 sweep #308 + Doc commit `56c3c1f`, Sprint 12 backlog #309+#310). Decision: mini-events get tighter retro file rather than session log fold (sprint-naming policy is permanent; operational learnings would get lost in `.squad/log/`).

## Learnings (Scribe)

- **Mini-event retros work.** When a session ships work that doesn't fit a full sprint retro (release cut + meta-cleanup + backlog sweep), a smaller-scope retro file is the right home. ~1-2 pages. Reference but don't rewrite any sprint retro it follows.
- **Label-vocab gotcha worth a one-line entry in any retro that hits it.** Future Scribes filing retros mentioning `gh issue create` failures should call out the actual label set. Six area labels: ci, hooks, windows, macos, linux, meta.
- **Sprint rename sweeps require Scribe to think about retro filenames.** When a Tier 3 rename runs in same session as a retro PR (this session: #303 filed -> #308 renamed it), the retro file itself gets `git mv`-ed and the H1 picks up the alias. Not a problem -- just flag so future Scribes don't double-write.
- **`(formerly Sprint X)` aliasing on first-occurrence-per-file** is team convention for historical references. Applied automatically in retros.
- **Sprint 12 Wave 1 fold (2026-05-17).** Folded 5-agent batch with 2 inbox decisions, 5 orchestration-log entries, 1 session log, 1 Jiminy history-rescue. Lessons earned: 5-agent batch fold pattern (one PR per wave, per-agent orchestration logs ~1-2 KB each with ISO 8601 UTC timestamps); Jiminy-history-rescue pattern (stage explicitly with `git add -- <path>`, do NOT broaden glob, note rescue in PR body); obsolete fold-request handling (delete inbox file without re-merging if content is already in place); size-gated 7-day archive cut (>=50 KB triggers rule, cut on trailing `---` separator, use `[System.IO.File]::WriteAllText` with no-BOM UTF8); history-summarization scope tension (defer when 15-KB hard gate fires outside fold scope -- discipline beats sprawl).

### 2026-05-17 -- Sprint 12 Wave 2 fold (summary)

- Drained 4 inbox decisions to `.squad/decisions.md` under "## 2026-05-17 entries (Sprint 12 Wave 2 fold)": mickey-arch-windows-dep (closes #310), donald-test-harness (closes #237), goofy-install-guard-deferral (Case B closure, closes #235 not_planned), jiminy-wave-2-audit (worktree-isolation remediation, surfaces #322).
- Folded staged history modifications (goofy + jiminy) from MAIN checkout via explicit `git add --`. Coordinator clears M state with `git checkout -- ...` post-merge.
- decisions.md gate: 44473 -> 57253 B (50 KB hard gate crossed) but 0 entries eligible for 7-day archive cut (oldest live entry was 3 days old; strict-rule reading: archive step ran with empty eligibility set).
- Orchestration log entries written for 5 wave events (PRs #320/#321, Goofy #235 Case B close, Jiminy audit, #322 filing). Dir gitignored -- local-only.
- Session log at `.squad/sessions/2026-05-17.md` (dispatch convention vs Scribe charter's `.squad/log/` -- both gitignored; possible drift to reconcile).
- CHANGELOG [Unreleased] -> Changed: one fold-note entry.
- Guardrails: branch off develop @ def5e59, no direct commits, conventional `docs(scribe):` prefix, explicit-path staging only, worktree CWD pinned per Jiminy W2 audit remediation.
- **History gate WARNINGS:** 8 of 9 agents at/above 15 KB warn line (scribe 15.8, chip 36.9, donald 28.5, goofy 39.9, jiminy 24.3, mickey 75.5, pluto 29.7, ralph 23.9). Pluto + Doc healthy. Surfaced #319 (Sprint 13 P0) as archival-sweep follow-up.
- **2026-05-17 -- Sprint 12 retrospective + Jiminy session-end audit fold.** Created `.squad/retros/2026-05-17-sprint-12-retro.md` (10268 B, ASCII clean). Covers 3 waves, 10 PRs (8 work + 2 Scribe folds), 9 Sprint 12 issues closed, scope rebalances (#254 Mickey->Pluto, #235 Mickey->Goofy), 5 follow-ups carried (#317, #319, #322, #325, #326). Harvested Jiminy session-end audit from main (24344 -> 28051 B) into branch alongside retro. CHANGELOG Changed appended.
- **Lesson (own bug, fix forward) -- atomic inbox drain.** Wave 2 fold (PR #323) merged 4 drop files' CONTENT to decisions.md but did NOT `git rm` the source drops -- Coordinator manually deleted post-Jiminy audit. Going forward, every Scribe fold MUST stage the source-drop deletion in the SAME commit as the append. Per-file staging discipline preserved (no bulk glob).
- **Lesson (own bug, write-path resolution) -- .NET file APIs use process CWD, not PowerShell `Set-Location`.** `[System.IO.File]::ReadAllBytes(".\path")` resolved against main checkout (process CWD) not worktree. Fix: ALWAYS use absolute paths with .NET APIs. PS native cmdlets (`Get-Content -LiteralPath`, `Get-Item`) respect `Set-Location`; .NET static methods do not. Same failure class as Mickey #310 worktree-isolation violation.


## 2026-05-17 Sprint 13 Wave 1 -- History archival sweep (#319)

- **Scope:** 8 over-gate .squad/agents/*/history.md files compressed under the 15 KB Scribe charter HARD GATE.
- **Strategy:** Option B (split with history-archive.md) for mickey/goofy/chip (largest). Option A (summarize-in-place) for pluto/donald/jiminy/ralph/scribe. Front matter + last sprint verbatim; older sessions reduced to dated one-line bullets preserving lessons + PR/issue cross-refs.
- **Before/after (bytes):** mickey 80823 -> 12076 (+ archive 57671); goofy 39857 -> 13923 (+ archive 24057); chip 36943 -> 12470 (+ archive 19911); pluto 29712 -> 14792; donald 28539 -> 12712; jiminy 28051 -> 8630; ralph 28464 -> 9503; scribe 20511 -> 11831 (this entry included). All 9 agent histories now under 15 KB; doc was already 10169 (untouched).
- **Forward fix from PR #323 bug (atomic drain):** confirmed for next inbox fold cycle -- git add -- decisions.md AND git rm -- .squad/decisions/inbox/*.md MUST land in the SAME commit so drain is atomic with merge. Surfaced by Jiminy Sprint 12 session-end audit.
- **Lesson candidate (history-compression):** the WHAT-to-preserve heuristic that worked here: (a) Key Details / Core Context / Learnings preamble verbatim; (b) most recent sprint(s) verbatim; (c) older sessions as date + outcome + PR/issue ref bullets; (d) skill triggers and recurring-incident patterns kept literal even when compressed. Not yet formalized as a skill -- second application will tell if it generalizes.

## 2026-05-17 Sprint 13 Wave 1 Fold

- **Scope:** drained 3 inbox drops into per-topic decisions files AND re-compressed .squad/agents/jiminy/history.md back under the 15 KB charter gate.
- **Drops drained (3/3):**
  - mickey-w1-2026-05-17-issues-325-326.md (1404 B) -> appended to .squad/decisions/mickey-architecture-entry-point.md (broadened to ARCH+README accuracy fixes; 2710 -> 4207 B).
  - jiminy-w1-2026-05-17-issue-317-skill.md (1663 B) -> appended to .squad/decisions/doc-and-jiminy-automation.md (hygiene-automation theme; 12115 -> 14152 B).
  - scribe-w1-2026-05-17-history-archival.md (2137 B) -> NEW .squad/decisions/scribe-history-compression.md (3242 B; will be referenced by future folds and as skill candidate).
- **Atomic-drain forward-fix (from PR #323 bug):** verified -- the 3 source drops are removed from main-checkout inbox in the SAME PR as the per-topic appends. Inbox files are gitignored, so the removal lives on the filesystem rather than in the git index; documented in the new forward decision drop.
- **jiminy/history.md re-compress (Option A):** 22548 -> 13078 B. Older Sprint 12 verbose audit blocks reduced to one-line bullets; Sprint 13 Wave 1 entries (Jiminy's own + post-batch audit) preserved verbatim per spec; recurring-incident references (worktree-isolation, ASCII gap, atomic-drain, CP1252, autocrlf, AllScope) preserved literal. Target was <13312 B (13 KB) with 2 KB headroom; achieved 13078 B (234 B headroom).
- **Lesson (2nd application of compression heuristic):** the same WHAT-to-preserve heuristic from the Sprint 13 sweep generalized cleanly to a single-file re-compress after rebase regression. One more application would justify formalizing .squad/skills/history-compression/SKILL.md.

## 2026-05-17 Sprint 13 Wave 2 Fold

- **Scope:** drained 3 Sprint 13 W2 inbox drops to per-topic decisions files + re-compressed 4 over-gate agent history.md files back under 15 KB charter gate.
- **Drops drained (3/3):** scribe-w1-fold-2026-05-17.md (2414 B) -> scribe-history-compression.md (3190 -> 5603 B); mickey-w2-2026-05-17-hook-extension.md (1942 B) -> NEW mickey-hook-policy.md (2833 B); goofy-w2-2026-05-17-ascii-sweep.md (1656 B) -> NEW goofy-ascii-sweep.md (2661 B; ascii-sweep skill seed).
- **Atomic-drain forward-fix:** 3 source drops physically deleted from main-checkout inbox in same wall-clock action as per-topic appends. Inbox is gitignored (.gitignore:4); `git rm` cannot stage tracked deletions -- **physical delete IS the atomic action**. Future Scribes should not look for `git rm` of inbox files. Codified in scribe-history-compression.md.
- **Histories re-compressed (4/4) Option A summarize-in-place:** jiminy 18091 -> 13550 (Day-1 hire context + W1 audit condensed; W1+W2 verbatim); goofy 15158 -> 10925 (Sprint 11 #230/#292 + Sprint 12 #235 deferral condensed; W2 #322A verbatim); scribe 15076 -> 13294 pre-tail (Sprint 12 W2 fold + retro+audit-fold condensed; Sprint 13 verbatim); mickey 15024 -> 12988 (Sprint 11/12 + 0.9.2 release condensed; W1+W2 verbatim).
- **Preserved verbatim across all 4:** worktree-isolation, ASCII gap, atomic-drain, CP1252, autocrlf, AllScope, dogfood, abstraction-threshold incident references.
- **Compression heuristic 3rd application** (W1 sweep + W1 fold jiminy re-compress + this W2 4-file sweep) -- threshold met; formalize `.squad/skills/history-compression/SKILL.md` next cycle.
- **Hook validation:** all 4 histories + 3 decisions files = 0 non-ASCII bytes (byte-level scan pre-push). Post-#334 hook (.ps1|.md|.sh ASCII gate) expected to pass.
- CHANGELOG [Unreleased] -> Changed: one fold-note entry.