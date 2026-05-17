# Decision: Mickey hook policy

**By:** Mickey (Lead, architecture + hooks owner)
**Topic:** ``hooks/pre-commit`` and related guard policy
**Created:** 2026-05-17 (Sprint 13 Wave 2)

This file is the per-topic decisions store for Mickey-owned hook decisions. Append future hook scope / policy choices here.

---

## 2026-05-17 Sprint 13 Wave 2 -- extend pre-commit Check 2 ASCII scan beyond .ps1

**By:** Mickey (folded from inbox drop ``mickey-w2-2026-05-17-hook-extension.md``)
**Issue:** #322 part B
**Status:** Implemented (PR #334)

### Context

``hooks/pre-commit`` Check 2 globbed only ``*.ps1`` for non-ASCII bytes. Real-world audit: ``ARCHITECTURE.md`` had 134 non-ASCII hits, ``README.md`` 60, ``CONTRIBUTING.md`` 12 -- every one escaped the hook. Goofy swept the existing content (#322 part A); Mickey's job was preventing regression.

### Decision

Extend the Check 2 glob to scan ``.ps1``, ``.md``, and ``.sh`` files. Single-pass loop. No allow-list carve-outs.

### Alternatives considered

1. **Add only ``.md``.** Insufficient -- ``.sh`` files are equally vulnerable to copy-paste em-dashes; defensive scan is cheap.
2. **Add ``.py`` and ``.yml`` too.** Skipped: no ``.py`` files exist in repo; ``.yml`` is mostly CI template scaffolding where non-ASCII risk is low and false-positive risk (e.g. action descriptions) is non-zero. Revisit if a future incident lands in ``.yml``.
3. **Allow-list ``.squad/retros/*.md`` (semantic prose).** Rejected. Cleanest model is "scan all .md, no exceptions" -- retros that need em-dashes can use ``--`` like every other doc. Goofy is sweeping retros in part A regardless.

### Implementation

- ``hooks/pre-commit`` Check 2 regex: ``\.ps1$`` -> ``\.(ps1|md|sh)$``
- Error message generalized: "staged PowerShell file(s)" -> "staged file(s)" with extension list
- Help text expanded: added en-dash (U+2013) and ellipsis (U+2026) hints
- Tests: ``tests/test_precommit_hygiene.sh`` -- flipped T2c, added T2d (.sh), T2e (.txt allowed), T2f (.md ASCII passes). 26/26 PASS.

### Pattern note (skill candidate)

"Hook scope decision" pattern: when extending a guard to new file types, the bar is (a) does the file type appear in the repo, (b) is the failure mode similar, (c) is false-positive risk acceptable. Not yet generalizable -- one more application would justify formalizing as ``.squad/skills/hook-scope-decision/SKILL.md``.

### Dogfood incident (cross-reference)

The new hook BLOCKED Mickey's own history.md append in the same PR because the file carried 60 pre-existing non-ASCII bytes from earlier sprints. Correct behavior. Deferral handled by Jiminy auto-fix catch-up entry post-Goofy-sweep. Captured in PR #334 body Deferred Items section. Skill candidate: "ship-test + eat-dogfood" (1st clean application; watch for second).
