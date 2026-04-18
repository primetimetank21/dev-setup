# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup — A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent — safe to run multiple times


## Core Context

**Sprint 1–4 Summary (2026-04-07 to 2026-04-12):**

Established foundational architecture, team processes, initial feature set, and Windows Devcontainer compatibility fixes.

- **Architecture (Issue #3, PR #17):** OS detection entry points (`setup.sh` Unix, `setup.ps1` Windows); router pattern; WSL routed as Linux; full directory structure
- **Tool Implementation (Donald):** Linux/macOS core setup, 6 tool scripts (zsh, uv, nvm, gh, copilot-cli, auth)
- **Config (Pluto):** Dotfile templates (.gitconfig, .editorconfig, .npmrc, .aliases, .zshrc), shell aliases, install.sh scaffolding
- **Windows (Goofy):** PowerShell setup entry point (setup.ps1) and core Windows setup script
- **CI (Chip):** GitHub Actions workflow validating all platforms
- **Squad Governance:** Branch protection, review gates, admin merge pattern established
- **Process Improvements (Sprint 5):** Issue #54–#57 (branch protection, agent timeout policy, worktree isolation, binary cleanup)
- **Shell Compatibility (April 12):** PR #65 (append managed block to existing shells), PR #66 (.gitattributes eol=lf fix)

**Sprint 5 Summary (2026-04-08 to 2026-04-13):**

Resolved Sprint 4 action items, shipped bug fixes, and completed Windows regression tests.

- **Issues #54–#57 resolved:** Branch protection docs, agent timeout policy (5/10/20 min tiers), worktree isolation (`SQUAD_WORKTREES=1`), binary cleanup
- **PRs #58–#62 merged:** All Sprint 5 deliverables shipped to `develop`
- **Issues #68–#69 (PRs #70–#71):** `exec 2>&1` stderr/stdout merge + `onCreateCommand` CRLF guard for Devcontainer
- **Issue #72 (PRs #73, #78, #80):** Copilot CLI binary download fix — evolved from piped stdin to script(1) PTY to final `CI=true` bypass
- **PR #77:** vim added to Linux prerequisites (Goofy). **PR #84:** tmux added to Linux prerequisites
- **PR #104:** Windows PS regression tests (Groups A–D, 15 tests) — blocked by empty catch lint, fixed by Goofy (`Write-Verbose`), merged. Issues #102, #103 closed
- **Issue #97 (PR #99):** No-squash policy for sprint wrap PRs codified in Ralph charter + issue-lifecycle template

**Key Patterns Learned:**
- `CI=true` for postCreateCommand: when a CLI gates on `IsCI()`, set env var rather than PTY/pipe wrapping
- Empty catch blocks trigger PSScriptAnalyzer — use `Write-Verbose` for intentional silence
- `git add --renormalize` updates INDEX only, not working tree
- `script -q /dev/null -c 'command'` for isatty()-gated CLIs (general pattern)
- Branch protection write via `gh api` blocked by Codespace token scope — manual UI action required
- Frame issues as problems, not implementations; consult decisions.md before sprint planning
- Retro loop works: Sprint 4 action items all shipped in Sprint 5

**Board Status (end Sprint 5):** All Sprint 5 issues closed. 6 action items queued for Sprint 6.

---

## Learnings

Completed Issue #97 — updated Ralph charter and issue-lifecycle template to ban squash merges for sprint wrap PRs. PR #99 merged into develop, PR #100 (sprint wrap) merged into main. All process docs now consistent with no-squash policy.

<!-- Append new learnings below. Each entry is something lasting about the project. -->

---

## 2026-04-18 — Sprint 6 Retro Action Items: Created Issues #109–#111

**Task:** Convert retro action items from 2026-04-18 PS 5.x hotfix session into tracked GitHub issues for Sprint 6 visibility.

**Issues Created:**
- **Issue #111:** `docs(contributing): add PowerShell 5.x compatibility checklist` (Label: `enhancement`, Owner: Mickey)
  - Adds PS 5.x review checklist to CONTRIBUTING.md
  - Covers: `$PSScriptRoot` usage, version-guarded auto-vars, strict mode validation
  
- **Issue #109:** `ci: investigate PS 5.1 validation path on GitHub Actions` (Label: `enhancement`, Owner: Chip)
  - Research Windows runner PS version availability
  - Design PS 5.1 syntax/runtime validation step for CI
  - Implement in `.github/workflows/`
  
- **Issue #110:** `docs: codify direct-push-to-main override policy` (Label: `documentation`, Owner: Mickey)
  - Document override policy in CONTRIBUTING.md or docs/PROCESS.md
  - Specify: acceptable conditions, required annotations, authorization rules
  - Reference 2026-04-18 hotfix as precedent

**Status:** All three issues created and visible on board. No assignee set for Mickey-owned issues (#111, #110) per established policy. Chip-owned issue (#109) assignee optional (repo assignment attempted if applicable).

**Next:** Issues queued for Sprint 6 planning pass. All three are small-scoped, problem-framed, and ready to assign.

---

## 2026-04-19 — Issue Templates + Issue Fixes

### Templates created (Issue #113, PR #114)
- `.github/ISSUE_TEMPLATE/bug_report.md` — bug template with environment, steps, acceptance criteria
- `.github/ISSUE_TEMPLATE/feature_request.md` — feature template with motivation, proposed change, idempotency criteria
- `.github/ISSUE_TEMPLATE/documentation.md` — docs template with problem/proposed change structure
- `.github/ISSUE_TEMPLATE/ci_infra.md` — CI/infra template for workflow and tooling changes
- Branch: `squad/113-github-issue-templates` → PR #114 targeting `develop`

### Issues fixed
- **#106:** Replaced garbled body (backslashes replacing backticks, broken code fences) with correctly formatted version using `gh issue edit --body-file`
- **#111:** Added `## Background` section above `## Problem` to capture orphaned intro paragraph; normalized heading style from `## Acceptance Criteria` to `## Acceptance criteria`

### Decision
Standard issue sections going forward: `## Summary`, then type-specific sections, then `## Acceptance criteria`. Templates enforce this automatically.

---

## 2026-04-19 — Code Review: PR #112 and PR #114

**Reviewer:** Mickey (Lead)

### PR #112 — feat(windows): install vim via winget
- **Verdict:** ✅ APPROVED
- **Branch:** `squad/107-install-vim-winget` → `develop`
- **CI:** All 4 checks green
- **Assessment:** Clean implementation. Idempotent install pattern matches existing functions. PS 5.x compatible — no banned patterns. Group E tests (E-1 through E-5) cover function existence, Main integration, winget package ID, and compat checks. No scope creep.
- **Note:** Test framework uses emoji (✅/❌) instead of `[PASS]`/`[FAIL]` brackets — pre-existing, flagged for future housekeeping.

### PR #114 — feat(github): add GitHub issue templates
- **Verdict:** ✅ APPROVED
- **Branch:** `squad/113-github-issue-templates` → `develop`
- **CI:** All 4 checks green
- **Assessment:** All four template types present (bug, feature, docs, ci/infra). Consistent structure, proper front matter, checkbox acceptance criteria. Well done.
- **Scope note:** PR bundles unrelated `.squad/` changes (Goofy's vim history, sprint 6 decisions, user directive). Not blocking since no functional impact, but flagged — future PRs should keep one concern per PR.

**Overall:** Both PRs ready to merge.

---

## 2026-04-19 — Code Review: PR #115

**Reviewer:** Mickey (Lead)

### PR #115 — feat(windows): add missing aliases to PowerShell profile
- **Verdict:** ✅ APPROVED
- **Branch:** `squad/108-powershell-alias-parity` → `develop`
- **CI:** All 4 checks green
- **Author:** Pluto (Config Engineer)
- **Assessment:** All 30 aliases present and correct (14 git, 5 gh CLI, 8 dev shortcuts, 3 utility). `gs` fix applied (`git status -sb`). All 5 built-in alias conflicts (`gp`, `grb`, `grs`, `ni`, `h`) properly guarded. Every function passes `$args` correctly, inline comments on all functions, PS 5.x strict mode compatible. Test group F (6 tests) covers all alias groups plus compat. ASCII-only throughout.
- **Minor note:** Diff includes unrelated `.squad/agents/mickey/history.md` additions (prior review notes). Non-blocking, flagged for future discipline.

---

## 2026-04-19 — PRs #112, #114, #115 Merged; Issues #107, #108, #113 Closed

All three Sprint 6 PRs merged to `develop`:
- **PR #112** (vim via winget, closes #107) — merged
- **PR #114** (GitHub issue templates, closes #113) — merged
- **PR #115** (PowerShell alias parity, closes #108) — merged

Issues #107, #108, #113 closed manually (GitHub doesn't auto-close on develop merges).

**Earl directive captured:** Always use claude-opus-4.6 as default model — no usage limits.

---

## 2026-04-19 — Issues #110 and #111 Implemented

**Task:** Implement two documentation issues from Sprint 6 retro action items.

- **Issue #110** (direct-push override policy) → **PR #117** (`squad/110-direct-push-policy` → `develop`)
  - Added "Direct-Push Override Policy" section to `CONTRIBUTING.md`
  - Documents hotfix conditions, audit trail, and 2026-04-18 precedent

- **Issue #111** (PS 5.x compatibility checklist) → **PR #119** (`squad/111-ps5x-checklist` → `develop`)
  - Added "PowerShell 5.x Compatibility" section to `CONTRIBUTING.md`
  - 5-item checklist, testing guidance, known regressions table

**Status:** Both PRs open, targeting `develop`. Awaiting review and merge.
