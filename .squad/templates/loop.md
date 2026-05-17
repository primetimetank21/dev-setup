---
configured: false
interval: 10
timeout: 30
description: "My squad work loop"
---

# Squad Work Loop

> ! Set `configured: true` in the frontmatter above to activate this loop.
> Run with: `squad loop`

## What to do each cycle

Describe what your squad should do every time the loop wakes up. Be specific --
the more context you give, the better your squad performs.

Examples:
- Check for new messages in a Teams channel and summarize action items
- Review recent pull requests and flag anything needing attention
- Run a health check on staging and report anomalies
- Scan the inbox for anything that needs a response today

<!-- Replace this section with your actual loop instructions. -->

## Monitoring (optional)

If you want your squad to watch external channels, enable monitor capabilities:

```bash
squad loop --monitor-email --monitor-teams
```

## Personality (optional)

If your squad has a specific voice or style, describe it here so each cycle
stays consistent.

Example: "Be concise. Use bullet points. Flag blockers clearly."

## Tips

- **Be specific.** Vague prompts produce vague results.
- **Set boundaries.** Tell the squad what NOT to do (e.g., "Don't send messages to anyone but me").
- **Start small.** Begin with one task per cycle, then expand.
- **Use frontmatter.** `interval` controls how often the loop runs. `timeout` caps each cycle.

---

## Squad Operational Gates (Coordinator dispatch)

> These gates are NOT about the `squad loop` periodic activity above. They are the
> Coordinator's spawn-lifecycle SOPs that fire on EVERY dispatch turn. Read once,
> reinforce at sprint kickoff (see `ceremonies.md`).
>
> Source: `.squad/decisions/doc-and-jiminy-automation.md` (closes #289, #290).

### Gate 1 -- Jiminy post-batch audit (closes #290)

**Trigger condition:** the Coordinator dispatched 3 or more agents in a single turn (counted as `general-purpose` or named-agent spawns, NOT counting Scribe which is silent/background by design).

**Action required, BEFORE the Coordinator returns results to the user:**

1. Spawn Jiminy with the standard audit prompt.
2. Wait for `Jiminy clear` or a dirty report.
3. If dirty: route the fix per Jiminy's `Auto-fix scope` (charter section). Re-run Jiminy after fixes.
4. Only then return final results to the user.

**Why two-surface enforcement:** this gate is also documented in `Sprint Wrap` ceremony and Jiminy charter `Triggers` table. If the Coordinator forgets at one surface, the other two should catch it before session close.

### Gate 2 -- Jiminy session-end audit

**Trigger condition:** the user signals session-end (explicit "done", "wrap up", session-close intent, OR the work queue is empty after a full sprint).

**Action required:**

1. Spawn Jiminy with the full sweep prompt.
2. Jiminy BLOCKS session close on dirty state. Do not return final summary until clean.
3. Spawn Ralph for stale-branch cleanup (post-Jiminy, per Ralph charter).

### Gate 3 -- Doc worktree pre-spawn check (closes #289)

**Trigger condition:** the Coordinator is about to spawn Doc (Fact Checker) for any fact-check, verification, audit, or review task.

**Pre-spawn check:**

1. Run `git worktree list`. Confirm `..\dev-setup-doc` (or platform equivalent) is present and on branch `squad/doc-history-sprint-<N>`.
2. If absent: this is the first Doc spawn of the sprint -> create the worktree now (`git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>`) OR defer to `Sprint Kickoff` ceremony if the kickoff was skipped.
3. Doc's spawn prompt MUST begin with: "Your working directory is `<absolute path to ..\dev-setup-doc>`. `Set-Location` there BEFORE reading any files. All your `.squad/agents/doc/history.md` writes commit + push to `squad/doc-history-sprint-<N>`, never to develop."

**Why:** Doc runs as a `general-purpose` subagent and inherits the Coordinator's CWD by default. Without an explicit CWD override, Doc's writes land as `M` on `develop` in the primary worktree and require a per-fact-check fold PR (Sprint 10 (formerly Sprint S) anti-pattern: #281 + #283). The dedicated worktree isolates Doc's edits to a single sprint branch with ONE fold PR at sprint wrap.

### Gate compliance check

Before declaring a Coordinator turn complete:

- [ ] Counted spawns this turn. If >= 3, did Jiminy run? (Gate 1)
- [ ] If session-end signal was received, did Jiminy + Ralph run? (Gate 2)
- [ ] If Doc was spawned, did the spawn prompt include the `..\dev-setup-doc` CWD directive? (Gate 3)

If any gate was missed, the next Jiminy audit will flag it. Self-correct by re-spawning the missed gate before returning to the user.
