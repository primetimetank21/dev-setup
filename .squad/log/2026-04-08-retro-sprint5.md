# Sprint 5 Retrospective

**Date:** 2026-04-08  
**Sprint:** 5  
**Facilitator:** Mickey (Lead)  
**Status:** ✅ Complete — all 4 issues addressed, 5 PRs merged to develop

---

## 1. Sprint Summary

**Goal:** Ship the three process-improvement action items from the Sprint 4 retro, plus design a formal agent timeout policy.

| # | Issue | Owner | PR(s) | Result |
|---|-------|-------|-------|--------|
| #54 | Block direct pushes to develop (enforce_admins) | Mickey | #60 | ✅ Closed — deliberate `enforce_admins=false` documented |
| #55 | Agent timeout policy | Mickey | #61 | ✅ Merged |
| #56 | Worktree isolation for parallel agent work | Pluto | #58 | ✅ Merged |
| #57 | Remove ps.tar.gz binary artifact | Donald | #59 | ✅ Merged |

**Additional PR:** #62 (history summary) — merged to develop.

All 4 issues resolved. 5 PRs merged. Board is clear.

---

## 2. What Went Well

### Retro → action items → shipped (loop closed)

Every Sprint 5 issue traced directly to a Sprint 4 retro action item. The retrospective cycle is producing real process improvements, not shelf-ware.

### Parallel agent coordination worked

Round 1 ran Mickey, Donald, and Pluto concurrently on separate issues. All three produced clean PRs without stepping on each other. This is the first sprint where parallel work completed without a branch collision or wrong-content incident.

### `enforce_admins` decision was handled maturely

Instead of brute-forcing `enforce_admins=true` (which would create a self-approval deadlock on a solo repo), the team recognized the constraint, documented a deliberate design choice (`enforce_admins=false`), and established the `--admin` merge pattern as the standard workflow. Good engineering judgment over checkbox compliance.

### `--admin` merge pattern is now standardized

Ralph established `gh pr merge --admin` as the everyday merge workflow (after Mickey approval). This is documented, understood, and used consistently across all 5 merged PRs. No more ad hoc bypass — it's the pattern.

### Agent timeout policy shipped proactively

Issue #55 codified timeout tiers (Quick: 5 min, Standard: 10 min, Complex: 20 min) with explicit retry/escalate logic and Ralph stall detection signals. This directly prevents the Sprint 4 Chip-issue-43 runaway (45+ tool calls, 6+ minutes, no output).

### Documentation quality was high

Every PR included not just the code/config change but also decision records, skill docs, and CONTRIBUTING.md updates. The team is self-documenting.

---

## 3. What Didn't Go Well

### API permission wall — again

Mickey hit the same Codespace token 403 barrier on branch protection that was already documented from Sprint 3/4. Time was spent attempting the API call, debugging the 403, and documenting the workaround — for a limitation we already knew about.

### Pluto hit a race condition mid-task

Even in the sprint dedicated to *preventing* race conditions, Pluto's history.md commit landed on the wrong branch during parallel work. Cherry-pick fixed it, but it's ironic and proves worktree isolation (#56) was the right call. The fix shipped in the same sprint that exposed the problem one more time.

### Issue #54 scope pivoted mid-sprint

#54 started as "enable enforce_admins=true" and ended as "document why enforce_admins=false is deliberate." That's the right outcome, but the pivot happened during implementation rather than during planning. The acceptance criteria should have been re-scoped earlier.

### Agent timeout policy was not tested in production

Issue #55 shipped a policy document with timeout tiers, but no agent actually hit a timeout this sprint. The policy is untested. We won't know if the tiers are calibrated correctly until an agent stalls.

### PowerShell lint failure persists

The `Lint PowerShell Scripts` CI job has been red since at least Sprint 4 (PR #18 era). It's pre-existing and unrelated to any Sprint 5 work, but a persistently red CI job erodes trust in the pipeline. Nobody has picked it up.

---

## 4. Root Causes

### Repeated API permission wall

**Root cause:** No pre-check for known limitations before assigning work. The Codespace token scope restriction was documented in Sprint 3 decisions and Sprint 4 retro. Sprint 5 should have started #54 with "manual UI action required" as the known path, not "try the API first."

**Pattern:** We re-discover known constraints instead of consulting decisions.md before planning.

### Race condition during worktree isolation work

**Root cause:** Issue #56 (worktree isolation) was being implemented in the same shared working tree it was designed to protect. Chicken-and-egg: you can't use worktree isolation to build worktree isolation. The coordinator should have run Pluto sequentially for this specific issue.

### Issue #54 scope pivot

**Root cause:** The issue was written with an implementation assumption ("enable enforce_admins=true") rather than a problem statement ("ensure branch protection is appropriate for our repo model"). A problem-framed issue would have surfaced the solo-repo deadlock during planning.

### Untested timeout policy

**Root cause:** Sprint 5 had no long-running or complex agent tasks that would naturally trigger a timeout. The policy was designed retrospectively from Sprint 4 data. Testing would require either a real stall (undesirable) or a simulation/dry-run (not built).

---

## 5. Action Items for Sprint 6

| # | Action Item | Owner | Priority | Notes |
|---|-------------|-------|----------|-------|
| 1 | **Consult decisions.md during sprint planning** — before assigning any issue, check if the task involves a known limitation or prior decision. Add a "Known Constraints" section to issue templates. | Mickey | P2 | Prevents re-discovering the API permission wall and similar repeated friction. |
| 2 | **Fix PowerShell lint CI failure** — diagnose and fix the `Lint PowerShell Scripts` job that has been red since Sprint 4. Either fix the scripts or adjust the lint rules. | Goofy/Chip | P2 | Persistently red CI erodes trust. Should not carry into a third sprint. |
| 3 | **Dry-run the timeout policy** — in the first parallel agent sprint, have Ralph explicitly log timeout tier assignments and checkpoint timestamps. Validate that the 5/10/20 min tiers are realistic. | Ralph/Mickey | P3 | Policy is untested; first real use should be instrumented. |
| 4 | **Frame issues as problems, not implementations** — issue titles and ACs should describe the desired outcome, not the specific technical approach. Example: "Ensure branch protection suits solo-repo model" not "Enable enforce_admins=true". | Mickey | P2 | Prevents mid-sprint scope pivots when the assumed approach doesn't fit. |
| 5 | **Sequence chicken-and-egg tasks** — when an infrastructure improvement (like worktree isolation) must be built in the environment it protects, run that agent sequentially, not in parallel. | Mickey/Ralph | P3 | Prevents the exact race condition that hit Pluto during #56. |
| 6 | **Promote develop → main** — Sprint 5 process improvements are stable. Evaluate whether develop is ready for main promotion. | Mickey/Earl | P1 | Board is clear, all deliverables merged, CI is green (except pre-existing PS lint). |

---

## Metrics

- **Issues closed:** 4/4 (100%)
- **PRs merged:** 5/5 (100%)
- **Sprint violations:** 0 (all merges followed the `--admin` pattern with Mickey approval)
- **CI failures introduced:** 0
- **Pre-existing CI failures carried:** 1 (PowerShell lint)
- **Race conditions:** 1 (Pluto history.md — resolved via cherry-pick)
- **Retro action items from Sprint 4 addressed:** 3/3 (100%)

---

## Key Takeaway

Sprint 5 was a process sprint, and it delivered. The three Sprint 4 retro action items all shipped: worktree isolation prevents branch races, enforce_admins was resolved with a documented design decision, and agent timeouts have a formal policy. The `--admin` merge pattern is now the established standard. The team is closing the retro loop — action items don't just get written, they get built.

The honest gap: we're still re-discovering known constraints instead of checking our own records first. That's the Sprint 6 fix.
