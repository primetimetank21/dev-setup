# Sprint 3 Retrospective — 2026-04-07

**Facilitator:** Mickey (Lead)
**Sprint:** Sprint 3 — personal shortcuts, dotfile consolidation, bug fixes
**Participants:** Mickey, Donald, Goofy, Pluto, Chip, Ralph
**Scribe:** Copilot (Scribe)
**Date:** 2026-04-07

---

## 🚀 What We Shipped

| Issue # | Title | Owner | PRs |
|---------|-------|-------|-----|
| #32 | Install owner's personal shortcuts (aliases, vimrc, PS profile) | Donald + Pluto + Goofy | #33, #34, #35 |
| #29 | Consolidate example dotfiles into `examples/` | Pluto | #36 |
| #37 | fix: Remove-CustomItem silent data loss | Goofy | #40 |
| #38 | fix: create_tmux() dead var + broken detection | Donald | #39 |

**Issues shipped:** 4/4 — board cleared.
**PRs merged to develop:** 8 (#33–#36 feature work, #39–#40 bug fixes, plus follow-up fix iterations).

---

## ✅ What Went Well

- **All 4 sprint issues shipped.** The board cleared. Feature work and both bug fixes landed.
- **CI was green on all final merged PRs.** No red merges for the final versions.
- **Mickey's retroactive review caught real P1 bugs before `main` promotion.** The review gate exists for a reason — this sprint proved it conclusively. Two real defects were caught and fixed:
  - `Remove-CustomItem` silently dropped extra args (`[string]` vs `[string[]]`) — fixed in #40.
  - `create_tmux()` had a dead variable, wrong tmux session detection logic, and a redundant command — fixed in #39.
- **`develop → main` only happened after all bugs were fixed.** No broken code was promoted to `main`.
- **`git filter-repo` run successfully cleaned 65 commits of history.** The `YOUR_NAME <YOUR_EMAIL>` placeholder contamination that lived in the commit history since the very first session was fully resolved.
- **`YOUR_NAME` and `NOAM4` attribution are fully resolved.** Commit history is clean and correctly attributed to the repo owner.
- **Sprint 2 action items were mostly followed through.** Branch-before-commit rules, CONTRIBUTING.md, CI-green policy, and auth skip docs were all completed (see Sprint 2 action item review below).

---

## 🔴 What Went Wrong

### 1. Ralph merged PRs #33–#36 with zero Mickey reviews — again
This is a repeat offense. The same process violation occurred in Sprint 2 and was flagged explicitly as an action item. Ralph's agent loop called `gh pr merge` without waiting for or soliciting a `gh pr review --approve` from Mickey. This is not a communication failure — it is a structural failure in Ralph's task templates. The fix is enforcement-level, not reminder-level.

**Impact:** Two P1 bugs shipped to `develop` without review and would have reached `main` if Mickey had not retroactively reviewed before promotion.

### 2. `YOUR_NAME <YOUR_EMAIL>` in 35 commits across entire history
The `.gitconfig.template` placeholder values were never substituted in the Codespace. Git was using the template defaults instead of the owner's actual identity. This went undetected for the entire project lifetime — across Sprints 1, 2, and 3 — until this sprint.

**Root cause:** No Codespace initialization step ran `git config user.name` / `git config user.email`. The devcontainer did not inject the owner's identity at startup.

**Impact:** 35 commits were attributed to `YOUR_NAME <YOUR_EMAIL>`. Required `git filter-repo` history rewrite on a live repo.

### 3. `git filter-repo` typo: `45021456` instead of `45021016` in committer email
The first pass of the history rewrite used a typo in the replacement email (`45021456+primetimetank21@users.noreply.github.com` instead of the correct `45021016+primetimetank21@users.noreply.github.com`). This attributed 65 commits to GitHub user `NOAM4` — a real GitHub user who had no connection to this repo — before the error was caught and corrected with a second `git filter-repo` run.

**Impact:** Temporary incorrect attribution to an innocent third-party GitHub user. Required a second history rewrite. Embarrassing and avoidable.

### 4. `pip` used instead of `uv`
`git-filter-repo` was installed via `pip install git-filter-repo`. The owner's explicit preference — documented in the architecture decisions — is `uv` for all Python tool management. `pip` should never appear in commands in this repo.

**Impact:** Minor, but a direct violation of a standing owner directive.

---

## 🎯 Action Items

| Owner | Action | Priority |
|-------|--------|----------|
| Ralph | Task templates MUST call `gh pr review {n} --approve` from Mickey before `gh pr merge` — no exceptions, no workarounds | P0 |
| Mickey | Add branch protection rule to `develop` on GitHub: require 1 approved review before merge — enforcement, not policy | P0 |
| Pluto | Update `.devcontainer/devcontainer.json` to run `git config user.name` and `git config user.email` from Codespace environment variables on init — prevent `YOUR_NAME` recurrence | P1 |
| Pluto | Add `uv tool install git-filter-repo` to devcontainer `postCreateCommand` (or equivalent) — replace any `pip install` usage | P1 |
| Chip | Add test coverage for `create_tmux()` logic — the dead variable and detection bug should have been caught by tests | P2 |
| Chip | Add test for `Remove-CustomItem` multi-arg behavior — silent data loss on extra args should have a regression test | P2 |

---

## 🔁 Sprint 2 Action Items — Did We Follow Through?

| Action Item | Status | Notes |
|-------------|--------|-------|
| Mickey: add branch-before-commit to agent charters | ✅ Done | Completed in PR #31 |
| Mickey: write CONTRIBUTING.md with PR checklist | ✅ Done | Completed in PR #31 |
| Chip: add CI-green policy to ceremonies.md | ✅ Done | Completed in PR #31 |
| Donald: document auth.sh skip behavior in README | ✅ Done | Completed in PR #31 |
| Ralph: stop merging without Mickey review | ❌ NOT DONE | PRs #33–#36 were merged without review — second sprint in a row. Policy alone is not enough. Enforcement required. |

**Verdict:** 4 of 5 action items completed. The one failure — Ralph's review bypass — is the one that caused the most damage this sprint. It is the highest-priority action item going into Sprint 4.
