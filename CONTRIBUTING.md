# Contributing to dev-setup

Welcome! This repo is maintained by the **Disney Classic Squad** — a team of specialized AI agents each owning a slice of the codebase. Human contributors are equally welcome. This guide explains how to work alongside the squad.

---

## Branch Protection

The `develop` branch is protected at the GitHub level. Direct pushes are blocked for everyone — all changes must go through a PR with at least one approving review and passing CI.

The branch protection rule has `enforce_admins` intentionally **disabled**. Why? On a solo-owner repo, GitHub blocks self-approval — an admin can't approve their own PR. Setting `enforce_admins=true` would create a deadlock: the only approver (the admin) can't approve themselves. The solution is `enforce_admins=false`, which allows the repo owner to use `gh pr merge --admin` to bypass the approval requirement *only when necessary* (e.g., to unblock themselves). This preserves the protection goal (no direct pushes) while avoiding the self-approval deadlock.

---

## Branch Naming

All work happens on a dedicated branch. **Never commit directly to `develop` or `main`.**

```
squad/{issue-number}-{kebab-slug}
```

**Examples:**
- `squad/42-add-nvm-install`
- `squad/17-fix-zsh-detection`
- `squad/8-dotfile-editorconfig`

Base branch is **always `develop`**:

```bash
git checkout develop
git pull origin develop
git checkout -b squad/{issue-number}-{slug}
```

---

## PR Checklist

Before opening a pull request, confirm all of the following:

- [ ] Branch created from latest `develop`
- [ ] No direct commits to `main` or `develop`
- [ ] PR targets `develop` (never `main`)
- [ ] CI is green before requesting review
- [ ] Commit messages follow conventional commits
- [ ] One issue per PR
- [ ] Mickey approval required before merge

---

## Commit Message Format

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <short summary>
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`

**Examples:**

```
feat(linux): add uv install script
fix(windows): handle missing winget gracefully
docs(readme): add --skip-auth flag note
chore(ci): pin shellcheck version
refactor(auth): extract is_non_interactive helper
test(idempotency): verify nvm double-install is safe
```

Keep the summary under 72 characters. Add a body if the change needs more context.

---

## Code Review

- **Mickey** is the lead reviewer — all PRs require Mickey's approval before merge.
- **CI must be green** before requesting review. Do not ask for review on a failing PR.
- Reviewers may request changes or reassign work to a different squad member.
- If Mickey rejects a PR, a *different* agent (not the original author) will be assigned to revise.

---

---

## Parallel Agent Work

### Why worktree isolation matters

In Sprint 4, two Chip agents ran simultaneously on issues #41 and #43, both sharing the same git working tree. Chip-issue-43 checked out `squad/43` while Chip-issue-41 was mid-commit on a different branch. The result: wrong content landed on the wrong branch, and PR #51 had to be closed and recreated. This is a classic branch-checkout race condition.

### How to enable it

Set `SQUAD_WORKTREES=1` before starting any Squad session where parallel work is expected:

```bash
export SQUAD_WORKTREES=1
```

Or add it permanently to your `.env` / shell profile. The devcontainer sets it by default in `remoteEnv`.

When enabled, the Squad coordinator creates an isolated `git worktree` for each issue before handing control to the agent. Branch checkouts inside one worktree never affect any other.

### Worktree path convention

```
{repo-parent}/{repo-name}-{issue-number}
```

**Example:** for issue #56 inside `/workspaces/dev-setup`, the worktree is created at:

```
/workspaces/dev-setup-56/
```

Each worktree has its own index and working files but shares the same `.git` object store with the main repo — no extra disk space for history, just the working tree.

### Cleaning up

Worktrees are not automatically removed. After a PR is merged, clean up with:

```bash
git worktree remove /workspaces/dev-setup-56
```

Or list all active worktrees with `git worktree list`.

---

For the full technical overview, team ownership map, and architecture decisions, see [ARCHITECTURE.md](./ARCHITECTURE.md).
