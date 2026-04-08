# Skill: Worktree Isolation for Parallel Agent Runs

**Confidence:** medium (confirmed by Sprint 4 incident)
**Owner:** Pluto (Config Engineer)
**Issue:** #56

---

## What

Each issue being worked on by a Squad agent gets its own `git worktree`. Agents never share a working tree. Branch checkouts inside one worktree are fully isolated from every other agent running simultaneously.

## Why

When multiple agents share a single working tree, any agent can run `git checkout <branch>` at any moment — even while another agent has uncommitted changes or is mid-commit on a different branch. In Sprint 4, Chip-issue-43 checked out `squad/43` while Chip-issue-41 was committing to a different branch. Wrong content ended up on the wrong branch; PR #51 was closed.

This is a race condition at the filesystem level. The only safe fix is full working tree isolation.

## How

### Enable via environment variable

```bash
export SQUAD_WORKTREES=1
```

Set this before starting any Squad session where multiple agents will run in parallel. The devcontainer sets `SQUAD_WORKTREES=1` by default in `remoteEnv`.

### Enable via squad config

```yaml
worktrees: true
```

Add to your project's squad config file (`squad.yml` or equivalent).

### What the coordinator does

When `SQUAD_WORKTREES=1`, the Squad coordinator:

1. Creates a worktree at `{repo-parent}/{repo-name}-{issue-number}` for each issue.
2. Checks out the agent's branch inside that isolated worktree.
3. Hands the agent its `WORKTREE_PATH`.
4. After the agent finishes, the worktree can be removed with `git worktree remove <path>`.

### Worktree path convention

```
{repo-parent}/{repo-name}-{issue-number}
```

**Example:**

| Issue | Repo path                  | Worktree path                  |
|-------|----------------------------|--------------------------------|
| #41   | `/workspaces/dev-setup`    | `/workspaces/dev-setup-41`     |
| #43   | `/workspaces/dev-setup`    | `/workspaces/dev-setup-43`     |
| #56   | `/workspaces/dev-setup`    | `/workspaces/dev-setup-56`     |

### Cleanup

```bash
# List all worktrees
git worktree list

# Remove a worktree after PR is merged
git worktree remove /workspaces/dev-setup-56

# Prune stale worktree refs
git worktree prune
```

## When to use this

- Any time two or more Squad agents are expected to run simultaneously on different issues.
- Parallel sprints, parallel hotfix + feature work, or any CI-driven multi-agent pipeline.

## When not needed

- Single-agent runs (sequential, one issue at a time) — no race condition possible.
- Read-only agents (explorers, reviewers) — no branch checkouts.

## References

- Sprint 4 incident: PR #51 closed due to branch checkout race between Chip-issue-41 and Chip-issue-43.
- `git worktree` docs: `man git-worktree`
- CONTRIBUTING.md § "Parallel Agent Work"
