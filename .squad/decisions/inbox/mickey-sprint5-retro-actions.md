# Sprint 5 Retro — Action Items for Sprint 6

**Date:** 2026-04-08  
**Source:** Sprint 5 Retrospective  
**Author:** Mickey (Lead)  
**Status:** Inbox — pending triage into Sprint 6 planning

---

## Action Items

### 1. Consult decisions.md During Sprint Planning (P2)

**Owner:** Mickey  
**What:** Before assigning any issue, check decisions.md for known limitations or prior decisions related to the task. Add a "Known Constraints" check to the sprint planning workflow.  
**Why:** Sprint 5 re-attempted the API branch protection call despite this being a documented limitation from Sprint 3. Wasted agent time on a known dead end.

### 2. Fix PowerShell Lint CI Failure (P2)

**Owner:** Goofy / Chip  
**What:** Diagnose and resolve the `Lint PowerShell Scripts` CI job failure that has persisted since Sprint 4. Either fix the PowerShell scripts to pass PSScriptAnalyzer or adjust lint rules if the failures are false positives.  
**Why:** A persistently red CI job normalizes failure and reduces trust in the pipeline. This should not carry into a third consecutive sprint.

### 3. Dry-Run the Agent Timeout Policy (P3)

**Owner:** Ralph / Mickey  
**What:** In the first Sprint 6 parallel agent session, have Ralph explicitly log: (a) timeout tier assigned to each agent, (b) checkpoint timestamps, (c) whether any agent approached the limit. Report findings in orchestration log.  
**Why:** The timeout policy (issue #55) shipped as documentation but was never triggered in Sprint 5. First real use should be instrumented to validate the 5/10/20 min tiers.

### 4. Frame Issues as Problems, Not Implementations (P2)

**Owner:** Mickey  
**What:** Write issue titles and acceptance criteria to describe desired outcomes, not technical approaches. Example: "Ensure branch protection suits solo-repo workflow" instead of "Enable enforce_admins=true."  
**Why:** Issue #54 pivoted mid-sprint from "enable a flag" to "document why we don't enable it." Problem-framed issues absorb scope changes; implementation-framed issues create confusion.

### 5. Sequence Chicken-and-Egg Infrastructure Tasks (P3)

**Owner:** Mickey / Ralph  
**What:** When a task builds infrastructure that protects the environment it runs in (e.g., worktree isolation), run that agent sequentially — not in parallel with other agents who could trigger the exact problem being fixed.  
**Why:** Pluto hit a race condition on history.md while implementing the worktree isolation feature that would have prevented it. Cherry-pick resolved it, but the irony is avoidable.

### 6. Evaluate develop → main Promotion (P1)

**Owner:** Mickey / Earl  
**What:** Assess whether develop is ready for promotion to main. Sprint 5 shipped all planned process improvements, board is clear, 5/5 PRs merged.  
**Why:** Develop has been accumulating improvements across 3 sprints. If it's stable, it should ship. If it's not, identify the blockers.

---

## Decision Needed

These action items should be triaged into Sprint 6 issues during planning. P1 items (#6) should be addressed first. P2 items (#1, #2, #4) form the core sprint work. P3 items (#3, #5) are process refinements that can be applied during normal operations.
