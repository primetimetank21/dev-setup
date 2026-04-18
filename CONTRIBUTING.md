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

## PowerShell 5.x Compatibility

All `.ps1` scripts in this repo must run on **PowerShell 5.1** (the version shipped with Windows 10/11). PS 7+ runs on Linux Codespaces; PS 5.1 is what end users actually have.

### Checklist for any `.ps1` changes

- [ ] **No `$MyInvocation.MyCommand.Path`** — use `$PSScriptRoot` instead. `MyCommand.Path` returns null in PS 5.x when dot-sourced.
- [ ] **PS 6+ automatic variables are guarded** — `$IsLinux`, `$IsMacOS`, `$IsWindows` do not exist in PS 5.x. Always guard:
  ```powershell
  if ($PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux) { ... }
  ```
- [ ] **Works under `Set-StrictMode -Version Latest`** — `setup.ps1` runs with StrictMode on. Uninitialized variables and undefined properties are hard errors, not silent nils.
- [ ] **String literals are ASCII-only in test files** — Characters whose UTF-8 encoding contains byte `0x94` (em-dash `—`, curly quotes `""`, box-drawing chars) corrupt PS 5.x parsing under CP1252. Use plain hyphens and straight quotes in all test strings.
- [ ] **Built-in alias conflicts handled** — Before `Set-Alias`, remove conflicts: `Remove-Item -Force Alias:\{name} -ErrorAction SilentlyContinue`

### Testing on PS 5.1

Since the dev environment runs PS 7+, you cannot natively run PS 5.1 tests. Manual testing on a Windows machine is the current standard. See issue #109 for the CI validation track.

### Reference: Known PS 5.x regressions caught in this repo

| Date | Bug | Fix |
|------|-----|-----|
| 2026-04-18 | `$MyInvocation.MyCommand.Path` returned null in PS 5.x | Replaced with `$PSScriptRoot` |
| 2026-04-18 | `Remove-CustomItem` missing `Recurse` flag, broke under StrictMode | Added `-Recurse -Force` to `Remove-Item` call |

---

## Direct-Push Override Policy

Normally, all changes flow through PRs into `develop`. Direct pushes to `main` are **never** allowed as routine workflow.

**Exception: Hotfix Override**

A direct push to `main` is permitted ONLY when ALL of the following conditions are met:

1. A critical regression or broken state is on `main` that blocks users
2. The fix is small, surgical, and fully understood (not exploratory)
3. `develop` itself is broken or the PR pipeline cannot be expedited
4. The repo owner (Earl Tankard) explicitly authorizes the override in session

**Required audit trail:**

- Commit message must include `[hotfix-override]` annotation
- A squad decision record must be written to `.squad/decisions/inbox/` documenting: what was pushed, why, and who authorized
- The override must be referenced in the next sprint retro

**Reference:** The 2026-04-18 hotfix session (PS 5.x `$MyInvocation.MyCommand.Path` regression) is the canonical example of an authorized override.

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
