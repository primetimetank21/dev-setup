# Sprint 15 Decisions

(Archived from .squad/decisions.md at Sprint 17 Wave 1 -- Issue #371.)
(Original content: Sprint 15 dispatch and retrospective, 2026-05-17.)

---

# Sprint 15 Dispatch - 2026-05-17

**By:** Mickey  
**Date:** 2026-05-17T15:20:00-04:00

## Issues Filed

### Issue #356: Sweep legacy non-ASCII chars from .md files
- **Owner:** squad:doc (Doc - mechanical docs sweep)
- **Labels:** squad, squad:doc, priority:p2, type:chore, release:backlog
- **Scope:** Run ascii-sweep.py, hand-fix non-ASCII in fenced blocks, verify pre-commit passes
- **Risk:** Low (purely mechanical text substitution, 60+ files)

### Issue #355: Normalize Sprint letter refs to numbers in CHANGELOG
- **Owner:** squad:scribe (Scribe - CHANGELOG editorial per #343/#344)
- **Labels:** squad, squad:scribe, priority:p2, type:chore, release:backlog (sync-squad-labels added squad:mickey, go:needs-research)
- **Scope:** Replace Sprint R/S/T with Sprint 11/12/13 in [0.9.1]/[0.9.2]/[0.9.3] sections
- **Risk:** Low (prose-only edit to already-shipped entries, append-only rule applies to headers only)

## Wave Plan

**Structure:** Parallel - both issues are independent text edits with no dependencies.  
**Rationale:** Non-blocking edits to different files; no merge conflict risk (only CHANGELOG touched by #355, only .md files touched by #356).

## Decisions

1. **Assign Issue #356 to Doc:** Doc's audit findings in Sprint 14 drove the scope; mechanical sweeps are appropriate for Doc's fact-checking role.
2. **Assign Issue #355 to Scribe:** Scribe owns CHANGELOG editorial per pattern established in #343/#344; retroactive labeling is a prose-only fix within scope.
3. **No compression needed:** history.md at 10275 bytes (under 15360 hard gate).

## Follow-up

- Both issues eligible for Squad routing auto-claim per issue labels.
- No commits or branches needed at this stage (pure issue filing).

---

## 2026-05-17 Sprint 15 Retrospective (Scribe Drop)

**Filed:** 2026-05-17  
**Source:** .squad/decisions/inbox/scribe-sprint-15-retro-2026-05-17.md  
**Topic:** Sprint 15 retrospective completion and skill candidates

### Summary

Sprint 15 retrospective complete and filed to `.squad/retros/2026-05-17-sprint-15-retro.md` (11730 B, 0 non-ASCII bytes). All 8 key lessons captured:

1. Scribe charter scope catch (CHANGELOG reassigned to Mickey)
2. gh squash-merge stray tmp branch quirk
3. Silent success on background spawn detected via filesystem state
4. Doc dual-worktree pattern (first Sprint 15 use)
5. Doc "self-documenting non-ASCII" trap (2nd sprint occurrence)
6. Branch ancestry hook caught stale sprint branch; recovery pattern validated
7. Atomic inbox drain forward-fix applied cleanly
8. Worktree-remove-FIRST held 4-of-4 (lifetime 25-of-25)

### Skill Candidates Flagged for Formalization

- ascii-docs-about-non-ascii (NEW, medium confidence, 2 applications)
- worktree-base-refresh (NEW, low confidence, 1 application)
- worktree-remove-first (confirm HIGH, no change)

### Release Notes

- 0.9.5 shipped; tag on main @ 49545ad
- 6 issues, 6 work PRs + 2 release PRs merged
- Develop at 2dadf58 (post-release)

### Decision

Accept retro as filed. Skill candidates routed to Pluto for drafting (ascii-docs-about-non-ascii, worktree-base-refresh). No action needed on worktree-remove-first (already HIGH confidence).

