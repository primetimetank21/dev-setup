---
name: "worktree-base-refresh"
description: "When the pre-commit branch-ancestry hook rejects a stale sprint branch (cut from an old develop tip), use a 3-phase backup + git reset --hard origin/develop + restore recipe. Avoid git reset --soft -- it leaves the index pinned to the divergent base."
domain: "git-recovery"
confidence: "low"
source: "earned"
---

## Context

Sprint-scoped squad branches (e.g., `squad/doc-history-sprint-N`) are cut from
`develop` at sprint kickoff. As the sprint progresses, `develop` moves forward via
squash-merges of sister PRs. By the time the sprint-scoped branch is ready to
commit, its base is stale and the pre-commit branch-ancestry hook rejects the
commit with:

```
ERROR: Branch ancestry bleed detected.

  Branch '<name>' is not descended from 'develop'.
```

(Hook source: `hooks/pre-commit`, Check 1.)

This skill applies when:
- You have staged-but-uncommitted work.
- The branch has NO unique commits you need to keep (it is effectively a
  "fresh-cut" branch that never got a commit before develop moved on).

If the branch HAS unique commits you want to preserve, use `git rebase` instead
(see Anti-Patterns below).

## Patterns

### Why `git reset --soft` is unsafe

Intuition says: "preserve staged files, move HEAD to develop."

But `git reset --soft` moves only HEAD; it leaves the INDEX pinned to the old
base. Result: `git status` now shows every file that `develop` changed (relative
to the old base) as `M` -- spurious mass-staging that would commit a reversion
if you ran `git commit` without careful inspection. With 30+ changed files this
is nearly impossible to untangle safely.

**Never use `git reset --soft` for base-refresh on a diverged branch.**

---

### The 3-Phase Recovery Recipe

#### Phase 1 -- Backup staged files

Identify which files are staged (`git status --short` -- lines starting with
`M `, `A `, etc. in the index column). Copy each one to a safe scratch
directory inside the repo (never `/tmp` -- use a `_tmp_recovery_<slug>` folder
under `scripts/`).

```powershell
# Resolve repo root dynamically -- never hardcode a user path
$repoRoot = (git rev-parse --show-toplevel)
$tmpDir = Join-Path $repoRoot 'scripts\_tmp_recovery_<slug>'
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

Copy-Item '<staged-file-1>' "$tmpDir\<name-1>"
Copy-Item '<staged-file-2>' "$tmpDir\<name-2>"
# ... repeat for every staged file
```

#### Phase 2 -- Hard-reset to origin/develop

```powershell
git reset --hard origin/develop   # wipes working tree to develop's state
git --no-pager log --oneline -2   # verify HEAD is now on origin/develop tip
```

After this step `git status --short` must show an empty output. If it does not,
stop and investigate before proceeding.

#### Phase 3 -- Restore files and commit

```powershell
Copy-Item "$tmpDir\<name-1>" '<staged-file-1>' -Force
Copy-Item "$tmpDir\<name-2>" '<staged-file-2>' -Force
# ... restore all backed-up files

git add '<staged-file-1>' '<staged-file-2>'
git status --short   # MUST show ONLY your intended files

git commit -m "<your message>"
Remove-Item -Recurse -Force $tmpDir   # clean up scratch dir
```

---

### Acceptance Checks Before Pushing

Run all three checks. If any fails, stop and diagnose before pushing.

```powershell
# 1. Only intended files staged -- no 30+ M lines
git status --short

# 2. Only your additions in the diff -- no spurious reversions
git --no-pager diff HEAD~1

# 3. Branch is now descended from origin/develop (exits 0 on success)
git merge-base --is-ancestor origin/develop HEAD
echo "exit code: $LASTEXITCODE"   # must be 0
```

## Examples

**Sprint 15 -- PR #359 (`doc-history-sprint-15`)**

- Branch cut at `5c5eda4` (Sprint 14 end-of-sprint tip).
- `develop` advanced to `b471e76` via squash-merges #357 + #358.
- pre-commit Check 1 rejected the commit with the ancestry-bleed error.
- Recovery: 3-phase recipe above applied by the Coordinator.
- Recovery commit: `d3229c8`.

This is the single observed application that established this skill
(confidence: low). Confidence will graduate to medium on second observation.

## Anti-Patterns

- **`git reset --soft origin/develop`** -- leaves index pinned to old base;
  produces spurious mass-staging of all files develop changed. Do not use.

- **Committing after `--soft` without inspecting `git status --short`** --
  you will silently revert a large portion of develop's changes.

- **Using this recipe when the branch has real commits to keep** -- use
  `git rebase origin/develop` (interactive if needed) to replay commits
  on top of the new develop tip. This recipe is for zero-unique-commit
  branches with only staged-but-uncommitted work.

- **If you have time before staging work** -- the cleanest path is always:
  `git rebase origin/develop` first, then commit on the rebased branch.
  The 3-phase recipe is the emergency recovery path.

## Related Skills

- `.copilot/skills/git-workflow/SKILL.md` -- squad branching model,
  worktree setup, develop-first workflow.
- `hooks/pre-commit` Check 1 -- the branch-ancestry guard that produces
  the `Branch ancestry bleed detected` error triggering this recipe.
- Future skill: `worktree-remove-first` (12-of-12 lifetime but not yet
  formalized -- noted for a separate issue).
