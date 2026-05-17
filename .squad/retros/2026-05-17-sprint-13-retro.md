# Sprint 13 Retro -- 2026-05-17

Sprint 13 was a single-day intensive sprint focused on documentation
accuracy and ASCII policy hardening. Five backlog issues closed across
two waves, with nine PRs landed (seven work PRs plus two Scribe fold
PRs). Release 0.9.3 was cut and tagged at the end of the sprint. The
sprint also produced one formalized skill (`worktree-remove-first`) and
generated four new skill candidates for future cycles. Zero
worktree-isolation leaks occurred across nine agent dispatches,
confirming the Sprint 12 CWD-pin remediation is working.

## Sprint Summary

- Duration: 2026-05-17 (single-day intensive)
- Theme: Documentation accuracy and ASCII policy hardening
- Scope: 5 backlog issues closed (#317, #319, #322, #325, #326)
- PRs: 9 total (7 issue PRs + 2 Scribe fold PRs); 2 release PRs (#337,
  #338) on top
- Direct-push hygiene: 2 Jiminy commits (bd35b4b, 7c799be)
- Release: 0.9.3 tagged on main at edc67e2

## Sprint 13 at a Glance

| #    | Owner   | Title                                                       | PR / Status |
|------|---------|-------------------------------------------------------------|-------------|
| #325 | Mickey  | ARCHITECTURE.md stale auth.ps1 path (L54 + L505)            | #330 (batched with #326) Merged |
| #326 | Mickey  | README hooks count refresh (3 -> 4)                         | #330 Merged |
| #317 | Jiminy  | gh CLI worktree-variant merge failure (formalized as skill) | #331 Merged |
| #319 | Scribe  | 8 over-gate agent history.md files (HARD GATE enforcement)  | #332 Merged |
| #322A| Goofy   | ASCII sweep of all repo .md files                           | #335 Merged |
| #322B| Mickey  | Extend pre-commit ASCII scan to .md and .sh                 | #334 Merged |
| (fold) | Scribe | Wave 1 fold (inbox drain + jiminy re-compress)             | #333 Merged |
| (fold) | Scribe | Wave 2 fold (inbox drain + 4 history re-compress)          | #336 Merged |
| (release) | Mickey | 0.9.3 CHANGELOG fold + cut                              | #337 Merged |
| (release) | Coord  | develop -> main regular merge                            | #338 Merged |

## Wave Breakdown

- **Wave 1 (3 parallel):** Mickey #325+#326 (batched as PR #330),
  Jiminy #317 skill formalization (PR #331), Scribe #319 history
  archival sweep (PR #332). Followed by Jiminy post-batch hygiene
  fixes (direct push bd35b4b) and Scribe Wave 1 fold (PR #333,
  inbox drain + jiminy re-compress).
- **Wave 2 (2 parallel):** Goofy #322 part A `.md` sweep (PR #335)
  and Mickey #322 part B hook extension (PR #334). No file overlap.
  Followed by Scribe Wave 2 fold (PR #336, inbox drain + 4 history
  re-compress) and Jiminy catch-up of Mickey's dogfood-deferred
  hygiene-tail (direct push 7c799be).
- **Release fold:** Mickey 0.9.3 CHANGELOG fold (PR #337), develop
  -> main merge (PR #338), tag `0.9.3` pushed at edc67e2, GitHub
  Release published.

## What Went Well

- **CWD-pin remediation: 0 worktree-isolation leaks across 9 agent
  dispatches.** The mandatory `Set-Location -LiteralPath` + verify
  block introduced in Sprint 12 Wave 3 (after Mickey's #310
  incident) ran cleanly through every Sprint 13 dispatch. Post-flight
  audits of the main checkout returned EMPTY each time.
- **Worktree-remove-FIRST pattern proven 100%.** 9-of-9 clean merges
  in Sprint 13, on top of 5-of-5 in Sprint 12 = 14-of-14 lifetime
  success rate. The pattern is now codified as a skill
  (`.squad/skills/worktree-remove-first/SKILL.md`) per PR #331,
  closing #317 without a code fix.
- **CHANGELOG sub-section split auto-resolved cross-PR conflicts.**
  Splitting `[Unreleased]` into Added / Changed / Fixed / Removed
  sub-headings meant Wave 1 PRs #330, #331, #332 each appended to
  different sub-sections and merged without textual conflict on the
  CHANGELOG.
- **`scripts/lib/ascii-sweep.py` is reusable.** Goofy's #322 part A
  helper is generic over file globs and Unicode replacement maps;
  future ASCII normalization passes can reuse it directly.
- **2-issue batching saved a PR cycle.** Mickey rolled #325 and #326
  into a single PR (#330) since both were narrow doc fixes in
  ARCHITECTURE.md and README.md respectively. Second application of
  the "batch narrow doc fixes" pattern; one more cycle justifies a
  skill.
- **Goofy + Mickey parallel Wave 2 ran clean.** Goofy touched repo
  `.md` content; Mickey touched `hooks/pre-commit`. Zero file overlap
  meant the two PRs (#334, #335) merged in either order without
  conflict.
- **Only 1 CHANGELOG rebase conflict surfaced this sprint.** PR
  #332 (Scribe history archival) rebased against PRs #330/#331 and
  required 3-way merging on `.squad/agents/*/history.md` -- auto
  resolved cleanly because each agent's history block was
  independent.

## What We Learned / What to Improve

- **Dogfood pattern (NEW).** Mickey's Wave 2 hook extension (#322
  part B, PR #334) caught his own pre-existing non-ASCII bytes in
  `.squad/agents/mickey/history.md` once the extended pre-commit hook
  was active. Mickey deferred his own hygiene-tail rather than block
  on a same-PR cleanup; Jiminy then auto-applied the catch-up via
  Option A summarization (direct push 7c799be). This is a HEALTHY
  signal -- the new gate immediately enforces policy on first run.
  The "ship-test + eat-dogfood" pattern (one application this sprint)
  is a skill candidate.
- **Doc roster correction.** Coordinator briefly flagged
  `.squad/agents/doc/` as stray during dispatch planning. Memory was
  stale from before Doc was hired. Doc joined in Sprint 10-11
  (~2026-05-17) per his charter. The current active roster is 10
  agents (Mickey, Donald, Chip, Goofy, Pluto, Jiminy, Scribe, Ralph,
  Doc, plus Coordinator). Dispatch prompts and roster memory should
  be updated to reflect this.
- **Decisions store has two parallel models.** BOTH per-topic files
  (`.squad/decisions/<topic>.md`) AND consolidated journals
  (`.squad/decisions.md` + `.squad/decisions-archive.md`) exist. The
  per-topic files are canonical for Scribe inbox drains starting
  Sprint 13 (Wave 1 fold introduced
  `scribe-history-compression.md`; Wave 2 fold introduced
  `mickey-hook-policy.md` and `goofy-ascii-sweep.md`). The
  chronological `decisions.md` continues to serve as a parallel
  journal. Memory has been corrected; future Scribe folds should
  default to per-topic routing.
- **Inbox atomic-drain (forward-fix from Sprint 12 PR #323).** The
  Sprint 12 bug was that drop CONTENT was merged but source files
  were not removed atomically. Since `.squad/decisions/inbox/*.md`
  is gitignored (`.gitignore:4`), `git rm` cannot stage tracked
  deletions. The atomic drain action is therefore a PHYSICAL
  filesystem delete in the same wall-clock action as the per-topic
  appends. This pattern shipped successfully on Scribe Wave 1 fold
  (#333) and Wave 2 fold (#336) and is now codified as the standard
  Scribe model.
- **History rebound problem.** Scribe's #319 sweep brought 8 over
  gate files under the 15 KB HARD GATE, but rebase preservation of
  in-flight hygiene-tail entries from Mickey and Jiminy brought
  `jiminy/history.md` back over gate at 22548 B after Wave 1 land.
  Wave 1 fold #333 re-compressed it to 13078 B. Wave 2 audit-tails
  then bumped 4 files over gate again (jiminy 18091, goofy 15158,
  scribe 15076, mickey 15024); Wave 2 fold #336 re-compressed all
  four. Pattern: every fold must follow with a size-check + re
  compress pass. Alternatively, Scribe should compress AFTER all
  hygiene-tails land, not before, to avoid double work. Worth
  evaluating in Sprint 14 dispatch sequencing.
- **`gh --admin --squash --delete-branch` after worktree-remove is
  rock solid.** 5-of-5 in Sprint 12 + 9-of-9 in Sprint 13 = 14-of-14
  lifetime success. With the pattern now formalized as a skill
  (PR #331), `#317` is closed and the procedural guard stays in
  effect.
- **History-compression heuristic has 3 applications now.** Initial
  sweep (#319, Wave 1), Wave 1 fold jiminy re-compress, and Wave 2
  fold 4-file re-compress. The WHAT-to-preserve heuristic (front
  matter verbatim; latest sprint verbatim; older sessions as date +
  outcome + PR/issue bullets; skill triggers and recurring-incident
  refs literal) generalized cleanly each time. Threshold met; a
  `.squad/skills/history-compression/SKILL.md` formalization is the
  natural next-sprint deliverable for Scribe.
- **Per-topic inbox routing has 2 applications.** Wave 1 fold drained
  3 drops into per-topic files (one new file:
  `scribe-history-compression.md`); Wave 2 fold drained 3 drops with
  two more new per-topic files (`mickey-hook-policy.md`,
  `goofy-ascii-sweep.md`). One more application would justify
  formalizing the routing rules as a skill.

## Backlog Carried to Sprint 14

- **0 issues open** post-Sprint-13. Backlog is empty. Sprint 14 will
  open with fresh triage.

## Skill Candidates (Sprint 13 outputs)

- **Formalized this sprint (1):**
  - `worktree-remove-first` -- PR #331 (closes #317). Documents the
    gh CLI worktree-variant merge failure mode and the proven
    workaround (now 14-of-14 lifetime).
- **Candidates for Sprint 14 formalization:**
  - **"Batch narrow doc fixes into one PR"** -- 2 applications
    (Sprint 12 Donald #236+#237 considered but split; Sprint 13
    Mickey #325+#326 in PR #330 was clean). One more cycle justifies
    a skill.
  - **"ASCII sweep methodology"** -- 1 application (Goofy Wave 2
    + `scripts/lib/ascii-sweep.py`). The script is reusable; the
    methodology (helper-driven sweep + targeted exceptions) could
    be a skill on second application.
  - **"Ship-test + eat-dogfood"** -- 1 application (Mickey Wave 2
    #322 part B caught his own bytes once the extended hook ran).
    Pattern: agent extending an enforcement mechanism should
    expect to be the first violator caught by the new rule. One
    more cycle justifies a skill.
  - **"History-compression heuristic"** -- 3 applications this
    sprint (sweep + 2 folds). Threshold MET; should be formalized
    in Sprint 14 by Scribe.
  - **"Per-topic inbox routing"** -- 2 applications (Wave 1 + Wave
    2 folds). Could formalize next.

## Metrics

- Issues closed: 5 (#317, #319, #322, #325, #326)
- PRs merged: 9 (7 issue PRs + 2 Scribe fold PRs) + 2 release PRs
  (#337, #338) = 11 total this sprint
- Direct-push hygiene commits: 2 (bd35b4b Jiminy Wave 1 post-batch;
  7c799be Jiminy Mickey-dogfood catch-up)
- ASCII normalization: ~2,501 non-ASCII chars swept across 124
  `.md` files (Goofy #322 part A)
- Worktree-isolation leaks: 0 across 9 dispatches
- History compression: 8 files compressed in #319 sweep; 1 file
  re-compressed in Wave 1 fold; 4 files re-compressed in Wave 2
  fold. All 9 active agent history files end the sprint under the
  15 KB HARD GATE.
- New per-topic decisions files: 3
  (`scribe-history-compression.md`, `mickey-hook-policy.md`,
  `goofy-ascii-sweep.md`)
- Release: 0.9.3 tagged at edc67e2; GitHub Release published

## Release Readiness

- `[Unreleased]` CHANGELOG: empty at sprint end (folded into 0.9.3)
- Open issues: 0 (backlog drained)
- Suggested Sprint 14 themes:
  - Skill formalizations (history-compression, per-topic-routing,
    ascii-sweep-methodology, batch-narrow-doc-fixes,
    ship-test-eat-dogfood)
  - CI gate evaluations (e.g., GitHub Actions auto-label-from-
    linked-issue carried from Sprint 12)
  - Testing or coverage gap audits (no specific issues outstanding)

## Action Items into Sprint 14

1. Scribe: formalize `.squad/skills/history-compression/SKILL.md`
   (3 applications met threshold).
2. Scribe: evaluate dispatch sequencing so re-compression happens
   AFTER all hygiene-tails land, not before, to avoid rebound work.
3. Update roster memory and dispatch prompts to reflect 10-agent
   roster including Doc.
4. Codify per-topic vs chronological decisions-store model in
   Scribe charter or a dedicated skill.
5. Continue tracking skill candidates from Section 6 for
   second-application formalization triggers.
