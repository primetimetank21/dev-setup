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

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
