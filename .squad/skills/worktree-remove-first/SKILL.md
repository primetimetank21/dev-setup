---
name: "worktree-remove-first"
description: "Safe merge sequence for Squad PRs developed in a git worktree -- remove the worktree and delete the local branch BEFORE invoking gh pr merge --delete-branch, to sidestep a deterministic gh CLI quirk that leaves the remote branch ref orphaned"
domain: "repo-meta, release-flow"
confidence: "high"
source: "earned (issue #317, Sprint 12 -> Sprint 13, 5-of-5 proven)"
---

## Context

When a Squad agent develops a PR in an isolated git worktree (per the
`worktree-isolation` skill), the local feature branch is checked out inside the
worktree, not the main checkout. Merging that PR via
`gh pr merge <N> --delete-branch` while the worktree still owns the branch
fails 100% deterministically: gh refuses to delete the remote ref (or reports
"merge failed" / "branch still protected") because it sees the local branch is
checked out in a working tree. The squash/merge itself succeeds on the GitHub
side, but the remote-side `--delete-branch` step half-fails, leaving an
orphaned `origin/squad/<N>-<slug>` ref behind.

This skill applies whenever an agent (or coordinator) is about to merge any
`squad/*` PR that was developed in a worktree -- which, under the standard
Squad dispatch flow, is effectively every feature PR.

The pattern was originally tracked as a recurring nuisance in issue #300
(closed once as "no longer reproducible") and re-surfaced in Sprint 12 Wave 2,
where it was reproduced 5-of-5 across PRs #320, #321, #323, #324, and #327
(plus the 0.9.2 release PR #328 using `--merge`). Issue #317 captures the
formal write-up; this skill is the codification.

## Patterns

### Pattern 1 -- The worktree-remove-FIRST sequence (mandatory for any worktree-developed PR)

Run these five steps IN ORDER from the MAIN checkout (never from the worktree
being torn down).

```powershell
# 0. Harvest. Before destroying the worktree, copy out any uncommitted hygiene
# files the agent forgot to push (history.md tail, decisions/inbox/ drops).
# Stage them on develop from the main checkout, or stash and re-push.

# 1. Remove the worktree. --force handles the case where the agent left a
# dirty index; you have already harvested in step 0.
git worktree remove ..\dev-setup-<N> --force

# 2. Delete the LOCAL feature branch. It is now dangerous to leave around --
# any future `git checkout` could land you back on it.
git branch -D squad/<N>-<slug> 2>$null

# 3. Merge the PR with --delete-branch. With the worktree gone and the local
# ref deleted, gh's pre-flight check passes and the remote ref is removed
# cleanly along with the merge.
gh pr merge <N> --admin --squash --delete-branch

# 4. Verify. Both local AND remote refs should be gone.
git branch --list "squad/<N>-*"          # expect empty
git ls-remote --heads origin "squad/<N>-*"  # expect empty
```

### Pattern 2 -- Release PRs preserve history with --merge

For release PRs (e.g. `release/0.9.1`, `release/0.9.2`) that need the full
commit history preserved, swap `--squash` for `--merge`:

```powershell
gh pr merge <N> --admin --merge --delete-branch
```

The worktree-remove-FIRST sequence (steps 0-2 above) is identical; only the
merge strategy differs. Proven on the 0.9.1 and 0.9.2 cuts.

### Pattern 3 -- Recovery if you forget and merge with the worktree still attached

If you (or another agent) ran `gh pr merge --delete-branch` first and the
remote ref survived, recover by:

```powershell
# 1. Force-prune the worktree and local branch (now that merge is done).
git worktree remove ..\dev-setup-<N> --force
git branch -D squad/<N>-<slug> 2>$null

# 2. Manually delete the orphaned remote ref.
git push origin --delete squad/<N>-<slug>

# 3. Prune your local view of remotes.
git fetch origin --prune
```

This is the same fallback Ralph uses in EOS cleanup (see PR #295). Treat it as
a recovery path, not the default -- the upfront sequence is one fewer round
trip.

### Pattern 4 -- Why the order matters

`gh pr merge --delete-branch` invokes the GitHub REST API to delete the remote
ref AFTER the merge commit lands. gh's local pre-flight checks the working
copy state: if it finds the branch checked out in any worktree, it aborts the
remote-delete step (sometimes silently, sometimes with a confusing
"merge failed" surface) and leaves the post-merge cleanup half-done. Removing
the worktree first removes the precondition that trips the check.

## Examples

**Sprint 12 Wave 2 (5-of-5 successful applications):**
- PR #320 (Donald, `squad/237-test-harness-pattern`)
- PR #321 (Mickey, `squad/310-arch-windows-dep-order`)
- PR #323 (Scribe wave-2 fold, `squad/scribe-sprint-12-wave-2-fold`)
- PR #324 (Mickey, `squad/306-readme-refresh`)
- PR #327 (Scribe sprint-12 retro fold)

**Sprint 12 release:**
- PR #328 (`release/0.9.2`), same sequence with `--merge` instead of
  `--squash` to preserve the release history.

**Counter-example (Sprint 11, before the pattern was named):**
- Issue #300 tracked an apparent 5-of-6 fail rate of
  `gh pr merge --delete-branch` producing ghost remote refs. At the time, the
  root cause was hypothesised as a `gh` upstream bug. The Sprint 12 evidence
  reframes it: the trigger was the worktree-owns-branch precondition, not a
  CLI regression. Closing #300 as "no longer reproducible" was premature; the
  fix is procedural (this skill), not waiting on upstream.

## Anti-Patterns

- **Calling `gh pr merge --delete-branch` while the worktree is still attached.**
  100% failure on the remote-delete step. Symptoms: merge succeeds on GitHub,
  but `git ls-remote origin` still shows the feature branch ref days later.
- **Removing the worktree but skipping the local branch delete.** Leaves a
  dangling local `squad/<N>-<slug>` ref that future `git checkout` or
  `git branch -a` listings will surface as noise. Ralph's EOS sweep cleans
  these, but cleaning at merge time is cheaper.
- **Force-removing the worktree before harvesting hygiene files.** The agent's
  `history.md` tail or `decisions/inbox/` drop may live only in the worktree
  index if the agent forgot to push. Always copy out (or stash + apply on
  develop from the main checkout) before `git worktree remove --force`.
- **Running the sequence from inside the worktree being removed.** `git
  worktree remove` cannot remove the working tree you are currently sitting
  in. Always run from the main checkout (or any unrelated CWD).
- **Substituting `git worktree remove --force` with manual `rm -rf`.** Skips
  git's bookkeeping; `git worktree list` will keep reporting a stale entry
  until `git worktree prune` runs. Use the porcelain command.

## References

- Issue #317 -- formalization request and 5-of-5 evidence
- Issue #300 -- earlier (closed) tracker of the same symptom
- PR #295 -- Ralph EOS post-merge `git push origin --delete` fallback
- `.squad/skills/worktree-isolation/SKILL.md` -- the agent-dispatch race
  condition that necessitates worktrees in the first place (a different
  concern; this skill covers the merge tail, that skill covers the spawn head)
- `git worktree` man page

**Last reviewed:** 2026-05-17
