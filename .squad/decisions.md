# Squad Decisions

## Decision Records

## # Decision: CI PS 5.1 Validation Path

**Issue:** #109
**PR:** #116
**Agent:** Chip (Tester)
**Date:** 2026-04-18

## Context

All prior PowerShell CI validation ran under PS 7+ (`pwsh`). The existing `lint-powershell` job uses `pwsh` on `ubuntu-latest`, and `validate-powershell` uses `pwsh` on `windows-latest`. Neither tests compatibility with Windows PowerShell 5.1, which is the default shell on most Windows 10/11 machines.

## Decisions

### 1. `windows-latest` runner
**Choice:** `runs-on: windows-latest`
**Why:** Windows Server runners come with PS 5.1 pre-installed. No setup needed — just use `shell: powershell` to invoke it.

### 2. `shell: powershell` vs `shell: pwsh`
**Choice:** All steps use `shell: powershell`
**Why:** `powershell` invokes Windows PowerShell 5.1. `pwsh` invokes PowerShell 7+. Since the goal is PS 5.1 validation, every step must use the `powershell` shell directive. This is the single most important detail in the job.

### 3. Syntax check via Parser::ParseFile
**Choice:** Use `[System.Management.Automation.Language.Parser]::ParseFile()` for syntax validation
**Why:** This is the native PS AST parser — catches syntax errors that would prevent the script from loading. It runs without executing the script, so it's safe in CI.

### 4. PSScriptAnalyzer under PS 5.1
**Choice:** Install and run PSScriptAnalyzer in the PS 5.1 shell
**Why:** PSScriptAnalyzer may flag different issues under PS 5.1 than under PS 7+. Running it under both runtimes (existing `lint-powershell` job for PS 7+, new job for PS 5.1) gives full coverage.

### 5. Both scripts validated
**Choice:** Validate both `setup.ps1` (root) and `scripts/windows/setup.ps1`
**Why:** The root `setup.ps1` is the entry point that users run. If it has PS 5.1 syntax issues, nothing works. Both must pass.

## What's NOT validated (known limitations)

- **Winget installs** — Cannot test actual `winget install` on CI runners (winget may not be available or may require interactive session)
- **User profile changes** — Tests mock profile paths; real `$PROFILE` behavior differs
- **Network-dependent installs** — Tool download URLs may fail in CI but work locally
- **Full end-to-end** — This is syntax + lint + unit test, not a full setup run

## Outcome

PS scripts now have dual-runtime CI coverage: PS 7+ (existing `lint-powershell`) and PS 5.1 (new `validate-ps51`).

---

## ## # Sprint 6 Hotfix Wrap (Issue #124, #125, PR #127)

**Date:** 2026-04-18
**Author:** Mickey (Lead)
**Status:** ✅ Complete

### Issues Fixed

| Issue | Title | Fix |
|-------|-------|-----|
| #124 | fix(setup): replace non-ASCII em-dash in root setup.ps1 comment | Removed U+2014 em-dash, replaced with ASCII `--` |
| #125 | fix(setup): refresh PATH after vim winget install so vim is immediately available | Added `$env:PATH` refresh and fallback warning |

### Context

Both issues identified as post-sprint bugs in Sprint 6. Bundled into single hotfix PR for develop → main merge to restore green CI on main branch.

### Outcome

✅ Both bugs fixed
✅ PR #127 merged to develop → main (regular merge, --admin)
✅ Green CI restored on main
✅ Ready for Sprint 7 development

---

### 2026-04-18T20:15: User directive — no squash merges, ever
**By:** Earl Tankard (via Copilot)
**What:** Never use squash merges anywhere in this repo. All merges (feature PRs to develop AND sprint wraps develop→main) must use regular merge commits. `--squash` is banned.
**Why:** User request — captured for team memory

### 2026-04-18T20:15: User directive — delete stale branches at end of session
**By:** Earl Tankard (via Copilot)
**What:** At the end of every session, always delete stale branches both locally and remotely.
**Why:** User request — captured for team memory

---

## # Decision: squad-cli install — skip+warn pattern (Issue #106)

**Date:** 2026-04-18
**Author:** Goofy (Cross-Platform Developer)
**Issue:** #106
**PR:** #118

## Context

squad-cli (`@bradygaster/squad-cli`) requires npm to install globally. Not all environments have Node.js/npm pre-installed (e.g., fresh Devcontainers without nvm setup complete).

## Decision

If npm is not present at install time, **skip with `[WARN]`** — do not force-install Node.js.

This matches the existing pattern used by other npm-dependent tools and avoids injecting a heavyweight Node.js install into the setup flow.

## Install placement

- **Windows:** `Install-SquadCli` called after `Install-CopilotCli` in `Main` (setup.ps1)
- **Linux:** `run_tool "squad-cli"` called after `run_tool "copilot-cli"` in `main()` (setup.sh)

Both are positioned at the end of the tool install sequence since squad-cli depends on npm, which is installed earlier via nvm.

## Alternatives considered

- **Force-install Node via nvm if missing:** Rejected — too aggressive, and nvm install may not have completed PATH reload yet.
- **Use npx instead of global install:** Rejected — squad-cli is used frequently enough to warrant a global install.

---

## # Decision Record: Issues #110 and #111 — Documentation Updates

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Status:** PRs open

## Context

Sprint 6 retro (2026-04-18) identified two documentation gaps from the PS 5.x hotfix session:
1. No written policy for when direct pushes to `main` are acceptable
2. No checklist for PS 5.x compatibility when reviewing `.ps1` changes

## What was written

### Issue #110 — Direct-Push Override Policy (PR #117)

- **File:** `CONTRIBUTING.md` (new section after "Code Review")
- **Content:** Defines the four conditions for a hotfix override, required audit trail (`[hotfix-override]` annotation, decision record, retro reference), and references the 2026-04-18 hotfix as canonical precedent.
- **Branch:** `squad/110-direct-push-policy` → `develop`

### Issue #111 — PowerShell 5.x Compatibility Checklist (PR #119)

- **File:** `CONTRIBUTING.md` (new section after "Code Review")
- **Content:** 5-item checklist (`$PSScriptRoot`, guarded auto-vars, StrictMode, ASCII-only strings, alias conflicts), testing guidance (manual PS 5.1, CI track in #109), and known regressions table.
- **Branch:** `squad/111-ps5x-checklist` → `develop`

## Design decisions

- Both sections placed in `CONTRIBUTING.md` (not `docs/PROCESS.md`) because `docs/` directory does not exist and `CONTRIBUTING.md` is the established process document.
- Sections placed between "Code Review" and "Parallel Agent Work" for logical grouping with workflow/review content.
- Each issue on its own branch with independent PR to keep concerns separated.

## Impact

Once merged, all contributors and squad agents have explicit reference material for:
- Override authorization (prevents unauthorized direct pushes)
- PS 5.x review (prevents the class of regressions seen on 2026-04-18)

---

## # Git Hooks Implementation (Issue #121, PR #130)

**Date:** 2026-04-18
**Author:** Chip (Tester)
**Status:** ✅ Complete

### What Was Implemented

Three git hooks were created and integrated into the setup process:

1. **`hooks/pre-commit`** — Enforces shellcheck on all shell scripts
2. **`hooks/commit-msg`** — Enforces Conventional Commits format (type(scope): message)
3. **`hooks/pre-push`** — Blocks direct pushes to `main` branch

### Configuration

Core hooks path wired in both setup scripts:
- **Unix:** `git config core.hooksPath hooks` added to `scripts/linux/setup.sh`
- **Windows:** `git config core.hooksPath hooks` added to `scripts/windows/setup.ps1`

### Testing

Comprehensive hook tests added to `test_git_hooks.ps1`:
- Hook file existence and executability
- Hook behavior for valid and invalid inputs
- Cross-platform compatibility (Unix shells via Git Bash on Windows)

### Key Design Decisions

1. **Hook Framework:** None — use native Git `core.hooksPath` + committed `hooks/` directory
   - Zero external dependencies (no Husky, lefthook, etc.)
   - Version-controlled and cross-platform
   - Works identically via Git Bash on Windows

2. **commit-msg Hook:** POSIX shell regex validation
   - Pattern: `^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?(!)?: .{1,}`
   - Hard error on non-conforming commits (can override with `git commit --no-verify`)
   - Exceptions: Merge commits and fixup/squash commits are allowed

3. **pre-push Hook:** Two checks
   - (1) Rejects any push targeting `main` with helpful error message
   - (2) Runs shellcheck on changed `.sh` files (if available)
   - Integrates with git-lfs if present

### Outcome

✅ All hooks implemented, tested, and integrated
✅ PR #130 merged to develop
✅ Issue #121 closed

---

## # Branch Isolation Rule (Issue #122, PR #129)

**Date:** 2026-04-18
**Author:** Mickey (Lead)
**Status:** ✅ Complete

### What Was Added

Two new sections added to CONTRIBUTING.md:

1. **Branch Isolation** — Enforces that all feature branches must be created from `develop` HEAD, never from another squad branch
2. **Merge Strategy** — Documents that ALL merges use regular merge commits, never squash merges

### Rationale

**Sprint 6 retro finding:** Branch ancestry bleed occurred 3 times (PRs #114, #116, #118), degrading PR review quality and inflating diffs with unrelated commits.

### Key Rules

- **Rule 1:** Always fork branches from develop HEAD
- **Rule 2:** Never branch from another feature branch
- **Rule 3:** All merges use regular merge commit (--merge flag)
- **Rule 4:** Never use squash merge

### Verification Guidance

Contributors can verify branch isolation with:
```bash
git log --oneline develop..HEAD
```
If this shows only commits from your branch, isolation is clean.

### Outcome

✅ Documentation complete and merged
✅ PR #129 merged to develop
✅ Issue #122 closed

---

## # CI Triage & PowerShell 5.1 Variable Guards (Issue #123, PR #130)

**Date:** 2026-04-18
**Author:** Chip (Tester)
**Status:** ✅ Complete

### Historical CI Failures (April 18 ~04:58 UTC)

**Finding:** 5 CI runs failed on main branch
**Root Cause:** Non-ASCII em-dash (U+2014) on line 63 of root setup.ps1
**Status:** Already fixed by PR #126; failures were stale artifacts

### Pre-existing develop Failure

**Test:** "Root setup.ps1 guards all three PS-Core-only variables"
**Root Cause:** Root setup.ps1 used PSVersionTable version checks instead of Test-Path Variable:* guards

#### The Problem

PS 5.1 doesn't recognize the PowerShell Core-only variables ($IsWindows, $IsLinux, $IsMacOS) natively. Runtime version checks (`$PSVersionTable.PSVersion.Major -ge 6`) don't work for source-level validation.

#### The Fix (PR #130)

Replaced all PSVersionTable checks with Test-Path Variable:* guards:

| Before (Wrong) | After (Correct) |
|---|---|
| `($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)` | `(Test-Path Variable:IsWindows -and $IsWindows)` |
| `($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')` | `(-not (Test-Path Variable:IsWindows) -and $env:OS -eq 'Windows_NT')` |
| `$PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux` | `Test-Path Variable:IsLinux -and $IsLinux` |
| `$PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS` | `Test-Path Variable:IsMacOS -and $IsMacOS` |

### Key Learning

**PowerShell 5.1 compatibility validation requires explicit source-level guards (Test-Path Variable:*), not runtime version checks.** This pattern aligns with approved PS 5.x compatibility rules documented in Issue #111.

### Outcome

✅ Historical failures triaged (superseded by PR #126)
✅ Pre-existing failure fixed in PR #130
✅ Issue #123 closed

---

## # Git Hooks Recommendation

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Requested by:** Earl Tankard, Jr., Ph.D.
**Status:** Awaiting Earl's approval

---

**TL;DR:** Use `core.hooksPath` pointing to a committed `hooks/` directory — zero dependencies, version-controlled, cross-platform via Git Bash — with three hooks: `commit-msg` (conventional commits regex), `pre-push` (branch protection + lightweight lint), and one-liner installs in both setup scripts.

---

## Framework

**Choice: `core.hooksPath` + committed `hooks/` directory. No framework.**

This repo has no `package.json` and no Node/Go runtime requirement. Husky needs npm; lefthook needs Go; both add dependencies to a repo whose job is *installing* dependencies. A committed `hooks/` directory with `git config core.hooksPath hooks` is zero-dependency, version-controlled, and works identically on every platform (Git Bash runs POSIX shell hooks on Windows). The setup scripts already configure the dev environment — adding one `git config` line is trivial.

---

## Hook 1: `commit-msg` — Conventional Commits Enforcement

**What it does:** Validates the commit message against Conventional Commits before the commit is recorded.

**Tool:** POSIX shell regex — no external tooling. `commitlint` requires npm, `commitizen` requires npm/Python. A regex covers 95% of what we need.

**Proposed regex:**
```sh
pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?(!)?: .{1,}'
```

This validates:
- Type is one of the standard prefixes
- Optional scope in parentheses: `feat(windows):`
- Optional breaking change marker: `feat!:`
- Colon + space + non-empty description
- Does NOT enforce body/footer format (too restrictive for dev workflow)

**Enforcement level: Hard error (exit 1).** The commit is rejected with a clear message showing the expected format. Rationale: conventional commits are only useful if they're consistent. A warning that people ignore defeats the purpose. Developers can always `git commit --no-verify` for WIP commits they plan to rebase.

**Exceptions:**
- Merge commits (`Merge branch ...`) — auto-detected and allowed
- Fixup/squash commits (`fixup!`, `squash!`) — allowed for interactive rebase workflows

---

## Hook 2: `pre-push` — Lightweight Validation

**What it runs:**
1. **shellcheck** on changed `.sh` files (if `shellcheck` is installed) — fast, catches real bugs
2. That's it.

**What it does NOT run:**
- PSScriptAnalyzer — requires `pwsh`, slow to invoke, platform-dependent. Leave to CI.
- Full setup validation (`bash setup.sh`) — too heavyweight for a pre-push hook (installs packages).
- PowerShell tests (`test_windows_setup.ps1`) — Windows-only, requires winget/registry access.

**Rationale:** The CI pipeline (`validate.yml`) already runs shellcheck, PSScriptAnalyzer, Linux validation, and PS tests on every push. Duplicating the full pipeline locally is slow, fragile, and platform-inconsistent. The pre-push hook should catch the fast, high-signal stuff. CI is the source of truth.

**Escape hatch:** `git push --no-verify` bypasses the hook. This is standard Git behavior, no extra work needed. Document it in the hook's error output.

**Changed-files detection:**
```sh
# Get files being pushed (compared to remote)
changed_files=$(git diff --name-only "$local_sha" "$remote_sha" -- '*.sh')
```

---

## Hook 3: `pre-push` — Branch Protection

**Combined into the same `pre-push` hook** (runs before the lint step above).

**The check:** Parse the remote ref from stdin. If any ref targets `main` (or `refs/heads/main`), reject the push with a clear message:

```
🚫 Direct push to 'main' is blocked.
   Workflow: push to your branch → PR to develop → sprint wrap PR to main.
   Override: git push --no-verify (see CONTRIBUTING.md direct-push policy)
```

**What it blocks:**
- `git push origin main` — blocked
- `git push origin HEAD:main` — blocked
- `git push --force origin main` — blocked (pre-push fires before force push too)

**What it allows:**
- Sprint wrap merges via GitHub UI (PR merge button) — hooks don't run server-side
- `git push --no-verify origin main` — allowed, for documented hotfix overrides (Issue #110)
- Pushes to `develop`, feature branches, `squad/*` branches — all allowed

**Edge case considered:** The `--no-verify` escape aligns with the direct-push override policy already documented in CONTRIBUTING.md (Issue #110). The hook message references that policy.

---

## Installation Strategy

**Mechanism:** `git config core.hooksPath hooks`

This tells Git to look for hooks in `hooks/` (repo root) instead of `.git/hooks/`. The `hooks/` directory is committed and version-controlled. Everyone gets the same hooks automatically after running setup.

**Where it's wired:**

- **`scripts/linux/setup.sh`** — Add near the end, after tool installs:
  ```sh
  git config core.hooksPath hooks
  log_ok "Git hooks installed (core.hooksPath → hooks/)"
  ```

- **`scripts/windows/setup.ps1`** — Add near the end:
  ```powershell
  git config core.hooksPath hooks
  Write-Ok "Git hooks installed (core.hooksPath -> hooks/)"
  ```

**Git LFS compatibility:** The current `.git/hooks/` has git-lfs hooks (pre-push, post-commit, post-checkout, post-merge). When `core.hooksPath` is set, Git ignores `.git/hooks/` entirely. Our committed hooks must chain to git-lfs if it's installed:
```sh
# At the end of hooks/pre-push:
command -v git-lfs >/dev/null 2>&1 && git lfs pre-push "$@"
```

---

## Files to Create

```
hooks/
├── commit-msg    # Conventional commits regex validation
└── pre-push      # Branch protection + shellcheck on changed files + git-lfs chain
```

- **`hooks/commit-msg`** — POSIX sh, ~30 lines. Reads `$1` (commit msg file), validates regex, exits 1 on failure with example format. Allows merge/fixup/squash commits.
- **`hooks/pre-push`** — POSIX sh, ~60 lines. Reads stdin for refs. (1) Rejects pushes to `main`. (2) Runs shellcheck on changed `.sh` files if available. (3) Chains to `git lfs pre-push` if git-lfs is present.
- **One-liner in `scripts/linux/setup.sh`:** `git config core.hooksPath hooks`
- **One-liner in `scripts/windows/setup.ps1`:** `git config core.hooksPath hooks`

All hooks must be `chmod +x` and committed with executable bit. The `.gitattributes` should ensure `hooks/*` keeps `eol=lf` (Git Bash on Windows needs Unix line endings for shell scripts).

---

## Cross-Platform Notes

| Concern | Approach |
|---------|----------|
| Hook shell | All hooks use `#!/bin/sh` (POSIX). Git Bash on Windows provides this. |
| shellcheck | Skip gracefully if not installed (`command -v shellcheck` guard). |
| PSScriptAnalyzer | Not run in hooks. CI only. |
| Line endings | Add `hooks/* text eol=lf` to `.gitattributes`. |
| Git LFS | Chain calls in hooks that have LFS counterparts. |

---

## Open Questions for Earl

1. **Hard error vs. warning on commit-msg?** I recommend hard error (reject non-conforming commits) with `--no-verify` as escape hatch. Are you comfortable with that, or do you prefer a warning-only mode during a transition period?

2. **Scope of pre-push lint:** I scoped it to shellcheck-only (fast, high-signal). Do you want PSScriptAnalyzer also attempted when `pwsh` is available, accepting it'll be slow (~5-10s)? Or keep it CI-only?

3. **Should we add a `pre-commit` hook too?** Earl's original question mentioned pre-commit. I folded everything into `commit-msg` (message validation) and `pre-push` (code validation + branch protection). A `pre-commit` hook could run shellcheck on staged files for even faster feedback, but it adds friction to every commit. Worth it?

---

*This recommendation is ready for implementation as a single PR once Earl approves. Estimated scope: 3 new files (`hooks/commit-msg`, `hooks/pre-push`, `.gitattributes` update) + 2 one-liners in existing setup scripts.*

---

## # Decision Record: Sprint 6 Retrospective — Action Items

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Type:** Retrospective Action Items
**Status:** Queued for Sprint 7

## Context

Sprint 6 retrospective identified process friction in three areas: branch isolation, merge strategy confusion, and PR hygiene. All 8 issues shipped (100% closure), but the delivery process had recurring problems that need structural fixes before Sprint 7 work begins.

## Action Items

### P1 — Must address at Sprint 7 kickoff

**1. Branch isolation rule — CONTRIBUTING.md update**
- **Owner:** Mickey
- **What:** Add explicit rule: "All feature branches MUST be created from `develop` HEAD. Never branch from another feature branch."
- **Include:** Verification command: `git log --oneline develop..HEAD` before opening PR
- **Why:** Branch ancestry bleed occurred 3 times in Sprint 6 (PRs #114, #116, #118). Inflated diffs and confused reviews.

**2. Merge strategy documentation — Sprint 7 kickoff**
- **Owner:** Mickey
- **What:** Sprint 7 kickoff notes must explicitly state: "Regular merge commit for all merges to develop and main. No squash merges."
- **Why:** PRs #116–#119 were squash-merged before Earl's late-sprint directive. Strategy must be stated up front, not discovered mid-sprint.

### P2 — Sprint 7 work items

**3. Git hooks implementation**
- **Owner:** Mickey
- **What:** Implement `commit-msg` + `pre-push` hooks per approved design (`mickey-githooks-design.md`). `core.hooksPath` approach, committed `hooks/` directory.
- **Why:** Automates commit message validation and blocks direct push to main. Reduces reliance on human discipline for enforceable rules.

**4. Triage historical CI failures on main**
- **Owner:** Chip
- **What:** Investigate 5 CI failures from April 18 on main. Fix, re-run, or document as known. Actions tab must not show unexplained red.
- **Why:** Stale failures confused the team and erode CI trust. If red is normal, green means nothing.

**5. One-concern-per-PR enforcement**
- **Owner:** Mickey (review gate)
- **What:** Hard-reject PRs carrying unrelated file changes during code review. No exceptions for "non-blocking" leaks.
- **Why:** 4 of 7 Sprint 6 PRs carried unrelated `.squad/` changes. Degrades review quality and scope verification.

### P3 — Ongoing practice

**6. Separate squad metadata commits**
- **Owner:** All agents
- **What:** `.squad/` file changes must be committed separately from feature work. Either a separate commit in the same branch or a dedicated end-of-session PR.
- **Why:** Root cause fix for unrelated-files-in-PR problem. Eliminates the issue at the source.

## Impact

These six items target the three friction areas identified in the Sprint 6 retro. Items 1–2 are process documentation (low effort, high leverage). Items 3–4 are implementation work (medium effort). Items 5–6 are behavioral rules enforced through review.

---

## # Decision: Batch Review — PRs #116, #117, #118, #119

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Type:** Code Review

## Verdicts

| PR | Author | Title | Verdict |
|----|--------|-------|---------|
| #116 | Chip | `ci: add PS 5.1 validation job on Windows runner` | ✅ APPROVED |
| #117 | Mickey | `docs: codify direct-push-to-main override policy` | ✅ SELF-VERIFIED |
| #118 | Goofy | `feat(setup): install squad-cli globally in Windows and Linux setup` | ✅ APPROVED |
| #119 | Mickey | `docs(contributing): add PowerShell 5.x compatibility checklist` | ✅ SELF-VERIFIED |

## Summary

All four PRs pass review. CI green on all. Code quality and PS 5.x compatibility verified.

## Recommended merge order

1. **PR #116** first (CI job — smallest surface area, resolves shared commits)
2. **PR #117** (docs — independent, single file)
3. **PR #118** (squad-cli — after #116 merge, diff collapses to only squad-cli changes)
4. **PR #119** (docs — independent)

## Process Issue: Branch Ancestry Bleed

PRs #116 and #118 share commits because their branches were created off each other rather than from `develop`. This causes both PRs to show the other's changes in the diff. This is the **third occurrence** of cross-branch contamination (previously flagged in PRs #114 and #115).

**Recommendation for Sprint 7:** Enforce that all feature branches are created from `develop` HEAD, never from another feature branch. Add this to the branching section of CONTRIBUTING.md.

---

## # Sprint 7 Issues Created

**Created by:** Mickey (Lead)
**Date:** 2026-04-19

## Issues

| Issue | Title | Labels |
|-------|-------|--------|
| #121 | `feat(hooks): implement git hooks for commit-msg, pre-commit, and pre-push enforcement` | `squad`, `enhancement` |
| #122 | `docs(contributing): add branch isolation rule — always fork from develop HEAD` | `squad`, `documentation` |
| #123 | `ci: triage and resolve 5 historical CI failures on main branch` | `squad`, `bug` |

## Priority Mapping
- **P1:** #122 (branch isolation — blocks clean PRs)
- **P2:** #121 (git hooks), #123 (CI triage)

## Notes
- All issues use repo issue templates (feature_request, documentation, ci_infra)
- Git hooks design approved by Earl Tankard — see `decisions/inbox/mickey-githooks-design.md`
- Branch isolation addresses the #1 process problem from Sprint 6 (3 occurrences of ancestry bleed)

---

## Active Decisions

## [2026-04-08] Use $PSScriptRoot for Script Directory Resolution in PowerShell

**Date:** 2026-04-08  
**Author:** Goofy (Cross-Platform Developer)  
**Status:** Adopted  
**Context:** Hotfix for Earl Tankard's bug report — `setup.ps1` line 51 crash on Windows

### Decision

All PowerShell scripts in this repo must use `$PSScriptRoot` (with a `$MyInvocation.MyCommand.Definition` fallback) to resolve the current script's directory. Use of `$MyInvocation.MyCommand.Path` is banned.

### Pattern to use

```powershell
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
```

### Rationale

`$MyInvocation.MyCommand.Path` is `$null` in several common invocation contexts:

- Script run via `./` notation in strict mode
- Script run from certain IDE or hosted PowerShell environments
- Dot-sourced execution (`. ./setup.ps1`)

`$PSScriptRoot` is a PowerShell automatic variable (available since PS 3.0) that is explicitly designed for this purpose and is populated reliably in all non-interactive script contexts.

`$MyInvocation.MyCommand.Definition` is the correct fallback — it contains the full path or script body and works in dot-sourced scenarios where `$PSScriptRoot` is empty.

### Scope

Applies to all `.ps1` files in this repo: `setup.ps1`, `scripts/windows/setup.ps1`, and any future PowerShell scripts.

---

## [Sprint 4] Enable Branch Protection on `develop`

**Date:** 2026-04-07
**Decision:** Enable GitHub branch protection on `develop` requiring 1 approving review + passing CI before merge.
**Rationale:** Ralph bypassed the Mickey approval gate in Sprint 2 and Sprint 3. Branch protection enforces this at the GitHub level.
**Owner:** Mickey
**Note:** GitHub API returned 403 (token lacks branch protection write scope); rules must be enabled manually in repo Settings → Branches.

### 2026-04-07T03:20:54Z: User directive
**By:** Earl Tankard, Jr., Ph.D. (via Copilot)
**What:** Always commit and push at the end of every session — Scribe must `git push` after the final commit, not just `git commit`.
**Why:** User request — captured for team memory

### 2026-04-07: 14 GitHub issues created
**Scope:** primetimetank21/dev-setup
**Created by:** Mickey (Lead)
**Detail:** 
- 14 issues covering architecture, tool installs (zsh, uv, nvm, gh, copilot-cli), config (dotfiles, shortcuts, devcontainer), auth, testing, CI
- Issue breakdown: 1 architecture, 7 tool installs/auth, 3 config, 2 testing/CI
- All issues labeled with `squad` + `squad:{member}` labels
- Squad labels created: squad, squad:mickey, squad:donald, squad:goofy, squad:pluto, squad:chip
**Owner distribution:** Mickey (1), Donald (7), Goofy (1), Pluto (3), Chip (2)

### 2026-04-07: Architecture — Entry Point and File Structure
**By:** Mickey (Lead)
**Issue:** #3

**Entry Points:** Two root-level entry points — `setup.sh` (Unix: Linux, macOS, WSL) and `setup.ps1` (Windows). OS detection uses `uname -s` + `/proc/version` on Unix; `$IsWindows` builtin on PowerShell.

**File Structure:**
```
dev-setup/
├── setup.sh              # Unix entry point (router only)
├── setup.ps1             # Windows entry point (router only)
├── scripts/linux/        # Core Linux/macOS installer + per-tool scripts
├── scripts/windows/      # Core Windows installer
├── config/dotfiles/      # Dotfile templates
└── .github/workflows/    # CI
```

**Key decisions:**
- WSL is always routed as Linux — grepped via `/proc/version` for "microsoft"
- Entry points are thin routers only — no tool installation at root level
- Tool scripts run via `bash <script>` (not `source`) to keep each isolated in its own subshell
- No package-manager abstraction layer — apt/brew per tool script, winget for Windows

### 2026-04-07: Dotfile Install Strategy
**By:** Pluto (Config Engineer)
**Issue:** #11

**Key decisions:**
- `.gitconfig.template` and `.npmrc.template` are **copied** (not symlinked) — machine-specific, user-editable
- `.editorconfig` is **symlinked** — project-agnostic, propagates updates automatically
- Placeholder substitution via `sed -i` (not `envsubst`) — `envsubst` absent on macOS without Homebrew
- On existing `.gitconfig`: **back up** (`.bak`) and overwrite — Codespaces may have stale auto-generated config
- No `.zshrc` in this issue — owned by issue #8 to avoid merge conflicts

## [2026-04-07] Process Violation — Sprint 3 PRs merged without Mickey review

PRs #33, #34, #35, #36 were merged to `develop` by Ralph's sub-agents without mandatory Mickey approval.

**Root cause:** Ralph's agent loop merged PRs via `gh pr merge` without waiting for a review approval.

**Corrective action:** Ralph's task templates must require `gh pr review --approve` from Mickey before calling `gh pr merge`. Branch protection rules should be enabled on `develop` to enforce required reviews.

## [2026-04-07] Decision: `develop → main` promotion requires Mickey's explicit green light

**By:** Mickey (Lead) — Sprint 3 retro
**What:** `develop` may only be promoted to `main` after Mickey gives explicit verbal (or written) approval. No agent, no automation, and no squad member may trigger the merge without that sign-off.
**Why:** Sprint 3 demonstrated that unreviewed code reaching `develop` contained P1 bugs. Without Mickey's retroactive review and hold on promotion, both bugs would have shipped to `main`. The review gate is the last line of defense.

## [2026-04-07] Decision: Codespace initialization must set git identity before any commits

**By:** Earl Tankard, Jr., Ph.D. (via retro) — Sprint 3
**What:** Every Codespace startup must run `git config user.name` and `git config user.email` with the owner's actual identity before any commit is made. The devcontainer must inject these values from environment variables at init time.
**Why:** The `.gitconfig.template` placeholders (`YOUR_NAME`, `YOUR_EMAIL`) were never substituted in the Codespace, resulting in 35 commits attributed to placeholder values across the entire project history. Fixing it required `git filter-repo` history rewrite — an expensive, error-prone, and disruptive operation.

## [2026-04-07] Decision: `uv` is the ONLY Python package manager — `pip` is banned

**By:** Earl Tankard, Jr., Ph.D. (owner preference) — Sprint 3
**What:** All Python tool installation in this repo must use `uv` (e.g., `uv tool install <package>`). `pip` is explicitly banned. This applies to devcontainer setup, documentation, scripts, and any ad-hoc commands run during squad work.
**Why:** `uv` is the owner's documented preference, established in the architecture decisions from Sprint 1. Using `pip install git-filter-repo` in Sprint 3 was a direct violation of a standing directive.

## [2026-04-07] Test Design — PowerShell Regression Tests

**By:** Chip (Tester)  
**Context:** Issue #41 — Remove-CustomItem regression test

### Decision: PowerShell tests must prove they catch regressions

**What:** PowerShell test files should include both the CORRECT implementation and a BROKEN version to demonstrate the test actually catches the bug.

**Why:** Regression tests are worthless if they would pass even with the bug present. Including the broken version proves the test has value and shows future maintainers what behavior is protected.

### Decision: Use current directory for temp files, never /tmp

**What:** PowerShell tests create temp files in the current working directory with random suffixes, not in `/tmp` or `$env:TEMP`.

**Why:** Cross-platform compatibility (Windows has no `/tmp`), security policy, CI isolation, and debugging benefits.

### Decision: Structured test output for CI visibility

Tests use colored output (✅/❌ prefixes), summary reports, and exit codes (0 on pass / 1 on any fail) that CI can parse and GitHub Actions can display in collapsed output.

## [2026-04-07] Test Design — tmux Session Detection Tests

**By:** Chip (Tester)  
**Issue:** #43  
**PR:** #53

### Decision: Mock tmux as shell function, not process-level mock

**Rationale:** CI environments may not have tmux installed. Shell function mocking is portable, self-contained, and requires no external dependencies. Keeps test as a single runnable bash script.

### Decision: Use namespaced loop variables in mocks (`mock_session` not `session`)

**Critical Bug Found:** Bash for-loop variables are function-scoped. A loop variable `for session in ...` inside a mock overwrites the caller's `local session` variable. Using unique names (`mock_session`) eliminates this class of bugs.

**Guideline for future mocks:** Always prefix loop variables with `mock_`, `temp_`, or another clear namespace indicator.

### Decision: Copy function under test into test file, don't source

**Rationale:** Sourcing the main script loads all functions/aliases, polluting the test namespace. Direct copy makes it clear exactly what code is being tested and avoids unexpected interactions.

## [2026-04-07] PR Review Approvals

**By:** Mickey (Lead)

### PR #52 — APPROVED (2026-04-07)
Test correctly validates the `ValueFromRemainingArguments` fix. Test 1 proves fix works, Test 2 is regression guard, Test 3 confirms single-file still works. CI green.

### PR #53 — APPROVED (2026-04-07T07:45:00Z)
All acceptance criteria met. CI 3/3 green. Tests cover 3 scenarios. tmux properly mocked. Bash syntax valid. Code clean and well-documented.

## [2026-04-08] Agent Timeout Policy

**By:** Mickey (Lead)  
**Issue:** #55  
**Status:** Adopted

### Timeout Tiers

| Task Type | Wall-Clock Limit |
|-----------|-----------------|
| Quick (single lookup) | 5 min |
| Standard *(default)* (one feature + tests) | 10 min |
| Complex (multi-file refactor, cross-cutting) | 20 min |

### Coordinator Timeout Handling

When agent exceeds tier limit:
- **First timeout:** Cancel. Log to orchestration log. Retry once with leaner prompt.
- **Second timeout:** Cancel. Do NOT retry. Escalate to user: `⚠️ {AgentName} stalled twice`.

### Stall Detection Signals

- Elapsed time exceeds tier limit
- 30+ tool calls without file output or git commits
- Agent looping on same tool repeatedly
- No progress after 3 consecutive polls

**Ralph's role:** Flag stalls (not kill). Coordinator decides and acts.

**Rationale:** Sprint 4's Chip-issue-43 ran 6+ minutes with 45+ tool calls before Ralph intervened. Documented policy prevents runaway agents and gives unambiguous escalation rules.

## [2026-04-08] Block Direct Pushes to `develop` — enforce_admins

**Date:** 2026-04-08  
**Issue:** #54  
**Owner:** Mickey (Lead)  
**Status:** Pending manual action (API permission limitation)

### Decision

Enable `enforce_admins=true` on the `develop` branch protection rule. This blocks direct pushes for **all contributors including repository admins**.

### Why

In Sprint 4, a Chip agent pushed `.squad/` files directly to `develop` without opening a PR. Branch protection required 1 review + passing CI, but `enforce_admins=false` allowed admins to bypass.

### API Limitation

The Codespace token (ghu_ prefix) has `administration=read` only; branch protection PUT requires `administration=write`. API returned HTTP 403. Same limitation documented in prior sprint.

### Required Manual Action (Earl/Repo Owner)

1. Go to Settings → Branches on `primetimetank21/dev-setup`
2. Edit rule for `develop`
3. Check "Do not allow bypassing the above settings"
4. Save

Once enabled, close issue #54.

## [2026-04-08] Remove ps.tar.gz Binary Artifact

**Date:** 2026-04-08  
**Issue:** #57  
**Owner:** Donald (Shell Dev)  
**PR:** #59  
**Status:** PR Open

### What

Remove `ps.tar.gz` (69MB compiled PowerShell/.NET SDK DLLs) from repository.

### Why

- Binary artifact; no runtime purpose in a setup scripts repo
- Significant bloat
- Currently tracked in git; not in .gitignore

### Action Items

1. Remove file from working tree ✅
2. Update .gitignore ✅
3. Optional future: git history cleanup with git-filter-repo or bfg

## [2026-04-08] SQUAD_WORKTREES=1 for Parallel Agent Work

**Date:** 2026-04-08  
**Issue:** #56  
**Owner:** Pluto (Config Engineer)  
**PR:** #58  
**Status:** PR Open

### Decision

`SQUAD_WORKTREES=1` must be set for any Squad session with 2+ concurrent agents on different issues. Default in `.devcontainer/devcontainer.json`.

### Rationale

Sprint 4 revealed race condition: Chip-issue-43 ran `git checkout squad/43` while Chip-issue-41 was mid-commit on shared working tree. Wrong content landed on wrong branch; PR #51 had to close. Root cause: single git working tree cannot safely share between agents.

### Solution

With `SQUAD_WORKTREES=1`, coordinator creates isolated worktrees at `{repo-parent}/{repo-name}-{issue-number}`. Branch operations in one worktree are invisible to all others.

### Scope

- **Parallel runs:** SQUAD_WORKTREES=1 required
- **Sequential runs:** Not needed (no race condition)

### Implementation

- `SQUAD_WORKTREES=1` added to `.devcontainer/devcontainer.json` `remoteEnv`
- Skill documentation: `.squad/skills/worktree-isolation/SKILL.md`
- Contributor guidance: `CONTRIBUTING.md` § "Parallel Agent Work"

## [2026-04-08] Enforce Admins = False on Solo Repo (Deliberate Design)

**Date:** 2026-04-08  
**Issue:** #54  
**Owner:** Mickey (Lead)  
**Status:** Closed — Decision documented

### Decision

Branch protection on `develop` uses `enforce_admins=false`. This is a deliberate design choice, not a security oversight.

### Rationale

1. **Deadlock Prevention:** With `enforce_admins=true`, repo admins cannot approve and merge their own PRs. On a solo-developer repo (Mickey), this creates a merge deadlock.

2. **Review Gate Maintained:** PR requirement enforces 1 approving review + passing CI for all contributors (non-admins). This blocks direct pushes to `develop`.

3. **Admin Bypass Workflow:** Mickey (admin) opens PRs, reviews code, approves externally, then merges via `--admin` flag. This ensures every merge is reviewed without deadlock.

4. **Security Trade-off:** Admin can bypass PR requirement via direct push, but:
   - Team process (Scribe + squad conventions) enforces PR-first workflow
   - Codespace tokens prevent most direct pushes anyway (limited scope)
   - Mickey's review gate is the practical enforcement

### Going Forward

- Do NOT enable `enforce_admins=true` unless solo-dev workflow changes
- All squad PRs follow Mickey approve → admin merge pattern
- If multi-developer team forms, revisit this decision

## [2026-04-08] Admin Merge Pattern (Deliberate — NOT Emergency Override)

**Date:** 2026-04-08  
**Owner:** Ralph (Merge Coordinator)  
**Status:** Established standard

### Decision

Squad merge pattern is: `gh pr merge --admin` after Mickey approval. This is NOT an emergency override; it's the documented, everyday merge workflow.

### Context

- **Without this:** Solo-dev on admin account cannot merge own PRs (deadlock with `enforce_admins=true`)
- **With this:** Mickey approves → admin merge → no deadlock
- **Enforcement:** Process (Scribe task checks) + CONTRIBUTING.md documentation

### Standard Procedure

1. Agent opens PR
2. Mickey reviews and approves
3. Ralph executes `gh pr merge --admin` (or agent if solo task)
4. Scribe logs the merge

### Never

- Use `--admin` to force-merge unapproved PRs
- Use `--admin` as an emergency bypass without review
- Skip Mickey approval and go straight to admin merge

## [2026-04-08] Sprint 5 Action Items — Queued for Sprint 6 Planning

**Date:** 2026-04-08  
**Source:** Sprint 5 Retrospective  
**Facilitator:** Mickey (Lead)  
**Status:** Pending triage into Sprint 6 sprint planning

### 1. Consult decisions.md During Sprint Planning (P2)

**Owner:** Mickey  
**What:** Before assigning any issue, check decisions.md for known limitations or prior decisions related to the task. Add a "Known Constraints" check to the sprint planning workflow.  
**Why:** Sprint 5 re-attempted the API branch protection call despite this being a documented limitation from Sprint 3. Wasted agent time on a known dead end.

### 2. Fix PowerShell Lint CI Failure (P2)

**Owner:** Goofy / Chip  
**What:** Diagnose and resolve the `Lint PowerShell Scripts` CI job failure that has persisted since Sprint 4. Either fix the PowerShell scripts to pass PSScriptAnalyzer or adjust lint rules if the failures are false positives.  
**Why:** A persistently red CI job normalizes failure and reduces trust in the pipeline. This should not carry into a third consecutive sprint.

### 3. Dry-Run the Agent Timeout Policy (P3)

**Owner:** Ralph / Mickey  
**What:** In the first Sprint 6 parallel agent session, have Ralph explicitly log: (a) timeout tier assigned to each agent, (b) checkpoint timestamps, (c) whether any agent approached the limit. Report findings in orchestration log.  
**Why:** The timeout policy (issue #55) shipped as documentation but was never triggered in Sprint 5. First real use should be instrumented to validate the 5/10/20 min tiers.

### 4. Frame Issues as Problems, Not Implementations (P2)

**Owner:** Mickey  
**What:** Write issue titles and acceptance criteria to describe desired outcomes, not technical approaches. Example: "Ensure branch protection suits solo-repo workflow" instead of "Enable enforce_admins=true."  
**Why:** Issue #54 pivoted mid-sprint from "enable a flag" to "document why we don't enable it." Problem-framed issues absorb scope changes; implementation-framed issues create confusion.

### 5. Sequence Chicken-and-Egg Infrastructure Tasks (P3)

**Owner:** Mickey / Ralph  
**What:** When a task builds infrastructure that protects the environment it runs in (e.g., worktree isolation), run that agent sequentially — not in parallel with other agents who could trigger the exact problem being fixed.  
**Why:** Pluto hit a race condition on history.md while implementing the worktree isolation feature that would have prevented it. Cherry-pick resolved it, but the irony is avoidable.

### 6. Evaluate develop → main Promotion (P1)

**Owner:** Mickey / Earl  
**What:** Assess whether develop is ready for promotion to main. Sprint 5 shipped all planned process improvements, board is clear, 5/5 PRs merged.  
**Why:** Develop has been accumulating improvements across 3 sprints. If it's stable, it should ship. If it's not, identify the blockers.

---

## [2026-04-08] Guard Against gh Alias Conflicts Before Extension Install

**Date:** 2026-04-08  
**Owner:** Donald (Shell Dev)  
**Issue:** Bug — `scripts/linux/tools/copilot-cli.sh` fails with alias conflict  
**PR:** #63  
**Branch:** `squad/fix-copilot-cli-alias-conflict`  
**Status:** PR Open

### Problem

`gh extension install github/gh-copilot` fails with:
```
"copilot" matches the name of a built-in command or alias
```

The `gh` CLI refuses to install an extension whose command name matches an existing alias. The error goes to stdout, not stderr — so `2>/dev/null` redirection does not suppress it. A prior partial install can leave a stale `copilot` alias that permanently blocks future installs.

A secondary bug: the post-install check `$(gh copilot --version 2>/dev/null)` would trigger the same alias collision if one existed, leaking the error string into the output.

### Decision

Any shell script that installs a `gh` extension must:

1. Check for a conflicting alias before calling `gh extension install`:
   ```bash
   if gh alias list 2>/dev/null | grep -q "^copilot"; then
     log_warn "Removing conflicting gh alias 'copilot'..."
     gh alias delete copilot
   fi
   ```

2. Never use `$(gh <extension-cmd> --version)` as a post-install verification — it triggers the same alias lookup. Prefer `gh extension list | grep -q "<extension-name>"`.

### Rationale

- The `gh` alias conflict is silent from a script perspective (stdout, not stderr) and idempotency guards won't catch it if the extension was partially registered.
- The alias delete is safe: it only fires if the alias exists, and after install the extension's native command supersedes any alias anyway.
- Removing the `--version` subshell eliminates stdout-leaking post-install checks that could corrupt log output.

## [2026-04-12] Append Managed Block to Existing Shell RC Files

**Date:** 2026-04-12  
**Issue:** #64  
**Owner:** Pluto (Config Engineer)  
**PR:** #65  
**Branch:** `squad/64-dotfiles-append-managed-block`  
**Status:** PR Open

### Decision

`install.sh` now appends a dev-setup managed block to existing `.zshrc` and `.bashrc` instead of skipping them. A marker comment guards idempotency — the block is only appended once.

### Rationale

Devcontainer base images always ship with a pre-existing `.zshrc` and `.bashrc`. The previous skip behavior meant nvm, `$HOME/.local/bin`, and `.aliases` were never initialized in any container-based install — defeating the purpose of the dotfile step.

### Managed Block: `.zshrc`

```bash
# --- dev-setup managed block (do not edit) ---
export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
# --- end dev-setup managed block ---
```

### Managed Block: `.bashrc`

```bash
# --- dev-setup managed block (do not edit) ---
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
# --- end dev-setup managed block ---
```

nvm init is omitted from the `.bashrc` block — the nvm installer already appends its own initialization lines there.

### Idempotency

`grep -qF "# --- dev-setup managed block" <file>` before every append. Safe to run multiple times.

### Fresh Install Path

The "copy template if no `.zshrc`" path is preserved unchanged — correct behavior for truly new machines.

### `--dry-run`

`append_managed_block()` respects `$DRY_RUN` and reports what would happen without writing.

---

## [2026-04-12] User Directive — Scribe Must Always Push After Commit

**Date:** 2026-04-12  
**By:** Earl Tankard, Jr., Ph.D. (via Copilot)  
**Status:** Adopted

### Decision

Scribe must **ALWAYS commit AND push after logging**. Not just commit — push too. No exceptions. This is a standing directive from the repo owner.

### Rationale

User request — captured for team memory. Ensures that all squad work (logs, decisions, cross-agent updates) is immediately persisted to the remote branch without delay or manual intervention.

---

## Issue #81 — Copilot CLI Standalone Binary Install

**Date:** 2026-04-12  
**By:** Mickey (Lead) — Review of PR #82  
**Status:** Approved & Merged

### Decision

Replace the broken `CI=true gh copilot` shim approach with the official standalone installer (`curl -fsSL https://gh.io/copilot-install | bash`).

### Summary

Donald identified that `gh copilot` is a shim wrapper, not the actual binary. The previous `CI=true` + timeout hack was a workaround that didn't solve the root problem. The fix delegates to the official installer, which correctly places the standalone binary at `~/.local/bin/copilot`.

### Review Checklist

#### ✅ Idempotency
- Binary check: `[[ -x "$COPILOT_BIN" ]]` where `COPILOT_BIN="${HOME}/.local/bin/copilot"`
- Exits 0 immediately if already installed
- Correct for non-root use case

#### ✅ Error Handling
- Set -euo pipefail present
- Install wrapped in if-then with graceful fallback
- No silent failures; clear manual instructions on failure

#### ✅ Logic & Path Coverage
- Binary at `~/.local/bin/copilot` (non-root case)
- PATH already includes `~/.local/bin` via dev-setup managed block
- Removes `gh auth` dependency for install step (only needed to use the tool)

#### ⚠️ Root User Case
- **Issue:** Script checks `~/.local/bin/copilot` but root would install to `/usr/local/bin/copilot`
- **Verdict:** **Acceptable** — Script is explicitly for non-root dev environments. Root use is outside expected scope. Trade-off for simplicity is justified.

#### ✅ `curl | bash` Pattern
- Source: Official GitHub Copilot CLI installer (https://gh.io/copilot-install)
- Standard for dev tooling; acceptable for a dev setup script

#### ✅ Simplicity
- LOC reduced from 51 to 37 lines (14 lines removed)
- Removed: `gh auth` check, `CI=true timeout` hack, PTY workarounds
- Delegates to official installer — the right solution

### Improvements

1. **Fixes root cause:** Installs actual binary, not shim wrapper
2. **Removes auth dependency:** `gh auth` only needed to use tool, not install

## [2026-04-12] Branch Cleanup Complete — Issue #95

**Date:** 2026-04-12T05:42:16Z  
**Team:** Mickey (issue creation), Donald (execution)

**Decision:** Deleted 11 local + 2 remote stray branches from repository.

**Branches Removed (Local):**
- feat/add-va-alias
- fix/copilot-cli-standalone-install
- squad/66-fix-gitattributes-eol-lf
- squad/68-fix-output-ordering
- squad/69-devcontainer-crlf-guard
- squad/72-fix-copilot-binary-download
- squad/75-add-vim-to-prerequisites
- squad/76-fix-copilot-cli-non-interactive
- squad/79-ci-true-copilot-install
- squad/92-guard-sb-sz-aliases
- squad/fix-copilot-cli-alias-conflict

**Branches Removed (Remote):**
- squad/88-fix-crlf-line-endings
- squad/92-guard-sb-sz-aliases

**Rationale:** Team rule — all merged branches must be deleted promptly to maintain a clean branch list. These branches were already integrated to `develop`.

**Verification:** Final `git branch -a` shows only `develop`, `main`, and their remotes.
3. **Better idempotency:** Checks for binary itself, not shim directory
4. **Simpler:** No environment variable hacks or timeout workarounds
5. **Post-install validation:** `copilot --version` now works correctly

### Action Taken

- Approved PR #82
- Merged to `develop` (squash merge) on 2026-04-12T00:11:40Z
- Remote branch deleted
- Issue #81 closed

## [2026-04-13] Two-Issue Split for Install Script Fixes (Issues #68–#69)

**Date:** 2026-04-13  
**Decided by:** Mickey (Lead)  
**Issues:** #68 (stdout/stderr ordering), #69 (CRLF guard)  
**Related PR:** #66 (prior .gitattributes fix by Donald)  

### Problem Statement

Windows users continue to experience failures in Devcontainer setup despite PR #66 fixing `.gitattributes` and `.sh` file line endings. Investigation revealed TWO independent issues:

1. **Diagnostic Noise:** All error logs go to stderr, other logs to stdout. In piped contexts (Devcontainer `postCreateCommand`), this causes interleaved, out-of-order output that obscures failures.
2. **Working Tree CRLF Persistence:** `git add --renormalize` only updates git's index, not on-disk working tree files. Windows users who cloned before PR #66 still have CRLF `.sh` files on their machines. Linux Devcontainer sees these CRLF files when bind-mounted, causing `pipefail\r` bash errors.

### Decision

**Create TWO separate issues and PRs:**

#### Issue #68: Output Order (Logging Fix)
- **Root cause:** Mixed stdout/stderr streams in captured context
- **Fix:** `exec 2>&1` to merge stderr into stdout
- **Scope:** Minimal (2 entry points: `setup.sh` and `scripts/linux/setup.sh`)
- **Risk:** Very low; pure output order fix
- **Why separate:** Orthogonal to line-ending issue; can be reviewed/merged independently

#### Issue #69: CRLF Persistence (Devcontainer Remediation)
- **Root cause:** Working tree files untouched by `git add --renormalize`
- **Fix:** `onCreateCommand` in `.devcontainer/devcontainer.json` to strip CRLF before `postCreateCommand`
- **Scope:** Single configuration addition; defensive (no-op on already-LF)
- **Risk:** Very low; runs as setup step, no production impact
- **Why separate:** Addresses a deeper git/working-tree issue distinct from logging

### Rationale

**Why not merge both into one issue/PR?**
1. **Separation of concerns:** Logging order vs. line-ending normalization are different problems
2. **Independent review:** Easier for reviewers to reason about focused changes
3. **Test isolation:** Each can be tested and validated separately
4. **Faster merge:** If one encounters questions, the other isn't blocked

**Why this approach beats alternatives:**
- ✅ Not fixing in PRs before issues: Allows team visibility and decision-making
- ✅ Not bundling both into one PR: Avoids mixing unrelated concerns
- ✅ Not leaving broken: Creates actionable items for Scribe/team to implement

---

## [2026-04-13] Implementation: Issues #68 and #69 (Merged)

**Date:** 2026-04-13  
**Author:** Donald (Shell Dev)  
**PRs:** #70 (issue #68), #71 (issue #69)  
**Status:** Merged to `develop`

### Issue #68 — stdout/stderr merge with `exec 2>&1`

#### Problem

`log_error()` uses `>&2` in both `setup.sh` and `scripts/linux/setup.sh`. All other log helpers write to stdout. In a Devcontainer or piped environment, stderr and stdout are independently buffered — error messages can appear before or after unrelated lines, making it hard to understand which step failed.

#### Solution

Add `exec 2>&1` immediately after `set -euo pipefail` in both root scripts only:

- `setup.sh`
- `scripts/linux/setup.sh`

**Why only root scripts?**

`exec 2>&1` merges file descriptors for the running process AND all child processes it spawns (FDs are inherited via `fork/exec`). Every tool script under `scripts/linux/tools/` is launched via `bash ${tool_script}` — they inherit the merged FD. Adding `exec 2>&1` to child scripts would be redundant and misleading.

**Why not modify tool scripts anyway?**

Audited all 6 tool scripts (`auth.sh`, `copilot-cli.sh`, `gh.sh`, `nvm.sh`, `uv.sh`, `zsh.sh`) — none contain `>&2` redirections. Adding `exec 2>&1` to files that have no stderr output would create noise and false expectations.

#### Alternatives Considered

- Writing `log_error()` to stdout instead of stderr: rejected — stderr is semantically correct for errors; tools like CI log parsers and shell `2>` redirections rely on it.
- Adding `exec 2>&1` to every script individually: rejected — redundant once the root process has merged FDs.

#### PR #70: Merged
- Branch: `squad/68-fix-output-ordering` (deleted)
- CI: 4/4 green
- Approved by: Mickey

---

### Issue #69 — CRLF guard in `devcontainer.json`

#### Problem

PR #66 added `*.sh text eol=lf` to `.gitattributes` and ran `git add --renormalize .`. This normalizes git's index (what it will write on future `git checkout` calls) but does NOT rewrite existing files in the working tree. Windows users who had already cloned the repo before PR #66 still have CRLF `.sh` files on disk. When the Devcontainer bind-mounts `/workspaces/dev-setup` from the Windows host, bash executes those CRLF files and fails with `set: pipefail\r: invalid option`.

#### Solution

Add `onCreateCommand` to `.devcontainer/devcontainer.json`:

```json
"onCreateCommand": "find . -name '*.sh' | xargs sed -i 's/\\r//'",
```

Place it BEFORE `postCreateCommand` in the JSON so the intent is clear: strip CRLF first, then run setup.

**Why `onCreateCommand` and not `postCreateCommand`?**

`onCreateCommand` runs once when the container is first created, before `postCreateCommand`. Stripping CRLF in `postCreateCommand` would be too late — `bash setup.sh` is called inside `postCreateCommand`, which is the script that fails.

**Why `sed -i 's/\r//'` and not `dos2unix`?**

`dos2unix` is not guaranteed to be available in all base images. `sed` is POSIX and present everywhere. The `find | xargs sed -i` pattern is standard and well-understood.

**Safety:**

- On an already-LF system (Codespaces, CI, any Linux clone): `sed 's/\r//'` is a no-op — no `\r` characters exist to remove.
- On a Windows bind-mount: strips `\r` before any shell script runs.
- Idempotent: can run multiple times safely.

#### Alternatives Considered

- Running `git checkout -- .` in `onCreateCommand`: rejected — this would discard any uncommitted working tree changes the user may have.
- Using a `Dockerfile` `COPY` step to strip CRLF at image build time: rejected — doesn't apply to bind-mount scenarios where the host files are mounted live.
- Relying solely on `.gitattributes` `eol=lf`: insufficient — only affects future checkouts, not existing working trees.

#### PR #71: Merged
- Branch: `squad/69-devcontainer-crlf-guard` (deleted)
- CI: 4/4 green
- Approved by: Mickey

---

## [2026-04-13] Issue #72 — copilot-cli.sh Directory Check + printf Pipe for Binary Download

**Date:** 2026-04-13  
**Author:** Donald (Shell Dev)  
**Issue:** #72  
**PR:** #73  
**Branch:** `squad/72-fix-copilot-binary-download` (merged & deleted)  
**Status:** Merged to `develop`

### Problem

On `gh 2.89.0+`, `gh copilot` is a built-in command that prompts "Install GitHub Copilot CLI? [y/N]" on first invocation. The previous script used `gh copilot -- --help &>/dev/null 2>&1` as an idempotency check, which swallowed the install prompt. stdin got EOF, defaulted to 'N', binary was never downloaded. The script then tried `gh extension install github/gh-copilot`, which failed with "matches the name of a built-in" — we detected that message and incorrectly claimed success. Binary was never present.

### Decision

1. **Idempotency check:** Use directory existence — `~/.local/share/gh/copilot` non-empty. Exit-code probing is unreliable when gh intercepts the command before the binary runs.

2. **Install trigger:** `printf 'y\n' | timeout 60 gh copilot >/dev/null 2>&1`. Pipes stdin so the prompt is answered non-interactively. Works in non-TTY environments. `timeout 60` prevents hanging if the binary launches interactively after download.

3. **Removed:** `gh extension install github/gh-copilot` path — not applicable for built-ins.

4. **Removed:** `gh alias delete copilot` path — not needed, alias conflicts aren't the issue.

5. **Auth check moved before directory check** — better to fail early on auth than attempt a check that requires auth to succeed anyway.

### Rule

Never use exit-code from `gh copilot` subcommands as an install probe — gh intercepts them before the binary runs. Use filesystem state (`~/.local/share/gh/copilot`) instead.

#### PR #73: Merged
- CI: 4/4 green
- Approved by: Mickey
- Merge method: `--squash --delete-branch --admin`

---

---

## [2026-04-13] Issues #75 & #76 — vim Prerequisite & Copilot CLI PTY Fix

**Date:** 2026-04-13  
**Author:** Donald (Shell Dev)  
**Issues:** #75, #76  
**PRs:** #77 (feat: add vim), #78 (fix: copilot-cli PTY)  
**Status:** Open, pending review (target: develop)

### Issue #75 — vim Prerequisite

#### Problem

Pluto's dotfiles include aliases `vb` (vim bash config) and `vz` (vim zsh config) that invoke `vim` directly. On fresh Devcontainer builds without vim in system prerequisites, these aliases fail with "vim: command not found".

#### Solution

Add `vim` to system packages in `scripts/linux/setup.sh` line 69:
```bash
sudo apt-get install -y curl git build-essential vim
```

**Why:** vim is a hard dependency for user-facing aliases. Adding to prerequisites ensures a working environment on first boot. Idempotent and backward-compatible.

---

### Issue #76 — Copilot CLI Non-Interactive Binary Download

#### Problem

`gh copilot` binary download fails in non-interactive environments (Devcontainer `postCreateCommand`). The `gh` CLI checks `isatty(stdin)` — when stdin is a pipe, it ignores piped input and defaults to not downloading. Direct piping (`echo 'y' | gh copilot`) fails silently.

#### Solution

Use `script` (from util-linux, always on Ubuntu) to create a pseudo-TTY in `scripts/linux/tools/copilot-cli.sh` lines 40–46:

```bash
printf 'y\n' | timeout 120 script -q /dev/null -c "gh copilot"
```

**Why `script`?**
- Creates a pseudo-TTY; child process `gh copilot` runs with stdin connected to TTY slave
- `isatty(stdin)` returns true → accepts piped `y` input
- No external dependencies — script is from util-linux (base Ubuntu package)
- Alternative (`expect`, `unbuffer`) requires additional package installs; rejected

**Timeout bumped to 120s** from 60s to allow binary download on slow networks.

### Rule

**When automating interactive CLI tools that check `isatty()`:** Use `script -q /dev/null -c "command"` to provide pseudo-TTY. Direct piping fails if the tool ignores non-TTY input.

---

---

## [2026-04-12] Issue #83 — Add tmux to System Prerequisites

**Date:** 2026-04-12  
**Author:** Donald (Shell Dev)  
**Issue:** #83  
**PR:** #84  
**Branch:** `feat/add-tmux-prerequisite` (merged & deleted)  
**Status:** Merged to `develop`

### Problem

The `.aliases` file and `start_up()` function depend on tmux but it was never added to system prerequisites in `scripts/linux/setup.sh`. Fresh installs fail when users try to use tmux-related shortcuts.

### Solution

Add `tmux` to the system package installation in `scripts/linux/setup.sh`:
- macOS (brew): line 66 — added to `brew install` command
- Linux/WSL (apt-get): line 69 — added to `apt-get install` command

**Validation:** Ran `bash -n scripts/linux/setup.sh` to verify syntax.

### PR #84: Merged
- CI: 4/4 green (all checks passed)
- Approved by: Mickey (LGTM)
- Merge method: `--squash --delete-branch --admin`
- Merged at: 2026-04-12T04:31:48Z

---

## [2026-04-12] Session Retro Written — Session Wrap Complete

**Date:** 2026-04-12  
**Author:** Mickey (Lead)  
**Status:** ✅ Complete

### Summary

Sprint retrospective for the 2026-04-12 session wrap has been written to `.squad/retros/2026-04-12-session-retro.md`.

### Work Completed This Session

1. **Verified main/develop state** — Confirmed files are identical despite commit history divergence (expected with squash-merge workflow). Explained to Earl that the divergence is normal and documented the pattern.
2. **Branch cleanup (#95)** — Donald deleted 11 local + 2 remote stray branches. Board is clean.
3. **Sprint wrap PR #96** — develop → main PR to sync .squad/decisions.md. CI passed (8/8). Mickey merged to main. develop preserved.
4. **Final verification** — main is fully up to date. Only main and develop remain.

### Retro Insights

**What went well:**
- Verify → Action → Close cycle. Earl's divergence question was excellent hygiene.
- Branch cleanup executed cleanly with no rework.
- Promotion smooth; `--admin` pattern is now documented and repeatable.
- Process documentation is paying dividends.

**What could improve:**
- Stray branches accumulating as a pattern (2nd cleanup in project history).
- Squash-merge behavior isn't obvious to new users.
- No CI test validates squash-merge commit history.

**Action items:**
- [Mickey] Add "Why Main Diverges from Develop" to CONTRIBUTING.md.
- [Mickey] Establish branch cleanup SOP with sprint-end audit.
- [Chip] Optional: Validate squash-merge linearity in CI.

### Decision

This decision documents that the session retro was written and the board is clean. The action items from the retro should be incorporated into the next sprint planning cycle.

---

## [2026-04-12] Copilot Directive: Develop Reset Workflow

**Date:** 2026-04-12  
**By:** Earl Tankard, Jr., Ph.D. (via Copilot)  
**Status:** Adopted

### Decision

After every squash-merge sprint wrap (develop → main), reset develop by deleting and re-creating it from main. This keeps develop and main histories in sync. The old rule 'NEVER delete develop' applied to accidental mid-sprint deletion only — intentional post-sprint-wrap resets are required.

### Rationale

User request — captured for team memory. This directive ensures a clean state for the next sprint by maintaining synchronized histories.

---

## [2026-04-12] Copilot Directive: Merge Strategy

**Date:** 2026-04-12  
**By:** Earl Tankard, Jr., Ph.D. (via Copilot)  
**Status:** Adopted

### Decision

Sprint wrap PRs from develop → main must use REGULAR merge commits (not squash). This keeps develop and main histories in sync without needing to reset develop. Squash merges are no longer used for the develop → main promotion.

### Rationale

develop is branch-protected (can't delete or force-push). Regular merges keep histories connected automatically. This eliminates the need for post-sprint develop reset operations.

## [20260412T020010] User Directive — No-Squash for Sprint Wrap PRs

**By:** Earl Tankard, Jr., Ph.D. (via Copilot)  
**Date:** 2026-04-12T02:00:10Z

**What:** Going forward, ALL sprint wrap PRs (develop → main) MUST use regular merge commits. NEVER squash.

**Why:** Squash merges create permanent history divergence because develop is branch-protected. Regular merges keep both branches in sync.

**Rationale:** This is a hard rule with no exceptions.

---

## [2026-04-13] Documentation Update: Sprint Wrap Process Docs Aligned

**Date:** 2026-04-13T15:45:00Z  
**By:** Mickey  
**Status:** Implemented

### Decision

Updated Ralph's charter (`.squad/agents/ralph/charter.md`) and issue-lifecycle template (`.squad/templates/issue-lifecycle.md`) to enforce regular merge commits (`--merge`) for develop → main promotion PRs. Squash merges explicitly banned in both process documents.

### Changes

- `.squad/agents/ralph/charter.md`: Updated merge gate rule from `--squash` to `--merge`
- `.squad/agents/ralph/charter.md`: Added explicit warning that sprint wrap PRs must never use squash
- `.squad/templates/issue-lifecycle.md`: Added context documenting sprint wrap merge strategy
- Both files reference `.squad/decisions.md` for the no-squash rationale

### Rationale

Issue #97 closed. This ensures all process documentation and team member charters reflect the no-squash policy already captured in decisions.md. Squash merges create permanent history divergence on protected branches; regular merge commits keep develop and main in sync.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
### 20260412T021515: User directive
**By:** primetimetank21 (via Copilot)
**What:** Always delete merged branches both locally AND remotely. No stale branches ever — clean up local tracking refs at the same time as remote deletion.
**Why:** User request — sick of seeing stale branches locally after remote branches are deleted


---
### 20260412T022446: User directive — Scribe file scope constraint
**By:** primetimetank21 (via Copilot)
**What:** Scribe MUST NEVER modify files outside of .squad/. Root-level project files (.gitignore, .gitattributes, README.md, setup.sh, setup.ps1, etc.) are strictly off-limits for Scribe. Scribe's only authorized write targets are .squad/ files.
**Why:** Scribe modified .gitignore without authorization, un-ignoring log directories. This is a scope violation.


---

# Decision: Vim Install Pattern for Windows (Issue #107)

**Date:** 2026-04-13
**Author:** Goofy (Cross-Platform Developer)
**Status:** Proposed
**Issue:** #107

## winget Package ID

```
vim.vim
```

Full install command:
```powershell
winget install --id vim.vim --silent --accept-source-agreements --accept-package-agreements
```

## Idempotency Pattern

Follows the established pattern used by Install-GitBash, Install-GhCli, etc.:

```powershell
function Install-Vim {
    if (Get-Command vim -ErrorAction SilentlyContinue) {
        Write-Ok "vim already installed: $(vim --version | Select-Object -First 1)"
        return
    }
    Write-Info "Installing vim..."
    winget install --id vim.vim --silent --accept-source-agreements --accept-package-agreements
    Write-Ok "vim installed"
}
```

- Check `Get-Command vim` first -- if it exists, print `[OK]` and return immediately
- No PATH reload required (vim.vim adds to PATH via the installer; new terminal picks it up)
- No post-install steps or warnings needed

## Call Order in Main

Inserted after `Install-GhCli` and before `Install-CopilotCli`:

```
Install-GitBash
Install-Uv
Install-Nvm
Install-GhCli
Install-Vim          <-- here
Install-CopilotCli
Write-PowerShellProfile
```

Rationale: vim is a prerequisite for the vb/vz aliases (edit .bashrc / .zshrc) and should be
available before Copilot CLI in case any vim-based workflows are triggered during setup.

## PS 5.1 Compatibility

- No `$MyInvocation.MyCommand.Path` used
- No unguarded `$IsLinux` / `$IsMacOS` / `$IsWindows` references
- Works under `Set-StrictMode -Version Latest`
- Validated by Group E tests in `tests/test_windows_setup.ps1`

---

# Sprint 6 Retro Action Items — GitHub Issues Created

**Date:** 2026-04-18 (Session timestamp)  
**Source:** 2026-04-18 PS 5.x hotfix retro action items  
**Created by:** Mickey (Lead)  
**Status:** ✅ All three issues created and tracked

## Summary

Converted three untracked retro action items from the 2026-04-18 PS 5.x hotfix session into GitHub issues for Sprint 6 visibility. All issues are problem-framed, scoped, and ready for sprint planning assignment.

## Issues Created

### Issue #111: PS 5.x Compatibility Checklist
- **Title:** `docs(contributing): add PowerShell 5.x compatibility checklist`
- **Label:** `enhancement`
- **Owner:** Mickey
- **Goal:** Add documented PS 5.x review gate to CONTRIBUTING.md
- **Key items:**
  - Require `$PSScriptRoot` over `$MyInvocation.MyCommand.Path`
  - Mandate version guards for PS 6+ auto-vars (`$IsLinux`, `$IsMacOS`, `$IsWindows`)
  - Validate `Set-StrictMode -Version Latest` behavior

### Issue #109: CI PS 5.1 Validation Path
- **Title:** `ci: investigate PS 5.1 validation path on GitHub Actions`
- **Label:** `enhancement`
- **Owner:** Chip
- **Goal:** Research and implement PS 5.1 validation step in CI
- **Scope:** Windows runner investigation, syntax/runtime check design, workflow implementation, limitation documentation

### Issue #110: Direct-Push-to-Main Override Policy
- **Title:** `docs: codify direct-push-to-main override policy`
- **Label:** `documentation`
- **Owner:** Mickey
- **Goal:** Document exceptions to PR-only merge policy
- **Key items:**
  - Define acceptable override conditions (hotfix-only?)
  - Require explicit authorization record (Earl, squad log annotation)
  - Reference 2026-04-18 hotfix as precedent

## Rationale

**Why now:** These three items were identified as critical in the 2026-04-18 retro but had no GitHub home. Without issues, they risk being lost or forgotten between retrospectives. GitHub issues ensure:
- Visibility in sprint planning and burndown
- Traceable ownership (Mickey, Chip)
- Clear acceptance criteria for reviewers
- Audit trail of retro → implementation → merge

**Problem-framed:** Each issue frames the underlying problem (PS 5.x regressions, CI blind spot, undocumented override) rather than prescribing exact implementation. This allows flexibility during implementation while keeping the goal clear.

## Next Steps

1. Include issues #109–#111 in Sprint 6 planning pass
2. Assign to Mickey and Chip per issue ownership
3. Ensure checklist items are incorporated into acceptance criteria during sprint start
4. Reference this decision when closing issues (link back to retro)

## Learnings

- **Retro action items → GitHub issues:** Ensures accountability and visibility. Retros without GitHub homes risk being shelf-ware.
- **Problem-framing vs. implementation:** Framing issues as problems absorbs scope changes and pivot requests without expanding scope creep.
- **Durable documentation:** Decisions like this one create an audit trail. Future readers will see *why* these issues were created, *when*, and *what problem they solve*.

---

### 2026-04-18T19:19:41Z: User directive
**By:** Earl Tankard (via Copilot)
**What:** For issue #106 (install squad-cli globally in setup scripts), if npm/Node.js is not available, gracefully skip with a warning — do not force install Node.js as a prerequisite.
**Why:** User request — captured for team memory

---

## [2026-04-18] User Directive — Default Model Policy

**Date:** 2026-04-18T19:48Z
**By:** Earl Tankard (via Copilot)
**Status:** Adopted

**What:** Always use claude-opus-4.6 as the default model for every task — no model usage limits apply.
**Why:** User request — captured for team memory.

---

## [2026-04-19] PR #115 Review — feat(windows): add missing aliases to PowerShell profile

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**PR:** #115
**Branch:** `squad/108-powershell-alias-parity` → `develop`
**Closes:** #108
**Verdict:** ✅ APPROVED

**Summary:** 30 new aliases across 3 new section groups plus 14 in existing git section. All with PS 5.x compatibility, conflict guards, `$args` forwarding, inline comments, and test coverage (group F, 6 tests).

**Key points:**
- `gs` fix confirmed: `git status -sb` replaces `git status`
- Conflict guards: `gp`, `grb`, `grs`, `ni`, `h` all guarded with `Remove-Item -Force`
- Strict mode safe: All functions use `function Name { cmd $args }` pattern
- CI: All 4 checks green
- Tests: F-1 through F-6, `Test-Scenario` framework, ASCII-only, no Pester

**Non-blocking note:** Diff includes unrelated `.squad/agents/mickey/history.md` changes. Future PRs should keep one concern per PR.

---

## [2026-04-19] PR Review Verdicts: #112 and #114

**Date:** 2026-04-19
**Reviewer:** Mickey (Lead)
**Status:** Both approved

### PR #112 — feat(windows): install vim via winget
- **Verdict:** ✅ APPROVED
- **Issue:** #107
- **Branch:** `squad/107-install-vim-winget` → `develop`
- **CI:** All 4 checks green
- **Assessment:** Clean idempotent install pattern. PS 5.x compatible. Group E tests (E-1 through E-5) cover function existence, Main integration, winget package ID, and compat checks.
- **Note:** Test framework uses emoji instead of `[PASS]`/`[FAIL]` — pre-existing, track separately.

### PR #114 — feat(github): add GitHub issue templates
- **Verdict:** ✅ APPROVED
- **Issue:** #113
- **Branch:** `squad/113-github-issue-templates` → `develop`
- **CI:** All 4 checks green
- **Assessment:** All four template types present. Consistent structure, proper front matter, checkbox acceptance criteria.
- **Scope note:** PR bundles unrelated `.squad/` changes. Non-blocking, flagged for future discipline.

---

## [2026-04-19] Pluto Decision Log — Issue #108: PowerShell Alias Parity

**Date:** 2026-04-19
**Author:** Pluto (Config Engineer)
**Branch:** `squad/108-powershell-alias-parity`

### Aliases Added (30 total)

**Git (14 new + 1 fix):** Fixed `gs` → `git status -sb`. Added: `gaa`, `gcm`, `gcb`, `gco`, `gd`, `gds`, `ggsp`, `gp`, `gpf`, `gpl`, `grb`, `grbi`, `grs`, `grss`
**GitHub CLI (5):** `ghpr`, `ghprl`, `ghprv`, `ghis`, `ghiv`
**Dev Shortcuts (8):** `uvr`, `uvs`, `ni`, `nr`, `nrd`, `nrt`, `py`, `c`
**Utility (3):** `myip`, `pb`, `h`

### PS 5.1 Compatibility Decisions

- `Remove-Item -Force Alias:\<name>` before `Set-Alias` for built-in conflicts: `gc`, `gl`, `gp`, `grb`, `grs`, `ni`, `h`
- No `$MyInvocation.MyCommand.Path` anywhere
- All functions follow `function Name { command $args }` pattern for PS 5.1 strict mode
- No unguarded PS 6+ auto-vars

### Aliases Skipped

Shell-specific (navigation, ls, tmux, docker, reload), `path`, `ports`, `pip` — not applicable to PowerShell or not in scope for #108.
## [2026-04-18] PS 5.1-Safe Platform Detection in `Get-Platform`

**Date:** 2026-04-12  
**Author:** Goofy (Cross-Platform Developer)  
**Requested by:** Earl Tankard  
**File affected:** `setup.ps1` — `Get-Platform` function

### Context

`setup.ps1` uses `Set-StrictMode -Version Latest`. On Windows PowerShell 5.x, the automatic variables `$IsLinux`, `$IsMacOS`, and `$IsWindows` do not exist — they were introduced in PowerShell 6 (Core). Under strict mode, referencing an unset variable is a hard error.

### Decision

Replace bare references to `$IsLinux`/`$IsMacOS`/`$IsWindows` with version-guarded expressions that short-circuit on PS 5.x:

```powershell
$isWin = ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) -or
          ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')
$isLin = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$isMac = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
```

### Why This Works

- PowerShell's `-and` operator short-circuits: if the left side is `$false`, the right side is never evaluated. So on PS 5.x (`Major -lt 6`), `$IsLinux` and `$IsMacOS` are never touched.
- `$PSVersionTable.PSVersion.Major` is available from PS 2 onwards — safe everywhere.
- `$env:OS` is `Windows_NT` on every Windows version under PS 5.x — a reliable Windows fingerprint without needing `$IsWindows`.

### Outcome

`Get-Platform` now works correctly on PS 5.1 and PS 7+. On PS 5.x Windows:
- `$isWin` → `$true` (via `$env:OS -eq 'Windows_NT'`)
- `$isLin` → `$false` (short-circuited, `$IsLinux` never evaluated)
- `$isMac` → `$false` (short-circuited, `$IsMacOS` never evaluated)

---

## [2026-04-18] Retro Action Items — PS 5.x Hotfix Session

**Source:** Session retro facilitated by Mickey  
**Date:** 2026-04-18  
**Session:** PS 5.x hotfix (bugs in setup.ps1)

### Action Items from Retro

#### 1. PS 5.x Compatibility Checklist (new process gate)

**Owner:** Mickey  
**Priority:** P2

Create and document a PS 5.x review checklist to be applied to any new `.ps1` code:
1. No use of `$MyInvocation.MyCommand.Path` — use `$PSScriptRoot` always
2. All PS 6+ automatic variables (`$IsLinux`, `$IsMacOS`, `$IsWindows`) must be guarded behind `$PSVersionTable.PSVersion.Major -ge 6` short-circuit
3. Strict mode behavior (`Set-StrictMode -Version Latest`) must be validated for all variable references
4. Any new Windows code must explicitly note whether it was tested on PS 5.1 or PS 7+

Add this checklist to CONTRIBUTING.md under "Windows / PowerShell Review Gate."

#### 2. CI: PS 5.1 Validation Path

**Owner:** Chip  
**Priority:** P2

Investigate adding a Windows runner to GitHub Actions that validates `setup.ps1` on PowerShell 5.1. At minimum, a syntax check (`powershell -Version 5 -File setup.ps1 -WhatIf` or PSScriptAnalyzer) would catch this category of bugs before they reach `main`.

#### 3. Direct-Push-to-Main Override Policy

**Owner:** Mickey  
**Priority:** P3

The current PR policy has no documented exception path. Earl authorized direct push to `main` for today's session. We need a short policy:
- Direct pushes to `main` require explicit Earl authorization
- The commit message or squad log must note the override (e.g., `[main-override: Earl Tankard YYYY-MM-DD]`)
- Not for use outside genuine hotfix scenarios

Add to CONTRIBUTING.md under "Merge Policy > Emergency Hotfix."

#### 4. Sprint 6 Issue Assignment

**Owner:** Mickey  
**Priority:** P1

Assign existing issues to Sprint 6:
- Issue #107 (install vim on Windows via winget) → Goofy
- Issue #108 (add .aliases to Windows PowerShell profile) → Pluto or Goofy

Both are scoped, small, and ready. Include in next sprint planning pass.

#### 5. Windows Shortcuts Coverage Gap

**Owner:** Mickey / Pluto  
**Priority:** P2

Issue #108 was created because `.aliases` shortcuts are currently only applied on Linux/macOS (via `.zshrc`). Windows users running PowerShell get no shell shortcuts at all. This is a feature parity gap. Ensure Sprint 6 planning accounts for the full scope: discovering which aliases are useful in PS context, and adapting them to PS syntax (not just copying bash aliases).


## [2026-04-18]: Sprint 7 wrap — develop → main

**By:** Mickey
**What:** Merged develop → main via PR #131 (regular merge commit). Sprint 7 complete: git hooks (#121), branch isolation docs (#122), CI PS guards (#123).
**Why:** Sprint 7 all issues closed, develop ahead of main.

---

## [2026-04-18]: PR #130 Regressions Fixed — PS 5.1 Guard Pattern Confirmed

**Issues:** #132 (Goofy + Mickey regression reports)
**PR:** #133 (Goofy fix)
**Status:** ✅ Merged to develop

### What
PR #130 (git hooks + CI guards) inadvertently introduced two regressions:

1. **PSScriptAnalyzer warnings** — Function name violated `PSUseSingularNouns` rule; missing function reference
2. **PS 5.1 crash** — Test-Path Variable:* guard pattern (`Test-Path Variable:IsWindows -and $IsWindows`) throws `VariableIsUndefined` under `Set-StrictMode -Version Latest` on PowerShell 5.1, even with short-circuit `-and`

### Root Cause Analysis
- **PSAnalyzer:** `Install-GitHooks` → `Install-GitHook` (singular noun required); function was referenced but assignment not used
- **PS 5.1 strict mode:** Even though `-and` short-circuits at runtime, strict mode validates ALL operands at parse time. The `Test-Path Variable:*` check doesn't prevent evaluation of `$IsWindows` on PS 5.1.

### Correct Pattern
The ONLY safe pattern for PS 5.1 strict mode compatibility:
```powershell
# Correct: PSVersion check short-circuits BEFORE $IsWindows is evaluated
($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)

# BROKEN on PS 5.1 strict mode (even with -and short-circuit)
(Test-Path Variable:IsWindows -and $IsWindows)
```

### Fixes Applied (PR #133)
- Renamed `Install-GitHooks` → `Install-GitHook`
- Removed unused `$gitDir` variable
- Restored PSVersion guards in `setup.ps1` guards (revert to pre-#130 pattern)
- All PSScriptAnalyzer checks now pass

### Key Learning for Future Work
Test-Path Variable:* pattern is **NOT** a valid substitute for PSVersion-based guards under strict mode on PS 5.1. The approved pattern (`$PSVersionTable.PSVersion.Major -ge 6 -and ...`) must always be used for PS 6+ automatic variables.

### Follow-up
Test "Root setup.ps1 guards all three PS-Core-only variables" still expects Test-Path Variable:* pattern and will fail. Needs stale test update in follow-up work.

---

## # Decision: Issue #135 Stale Test Fix (PR #136)

**Date:** 2026-04-18
**Agent:** Chip (Tester), Mickey (Lead)
**Issue:** #135
**PR:** #136
**Branch:** `squad/135-fix-stale-ps-guard-test`
**Status:** ✅ Merged to develop

### What Changed

Updated the stale test assertion in `tests/test_windows_setup.ps1`:

**Test:** "Root setup.ps1 guards all three PS-Core-only variables"

**Before (broken — checked for obsolete pattern):**
```powershell
$setupContent = Get-Content (Join-Path $RepoRoot 'setup.ps1') -Raw
foreach ($varName in @('IsLinux', 'IsMacOS', 'IsWindows')) {
    if ($setupContent -notmatch "Test-Path Variable:$varName") {
        throw "Root setup.ps1 is missing 'Test-Path Variable:$varName' guard"
    }
}
```

**After (correct — validates actual PSVersion-based guards):**
```powershell
$setupLines = Get-Content (Join-Path $RepoRoot 'setup.ps1')
foreach ($varName in @('IsLinux', 'IsMacOS', 'IsWindows')) {
    $guarded = @($setupLines | Where-Object { $_ -match ('\$' + $varName) -and $_ -match 'PSVersionTable\.PSVersion\.Major' })
    if ($guarded.Count -eq 0) {
        throw "Root setup.ps1 is missing PSVersion-based guard for '$varName'"
    }
}
```

Also updated header comment to describe the PSVersion-based guard pattern.

### Why

The test was checking for `Test-Path Variable:` guards that no longer exist in `setup.ps1`. The actual implementation (merged via PR #130) uses PSVersion-based guards.

The `Test-Path Variable:` pattern was the original broken pattern (fails under PS 5.1 strict mode). The PSVersion-based pattern is the correct, currently-in-production pattern.

### Key Learning

**Test assertions must match the actual implementation pattern, not historical patterns.**

When a guard strategy changes in production code (e.g., from `Test-Path Variable:` to PSVersion checks), the test that validates the guard must be updated in sync. Stale tests checking for a superseded implementation are false failures — they block CI and mislead developers about what is actually broken.

### Verification

✅ `setup.ps1` *does* use PSVersion-based guards:
- Line 32: `$PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows`
- Line 34: `$PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux`
- Line 35: `$PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS`

✅ No Unicode/smart quotes in test file (ASCII only)
✅ Test logic validates the right thing (PSVersion pattern, not Test-Path Variable:*)

### Outcome

✅ PR #136 merged to develop
✅ Issue #135 closed
✅ Test now reliable and validates correct guard pattern

---

## # Decision: Sentinel Fix Scope — Write-PowerShellProfile

**Issue:** #144 (child of #138)
**Agent:** Mickey (Lead)
**Date:** 2026-04-20

## Context

`Write-PowerShellProfile` in `scripts/windows/setup.ps1` uses a sentinel check (`# BEGIN dev-setup profile`) to guard against duplicate profile injection. When the sentinel is found, the function returns early — skipping all injection. This made sense when the profile block was static, but now that aliases are being added incrementally (e.g., psmux aliases in PRs #141/#142), the skip logic means returning users never pick up new content.

Earl reported `ta`, `tks`, `tls`, `tt` are undefined after re-running setup.ps1. Root cause confirmed: his profile has the sentinel from a prior run, so setup skips injection of the now-larger block.

## Decision

**Change sentinel semantics from "skip" to "replace."**

1. If the `# BEGIN dev-setup profile` ... `# END dev-setup profile` block exists, strip it from the profile file content.
2. Fall through to inject the full current block (same path as first-time install).
3. Preserve all user content outside the managed block markers.

This keeps the idempotency contract: re-running setup converges to the latest desired state, regardless of how many times it's been run or what version was previously installed.

## Scope Boundaries

- **In scope:** Sentinel logic change in `Write-PowerShellProfile`, tests for re-injection, line ending handling (CRLF/LF).
- **Out of scope:** Alias conflict resolution with built-in cmdlets (separate concern tracked in #138), profile auto-load behavior across PS versions (separate diagnostic).

## Risk

Low. The managed block is clearly delimited by markers. Stripping between markers and re-injecting is a well-understood pattern (same approach used in the Unix `install.sh` managed block logic). The main risk is regex edge cases with line endings, which is why CRLF/LF handling is an explicit acceptance criterion.

## Outcome

Issue #144 created with full acceptance criteria. Comment added to parent issue #138 linking the fix. Ready for assignment in next sprint planning pass.

---

## # Decision: Strip+Re-inject Pattern for Managed Config Blocks

**Date:** 2026-04-18  
**Author:** Goofy (Developer)  
**Status:** Adopted  
**PR:** #145  
**Issue:** #144

## Context

Write-PowerShellProfile in scripts/windows/setup.ps1 used "skip if sentinel present" logic:
```powershell
if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern ([regex]::Escape($sentinel)) -Quiet)) {
    Write-Ok "PowerShell profile shortcuts already installed"
    return  # ❌ SKIP — never updates
}
```

When psmux aliases were added in PRs #141/#142, users who had already run setup.ps1 never received the new aliases (`ta`, `tks`, `tls`, `tt`) because the function returned early.

## Decision

Change Write-PowerShellProfile (and similar managed-content functions) to use **strip + re-inject** instead of **skip**:

```powershell
# If the managed block already exists, strip it out so we can re-inject fresh
if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern ([regex]::Escape($beginMarker)) -Quiet)) {
    Write-Info "Updating PowerShell profile shortcuts..."
    $raw = Get-Content $PROFILE -Raw
    # Strip the managed block (handles both LF and CRLF)
    $raw = $raw -replace "(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?", ''
    Set-Content $PROFILE $raw -NoNewline
}
# Fall through to inject fresh current block
```

## Rationale

- **Never skip** — always update when content changes
- **Safe removal** — regex only strips content between BEGIN/END markers
- **Preserves user content** — anything outside the markers is untouched
- **Cross-platform** — handles both CRLF (Windows) and LF line endings
- **Incremental features** — new aliases/functions automatically delivered to existing users

## Consequences

### Positive
- Users always get the latest profile content on next setup run
- No need to manually delete managed blocks to force updates
- Supports iterative feature additions (like psmux aliases)

### Negative
- Slightly more complex than skip logic (regex strip required)
- Profile rewrites on every run (but only managed block, user content safe)

### Neutral
- Must ensure BEGIN/END markers are always present in managed content
- Regex must handle both CRLF and LF (already implemented)

## Alternatives Considered

1. **Manual deletion instructions** — Ask users to delete the old block manually
   - ❌ Poor UX, error-prone
2. **Version number in sentinel** — Track version, update when version changes
   - ❌ Still requires version bump logic, not idempotent
3. **Content hash check** — Skip only if hash matches current content
   - ❌ Complex, doesn't handle partial edits by users

## Testing

Added test group J (4 tests) to verify:
- BEGIN/END markers present in function body
- No 'return' after sentinel check (confirms skip removed)
- Get-Content/Set-Content present (confirms strip logic)
- Regex handles both CRLF and LF

## Related

- Issue #144: Write-PowerShellProfile should update existing profile block, not skip it
- Issue #138: Windows PowerShell aliases not fully working after setup
- PRs #141/#142: Added psmux aliases (ta, tks, tls, tt)

## Recommendation

**Adopt strip+re-inject as the standard pattern for ALL managed configuration blocks** (PowerShell profile, shell rc files, git hooks, etc.) to ensure users always receive incremental updates without manual intervention.

---

## # Decision: Adopt strip+re-inject pattern for managed config blocks

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Context:** PR #145 review (Issue #144)

## Decision

All managed config blocks (e.g., `# BEGIN dev-setup profile` / `# END dev-setup profile`) must use the **strip + re-inject** pattern instead of **skip if sentinel present**. This ensures re-running setup always converges to the latest managed content.

## Rationale

The old skip pattern silently dropped new aliases/functions for users who ran setup before those features were added. The strip+re-inject pattern preserves user content outside the markers while always injecting the current block.

## Applies To

- `Write-PowerShellProfile` in `scripts/windows/setup.ps1`
- Any future managed block injection (Linux shell configs, etc.)
