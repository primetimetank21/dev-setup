# SKILL: sandbox-cwd-isolation

**Confidence**: High  
**First observed**: Issue #430 (PR #431)  
**Confirmed again**: Issue #433  

## Rule

Always run test scripts from a **neutral CWD** (a directory that is NOT a git
repo and does NOT have the tags/history your test sandbox creates) before
pushing. Never consider a test fix complete based on a run inside the worktree.

## When to invoke

Invoke this check any time a test:
- Shells out to `git` (e.g., `git rev-parse`, `git log`, `git tag`)
- Creates a temporary git sandbox (`git init` + `git tag`)
- Uses `bash -c` to invoke a script that internally calls `git`

If any of the above apply, the "neutral CWD" smoke test is **mandatory** before
pushing.

## Recipe

```powershell
# 1. Create a fresh directory that is NOT inside any git repo
$tmpCwd = "C:\Temp\test-isolated-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpCwd | Out-Null

# 2. cd into it (so the test process CWD has no git history/tags)
Set-Location $tmpCwd

# 3. Run the test suite with an absolute path to the script
pwsh -File "C:\path\to\worktree\tests\test_changelog_fold.ps1"

# 4. MUST report: 5 passed, 0 failed
# If any fail, the fix is incomplete -- iterate before pushing.

# 5. Clean up
Set-Location $WORKTREE_PATH
Remove-Item $tmpCwd -Recurse -Force
```

## Why this matters

When running tests from inside the worktree:
- Git commands pick up the *host* repo's tags, history, and refs.
- A sandbox `git init + git tag` may appear to work because the host repo
  already has that tag in scope.
- On CI (shallow clone, no host tags), the same test fails.

The neutral-CWD run exactly replicates CI's stateless environment and will
catch this class of state-leak bug before it reaches CI.

## Anti-pattern to avoid

```powershell
# BAD: running test from inside the worktree
Set-Location $WORKTREE_PATH
pwsh -File tests\test_changelog_fold.ps1  # PASSES locally, FAILS on CI
```

```powershell
# GOOD: running test from neutral CWD
Set-Location C:\Temp\test-isolated-12345
pwsh -File $WORKTREE_PATH\tests\test_changelog_fold.ps1  # catches CI bugs
```

## Related issues

- #430: First occurrence -- `changelog-fold` tag resolution in CI
- #433: Second occurrence -- same test, same error, different root cause layer
