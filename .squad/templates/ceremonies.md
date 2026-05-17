# Ceremonies

> Team meetings that happen before or after work. Each squad configures their own.

## Design Review

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | before |
| **Condition** | multi-agent task involving 2+ agents modifying shared systems |
| **Facilitator** | lead |
| **Participants** | all-relevant |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. Review the task and requirements
2. Agree on interfaces and contracts between components
3. Identify risks and edge cases
4. Assign action items

---

## Retrospective

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | after |
| **Condition** | build failure, test failure, or reviewer rejection |
| **Facilitator** | lead |
| **Participants** | all-involved |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. What happened? (facts only)
2. Root cause analysis
3. What should change?
4. Action items for next iteration


---

## Retrospective with Enforcement

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | weekly |
| **Condition** | No *retrospective* log in .squad/log/ within the last 7 days |
| **Facilitator** | lead |
| **Participants** | all |
| **Time budget** | focused |
| **Enabled** | yes |
| **Enforcement skill** | retro-enforcement |

**Agenda:**
1. What shipped this week? (closed issues, merged PRs)
2. What did not ship? (open issues, blockers)
3. Root cause on any failures
4. Action items -- each MUST become a GitHub Issue labeled retro-action

**Coordinator integration:**
At round start, call Test-RetroOverdue (see skill retro-enforcement). If overdue, run this ceremony before the work queue.

**Why GitHub Issues, not markdown:**
Production data: 0% completion across 6 retros using markdown checklists, 100% after switching to GitHub Issues.

---

## Sprint Kickoff

| Field | Value |
|-------|-------|
| **Trigger** | manual + auto |
| **When** | before first agent dispatch of a new sprint |
| **Condition** | start of a new sprint (Coordinator first turn after a sprint wrap, OR `go:yes` labels appear on a fresh batch of issues) |
| **Facilitator** | coordinator |
| **Participants** | coordinator (with Mickey if scope changes are needed) |
| **Time budget** | quick |
| **Enabled** | yes |

**Source:** `.squad/decisions/doc-and-jiminy-automation.md` (closes #289).

**Agenda:**

1. **Create Doc worktree for the sprint.** From the primary repo root:
   ```
   git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>
   ```
   Verify with `git worktree list`. If the branch already exists from a prior sprint, replace `-b squad/doc-history-sprint-<N>` with the current sprint's branch name (do NOT reuse a prior sprint's branch; one branch per sprint keeps fold-PRs sprint-scoped).
2. **Confirm Squad Operational Gates are loaded.** Skim `.squad/templates/loop.md` -> "Squad Operational Gates" section. Three gates: Jiminy post-batch, Jiminy session-end, Doc worktree pre-spawn.
3. **Triage `go:yes` issues** through Mickey if not already done.
4. **Sprint goal recorded** in coordinator notes / session opening.

**Outputs:**

- A `..\dev-setup-doc` worktree on `squad/doc-history-sprint-<N>`.
- Mental load checked: Coordinator has the three gate trigger conditions in working memory.

---

## Sprint Wrap

| Field | Value |
|-------|-------|
| **Trigger** | manual + auto |
| **When** | last turn of a sprint, before session close |
| **Condition** | sprint goal met OR work queue drained OR user signals session-end |
| **Facilitator** | coordinator |
| **Participants** | Jiminy, Ralph, Mickey, Scribe, Doc (if any fact-check edits accumulated) |
| **Time budget** | focused |
| **Enabled** | yes |

**Source:** `.squad/decisions/doc-and-jiminy-automation.md` (closes #289, #290).

**Agenda:**

1. **Jiminy session-end audit.** Spawn Jiminy with the full sweep prompt. Jiminy BLOCKS session close on dirty state. Do not proceed until `Jiminy clear` or all dirty items are resolved.
2. **Fold Doc history (if Doc ran this sprint).** From the Doc worktree (`..\dev-setup-doc`):
   - Confirm all Doc commits are pushed: `git status` clean, `git log origin/squad/doc-history-sprint-<N>..HEAD` empty.
   - Open ONE fold PR: `gh pr create -B develop -t "docs(doc): fold sprint-<N> fact-check history" -b "Closes the sprint's Doc fact-check log. Single fold-PR per the doc-worktree SOP (.squad/decisions/doc-and-jiminy-automation.md)."`
   - Mickey reviews + approves (pure history.md edits, fast). Merge with `--admin` if self-approval blocks.
3. **Ralph end-of-session cleanup.** Spawn Ralph to delete stale remote `squad/*` branches that have already been merged.
4. **Scribe drain.** If `.squad/decisions/inbox/` is non-empty, spawn Scribe to fold to canonical locations.
5. **Retro action items.** Capture any SOP regressions (e.g., "missed kickoff gate", "Jiminy not auto-fired on batch N") as GitHub Issues labeled `retro-action` per the Retrospective ceremony.

**Outputs:**

- `Jiminy clear` at session end.
- At most ONE fold PR for Doc's sprint history (target: 1 if Doc ran, 0 if not). Sprint S had 2; the new SOP targets 1.
- Stale branches deleted.
- Decisions inbox drained.

**Why this matters:**

Before this ceremony existed, Sprint S leaked the `bradygaster-squad-sdk-0.9.4.tgz` artifact (caught by Earl manually) and required two fold PRs for Doc (#281, #283). Both failures trace to "no checklist surface at session-end". Sprint Wrap exists so those misses are visible at the moment they happen, not three days later.
