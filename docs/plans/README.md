# docs/plans -- Plan Document Convention

This folder contains per-issue vertical slice plans for primetimetank21/dev-setup. Plans are
the pre-implementation spec; they capture scope decisions, design decisions, and acceptance
criteria for a given issue before code is written.

---

## Front-Matter Schema

Every plan doc must begin with a YAML front-matter block:

```yaml
---
issue: <GitHub issue number, integer>
title: "Short human-readable title"
status: <see Status Vocabulary below>
created: <ISO date, YYYY-MM-DD>
updated: <ISO date, YYYY-MM-DD>
---
```

No other fields are required. `supersedes: <issue>` is optional when a plan replaces
a prior one.

---

## Status Vocabulary

| Status      | Meaning                                          |
|-------------|--------------------------------------------------|
| draft       | In progress; not ready for implementation        |
| ready       | Grill-passed or otherwise approved; ready impl   |
| in-progress | Implementation underway (PR open)                |
| implemented | Shipped to develop; doc kept for reference       |
| superseded  | Replaced by another plan doc (note supersedes)   |

---

## File Naming

```
NNN-slug.md
```

Where NNN is the GitHub issue number (zero-padded to 3 digits) and slug is a short
kebab-case descriptor. Example: 468-customizable-install.md

---

## Layout

Flat files in docs/plans/. No per-feature subfolders unless a plan accumulates
supplementary assets (diagrams, data tables) that cannot live inline. Threshold: >10 plans
or attached binary assets.

---

## Grill / Review History

Do NOT commit grill-panel review changelogs to plan docs. The HQ coordinator maintains
review history externally. Plan docs contain only the living spec; revision history is
captured in git log and front-matter `updated` field.

---

## What Belongs Here

- Problem statement
- Scope (IN / OUT)
- Design decisions (with rationale)
- Algorithm / data structures / pseudocode as needed
- Test plan / acceptance criteria
- Out-of-scope items (tracked issues)

## What Does NOT Belong Here

- Review panel names, cast names, or griller attributions
- Version changelog blocks (vN Changes sections)
- Process notes (merge decisions, admin notes, coordinator instructions)
- Implementation progress updates (use the GitHub issue for that)
