# Decision: Goofy ASCII sweep methodology

**By:** Goofy (Cross-Platform Dev)
**Topic:** ``.md`` ASCII-sweep methodology + ``scripts/lib/ascii-sweep.py`` reference
**Created:** 2026-05-17 (Sprint 13 Wave 2)

This file is the per-topic decisions store for Goofy's ASCII-sweep methodology. Seed for a future ``.squad/skills/ascii-sweep/SKILL.md`` formalization once the pattern has a second application.

---

## 2026-05-17 Sprint 13 Wave 2 -- ASCII-sweep repo .md corpus

**By:** Goofy (folded from inbox drop ``goofy-w2-2026-05-17-ascii-sweep.md``)
**Issue:** #322 part A
**Branch:** ``squad/322-goofy-md-sweep`` (PR #335)

### Scope

All ``.md`` files in the repo (163 files). Excludes ``.git/``, ``node_modules/``, ``.copilot/``. Excludes non-``.md`` files (``hooks/``, ``scripts/``, ``*.ps1``, ``*.sh``). Mickey owns part B (``hooks/pre-commit`` ASCII gate) in a parallel worktree.

### Exclusions

- Fenced code blocks (``` and ~~~) preserved verbatim per repo policy. Tree diagrams in ARCHITECTURE.md and README.md, hex/byte tables, and code samples are inside fences and remain intact.
- CHANGELOG.md prior-release entries untouched; only added new ``[Unreleased] / Changed`` line for this sweep.

### Before / After

- Files scanned: 163
- Files with hits pre-sweep: 125 (4,187 non-ASCII chars)
- Files edited: 124
- Chars replaced: 2,501
- Non-ASCII outside fences after sweep: **0**
- Non-ASCII inside fences (preserved): 1,686 (intentional)

### Mapping highlights

- ``--`` (em) -> ``--``, ``-`` (en) -> ``-``
- Smart quotes -> ASCII quotes
- Arrows (``->``, ``<-``, ``<->``) -> ``->``, ``<-``, ``<->``
- Box-drawing U+2500..U+257F -> ``+``, ``-``, ``=``, ``|``
- Checkmarks (``[x]``, ``[x]``) -> ``[x]``; crosses (``[ ]``, ``[ ]``) -> ``[ ]`` (preserves task-list semantics in team.md and status tables)
- Status emoji (``[RED]``, ``[GREEN]``, ``[YELLOW]``, ...) -> ``[RED]``, ``[GREEN]``, ``[YELLOW]``, ...
- Tooling emoji ([NOTE], [TOOL], [SEARCH], ...) -> bracketed ASCII tokens

### Tool

``scripts/lib/ascii-sweep.py`` -- idempotent, fence-aware, re-runnable. Could underpin Mickey's pre-commit hook check or become a ``.squad/skills/ascii-sweep/`` skill on second application.

### Skill candidate

First clean application of the fence-aware ASCII-sweep methodology. The script (``scripts/lib/ascii-sweep.py``, 6342 B) and the mapping table above are the seed. Formalize as ``.squad/skills/ascii-sweep/SKILL.md`` on the second application -- per Squad abstraction-threshold rule. At that point also add a CONTRIBUTING.md cross-reference (Jiminy W2 audit Sec 6 flagged the missing reference).
