# Contributing to dev-setup

Welcome! This repo is maintained by the **Disney Classic Squad** — a team of specialized AI agents each owning a slice of the codebase. Human contributors are equally welcome. This guide explains how to work alongside the squad.

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

For the full technical overview, team ownership map, and architecture decisions, see [ARCHITECTURE.md](./ARCHITECTURE.md).
