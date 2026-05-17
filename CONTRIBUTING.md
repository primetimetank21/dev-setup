# Contributing to dev-setup

Welcome! This repo is maintained by the **Disney Classic Squad** -- a team of specialized AI agents each owning a slice of the codebase. Human contributors are equally welcome. This guide explains how to work alongside the squad.

---

## Branch Protection

The `develop` branch is protected at the GitHub level. Direct pushes are blocked for everyone -- all changes must go through a PR with at least one approving review and passing CI.

The branch protection rule has `enforce_admins` intentionally **disabled**. Why? On a solo-owner repo, GitHub blocks self-approval -- an admin can't approve their own PR. Setting `enforce_admins=true` would create a deadlock: the only approver (the admin) can't approve themselves. The solution is `enforce_admins=false`, which allows the repo owner to use `gh pr merge --admin` to bypass the approval requirement *only when necessary* (e.g., to unblock themselves). This preserves the protection goal (no direct pushes) while avoiding the self-approval deadlock.

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

## Branch Isolation

**Always create new branches from the tip of `develop`:**

```bash
git checkout develop
git pull origin develop
git checkout -b squad/{issue-number}-{slug}
```

**Never fork a squad branch from another squad branch.** Branching from a peer's branch pulls in their unmerged commits, inflating your PR diff and making review harder. If you see commits in your PR that don't belong to your issue, your branch was not forked from `develop`.

> This rule exists because "branch ancestry bleed" occurred 3 times in Sprint 6. Every time it's violated, PR review quality degrades.

**All squad branches MUST be cut from `develop`, not `main`.** The pre-commit hook validates this: if you commit to a `squad/*` branch that is not an ancestor of `develop`, the hook warns that you may have accidentally forked from `main` or another squad branch. To fix: `git rebase develop` before pushing.

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

- **Mickey** is the lead reviewer -- all PRs require Mickey's approval before merge.
- **CI must be green** before requesting review. Do not ask for review on a failing PR.
- Reviewers may request changes or reassign work to a different squad member.
- If Mickey rejects a PR, a *different* agent (not the original author) will be assigned to revise.

---

## Merge Strategy

**ALL merges use regular merge commits** (`--merge` or `gh pr merge --no-squash`).

**Never squash** -- not for feature PRs to `develop`, not for sprint wrap PRs (`develop` -> `main`). This is a hard team rule.

**Why?** Regular merge commits preserve history and make debugging (`git log`, `git blame`) clear. Squash collapses history, making it harder to trace which issue introduced a bug.

---

## CHANGELOG Conflict Strategy

When multiple PRs land in a single sprint, `CHANGELOG.md` `[Unreleased]` is a predictable
conflict zone (multiple PRs append to the same `### Added` / `### Changed` / `### Fixed`
section). Resolution is mechanical, not semantic:
1. Entries land in **merge order** (the later PR rebases on top of the earlier one's entry).
2. Keep **unique section headers** (`### Added`, `### Changed`, `### Fixed`, `### Removed`).
3. On conflict: **union both entries - keep ALL lines from both sides, no deduplication**.
   `CHANGELOG.md` is an append-only log, not a deduped list. Both agents intended their entry.
4. Add `CHANGELOG.md merge=union` to `.gitattributes` is NOT recommended here - manual review
   catches accidentally inverted entries.

---

## PowerShell 5.x Compatibility

All `.ps1` scripts in this repo must run on **PowerShell 5.1** (the version shipped with Windows 10/11). PS 7+ runs on Linux Codespaces; PS 5.1 is what end users actually have.

### Checklist for any `.ps1` changes

- [ ] **No `$MyInvocation.MyCommand.Path`** -- use `$PSScriptRoot` instead. `MyCommand.Path` returns null in PS 5.x when dot-sourced.
- [ ] **PS 6+ automatic variables are guarded** -- `$IsLinux`, `$IsMacOS`, `$IsWindows` do not exist in PS 5.x. Always guard:
  ```powershell
  if ($PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux) { ... }
  ```
- [ ] **Works under `Set-StrictMode -Version Latest`** -- `setup.ps1` runs with StrictMode on. Uninitialized variables and undefined properties are hard errors, not silent nils.
- [ ] **String literals are ASCII-only in test files** -- Characters whose UTF-8 encoding contains byte `0x94` (em-dash `--`, curly quotes `""`, box-drawing chars) corrupt PS 5.x parsing under CP1252. Use plain hyphens and straight quotes in all test strings.
- [ ] **Built-in alias conflicts handled** -- Before `Set-Alias`, remove conflicts: `Remove-Item -Force Alias:\{name} -ErrorAction SilentlyContinue`

### Testing on PS 5.1

Since the dev environment runs PS 7+, you cannot natively run PS 5.1 tests. Manual testing on a Windows machine is the current standard. See issue #109 for the CI validation track.

### Reference: Known PS 5.x regressions caught in this repo

| Date | Bug | Fix |
|------|-----|-----|
| 2026-04-18 | `$MyInvocation.MyCommand.Path` returned null in PS 5.x | Replaced with `$PSScriptRoot` |
| 2026-04-18 | `Remove-CustomItem` missing `Recurse` flag, broke under StrictMode | Added `-Recurse -Force` to `Remove-Item` call |

---

## Git Hooks

Git hooks are **configured automatically** by `setup.sh` / `setup.ps1` via `git config core.hooksPath hooks`. You do not need to copy or symlink anything manually.

After running setup, the following hooks are active:

| Hook | Behavior |
|------|----------|
| `pre-commit` | Checks staged `.sh` files with shellcheck. Blocks commit on errors; silently skips if shellcheck not installed. |
| `commit-msg` | Enforces Conventional Commits format. Hard reject on non-conforming messages. |
| `pre-push` | Blocks direct pushes to `main`. Runs shellcheck/PSScriptAnalyzer on changed files (advisory--never blocks). |

See README > Git Hooks (Auto-configured) for details on each hook's checks and how to bypass with `--no-verify`.

### Installing PSScriptAnalyzer locally (optional)

To get PS lint feedback during `pre-push`, install the module once in PowerShell:

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
```

The hook auto-detects `pwsh` and the module. If either is absent, the check is silently skipped.

### Why is PSSA advisory in `pre-push`?

PSSA findings warn but never block local pushes. The hook intentionally exits 0 even when PSSA reports issues. Three reasons:

1. **Availability gap.** Not every contributor host has `pwsh` + the PSScriptAnalyzer module installed (e.g., Linux/macOS without PowerShell Core, or Windows boxes without PSGallery network access). Blocking would punish hosts that simply lack the tool.
2. **Subjective rules.** Many PSSA rules (`PSAvoidUsingWriteHost`, `PSUseSingularNouns`, etc.) are style preferences, not bugs. CI -- not the developer's machine -- is the right gate for those.
3. **Out of scope to harden.** Making PSSA blocking locally would require pinning a module version and curating a cmdlet allowlist. That work is deferred; if you need strict local linting today, run `Invoke-ScriptAnalyzer` manually before pushing. The inline comment block at the top of the PSSA section in `hooks/pre-push` records this intent so the `|| true` is not "fixed" away.

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

Each worktree has its own index and working files but shares the same `.git` object store with the main repo -- no extra disk space for history, just the working tree.

### Cleaning up

Worktrees are not automatically removed. After a PR is merged, clean up with:

```bash
git worktree remove /workspaces/dev-setup-56
```

Or list all active worktrees with `git worktree list`.

### Merging Squad PRs from worktrees

When merging a Squad PR that was developed in a worktree, follow the worktree-remove-FIRST pattern (remove the worktree and delete the local branch BEFORE `gh pr merge --delete-branch`). See `.squad/skills/worktree-remove-first/SKILL.md` for the five-step sequence and the gh CLI quirk it sidesteps.

---

## Test Harness Pattern

Bash test files in `tests/*.sh` follow a **tally-based harness convention**: each assertion
increments a `PASS` or `FAIL` counter, the script prints a results line, and the script
exits non-zero only if `FAIL > 0`. **This is intentional** -- a single failed assertion must
not abort the rest of the suite, because contributors need to see every failure in one run.

### `set -uo pipefail` vs `set -euo pipefail`

The non-obvious gotcha: most bash test files use `set -uo pipefail` -- **`-e` is
intentionally OFF**.

| Flag | Behavior |
|------|----------|
| `-e` (errexit) | Abort the script on the first command that returns non-zero. |
| `-u` (nounset) | Error on reference to an unset variable. |
| `-o pipefail`  | A pipeline returns the first non-zero exit code in the chain. |

If `-e` were on, a single failing assertion (e.g., `grep -q PATTERN file` returning 1
because the pattern was absent) would kill the script before `fail()` could even
increment the counter. The remaining tests would never run. The tally model relies on
each assertion completing AND being counted, regardless of outcome.

**When `-euo pipefail` IS acceptable:** when every potentially-failing command is
wrapped in `if ...; then ... fi` or `cmd || handler`, `-e` does not fire on that
command. Three files in the suite (`test_nvm_bootstrap.sh`, `test_precommit_hygiene.sh`,
`test_shared_logging.sh`) use `-euo` because every assertion is `if grep -q ...; then
pass; else fail; fi` shaped. Both styles are valid; prefer `-uo` when the test body
calls subprocesses or scripts that may legitimately exit non-zero outside an `if`.

**Rule of thumb:** if you add a new bash test that calls a script directly (e.g.,
`bash setup.sh` as part of the test), use `set -uo pipefail` and let the tally
counters be the source of truth for PASS/FAIL.

### Failure tally pattern

Every bash test file establishes counters at the top and exits based on the tally:

```bash
#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

# ...assertions invoke pass "..." or fail "..."...

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
```

Notes:

- Counter names vary by file (`PASS`/`FAIL` in older tests, `passed`/`failed` in
  newer ones). Either is fine; pick one and use it consistently within a file.
- The non-zero exit at the end is what CI sees. Without it, a tally of `5 passed,
  3 failed` would still report success to CI.
- Color escapes are conventional but optional. Tests must stay ASCII-only
  (the `RED`/`GREEN`/`RESET` strings themselves are ASCII -- only the rendered
  output is colored).

### Helper conventions

Most test files define `pass()` and `fail()` as one-liners (see snippet above).
Files that test against a complex fixture (e.g., `test_idempotency.sh`) wrap
common assertions in helpers prefixed with `assert_`:

| Helper | Used in | What it checks |
|--------|---------|----------------|
| `assert_command_exists "<cmd>" "<msg>"` | `test_idempotency.sh` | `command -v` resolves the binary; tallies pass/fail with the supplied message. |
| `assert_file_exists "<path>" "<msg>"` | `test_idempotency.sh` | `[[ -f $path ]]`; tallies pass/fail. |
| `assert_dir_exists "<path>" "<msg>"` | `test_idempotency.sh` | `[[ -d $path ]]`; tallies pass/fail. |
| `assert_no_duplicate_lines "<file>" "<pattern>" "<msg>"` | `test_idempotency.sh` | `grep -c <pattern> <file>` returns <= 1. |
| `assert_idempotent_tool_script "<script>" "<name>"` | `test_idempotency.sh` | Runs the script a second time; expects exit 0 plus an "already installed / configured / skipping" marker. |

These helpers are file-local -- there is no shared `tests/helpers.sh` yet. If a new
helper is reused across two or more test files, factor it into a shared library
under `tests/lib/` (matches the `scripts/linux/lib/` + `scripts/windows/lib/`
source-of-truth pattern; see ARCHITECTURE.md).

### Minimal skeleton

Copy this into a new `tests/test_<thing>.sh` and adapt:

```bash
#!/usr/bin/env bash
# tests/test_<thing>.sh -- <one-line description>
#
# Usage (from repo root):
#   bash tests/test_<thing>.sh
#
# Exit codes:
#   0 -- all assertions passed
#   1 -- one or more assertions failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

# Example assertion
if [ -f "${REPO_ROOT}/setup.sh" ]; then
    pass "setup.sh exists at repo root"
else
    fail "setup.sh is missing at repo root"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
```

### Scope

This convention covers **bash** test files (`tests/*.sh`). PowerShell tests
(`tests/*.ps1`) use a different harness (`Test-Scenario` blocks in
`test_windows_setup.ps1`, see Group Letter Assignment below) and are out of scope
for this section.

For the broader rationale around test isolation and second-run safety, see
`tests/README.md` (idempotency suite overview).

---

## Group Letter Assignment (parallel test work)

Behavioral tests in `tests/test_windows_setup.ps1` are organized by alphabetic groups
(Group A, B, ..., V, W, X, Y, Z, AA, BB, ...). When 2+ parallel agents may extend this
file in the same sprint, the **coordinator pre-assigns Group letters in each spawn prompt**
to prevent collisions. Sprint 9 (formerly Sprint R) example: Chip #267 picked "Group X" independently while
Goofy #268 also picked "Group X" - required a manual rename to Group Y during rebase.
Going forward, the coordinator's spawn checklist includes Group letter assignment for any
agent that may add tests to this file.

---

## Sprint Naming Convention

Sprints use **numeric naming** (Sprint 1, Sprint 2, ...).

### Historical mapping (letters -> numbers)

| Old (letter) | New (number) | Reason |
|---|---|---|
| Sprint Q | **Sprint 8-hotfix** | P0 emergency batch fixed AFTER Sprint 8 wrap but BEFORE 0.8.0 ship; #249, #251, #252. Shipped inside 0.8.0. |
| Sprint R | **Sprint 9** | Hygiene backlog sprint, post-0.8.0. |
| Sprint S | **Sprint 10** | Tool-version pin sweep sprint. |
| Sprint T | **Sprint 11** | ARCHITECTURE refresh + auth.ps1 move + PSSA advisory + LASTEXITCODE hardening. |

Next sprint = **Sprint 12** (was going to be Sprint U).

### Aliasing convention

First-occurrence-per-file mentions of old names include a `(formerly Sprint X)` parenthetical
for grep continuity. Subsequent occurrences in the same file use the new numeric name alone.
This preserves searchability for anyone referencing old PR titles, commit messages, or external
docs that used the letter names.

### History

- **Sprints 1-7** -- numbered, each shipped its own version (0.1.0 - 0.7.0). CHANGELOG headers
  used the suffix `-- Sprint N: name`.
- **Sprint 8** -- gap audit / Windows setup refactor (PR #195 et al). Folded into 0.8.0 alongside Sprint 8-hotfix.
- **Sprint 8-hotfix (formerly Sprint Q)** -- emergency hotfix batch fixed AFTER Sprint 8 wrap but BEFORE 0.8.0 ship.
  Three P0 install regressions (#249, #251, #252). Got the letter "Q" because it was an
  out-of-cadence quality/hotfix interjection.
- **Sprint 9 (formerly Sprint R), Sprint 10 (formerly Sprint S), Sprint 11 (formerly Sprint T)** --
  continued the letter scheme instead of switching back to numbers. With only 26 letters in
  the alphabet and 4 already used in 2 weeks, the letter scheme isn't sustainable.
  Reverting to numbers (decision: 0.9.1 release wrap, Earl-driven).

### Convention going forward

- Next sprint after Sprint 11 = **Sprint 12** (NOT Sprint U).
- CHANGELOG release headers MUST include `-- Sprint N: short-name` suffix (matches the 0.1.0-0.7.0 pattern).
- Retro file naming: `.squad/retros/YYYY-MM-DD-sprint-N-retro.md` (numeric).
- Retro files renamed to numeric (e.g., `2026-05-16-sprint-8-hotfix-retro.md`).
- Out-of-cadence hotfix sprints (a la Sprint 8-hotfix) get a `-hotfix` suffix in retro filename:
  `.squad/retros/YYYY-MM-DD-sprint-N-hotfix-retro.md` -- the version header attribution stays
  on the numeric parent (e.g., `Sprint 8 + Sprint 8-hotfix`).

### Why this matters

The letter scheme caused real confusion: Sprint 8 silently vanished from CHANGELOG headers
between 0.7.0 and 0.8.0, and the alphabet runs out. Numbers are unbounded and consistent
with the established 1-7 history.

---

For the full technical overview, team ownership map, and architecture decisions, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Tool Version Pin Enforcement

All install scripts that install a versioned tool MUST follow the version-pin pattern.
**Never use a bare `command -v X` (or `Get-Command X`) idempotency guard.** That pattern
silently keeps whatever version the runner cached and never upgrades on version bumps.

### Pattern

1. **Pin** the desired version in `.tool-versions`:
   ```
   squad-cli 0.9.4
   gh 2.92.0
   ```

2. **Read** the pin at install time using the shared helpers:
   ```bash
   # Bash/POSIX (Linux/macOS)
   VERSION="$(sh scripts/lib/read-tool-version.sh squad-cli)"
   ```
   ```powershell
   # PowerShell (Windows)
   . "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"
   $Version = Get-ToolVersion -Name 'squad-cli'
   ```

3. **Detect** the installed version:
   ```bash
   INSTALLED="$(squad --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
   ```

4. **Branch** on comparison:
   - installed == pinned -> log OK, skip
   - installed != pinned (or not installed) -> install/upgrade to pinned version

5. **Install explicitly with version**:
   ```bash
   npm install -g "@bradygaster/squad-cli@${VERSION}"
   ```
   ```powershell
   winget install --id GitHub.cli --version $Version ...
   ```

### Why this matters

The bare-idempotency anti-pattern (`if command -v X; then exit 0; fi`) was the root
cause of issue #255: squad-cli, copilot-cli, and gh silently stayed at cached/older
versions on CI runners. Fix PRs that bumped `.tool-versions` had no effect because the
old binary was already present. Version-aware guards eliminate this silent drift.

### Winget constraint

winget version IDs for some packages (e.g., `GitHub.Copilot`) may not match the semver
in `.tool-versions` (which typically reflects the npm package version). If winget refuses
`--version <pin>`, fall back to latest-available and log a WARN. Document the constraint
in the script header and update `.tool-versions` to a known winget catalog version when
pinning is required.

### macOS / brew constraint

Homebrew does not publish versioned formulae for tools like `gh`. On macOS, accept
the latest brew version, compare against the pin, and log a WARN if they differ.
macOS is a secondary target; version drift is tolerated with visibility.

---

## PowerShell Exit Code Discipline

`$LASTEXITCODE` leaks across PowerShell `&` script-call boundaries. When a
Windows script ends with an *expected-failure* native command (e.g.,
`git config --unset-all <key>` exiting `5` because the key was never set), the
caller -- including the GitHub Actions `pwsh` step wrapper -- sees the non-zero
code and fails the step even though the script logically succeeded.

### Canonical expected-failure sites

- `git config --unset` / `--unset-all <key>` (exits `5` when key absent)
- `git rev-parse --git-dir` outside a git repo (exits `128`)
- `gh auth status` when not authenticated (exits `1`)
- `gh api <path>` for a missing resource (exits `1` on 404)
- `npm uninstall -g <pkg>` for an uninstalled package (exits `1`)
- `winget uninstall <id>` for a missing package (non-zero)

### Fix

After every expected-failure native command, read `$LASTEXITCODE`, classify
the cases you intend to swallow, then reset with **`$global:LASTEXITCODE = 0`**
(the local `$LASTEXITCODE = 0` shadows but does not clear the automatic
variable). Optionally pair with `2>$null` or `2>&1 | Out-Null` to silence
stderr noise. The trailing reset is load-bearing for any script invoked from
a workflow `shell: pwsh` step via `& .\path\to\script.ps1` -- without it the
GH Actions wrapper fails the step on the next inspection of `$LASTEXITCODE`.

See `.squad/skills/pwsh-lastexitcode/SKILL.md` for the full pattern, a
detection checklist, and the call-site audit. The discovery PR is #277
(`fix(uninstall): unset core.hooksPath`); the skill closes #288.

---

## Squad Operational Gates (Coordinator dispatch)

Two operational SOPs govern Coordinator-side spawn behavior. Both are codified at
three independent surfaces (charter + `.squad/templates/loop.md` + `.squad/templates/ceremonies.md`)
so a single forgotten checkpoint doesn't silently break the SOP. Source decision:
`.squad/decisions/doc-and-jiminy-automation.md` (closes #289, #290).

### Doc subagent runs in a dedicated worktree (#289)

Doc (Fact Checker) is a `general-purpose` subagent that inherits the Coordinator's
CWD by default. To prevent his `.squad/agents/doc/history.md` writes from landing
as `M` on `develop` in the primary worktree (Sprint 10 anti-pattern: required PRs
#281 + #283), Doc runs in a dedicated per-sprint worktree.

**Sprint kickoff (Coordinator, one-time per sprint):**

```bash
git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>
```

**Every Doc spawn prompt** MUST begin with an explicit CWD directive pointing at
`..\dev-setup-doc`. Doc commits + pushes after every fact-check. At sprint wrap,
the Coordinator opens ONE fold PR from `squad/doc-history-sprint-<N>` into
`develop`. Target: 1 fold PR per sprint (down from 2 in Sprint 10).

### Jiminy auto-dispatch after >= 3-agent batches and at session-end (#290)

The Jiminy dispatch SOP from PR #280 (Coordinator MUST invoke Jiminy after every
3+ agent batch and at session-end) is now enforced at three surfaces:

1. `.squad/agents/jiminy/charter.md` -> `Triggers` table (canonical).
2. `.squad/templates/loop.md` -> "Squad Operational Gates" (Gate 1 post-batch, Gate 2 session-end).
3. `.squad/templates/ceremonies.md` -> `Sprint Wrap` ceremony, step 1.

**Trigger condition (Gate 1):** 3 or more agent spawns in a single Coordinator
turn, counted excluding Scribe (which runs silently in background by design).
**Action:** Spawn Jiminy BEFORE returning results to the user. Wait for
`Jiminy clear` or resolve the dirty report.

**Trigger condition (Gate 2):** user signals session-end OR work queue empties
after a full sprint. **Action:** Jiminy full sweep; BLOCKS session close on dirty
state. Ralph runs after Jiminy for stale-branch cleanup.

If you (Coordinator or human contributor) ever notice a >= 3-agent batch landed
without a Jiminy run, that is a Sprint Retro action item, not a one-off
self-correction. File a `retro-action` issue.


