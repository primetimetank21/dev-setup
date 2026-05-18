# Decision Log: Sprint 18 W1 -- Skills #398 + #399 (PR #402)

**Date:** 2026-05-18  
**Agent:** Pluto  
**Context:** Formalized two recurring hygiene skills from Sprint 17 audit

## Decisions

### 1. SKILL placement and naming

**Decision:** Both SKILLs placed in their original domain folders:
- `.squad/skills/history-md-pre-size-check/SKILL.md` -- repo-meta domain (squad management)
- `.copilot/skills/changelog-fold-completeness/SKILL.md` -- .copilot domain (Copilot CLI agent tooling)

**Rationale:** Mirrors existing structure: `.squad/skills/` for agent-hygiene patterns; `.copilot/skills/` for CLI ecosystem patterns. Precedent from Sprint 16 #362 (ascii-docs-about-non-ascii placed in .copilot/skills/).

### 2. Confidence levels

**Decision:** Both set to `medium` confidence.

**Rationale:**
- `history-md-pre-size-check`: 3+ observations across 3 sprints (15, 16, 17); meets medium threshold (2+ independent instances).
- `changelog-fold-completeness`: recurring failure in sprint release closure; medium until third independent observation.

### 3. Cross-linking from routing.md

**Decision:** Mandatory Hygiene Tail (`.squad/templates/spawn-prompt-hygiene.md`) item 4 links to `history-md-pre-size-check` SKILL.md.

**Rationale:** Establishes SKILL as canonical reference for the pre-size-check requirement. Eliminates duplication; single source of truth for recipe, thresholds, and examples.

### 4. Meta-validation discipline

**Decision:** When formalizing a hygiene SKILL, the very commit that introduces the SKILL must demonstrate compliance with the rule the SKILL teaches.

**Rationale:** This append was pre-sized against the history-md-pre-size-check threshold (14336 B) before committing. Enforces "eat your own dog food" discipline and prevents reflexive contradictions (e.g., committing an oversized SKILL that teaches size discipline).

## Related Issues

- #398 (history-md-pre-size-check)
- #399 (changelog-fold-completeness)
- #401 (routing.md Mandatory Hygiene Tail)
- #402 (this formalization PR)

## Audit Trail

- Sprint 17 retro identified 3 failure patterns
- Sprint 18 formalization completed
- Skill metadata verified (YAML frontmatter, domain, confidence, source)
