---
name: "grill"
description: "Adversarial pre-implementation review of a written plan, in parallel, by 3+ reviewers."
domain: "process"
confidence: "low"
source: "earned (issue #441, 2026-05-27 -- first formal application; pattern observed informally in prior sprint code reviews)"
---

## What is Grilling?

Grilling is a structured adversarial pre-implementation review of a **written plan**,
conducted BEFORE any code is written. It is NOT:

- Code review (code does not exist yet)
- A retrospective (no implementation happened yet)
- A brainstorm (the plan is fixed; grillers stress-test it, not rewrite it)

Grilling is a **plan-stress-test**: multiple reviewers independently attack the plan
from different angles to surface holes, wrong assumptions, and missing edge cases --
before the cost of being wrong is paid in code.

The key phrase is "before the cost is paid." A 30-minute grill that prevents a 4-hour
rework is the best trade in the sprint. A grill that runs after the first commit is
already too late -- that is code review, and the psychological cost of discarding
written code is much higher.

---

## When to Run a Grill

Run a grill when ANY ONE of these triggers is true:

| # | Trigger |
|---|---------|
| 1 | Plan touches 3+ files OR 2+ subsystems |
| 2 | Plan asserts platform behavior (OS, shell, runtime, registry, env var contract) that the team has NOT previously verified in a merged PR or skill |
| 3 | User (Earl) explicitly requests a grill |
| 4 | Cost of being wrong > 1 hour of rework (subjective; err toward grilling) |

When in doubt: grill. A grill costs 30-60 minutes of parallel agent time. A missed
assumption in a merged plan can cost an entire sprint.

---

## Who Participates

A minimum of **3 reviewers** with distinct angles. Each griller owns ONE angle; do not
let grillers poach each other's scope.

### Required roles

| Role | Primary angle | Typical assignment |
|------|---------------|--------------------|
| **Architecture/Scope Reviewer** (Lead) | Is the scope right? Does it match the issue? Are abstractions sound? Does it create future debt? | Mickey (Tinkerer/Architect) |
| **Test/Edge-Case Reviewer** (Tester) | What breaks this? Unhappy paths, boundary conditions, platform variation, concurrency, idempotency | Chip (CI Wrangler/Tester) |
| **Fact-Checker** (Verification) | Are the stated facts true? OS behavior, API contracts, env var semantics, registry keys, docs links | Doc (Researcher/Fact-Checker) |

### Optional domain specialists

Add a fourth (or fifth) griller when the plan touches a known-difficult domain:

- Windows-specific paths / shell / PS 5.1 behavior -> Pluto (Config Engineer)
- CI / GitHub Actions -> Chip (if not already in Tester role)
- Shell portability (bash/zsh/POSIX) -> Donald (Shell/CLI Engineer)
- Squad process / team conventions -> Jiminy (Hygiene Auditor)

The plan author does NOT grill their own plan. See Lockout Rule below.

---

## Lockout Rule

**The plan author MAY NOT serve as a griller.** This is a strict rule, not a guideline.

Rationale: the author has already committed to the approach. Even with good intentions,
the author unconsciously steers reviewers away from the weakest assumptions. The grill
only works when reviewers have no stake in the plan's success.

This is the same principle as the Reviewer Rejection Protocol: different-agent rule.
If the plan author is the only available specialist for a required angle, escalate to
Earl rather than break the lockout.

---

## Spawn Pattern

All grillers are spawned **IN PARALLEL** as background-mode agents. This is mandatory.

```
# Example: spawn 3 grillers in parallel (pseudocode -- use task tool with mode: background)

spawn Mickey   -> background -> reads plan -> writes docs/plans/441-grill-mickey.md
spawn Chip     -> background -> reads plan -> writes docs/plans/441-grill-chip.md
spawn Doc      -> background -> reads plan -> writes docs/plans/441-grill-doc.md
```

Rules for parallel grill spawning:

1. Each griller receives the plan path and their assigned angle ONLY.
2. Grillers do NOT see each other's reports while writing. No cross-contamination.
3. Grillers do NOT discuss the plan with each other before writing.
4. The coordinator waits for ALL grillers to complete before reading any report.
5. The coordinator synthesizes the verdicts AFTER all reports are in.

Why parallel? Independent reports surface independent observations. If Griller A reads
Griller B's report first, A will consciously or unconsciously anchor on B's findings
and miss distinct holes. Parallel execution is the structural guarantee of independence.

---

## Output Convention

Each griller writes a report to:

    docs/plans/{N}-grill-{name}.md

where `{N}` is the issue number and `{name}` is the griller's agent name (lowercase).

### Required sections (fixed format)

```
# Grill Report: #{N} -- {plan title}

**Griller:** {name} ({role/angle})
**Plan reviewed:** docs/plans/{N}-{slug}.md
**Date:** {YYYY-MM-DD}
**Verdict:** Approve | Revise | Reject

---

## Angle: {assigned angle}

### Holes / Missing Edge Cases / Untested Assumptions

{bullet list -- be specific; cite plan section by heading or line range}

### Strong Points

{bullet list -- acknowledge what the plan gets right; be genuine, not ceremonial}

### Verdict

{1-2 paragraphs explaining the verdict. If Revise: name the specific sections that must
change and recommend who should revise (NOT the plan author). If Reject: explain why the
plan cannot be repaired with targeted revisions and must start over with a new agent.}

---

## If Revision Needed

**Revision owner:** {agent name -- NOT the plan author}
**Sections requiring change:** {list}
**Re-grill required after revision:** Yes | No (if No, explain why scope is narrow enough)
```

The "If Revision Needed" section is OMITTED for Approve verdicts.

Grillers MUST be hard but SPECIFIC. "This is wrong" is not a finding. "Section 3.2
assumes $HOME\Documents exists after KFM redirect, but [Environment]::GetFolderPath
returns the redirected path -- this breaks Scenario A" is a finding.

---

## Verdict Synthesis

The coordinator collates all grill reports and applies the following synthesis rules.
No implementation begins until synthesis is complete.

### Rules

| Outcome | Condition | Action |
|---------|-----------|--------|
| **Proceed** | All grillers vote Approve | Implementation proceeds immediately |
| **Revise** | ANY griller votes Revise (no Reject) | Plan author is out; a different agent revises; re-grill the revised plan |
| **Reject** | ANY griller votes Reject | Plan goes back to drawing board; new agent writes a fresh plan from scratch |

### Re-grill scope

After a Revise cycle, the re-grill MAY be scoped to the changed sections if:

- The revision is narrow (affects 1-2 sections)
- At least 2 of the original grillers confirm the changed sections only

A full re-grill (all 3 angles) is required if the revision changes the approach,
adds a new subsystem, or contradicts a strong-point the original grillers cited.

### Who synthesizes

The coordinator (not a griller, not the plan author) writes a 1-paragraph synthesis
note in the plan's `Status` field or a `docs/plans/{N}-synthesis.md` file, stating:
final verdict, revision owner (if any), and next step.

---

## Anti-Patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| **Gloating or piling on** | "This plan is terrible" wastes time and demoralizes. Be hard but SPECIFIC. Every finding needs a plan section reference and a concrete consequence. |
| **Grilling without a written plan** | No oral grilling. No grilling of a sketch, a GitHub issue description, or a bullet list. The plan must be a complete written document before grill starts. |
| **Same agent drafts AND grills** | Lockout violation. The author's blind spots are exactly what the grill is designed to catch. |
| **Grilling after code is written** | That is code review. Once code exists, the psychological and practical cost of discarding it changes the reviewer's calculus. Grill happens before any code is written. |
| **Skipping grill on "small" changes** | Trigger 1 is objective (3+ files OR 2+ subsystems). Small changes that touch shared state (env vars, profile loading, PATH, shell config) have historically caused multi-sprint regressions. Apply the trigger table, not intuition. |
| **Sequential grilling** | If grillers read each other's reports before writing their own, the independence guarantee is broken. Always spawn in parallel. |
| **Coordinator summarizing for grillers** | Give grillers the plan and their angle. Do not pre-explain what you think is wrong. The whole point is independent observation. |

---

## Worked Example: Issue #441 (2026-05-27)

Issue #441 reports that `scripts/windows/tools/profile.ps1` writes the dev-setup
block to the wrong path on OneDrive/KFM systems, causing aliases to silently fail.

**Plan author:** Goofy
**Plan file:** `docs/plans/441-profile-path.md`

**Grill triggers hit:**
- Trigger 1: plan touches profile.ps1, test files, and potentially setup orchestration (3+ files)
- Trigger 2: plan asserts Windows KFM/OneDrive behavior + PS 5.1 `$PROFILE` resolution
  semantics that had not been verified in a prior merged PR

**Grillers spawned in parallel:**

| Agent | Role | Report file |
|-------|------|-------------|
| Mickey | Architecture/Scope Reviewer | `docs/plans/441-grill-mickey.md` |
| Chip | Test/Edge-Case Reviewer | `docs/plans/441-grill-chip.md` |
| Doc | Fact-Checker | `docs/plans/441-grill-doc.md` |

Goofy (plan author) was locked out per the lockout rule.
All three grillers spawned simultaneously; no griller saw another's report before writing.
Coordinator synthesized verdicts after all three reports were in.

This instance (2026-05-27, issue #441) is the **canonical example** of the grill
ceremony. Future teams should reference it when the pattern needs illustration.

---

## Related Skills and References

- `.squad/skills/pre-spawn-checklist/SKILL.md` -- hygiene tail for spawned agents
- `.squad/skills/spawn-prompt-lint/SKILL.md` -- linting spawn prompts before sending
- `.squad/routing.md` -- Reviewer Rejection Protocol (same-agent lockout principle)
- `.squad/ceremonies.md` -- where the grill ceremony should be registered

## Changelog

- 2026-05-27 -- Initial formalization. Author: Pluto (Config Engineer). Issue #441.
  Confidence set to "low" (first formal capture). Bumps to "medium" when a second
  independent assignment applies the skill and confirms the pattern.
