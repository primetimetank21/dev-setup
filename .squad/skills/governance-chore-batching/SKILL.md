# Skill: Governance Chore Batching

**Slug:** governance-chore-batching
**Confidence:** low (1 observation -- bumps to medium on next independent application)
**Owner:** Mickey (governance domain)
**First observed:** 2026-05-27 (issues #455, #456 chore plan)

---

## Pattern

When two or more chore issues meet ALL of:
1. Both live under `.squad/**` (governance domain)
2. Touch **disjoint files** (no overlap)
3. Share the same executor (e.g., Scribe) and reviewer (Mickey)
4. Share labels (`type:chore`, `area:meta`, same priority)
5. Neither is blocking active sprint work

-> **Batch into one branch and one PR** rather than two separate branches.

---

## Triggers

- Two or more open issues labeled `type:chore` + `squad:scribe` touching `.squad/**`
- Mickey is planning execution and both issues land in same triage pass

---

## Branch Name Convention

```
squad/{lower-issue}-{higher-issue}-scribe-governance-chores
```

Example: `squad/455-456-scribe-governance-chores`

---

## Commit Message Template

```
chore(squad): <short description of both fixes> (#NNN, #MMM)

- <file1>: <what changed>
- <file2>: <what changed>

Closes #NNN
Closes #MMM

Co-authored-by: Copilot <copilot@github.com>
```

---

## Pre-flight Checks

1. **Verify no active Scribe sessions** writing the same files: check `.squad/decisions/inbox/` is empty.
2. **Check `merge=union` files**: if any target file uses `merge=union` (see `.gitattributes`), merge the PR promptly after creation to minimize window for concurrent appends.
3. **Verify byte-size gate** for `decisions.md` (hard gate: 51200 bytes): run `(Get-Item .squad\decisions.md).Length` before and after.

---

## Verification Pattern

For each issue in the batch, confirm acceptance criterion passes before committing:

```powershell
# Run each issue's acceptance Select-String / length check
# Stage only after ALL pass
git add <file1> <file2>
git commit -m "chore(squad): ..."
```

---

## Anti-patterns

- **Don't batch if files overlap** -- one edit could conflict with the other during rebase or review.
- **Don't batch across domains** -- if one issue is `.squad/**` and another is `scripts/**`, keep separate (different reviewers).
- **Don't batch if priorities differ significantly** -- a P1 chore should not wait for a P3 chore to be ready.

---

## Citation

- Issues #455 and #456 (2026-05-27): first formal application of this pattern.
- Plan: `.squad/decisions/inbox/mickey-chore-plan-455-456.md`
