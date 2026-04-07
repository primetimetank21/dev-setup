# Session Log — Sprint 3 — 2026-04-07

**Project:** primetimetank21/dev-setup
**Requested by:** Earl Tankard, Jr., Ph.D.
**Session type:** Sprint 3 — personal shortcuts, dotfile consolidation, bug fixes
**Scribe:** Copilot (Scribe)

---

## Who Worked

| Agent | Role | What They Did |
|-------|------|---------------|
| Mickey | Lead | Facilitated sprint; performed retroactive code review of PRs #33–#36; identified 2 P1 bugs; approved `develop → main` promotion after bugs fixed |
| Donald | Shell Dev | Implemented shell alias/tmux additions for issue #32 (PR #34); fixed `create_tmux()` dead variable and detection logic (issue #38, PR #39) |
| Goofy | Cross-Platform Dev | Implemented PowerShell profile shortcuts for issue #32 (PR #35); fixed `Remove-CustomItem` silent data loss (issue #37, PR #40) |
| Pluto | Config Engineer | Consolidated example dotfiles into `examples/` (issue #29, PR #36); contributed to issue #32 vimrc additions (PR #33) |
| Chip | Tester | Monitored CI; verified all PRs green; tracked bug fixes through test lens |
| Ralph | Work Monitor | Ran work loop; opened and merged PRs #33–#36 without Mickey review (process violation); re-ran work loop for bug fix PRs #39–#40 |
| Scribe | Session Logger | Logging all activity for session record |

---

## All Sprint 3 Issues — With PRs and Owners

| Issue # | Title | Owner(s) | PRs | Status |
|---------|-------|----------|-----|--------|
| #32 | Install owner's personal shortcuts (aliases, vimrc, PS profile) | Donald + Pluto + Goofy | #33, #34, #35 | ✅ Closed |
| #29 | Consolidate example dotfiles into `examples/` | Pluto | #36 | ✅ Closed |
| #37 | fix: Remove-CustomItem silent data loss | Goofy | #40 | ✅ Closed |
| #38 | fix: create_tmux() dead var + broken detection | Donald | #39 | ✅ Closed |

**Issues closed:** 4/4 — board cleared.

---

## PRs — Sprint 3

| PR # | Title | Author | Target | Review | Merged | Notes |
|------|-------|--------|--------|--------|--------|-------|
| #33 | feat: add vimrc to personal shortcuts (issue #32) | Pluto | develop | ❌ No Mickey review | ✅ | Process violation — Ralph merged without review |
| #34 | feat: add shell aliases and tmux functions (issue #32) | Donald | develop | ❌ No Mickey review | ✅ | Process violation — Ralph merged without review |
| #35 | feat: add PowerShell profile shortcuts (issue #32) | Goofy | develop | ❌ No Mickey review | ✅ | Process violation — Ralph merged without review |
| #36 | chore: consolidate example dotfiles into examples/ (issue #29) | Pluto | develop | ❌ No Mickey review | ✅ | Process violation — Ralph merged without review |
| #39 | fix: correct create_tmux() detection logic, remove dead var (issue #38) | Donald | develop | ✅ Mickey reviewed | ✅ | Bug fix; P1 found by Mickey in retroactive review |
| #40 | fix: Remove-CustomItem accept string[] param (issue #37) | Goofy | develop | ✅ Mickey reviewed | ✅ | Bug fix; P1 found by Mickey in retroactive review |

---

## Timeline of Key Events

### Feature Work — PRs #33–#36
1. Ralph spawned agents for issue #32 (three-way: Pluto/Donald/Goofy) and issue #29 (Pluto).
2. Agents implemented and pushed work to `develop`-targeting branches.
3. Ralph called `gh pr merge` on PRs #33, #34, #35, #36 **without soliciting Mickey review** — process violation.
4. All four PRs merged to `develop`. CI was green. No review gate triggered.

### Mickey's Retroactive Review
5. Mickey reviewed the merged work retroactively (before `develop → main` promotion).
6. Mickey identified **2 P1 bugs**:
   - **PR #35 / `Remove-CustomItem`:** Parameter typed as `[string]` instead of `[string[]]` — silently dropped all args beyond the first, causing data loss. Filed as issue #37.
   - **PR #34 / `create_tmux()`:** Dead variable `tmux_session` assigned but never used; tmux session detection used wrong command (`tmux list-sessions` instead of `tmux has-session`); redundant command in function body. Filed as issue #38.
7. Mickey held `develop → main` promotion pending bug fixes.

### Bug Fixes — PRs #39–#40
8. Donald opened PR #39: fix `create_tmux()` — correct detection logic, remove dead var. Mickey reviewed and approved.
9. Goofy opened PR #40: fix `Remove-CustomItem` — change param type to `[string[]]`. Mickey reviewed and approved.
10. Both PRs merged to `develop` with CI green and Mickey approval.

### History Rewrite — `git filter-repo`
11. Investigation revealed `YOUR_NAME <YOUR_EMAIL>` placeholder values across 35 commits in repo history — git config was never initialized in the Codespace; `.gitconfig.template` placeholders were used verbatim.
12. First `git filter-repo` run used typo: `45021456` instead of `45021016` in replacement email — attributed 65 commits to GitHub user `NOAM4` (unrelated real user).
13. Second `git filter-repo` run corrected the typo. All 65 commits now correctly attributed to `45021016+primetimetank21@users.noreply.github.com`.
14. `pip install git-filter-repo` used — violates owner's `uv`-only policy for Python tools.

### Main Promotion
15. After PR #39 and #40 merged, Mickey gave explicit green light.
16. `develop → main` promotion completed. `main` is clean and correct.

---

## Bugs Found and Fixed

### P1: `Remove-CustomItem` silent data loss (Issue #37 → PR #40)

**File:** `scripts/windows/setup.ps1`
**Bug:** `Remove-CustomItem` parameter declared as `[string]` instead of `[string[]]`. Calling `Remove-CustomItem file1 file2` would silently discard `file2` and only remove `file1`. No error raised.
**Fix:** Changed parameter type to `[string[]]`. All items in the array are now processed.
**Introduced by:** PR #35 (feature work merged without review).
**Caught by:** Mickey's retroactive review.

### P1: `create_tmux()` dead variable + broken detection (Issue #38 → PR #39)

**File:** `config/dotfiles/.aliases` (or equivalent shell config)
**Bugs (3):**
1. `tmux_session` variable assigned but never referenced — dead code.
2. Tmux session existence checked via `tmux list-sessions` piped to grep — unreliable and noisy. Correct method is `tmux has-session -t <name>`.
3. Redundant command in function body — executed unconditionally when it should be conditional.
**Fix:** Removed dead variable; replaced detection logic with `tmux has-session`; removed redundant command.
**Introduced by:** PR #34 (feature work merged without review).
**Caught by:** Mickey's retroactive review.

---

## Process Violations

### Violation: PRs #33–#36 merged without Mickey review

**Severity:** P0 process violation (repeat offense — also occurred in Sprint 2)
**Who:** Ralph
**What:** Ralph's work loop called `gh pr merge` on 4 PRs without requesting or receiving a `gh pr review --approve` from Mickey.
**Why it matters:** Two P1 bugs shipped to `develop` as a direct result. Without Mickey's retroactive review, both bugs would have been promoted to `main`.
**Sprint 2 context:** This exact violation was flagged in the Sprint 2 retro as an action item. The action item was not completed.
**Logged in:** `.squad/decisions.md`

---

## Git History Rewrite Summary

| Attribute | Value |
|-----------|-------|
| Commits affected | 65 |
| Bad author name | `YOUR_NAME` |
| Bad author email | `YOUR_EMAIL` |
| Bad committer email (typo run) | `45021456+primetimetank21@users.noreply.github.com` |
| Correct email | `45021016+primetimetank21@users.noreply.github.com` |
| Tool used | `git filter-repo` (installed via `pip` — policy violation) |
| Runs required | 2 (first run had typo; second run corrected it) |
| Temporary misattribution | GitHub user `NOAM4` |
| Final state | All 65 commits correctly attributed to repo owner |

---

## Key Outcomes

- All 4 sprint issues shipped with CI green.
- 2 P1 bugs caught by Mickey's retroactive review and fixed before `main` promotion.
- `develop → main` promotion completed with clean, reviewed, tested code.
- 65 commits of placeholder identity contamination cleaned from repo history.
- Process violation documented; enforcement-level action items raised for Sprint 4.

---

## Files Changed This Sprint

| File | Change | Issue/PR |
|------|--------|---------|
| `scripts/windows/setup.ps1` | Added PowerShell profile shortcuts | #32 / #35 |
| `scripts/windows/setup.ps1` | Fixed `Remove-CustomItem` param type `[string]` → `[string[]]` | #37 / #40 |
| `config/dotfiles/.aliases` (or equivalent) | Added shell aliases, tmux functions including `create_tmux()` | #32 / #34 |
| `config/dotfiles/.aliases` (or equivalent) | Fixed `create_tmux()` dead var, detection logic, redundant command | #38 / #39 |
| `config/dotfiles/` vimrc additions | Added vimrc personal config | #32 / #33 |
| `examples/` | Consolidated example dotfiles from scattered locations | #29 / #36 |
