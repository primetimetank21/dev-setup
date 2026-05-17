# Decision: Mickey release-process pattern

**By:** Mickey (Lead)
**Topic:** release / sprint-wrap
**Date:** 2026-05-17

---

## 2026-05-17 Sprint 13 -- 0.9.3 release fold

**By:** Mickey (folded from inbox drop `mickey-release-093-2026-05-17.md` by Jiminy session-end audit)
**Source:** develop @ d33691c -> release/0.9.3 -> PR #337 -> develop @ 031f317 -> PR #338 -> main @ edc67e2 -> tag `0.9.3`

**Scope:** Cut 0.9.3 CHANGELOG fold from develop. Eight entries folded under [0.9.3]:

- 1 Added: #317 worktree-remove-FIRST skill
- 4 Changed: #322A ASCII sweep, #319 history compress, W1 fold, W2 fold
- 3 Fixed: #325 ARCH path, #326 README hooks count, #322B hook ASCII extension
- 0 Removed

**Theme chosen:** "Sprint 13: Documentation accuracy and ASCII policy hardening" -- captures the two structural shifts (doc fixes #325/#326 + ASCII sweep #322A and hook extension #322B). Skipped the broader "markdown ASCII enforcement and squad hygiene" framing because doc-accuracy was the louder signal.

## Release pattern (3rd clean application: 0.9.1, 0.9.2, 0.9.3)

Same sequence each cut:

1. Mickey opens release/0.9.X branch from develop.
2. Mickey edits CHANGELOG to fold `[Unreleased]` entries under `[0.9.X] - YYYY-MM-DD -- <theme>`.
3. Mickey opens PR to develop (regular merge, preserve history).
4. Coordinator opens develop -> main PR (regular merge).
5. Coordinator tags `0.9.X` on main + `gh release create`.

Mickey's job ends at PR-open in step 3. No squash; no force-push.

**Why the pattern works:** Regular merge preserves the per-PR merge commits in the develop -> main mainline. Tag lands on main only. develop history stays linear-by-PR.

## Next-sprint hints (Sprint 14 candidates)

- Remaining ASCII gaps in non-`.md` / `.sh` / `.ps1` files; possible expansion of pre-commit ASCII scan to `.yml` / `.json` / `.txt`.
- Doc subagent worktree exercise (still untriggered as of Sprint 11 retro).
- Revisit history.md gate thresholds now that 15 KB has held two sprints with re-compress headroom.
- Watch the dogfood-incident pattern (own hook blocks own commit on legacy debt) -- if it recurs in Sprint 14, formalize as a skill per Mickey's #334 history note.

**Scope boundaries:** This file documents Mickey-owned release-cut pattern only. Tag / release-creation / develop -> main merge belong to Coordinator workflow (separate topic). Per-release CHANGELOG content lives in `CHANGELOG.md`, not here.
