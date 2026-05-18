---
name: "worktree-remove-first"
description: "Safe merge sequence for Squad PRs developed in a git worktree -- harvest hygiene files, remove the worktree, delete the local branch, THEN invoke gh pr merge --delete-branch. Skipping this order loses inbox files or leaves orphaned remote refs."
domain: "repo-meta, release-flow"
confidence: "medium"
source: "earned (issue #317 Sprint 12-13, 29+ applications Sprints 12-16)"
---

## Context

When a Squad agent develops a PR in an isolated git worktree (per the
`worktree-isolation` skill), the local feature branch is checked out inside the
worktree, not the main checkout. Two independent failure modes arise if the
merge sequence is wrong:

1. **Hygiene loss.** The agent may have dropped files into
   `.squad/decisions/inbox/` or appended to `history.md` inside the worktree
   without pushing. Those changes live only in the worktree index. If the
   worktree is torn down before they are harvested, or if the PR is merged
   before the coordinator inspects the worktree, those files are silently lost.

2. **Orphaned remote ref.** Calling `gh pr merge <N> --delete-branch` while the
   worktree still has the branch checked out causes the gh CLI to abort the
   remote-delete step (or half-fail silently), leaving `origin/squad/<N>-<slug>`
   behind after the merge commit lands on develop.

This skill applies whenever an agent (or coordinator) is about to merge any
`squad/*` PR that was developed in a worktree -- which, under the standard
Squad dispatch flow, is effectively every feature PR.

The pattern was originally tracked in issue #300 (closed once as
"no longer reproducible") and re-surfaced in Sprint 12 Wave 2 across PRs
#320, #321, #323, #324, #327. Issue #317 is the formal write-up.
The skill has been applied 29+ times across Sprints 12-16 without a single
failure when the order is followed.

## Patterns

### Pattern 1 -- The worktree-remove-FIRST sequence (mandatory for any worktree-developed PR)

Run these steps IN ORDER from the MAIN checkout (never from the worktree
being torn down).

```powershell
# Step 1. Harvest hygiene files BEFORE touching the worktree.
# Inspect .squad/decisions/inbox/* and any history.md appends the agent
# dropped in the worktree but did not push. Copy or cherry-pick them onto
# develop from the main checkout now, before the worktree is destroyed.
# If everything is already pushed, this step is a quick ls-and-confirm.

# Step 2. Remove the worktree. --force handles a dirty index; you have
# already harvested in step 1.
git worktree remove ..\dev-setup-<N> --force

# Step 3. Delete the LOCAL feature branch. With the worktree gone this ref
# is now an orphan that will cause confusion on future checkouts.
git branch -D squad/<N>-<slug> 2>$null

# Step 4. Merge the PR with --delete-branch. With the worktree gone and the
# local ref deleted, gh's pre-flight check passes and the remote ref is
# removed cleanly along with the merge commit.
gh pr merge <N> --admin --squash --delete-branch

# Step 5. Verify. Both local AND remote refs should be gone.
git branch --list "squad/<N>-*"             # expect empty
git ls-remote --heads origin "squad/<N>-*"  # expect empty
```

### Pattern 2 -- Release PRs preserve history with --merge

For release PRs (e.g. `release/0.9.1`, `release/0.9.2`) that need the full
commit history preserved, swap `--squash` for `--merge`:

```powershell
gh pr merge <N> --admin --merge --delete-branch
```

The worktree-remove-FIRST sequence (steps 1-3 above) is identical; only the
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

**Sprint 12 Wave 2 (5-of-5 -- first formal application after issue #317):**
- PR #320 (Donald, `squad/237-test-harness-pattern`)
- PR #321 (Mickey, `squad/310-arch-windows-dep-order`)
- PR #323 (Scribe wave-2 fold)
- PR #324 (Mickey, `squad/306-readme-refresh`)
- PR #327 (Scribe sprint-12 retro fold)
- PR #328 (`release/0.9.2`) -- same sequence with `--merge` to preserve history

**Sprint 15 (4-of-4 -- Doc dual-worktree wave):**
- PR #357 (Mickey, `squad/355-sprint-letter-normalization`)
- PR #358 (Doc, `squad/356-ascii-sweep`)
- PR #359 (Doc, history fold `squad/doc-history-sprint-15`)
- PR #360 (Coordinator, develop->main release fold)

Lifetime record at Sprint 15 close: 25-of-25 across Sprints 12-15.

**Sprint 16 (3 additional applications):**
- PR #368 (Pluto, `squad/367-skill-drift-audit`) -- also the `--base main`
  incident; worktree-remove-FIRST itself was followed correctly
- PR #369 (Pluto, `squad/362-ascii-docs-skill`)
- PR #370 (Pluto, `squad/364-worktree-base-refresh-skill`)

**Counter-example (Sprint 11, before the pattern was named):**
- Issue #300 tracked an apparent 5-of-6 fail rate of
  `gh pr merge --delete-branch` producing ghost remote refs. At the time the
  root cause was hypothesised as a gh upstream bug. The Sprint 12 evidence
  reframes it: the trigger was the worktree-owns-branch precondition. Closing
  #300 as "no longer reproducible" was premature; the fix is procedural (this
  skill), not waiting on upstream.

## Anti-Patterns

- **Calling `gh pr merge --delete-branch` while the worktree is still attached.**
  100% failure on the remote-delete step. Symptoms: merge succeeds on GitHub,
  but `git ls-remote origin` still shows the feature branch ref days later.
- **Merging the PR before harvesting hygiene files.** The worktree may contain
  inbox drops or history.md appends the agent did not push. Once the PR is
  merged and the worktree is removed, those files are unrecoverable from the
  branch history.
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

- Issue #317 -- formalization request and 5-of-5 Sprint 12 evidence
- Issue #383 -- Sprint 17 revision request (hygiene harvest + medium confidence)
- Issue #300 -- earlier (closed) tracker of the same symptom
- PR #295 -- Ralph EOS post-merge `git push origin --delete` fallback
- `.squad/skills/worktree-isolation/SKILL.md` -- the agent-dispatch race
  condition that necessitates worktrees in the first place (a different
  concern; this skill covers the merge tail, that skill covers the spawn head)
- `.squad/skills/gh-pr-base-develop/SKILL.md` -- companion skill: every
  `gh pr create` must pass `--base develop` explicitly
- `git worktree` man page

**Last reviewed:** 2026-05-17 (Sprint 17, issue #383)
