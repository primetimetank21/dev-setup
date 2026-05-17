# Project Context

- **Project:** dev-setup
- **Created:** 2026-04-07

## Core Context

Agent Ralph initialized and ready for work.

## Recent Updates

[PIN] Team initialized on 2026-04-07

---
> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place; no archive file).

## Sprint 2-4 Work Log (summary)

Compressed; older sprint logs kept as short bullets.

- **Sprint 2 (2026-04-07)** Issue #28 PSScriptAnalyzer lint fixes (PR #30: `PSAvoidUsingWriteHost`, `PSUseApprovedVerbs`, `PSUseBOMForUnicodeEncodedFile`). Sprint 1 retro action items batched into PR #31 (branch-before-commit rule on charters, CONTRIBUTING.md, CI merge gate, README auth docs).
- **Sprint 3 (2026-04-07)** Issue #32 owner shortcuts: Donald (PR #34 `.aliases`), Pluto (PR #35 `.vimrc`), Goofy (PR #36 PowerShell profile). Issue #29 examples/ consolidation. Retro P1 bug fixes: #37 Remove-CustomItem silent data loss (Goofy), #38 create_tmux three bugs (Donald). Sprint 3 promotion. PRs #33-#36, #39-#40 merged.
- **Sprint 4 (2026-04-07)** Issues #41-#46 worked: #41 Remove-CustomItem multi-arg ValueFromRemainingArguments fix (PR #52, caught by new validate-powershell job), #43 create_tmux 6-scenario test (PR #53, tmux mocking), #42/#45/#46/#44 already-merged closures. Race condition on parallel Chip spawns documented (PR #51 closed); chip-issue-43 stall pattern noted.
- **Round 1 (2026-04-07)** Initial board scan: 14 open issues, identified #3 (Mickey, architecture) as blocker for #1/#2/#4-9/#13; spawned Mickey + Pluto in parallel.

Lessons preserved verbatim in Learnings section below (Unicode in .ps1, self-approval block, sub-task parallelization, dotfile install pattern).

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

Initial setup complete.

---

### Sprint final cleanup (2026-05-16)
- **Audit pass:** Read-only audit performed pre-merge. Status: CLEAN -- no strays, no untracked work, no stashes, no orphan worktrees. Flagged 7 stale remote `squad/*` branches (all 0 commits ahead of develop).
- **Cleanup pass:** After PR #220 (sprint wrap) merged to main at `9d991a6`, deleted 7 stale remote branches: `squad/181-macos-ci`, `squad/186-shared-logging`, `squad/190-tool-versions`, `squad/191-windows-auth`, `squad/193-shellcheck-aliases`, `squad/201-nvm-bootstrap`, `squad/212-commit-msg-merge-bypass`. Pruned local refs to deleted remotes. Verified working tree still clean.
- **Final repo state:**
  - main: `9d991a6` (sprint wrap merge)
  - develop: `a821505` (synced with main)
  - Only local branches: develop, main
  - Only remote branches: develop, main
  - Worktrees: 1 (primary)
  - Open PRs: 0
  - Open go:yes issues: 0
- **Sprint outcome:** 22 PRs merged, 17 `go:yes` closed, develop fast-forwarded to main, all stale branches reaped. Sprint backlog clear.
- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

## Sprint 8 through Sprint 11 EOS cleanups (summary)

- **2026-05-16 Final EOS sweep.** 12-point hygiene sweep. CLEAN. develop `9eb5272`, working tree clean, 0 stashes, 0 open PRs/issues, 1 worktree, no orphan branches, inbox empty, no rogue files. gh auth OK. Ready for next session.
- **2026-05-16 Sprint 8-hotfix + 0.8.0 release cleanup.** After P0 fixes #249/#251/#252 via PRs #257/#256/#258, cut 0.8.0 (PR #259 + #260 + GH release). Deleted `release/0.8.0` local + remote branch post-merge. EOS verdict: clean.
- **2026-05-16 Sprint 9 EOS.** After 5 PRs (#265-#269) + follow-up #271 filed. Deleted 5 stale `squad/*` remote branches post-merge. Develop `a4d76ba`. Pattern: `gh pr merge --delete-branch` left ghost remote refs 3-of-5 times (Sprint 9 origin of issue #300 hypothesis).
- **2026-05-17 Sprint 10 EOS.** After 10 PRs (#274-#283) + 0.9.0 release. 7 stale remote branches pruned. Develop fast-forwarded to main; cut 0.9.0. EOS clean.
- **2026-05-17 Post-0.9.0 mini-batch EOS.** After Mickey PRs #291 + #293 (Doc worktree + Jiminy auto-dispatch SOPs). EOS clean, no orphans.
- **2026-05-17 Sprint 11 EOS.** After 4 issues shipped + bonus PRs #299/#301/#302 + retro PR #303. develop `033f80e`. Zero stale local + remote branches (Coordinator already cleaned -- pattern improving). gh-quirk recurrence remains at 75% -- tracked as #300.
- **2026-05-17 Post-0.9.1 + Sprint Rename EOS.** After 0.9.1 release (PRs #305 + #307) + Tier 3 sprint-naming sweep (PR #308 + Doc commit `56c3c1f`) + Sprint 12 backlog issues filed (#309, #310). EOS clean. Lesson: `git fetch --prune` on clean board is no-op but worth running.

## 2026-05-17 -- Sprint 12 EOS sweep (Earl, post-retro merge)

- **Trigger:** Earl's EOS protocol after Sprint 12 wrap (3 waves, 10 PRs, 9
  issues closed). Retro fold landed as PR #327 (`5e0fb53`) just before
  dispatch. Coordinator had already drained 4 Wave-2 inbox drops inline
  post-Jiminy-audit; board reported clean entering this sweep.
- **Pre-sweep state:**
  - develop @ `5e0fb53`, main @ `724c62c` (still 0.9.1, untouched)
  - Working tree clean, 1 worktree (primary only)
  - Inbox empty, no rogue body files, no temp/backup rogues
- **Pruned (Step 1) -- 5 stale `origin/squad/*` tracking refs:**
  - `origin/squad/237-test-harness-pattern`
  - `origin/squad/306-readme-refresh`
  - `origin/squad/310-arch-windows-dep-order`
  - `origin/squad/scribe-sprint-12-retro` (Jiminy listed 4 -- this was the
    5th, branch reaped when PR #327 squash-merged minutes earlier; local
    tracking ref hadn't caught up yet)
  - `origin/squad/scribe-sprint-12-wave-2-fold`
- **Already clean (Steps 2-5) -- Jiminy session-end audit was thorough:**
  - Local `squad/*` branches: 0 (Coordinator's worktree-remove-first dance
    held discipline across all 3 waves)
  - Remote `squad/*` branches via `gh api .../branches --paginate`: 0
    (confirmed -- only `develop` and `main` on the remote)
  - Filesystem `dev-setup-*` orphan dirs at parent: 0
  - `.squad/decisions/inbox/`: empty
  - Rogue `issue_body*.md` at repo root: 0 (`gh issue create -F` + `Remove-Item`
    pattern held)
  - Rogue `*.tmp`, `*.bak`, `.DS_Store`, `Thumbs.db`: 0
- **Step 6 -- `git gc --auto`:** exit 0, no output. Heuristics did not
  trigger a pack -- expected, since the worktree-local strategy keeps
  most churn off the primary checkout's loose-object pile. 10 PRs of
  merge activity did not accumulate enough loose objects to cross the
  auto-gc threshold.
- **Final repo state:**
  - develop: `5e0fb53` (clean)
  - main: `724c62c` (0.9.1, untouched)
  - Local branches: develop, main
  - Remote branches (post-prune): origin/develop, origin/main, origin/HEAD
  - Worktrees: 1 (primary)
  - Open PRs: 0
- **Sprint 12 EOS verdict:** CLEAN. 5 stale tracking refs pruned, 0 actual
  orphans (no branches, no worktrees, no fs dirs, no rogue files). Jiminy's
  session-end audit handled everything except the local-tracking-ref
  catchup, which is the canonical Ralph job. Sweep complete.
- **EOS pattern note:** 3rd consecutive EOS (Sprint 11 wrap -> 0.9.1
  release -> Sprint 12 wrap) with zero orphan branches and zero worktree
  stragglers. The Sprint 11-era hypothesis ("the team has internalized
  cleanup-on-merge OR `gh pr merge --delete-branch` reliability improved")
  now has a 3rd data point in its favor. One more cycle and the
  `gh --delete-branch` quirk (issue #300) is effectively obsolete for
  this repo's workflow.
- **Multi-wave/multi-PR scaling note (new):** This is the first EOS
  following a 3-wave / 10-PR sprint. The cleanup load did NOT scale
  linearly with PR count -- the entire sweep produced 5 stale tracking
  refs (1 per active wave/release + the retro), not 10. Worktree-local
  strategy + Scribe's per-wave fold pattern keeps the EOS surface area
  bounded regardless of sprint size. Worth remembering when sizing
  future sprints: cleanup cost is per-wave, not per-PR.

### Learnings (Ralph)

- **Local tracking refs always lag a fresh merge.** When `gh pr merge`
  deletes the remote branch, the local `origin/squad/*` ref persists
  until the next `git fetch --prune` (or explicit `git remote prune`).
  Jiminy's session-end audit ran before PR #327 merged, so it counted
  4 refs; by the time Ralph dispatched, it was 5. Not a bug in Jiminy's
  count -- a timing artifact. Future EOS dispatches after a fresh
  merge should expect +1 ref vs. the prior audit.
- **`git gc --auto` on a worktree-local-strategy repo rarely triggers.**
  3rd consecutive EOS where `git gc --auto` no-ops. The primary checkout
  stays lean because feature work happens in dedicated worktrees that
  share the object DB but don't keep their loose objects "live" the way
  a single-checkout workflow would. Safe to keep running it as cheap
  insurance, but don't expect it to do anything on this repo.
- **`gh api ... --jq` quoting is brittle in PowerShell.** First attempt
  with embedded backslash-escaped quotes failed at the jq parser. The
  reliable pattern is: `--jq '.[].name'` (no embedded quotes), then
  filter the result list in PowerShell with `Where-Object { $_ -like
  'squad/*' }`. Saves a round-trip when the quote dance fails.

## Sprint 13 EOS Cleanup (2026-05-17)

- **Trigger:** Post Sprint 13 close. Tag `0.9.3` cut to main
  (`edc67e2`), develop @ `ea2f5f0` after Jiminy session-end audit.
  0 open issues, 0 open PRs.
- **Known remnant (handed off by Jiminy, out of his scope):** live
  remote branch `origin/squad/319-history-archival` -- its PR #332
  merged 2026-05-17T09:24:42Z without `--delete-branch`.

### Actions

- `git worktree list` -- only main checkout
  (`C:\Users\Earl Tankard\Coding\dev-setup`) present. No stray
  worktrees to remove.
- `git branch -vv` -- only `develop` (active) and `main` local.
  No stale `squad/*` or `release/*` locals. Nothing to delete.
- Remote squad/release sweep -- `git ls-remote --heads origin`
  returned exactly 1 hit:
  - `squad/319-history-archival` @ `15e55be` -- PR #332 confirmed
    MERGED via `gh pr list --state merged --head ... --limit 1`.
    Deleted via `git push origin --delete`.
- `git remote prune origin` + `git fetch --all --prune` --
  idempotent, no further refs reaped (already in sync post-delete).
- `git gc --auto` -- no-op (4th consecutive EOS; pattern holds).
  `git count-objects -vH`: 2833 loose / 6.93 MiB, 5 packs /
  69.22 MiB, 238 prune-packable, 0 garbage.

### Final state

- Remote heads: `develop` (`ea2f5f0`), `main` (`edc67e2`).
  0 `squad/*` or `release/*` remnants.
- Local: `develop` (active), `main`. Working tree clean.
- Worktrees: 1 (main checkout only).

### Learnings (Ralph)

- **Jiminy handoff pattern works.** Jiminy's session-end audit
  explicitly documented the one ref it couldn't reap
  (`squad/319-history-archival`) because the merge happened outside
  his audit window. Ralph picked it up cleanly with a single targeted
  `--delete` + prune. The previous EOS learning ("local refs lag a
  fresh merge") generalizes: when a PR merges between Jiminy and Ralph
  dispatch, Ralph should expect exactly +1 remote ref to reap, not a
  full sweep. Cheap, predictable handoff.
- **Sprint 13 cleanup load was the smallest in 4 sprints.** 1 remote
  branch deleted, 0 local, 0 worktrees, 0 prune output. Consistent
  with the "cost per wave, not per PR" rule from Sprint 12 EOS: this
  sprint had fewer concurrent waves still open at close, so the
  surface area shrank accordingly. No new tooling needed.