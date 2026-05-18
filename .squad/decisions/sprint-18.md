# Sprint 18 Decisions

(Archived from .squad/decisions.md at Sprint 18 completion -- Issues #397-#400.)
(Original content: Sprint 18 dispatch, wave 1 audit, and retrospective, 2026-05-17 to 2026-05-19.)

---

# Coordinator Directive: Mandatory Hygiene Tail for Spawn Prompts

**Date:** 2026-05-17T22:10:23-04:00
**Author:** Mickey (Sprint 18 Wave 1, issue #397)
**PR:** #401 (merged @ 0883c505e7c010ac6f18558755b756d93a6583d5)

## Decision

Every coordinator spawn prompt MUST include the Mandatory Hygiene Tail block
verbatim. The canonical template is at:

  .squad/templates/spawn-prompt-hygiene.md

No items may be omitted without explicit justification.

## The 6 items (summary)

1. CWD-pin -- run and PASS before every file write
   Ref: PowerShell Set-Location + path equality guard

2. base=develop discipline
   Ref: .squad/skills/gh-pr-base-develop/SKILL.md
   Verify post-create: gh pr view <N> --json baseRefName must equal "develop"

3. ASCII discipline per file written
   Ref: .copilot/skills/ascii-docs-about-non-ascii/SKILL.md
   Verify: python one-liner byte count must be 0

4. history.md pre-size-check before append
   Ref: .squad/skills/history-md-pre-size-check/SKILL.md
   Threshold: 14336 B (90% of 15360 B hard gate)

5. Worktree-remove-FIRST cleanup after PR merges
   Ref: .squad/skills/worktree-remove-first/SKILL.md
   Order: harvest -> git worktree remove -> git branch -D -> gh pr merge --squash

6. Hygiene tail completion
   - Append 1-2 line entry to own history.md
   - Drop decision to inbox if applicable
   - File SKILL formalization issue if pattern is 2nd+ application

## Rationale

Sprint 17 retro identified 3 hygiene failures all preventable by an enforced
template:
- Donald-2 #389 breached history.md 15360 B gate (no pre-size-check)
- Donald-2 #389 wrote em-dash to .gitignore (ASCII not verified per write)
- Sprint 16 PR #368 went to --base=main (base=develop not in spawn prompt)

Jiminy caught all three post-facto. This template makes the hygiene tail a
reflex at spawn time, not a recovery task at audit time.

## routing.md update

Added "Mandatory Hygiene Tail" section to .squad/routing.md with instruction
that every spawn MUST include this block verbatim and reference to template.

---

# Jiminy S18 W1 Post-Batch Audit Summary

**Date:** 2026-05-18
**Agent:** jiminy-6
**PR:** #404 (squash-merged to develop)

## Auto-fixes
- ralph/history.md compressed: 15006 -> 9312 B (Option A)
- scribe/history.md compressed: 14449 -> 13606 B (Option A)

## Flags (coordinator attention needed)
- Pluto missing inbox drop for PR #402 (SKILL formalization)
- Donald missing inbox drop for PR #403 (sprint-end-labels)
- Pluto missing history.md trail entry for PR #402
- Donald missing history.md trail entry for PR #403
- Recommend re-spawn or manual append for attribution

## All-clear checks
- decisions.md: 10094 B (OK)
- ASCII purity: 0 non-ASCII (OK)
- Stale refs: 0 branches, 1 worktree (OK)
- Pre-commit/whitespace: PASS
- SKILL cross-links: wired (OK)
- jiminy history.md: 14287 B (OK)

---

# Decision: Sprint 18 Wave 1 Label Automation Live Run (#403)

## Date
2026-05-19

## Context
First live production run of sprint-end-labels.sh script completed. Decision documents input scheme, label infrastructure created, and bugs surfaced during execution.

## Input Scheme (A) Selected: Backfill Sprint 17

- Rationale: Established retroactive sprint labels for S17 closed issues (#371, #381-#384) and merged PRs (#385-#396) to create historical record.
- Alternative (B) considered: start fresh from S18 only. Rejected to maintain label continuity across all completed sprints.

## Label Infrastructure Established

Created three labels with standardized naming and color scheme:
- sprint:17 (#FFA500) -- Orange, identifies S17 work
- sprint:18 (#FF8C00) -- Dark Orange, identifies S18 work  
- elease:shipped-0.9.7 (#0E8A16) -- Green, marks shipped release

Scheme applied to all Sprint 17 closed issues and merged PRs. Going forward, sprint labels will be created at sprint start per this standard.

## Bugs Surfaced and Fixed

1. **gh issue list --search silently appends is:issue** (excludes PRs)
   - Manifested: combined backfill of issues and PRs required separate queries
   - Fix: gh issue list --state closed + gh pr list --state merged, deduplicate with jq

2. **Windows jq CRLF breaks idempotency guard**
   - Manifested: Windows jq outputs \r\n line endings; trailing \r attached to label field prevented grep match
   - Fix: pipe jq through tr -d '\r' before loop

## Test Coverage

Added Test G to tests/test_sprint_end_labels.ps1 to detect CRLF regression. Uses function-override shim pattern to inject bad data into has_label mock.

## Verification

- All 17 label adds verified on first read (0 retries, Earl directive satisfied)
- Idempotency confirmed on 3rd run: total=17 changed=0

## Lessons

- gh issue list --search is issues-only even with the search API; must pair with gh pr list for batch automation
- Windows jq CRLF is a latent trap in any bash script parsing TSV output on Windows

---

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
