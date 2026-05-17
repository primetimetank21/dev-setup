# Sprint 16 Skill Drift Watchlist Audit

**Date:** 2026-05-17
**By:** Pluto
**Scope:** 30 .copilot/skills + 0 .squad/skills

## Summary

- Total skills audited: 30
- Eligible for graduation (low -> medium): 0
- Eligible for graduation (medium -> high): 0
- Stale watchlist (>90 days, no recent mentions): 0
- Never-applied: 27

## Per-skill findings

| Skill | Confidence | Last update | Mentions | Recommendation |
|---|---|---|---|---|
| agent-collaboration | "high" | 2026-05-17 | 0 | monitor |
| agent-conduct | "high" | 2026-05-17 | 0 | monitor |
| architectural-proposals | "high" | 2026-05-17 | 0 | monitor |
| ci-validation-gates | "high" | 2026-05-17 | 0 | monitor |
| cli-wiring | unknown | 2026-05-17 | 0 | monitor |
| client-compatibility | "high" | 2026-05-17 | 0 | monitor |
| cross-squad | "medium" | 2026-05-17 | 0 | monitor |
| distributed-mesh | "high" | 2026-05-17 | 0 | monitor |
| docs-standards | "high" | 2026-05-17 | 0 | monitor |
| economy-mode | "low" | 2026-05-17 | 0 | monitor |
| error-recovery | "high" | 2026-05-17 | 0 | monitor |
| external-comms | "low" | 2026-05-17 | 1 | keep |
| gh-auth-isolation | "high" | 2026-05-17 | 0 | monitor |
| git-workflow | "high" | 2026-05-17 | 2 | keep |
| github-multi-account | high | 2026-05-17 | 0 | monitor |
| history-hygiene | high | 2026-05-17 | 0 | monitor |
| humanizer | "low" | 2026-05-17 | 0 | monitor |
| init-mode | "high" | 2026-05-17 | 0 | monitor |
| model-selection | unknown | 2026-05-17 | 0 | monitor |
| nap | unknown | 2026-05-17 | 3 | keep |
| personal-squad | unknown | 2026-05-17 | 0 | monitor |
| project-conventions | "medium" | 2026-05-17 | 0 | monitor |
| release-process | "high" | 2026-05-17 | 0 | monitor |
| reskill | "high" | 2026-05-17 | 0 | monitor |
| reviewer-protocol | "high" | 2026-05-17 | 0 | monitor |
| secret-handling | high | 2026-05-17 | 0 | monitor |
| session-recovery | "high" | 2026-05-17 | 0 | monitor |
| squad-conventions | "high" | 2026-05-17 | 0 | monitor |
| test-discipline | "high" | 2026-05-17 | 0 | monitor |
| windows-compatibility | "high" | 2026-05-17 | 0 | monitor |

## Graduation candidates

No skills meet graduation thresholds at this time.

## Watchlist (stale or never-applied)

Skills with zero observed applications (monitor for utility):

- agent-collaboration (last updated 2026-05-17, confidence: "high", never applied)
- agent-conduct (last updated 2026-05-17, confidence: "high", never applied)
- architectural-proposals (last updated 2026-05-17, confidence: "high", never applied)
- ci-validation-gates (last updated 2026-05-17, confidence: "high", never applied)
- cli-wiring (last updated 2026-05-17, confidence: unknown, never applied)
- client-compatibility (last updated 2026-05-17, confidence: "high", never applied)
- cross-squad (last updated 2026-05-17, confidence: "medium", never applied)
- distributed-mesh (last updated 2026-05-17, confidence: "high", never applied)
- docs-standards (last updated 2026-05-17, confidence: "high", never applied)
- economy-mode (last updated 2026-05-17, confidence: "low", never applied)
- error-recovery (last updated 2026-05-17, confidence: "high", never applied)
- gh-auth-isolation (last updated 2026-05-17, confidence: "high", never applied)
- github-multi-account (last updated 2026-05-17, confidence: high, never applied)
- history-hygiene (last updated 2026-05-17, confidence: high, never applied)
- humanizer (last updated 2026-05-17, confidence: "low", never applied)
- init-mode (last updated 2026-05-17, confidence: "high", never applied)
- model-selection (last updated 2026-05-17, confidence: unknown, never applied)
- personal-squad (last updated 2026-05-17, confidence: unknown, never applied)
- project-conventions (last updated 2026-05-17, confidence: "medium", never applied)
- release-process (last updated 2026-05-17, confidence: "high", never applied)
- reskill (last updated 2026-05-17, confidence: "high", never applied)
- reviewer-protocol (last updated 2026-05-17, confidence: "high", never applied)
- secret-handling (last updated 2026-05-17, confidence: high, never applied)
- session-recovery (last updated 2026-05-17, confidence: "high", never applied)
- squad-conventions (last updated 2026-05-17, confidence: "high", never applied)
- test-discipline (last updated 2026-05-17, confidence: "high", never applied)
- windows-compatibility (last updated 2026-05-17, confidence: "high", never applied)

## Methodology notes

- **Mentions counted via** grep across .squad/agents/*/history.md files, case-insensitive skill name matching
- **Last-update timestamps** extracted from git log -1 --format=%ai for each SKILL.md file
- **Confidence** values read from SKILL.md frontmatter (confidence: field)
- **Drift criteria:**
  - Low -> Medium: confidence still 'low' after 3+ applications observed
  - Medium -> High: confidence still 'medium' after 5+ applications observed
  - Stale watchlist: last update >90 days ago AND zero history mentions
  - Never-applied: zero mentions across all agent history.md files

## Observations

All 30 skills in .copilot/skills were recently updated (2026-05-17), indicating fresh initialization of the worktree. The audit reveals 27 skills with zero observed applications in agent history, suggesting either:
1. History data is fresh/limited (early in sprint)
2. Skills are not yet integrated into agent workflows
3. Agent history files do not exist or are empty

Zero skills currently meet graduation thresholds. Once agents begin using skills and history accumulates, future audits will identify promotion candidates.

The presence of some "unknown" confidence values (cli-wiring, model-selection, nap, personal-squad) indicates inconsistent frontmatter in SKILL.md files - recommend standardization pass.

## Next steps

- Continue monitoring application counts in .squad/agents/*/history.md
- Issue #366 (graduation audit) will execute the recommended promotions once thresholds are met
- Consider standardizing confidence frontmatter across all skills
- Track future audits to identify drift patterns
