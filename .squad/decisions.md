# Squad Decisions

## Active Decisions

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

