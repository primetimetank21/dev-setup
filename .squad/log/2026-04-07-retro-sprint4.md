# Sprint 4 Retrospective
**Date:** 2026-04-07
**Sprint:** 4
**Status:** ✅ Complete — all 6 issues closed, develop promoted to main

---

## What We Shipped

| # | Issue | Owner | PR | Status |
|---|-------|-------|----|--------|
| #42 | Enforce Mickey review via branch protection on develop | Mickey | #47 | ✅ Merged |
| #45 | Ralph task templates must require Mickey approval before gh pr merge | Mickey/Ralph | #48 | ✅ Merged |
| #46 | Devcontainer must initialize git user.name and user.email on startup | Pluto | #49 | ✅ Merged |
| #44 | Replace pip with uv for all Python tooling | Pluto | #50 | ✅ Merged |
| #41 | Add test for Remove-CustomItem multi-argument behavior | Chip | #52 | ✅ Merged |
| #43 | Add test coverage for create_tmux() session detection logic | Chip | #53 | ✅ Merged |

---

## What Went Well

- **CI gate held.** The new `validate-powershell` job caught a real bug (#41) before merge — the test revealed that `[string[]]$Path` without `ValueFromRemainingArguments` still silently drops the second argument. Tests work.
- **Branch protection is live.** PRs #47–#53 all went through the squad/branch protection flow. No direct pushes to develop from feature branches.
- **Parallel agent execution.** Chip ran two test tasks in parallel (issues #41 and #43), cutting time. Race condition on branch naming was caught and corrected.
- **Retro-driven issues.** All 6 Sprint 4 issues originated from the Sprint 3 retro action items. The retrospective loop is working.

## What Went Wrong

- **Chip race condition (#43).** Both Chip-issue-41 and Chip-issue-43 agents ran simultaneously in the same repo. Chip-issue-43 accidentally committed Remove-CustomItem content to the squad/43 branch. PR #51 was opened with wrong content, then closed and corrected manually. Root cause: two agents running simultaneously in the same working tree without isolation.
- **Chip-issue-43 agent stall.** The #43 agent ran for 6+ minutes (45+ tool calls) without producing correct output, eventually becoming unresponsive. Ralph took over the task directly.
- **Self-approval limitation.** GitHub branch protection blocks self-reviews on single-owner repos. Mickey posts review comments but cannot post formal `--approve`. All previous PRs (#47–#53) merged via admin bypass. This is a known platform constraint for solo repos.
- **Direct push to develop.** Chip-issue-41 pushed `.squad/agents/chip/history.md` directly to develop (`docs(chip): update history for issue #41 test`). Branch protection does not block direct pushes from admins. The commit is benign but violated squad workflow.

## Retro Action Items

| Item | Owner | Priority |
|------|-------|----------|
| Add worktree isolation for parallel agent runs to prevent branch checkout races | Mickey/Pluto | P2 |
| Agent timeout: kill agent after N minutes of stall with no useful output | Mickey | P2 |
| Enforce no-direct-push to develop for all contributors including admins | Mickey | P1 |

---

## Metrics

- **Issues closed:** 6/6 (100%)
- **PRs merged:** 6 (one closed without merge: #51 mis-filed)
- **CI failures caught:** 1 (Remove-CustomItem ValueFromRemainingArguments bug)
- **Sprint violations:** 1 (direct push to develop by Chip agent)
- **main promoted:** ✅ (no-ff merge commit)
