---
name: "git-workflow"
description: "Dev-first workflow with insiders preview channel"
domain: "version-control"
confidence: "high"
source: "team-decision"
---

## Context

This project uses a two-branch model. **All feature work branches from `develop`, never from `main`.**

| Branch | Purpose | Rules |
|--------|---------|-------|
| `main` | Stable, released code only | NEVER push or PR directly -- only receives merges from `develop` |
| `develop` | Integration branch -- all feature work lands here | ALWAYS the base for feature PRs |

## Branch Naming Convention

Issue branches MUST use: `{type}/{issue-number}-{kebab-case-slug}`

Types: `feat`, `fix`, `chore`, `docs`, `refactor`

Examples:
- `fix/195-version-stamp-bug`
- `feat/42-profile-api`
- `chore/468-customizable-install`

## Workflow for Issue Work

1. **Branch from develop:**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b {type}/{issue-number}-{slug}
   ```

2. **Mark issue in-progress:**
   ```bash
   gh issue edit {number} --add-label "status:in-progress"
   ```

3. **Create draft PR targeting develop:**
   ```bash
   gh pr create --base develop --title "{description}" --body "Closes #{issue-number}" --draft
   ```

4. **Do the work.** Make changes, write tests, commit with issue reference.

5. **Push and mark ready:**
   ```bash
   git push -u origin {type}/{issue-number}-{slug}
   gh pr ready
   ```

6. **Merge gates -- BOTH must pass before merging:**
   - [x] Code review approval
   - [x] CI checks are green

7. **After merge to develop -- delete the branch immediately:**
   ```bash
   git checkout develop
   git pull origin develop
   git branch -d {type}/{issue-number}-{slug}
   git push origin --delete {type}/{issue-number}-{slug}
   ```

## Parallel Multi-Issue Work (Worktrees)

When the coordinator routes multiple issues simultaneously (e.g., "fix bugs X, Y, and Z"), use `git worktree` to give each agent an isolated working directory. No filesystem collisions, no branch-switching overhead.

### When to Use Worktrees vs Sequential

| Scenario | Strategy |
|----------|----------|
| Single issue | Standard workflow above -- no worktree needed |
| 2+ simultaneous issues in same repo | Worktrees -- one per issue |
| Work spanning multiple repos | Separate clones as siblings (see Multi-Repo below) |

### Setup

From the main clone (must be on develop or any branch):

```bash
# Ensure develop is current
git fetch origin develop

# Create a worktree per issue -- siblings to the main clone
git worktree add ../work-195 -b fix/195-stamp-bug origin/develop
git worktree add ../work-193 -b refactor/193-loader origin/develop
```

**Naming convention:** `../{repo-name}-{issue-number}` (e.g., `../dev-setup-195`, `../dev-setup-pr-42`).

Each worktree:
- Has its own working directory and index
- Is on its own `{type}/{issue-number}-{slug}` branch from develop
- Shares the same `.git` object store (disk-efficient)

### Per-Worktree Agent Workflow

Each developer operates inside their worktree exactly like the single-issue workflow:

```bash
cd ../work-195

# Work normally -- commits, tests, pushes
git add -A && git commit -m "fix: stamp bug (#195)"
git push -u origin fix/195-stamp-bug

# Create PR targeting develop
gh pr create --base develop --title "fix: stamp bug" --body "Closes #195" --draft
```

All PRs target `develop` independently. Multiple worktrees don't interfere with each other's filesystem.

### Project State Files in Worktrees

Project-specific state files (if present) exist in each worktree as a copy. To avoid conflicts on merge:
- Configure `.gitattributes` to use `merge=union` for append-only files
- Each process appends its own section; union merge reconciles sections on PR merge
- **Rule:** Never rewrite or reorder state files in a worktree -- append only

### Cleanup After Merge

After a worktree's PR is merged to develop:

```bash
# From the main clone
git worktree remove ../work-195
git worktree prune          # clean stale metadata
git branch -d fix/195-stamp-bug
git push origin --delete fix/195-stamp-bug
```

If a worktree was deleted manually (rm -rf), `git worktree prune` recovers the state.

---

## Multi-Repo Downstream Scenarios

When work spans multiple repositories (e.g., a CLI changes need SDK changes, or a user's app depends on a library):

### Setup

Clone downstream repos as siblings to the main repo:

```
~/work/
  main-project/      # main repo
  lib-sdk/           # downstream dependency
  user-app/          # consumer project
```

Each repo gets its own issue branch following its own naming convention.

### Coordinated PRs

- Create PRs in each repo independently
- Link them in PR descriptions:
  ```
  Closes #42

  **Depends on:** lib-sdk PR #17 (lib-sdk changes required for this feature)
  ```
- Merge order: dependencies first (e.g., lib-sdk), then dependents (e.g., main-project)

### Local Linking for Testing

Before pushing, verify cross-repo changes work together:

```bash
# Node.js / npm
cd ../lib-sdk && npm link
cd ../main-project && npm link lib-sdk

# Go
# Use replace directive in go.mod:
# replace github.com/org/lib-sdk => ../lib-sdk

# Python
cd ../lib-sdk && uv pip install -e .
```

**Important:** Remove local links before committing. `npm link` and `go replace` are dev-only -- CI must use published packages or PR-specific refs.

### Worktrees + Multi-Repo

These compose naturally. You can have:
- Multiple worktrees in the main repo (parallel issues)
- Separate clones for downstream repos
- Each combination operates independently

---

## Anti-Patterns

- [ ] Branching from main (always branch from develop)
- [ ] PR targeting main directly (always target develop)
- [ ] Pushing directly to main or develop (use PRs)
- [ ] Non-conforming branch names (must be {type}/{number}-{slug})
- [ ] Merging without code review approval
- [ ] Merging without green CI
- [ ] Leaving branches around after merge (delete immediately)
- [ ] Deleting main or develop (never)
- [ ] Switching branches in the main clone while worktrees are active (use worktrees instead)
- [ ] Using worktrees for cross-repo work (use separate clones)

## Branch Protection

The `develop` branch requires:
- 1 approving review before merge (dismiss stale reviews enabled)
- All CI checks passing: Validate Linux Setup, Lint Shell Scripts, Lint PowerShell Scripts
- Configured via GitHub branch protection rules (enabled Sprint 4)

## Merge Gates

### Hard Rule: No Merge Without Approval
The reviewer MUST call `gh pr review {n} --approve` BEFORE `gh pr merge`.
Branch protection on `develop` enforces this at the GitHub level.

## Promotion Pipeline

- develop -> main: Code review approval + CI green -> merge, then tag for release
- Hotfixes: Branch from develop as `hotfix/{slug}`, PR back to develop, then promote to main
