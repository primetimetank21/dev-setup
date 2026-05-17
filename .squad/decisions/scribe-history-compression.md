# Decision: Scribe history-compression workflow

**By:** Scribe (Session Logger / Knowledge Keeper)
**Issue:** #319
**Date:** 2026-05-17

---

## 2026-05-17 Sprint 13 Wave 1 -- history archival sweep

**What shipped:** Compressed 8 over-gate `.squad/agents/*/history.md` files per the Scribe charter 15 KB HARD GATE.

Two compression options were applied per file size:

- **Option B (split with `history-archive.md`):**
  - `mickey` -- 80823 -> 12076 B live + archive 57671 B
  - `goofy` -- 39857 -> 13923 B live + archive 24057 B
  - `chip` -- 36943 -> 12470 B live + archive 19911 B
- **Option A (summarize-in-place, no archive file):**
  - `pluto` -- 29712 -> 14792 B
  - `donald` -- 28539 -> 12712 B
  - `jiminy` -- 28051 -> 8630 B
  - `ralph` -- 28464 -> 9503 B
  - `scribe` -- 20511 -> 13334 B (including the Sprint 13 hygiene-tail entry)

All 9 agent histories under 15 KB after the sweep.

**Why:** The charter HARD GATE was breached on 8 of 9 agents. Jiminy's Sprint 12 session-end audit (PR #318) and PR #323 surfaced the size pressure; #319 was filed as Sprint 13 P0.

## Compression heuristic (lesson candidate for `.squad/skills/history-compression/SKILL.md`)

1. Keep front-matter sections verbatim (`Project Context`, `Key Details`, `Core Context`, `Learnings` preamble).
2. Keep most-recent-sprint entries verbatim (Sprint 11+ during the Sprint 13 sweep, since Sprint 12 was just wrapped).
3. Reduce older sessions to dated one-line bullets: `YYYY-MM-DD -- <what shipped> (PR/issue refs)`.
4. Preserve literally: skill triggers, recurring-incident patterns (worktree-isolation, ASCII gaps, autocrlf, AllScope alias, CP1252 trap), and PR/issue cross-refs that future archaeology needs.
5. Defer formalization to `.squad/skills/history-compression/SKILL.md` until a 2nd application confirms the heuristic generalizes.

## Scope boundaries honored

- No edits to `decisions/*.md` topic files (separate workflow).
- No edits to non-`history.md` files (except the `CHANGELOG.md` entry per spec).
- No retroactive review/judgement of agent past decisions -- Scribe is custodian, not critic.

## Forward-fix reminder (from PR #323 atomic-drain bug)

When folding `.squad/decisions/inbox/` drops in a future cycle, the per-topic-file append AND the removal of the source drop file MUST land in the SAME commit so drain is atomic with merge. The Sprint 13 Wave 1 fold (this PR's companion) explicitly re-tests this guarantee.

## 2026-05-17 Sprint 13 Wave 1 fold -- jiminy/history.md re-compression

Post-sweep regression: `.squad/agents/jiminy/history.md` regressed from 8630 B to 22548 B after Sprint 12 hygiene tails + the Sprint 13 Wave 1 post-batch audit tail were rebased back in. Re-compressed in this fold under Option A: older Sprint 12 verbose audit blocks reduced to one-line bullets; Sprint 13 Wave 1 entries (Jiminy's own + post-batch audit) preserved verbatim per spec; recurring-incident references (worktree-isolation, ASCII gap, atomic-drain) preserved verbatim.

This is the **2nd application** of the compression heuristic (1st was the Sprint 13 Wave 1 sweep above). One more application would justify formalizing as `.squad/skills/history-compression/SKILL.md`.


## 2026-05-17 Sprint 13 Wave 2 -- Scribe W1 fold outcome (forward-fix verification)

**By:** Scribe (folded from inbox drop `scribe-w1-fold-2026-05-17.md`)
**Issue:** follow-on to #319; forward-fix of PR #323 atomic-drain bug
**PR:** Sprint 13 W1 fold companion PR

**What happened:**

- Drained 3 Sprint 13 Wave 1 inbox drops into per-topic decisions files (atomic with this commit):
  - `mickey-w1-2026-05-17-issues-325-326.md` -> appended to `mickey-architecture-entry-point.md` (broadened topic to ARCH+README accuracy; 2710 -> 4207 B)
  - `jiminy-w1-2026-05-17-issue-317-skill.md` -> appended to `doc-and-jiminy-automation.md` (hygiene-automation theme; 12115 -> 14152 B)
  - `scribe-w1-2026-05-17-history-archival.md` -> NEW `scribe-history-compression.md` (this file; 3242 B)
- Re-compressed `.squad/agents/jiminy/history.md` from 22548 B back to 13078 B (Option A summarize-in-place). Sprint 13 Wave 1 entries kept verbatim per spec; older Sprint 12 verbose audits reduced to one-line bullets; recurring-incident references (worktree-isolation, ASCII gap, atomic-drain) kept literal.

**Atomic-drain verification (canonical model going forward):**

Inbox is gitignored (`.gitignore:4: .squad/decisions/inbox/`), so `git rm` cannot stage tracked deletions. The drain is enforced by physically removing the source drop files from the main-checkout inbox in the same wall-clock action as the per-topic append. Validation: `Get-ChildItem .squad/decisions/inbox/` in the main checkout must NOT contain the drained files when this PR merges. **A future Scribe should not look for `git rm` of inbox files -- physical delete IS the atomic action.** This forward-fix decision drop (`scribe-w1-fold-2026-05-17.md`) was itself folded in the next cycle (Sprint 13 W2 fold).

**Sizes:**

- jiminy/history.md before W1 fold: 22548 B; after: 13078 B (target was <13312 B, achieved 234 B headroom)
- scribe/history.md after Sprint 13 W1 Fold hygiene-tail: 15076 B (still under 15 KB hard gate, but tight -- prompted W2 fold re-compress of scribe + 3 others)
- Target topic files written: `mickey-architecture-entry-point.md`, `doc-and-jiminy-automation.md`, `scribe-history-compression.md` (new)

**Scope boundaries honored:** No other agent histories compressed in W1 fold (jiminy was the only regression). No hooks/scripts/code touched. No consolidated `decisions.md` reintroduced -- per-topic model is current state.