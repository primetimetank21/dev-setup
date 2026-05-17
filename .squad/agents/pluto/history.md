# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup -- A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent -- safe to run multiple times

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### Worktree isolation pattern (Issue #56, 2026-04-07)

- `SQUAD_WORKTREES=1` is the recommended env var to enable per-issue git worktree isolation.
- The coordinator creates worktrees at `{repo-parent}/{repo-name}-{issue-number}` so each agent gets a fully isolated working tree.
- This prevents the Sprint 4 race condition where Chip-issue-43 checked out a branch while Chip-issue-41 was mid-commit on the same working tree.
- `SQUAD_WORKTREES=1` is now set by default in `.devcontainer/devcontainer.json` `remoteEnv`.
- Full pattern documented in `.squad/skills/worktree-isolation/SKILL.md` and `CONTRIBUTING.md Sec. "Parallel Agent Work"`.
- PR: https://github.com/primetimetank21/dev-setup/pull/58

### Gitconfig templates do not support shell expansion (Issue #184)

- Git reads `.gitconfig` values as literal strings -- `${EDITOR:-vim}` is NOT expanded by the shell, it becomes the literal editor command, which fails.
- For any tool-config template that is NOT processed by a shell at apply time, always use literal values.
- Pattern: use a sensible literal default + a comment showing how to override (e.g., `# Override with: git config --global core.editor <your-editor>`).
- The dotfiles `install.sh` does `sed` substitution for `YOUR_NAME`/`YOUR_EMAIL` placeholders, but does NOT expand arbitrary shell variables in the gitconfig template.

> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place; no archive file).

## Work Log (pre-2026-05-16 summary)

Compressed; older sessions kept as short bullets to preserve audit trail.

- **2026-04-07 -- Issue #10** Dev Container + Codespace post-create setup. Devcontainer.json, postCreateCommand, CRLF guard precursor.
- **2026-04-07 -- Issue #11** Dotfile templates: `.gitconfig`, `.npmrc`, `.editorconfig` under `config/dotfiles/`. Decision: templates with shell-expansion limitation (see Learnings).
- **2026-04-07 -- Issue #8** Shell aliases first cut; design decisions on POSIX vs bash/zsh-only (later formalized in #236).
- **2026-04-08 -- Issue #56** Worktree isolation for parallel agent work -- pattern that became standard SOP (see Learnings).
- **2026-04-07 -- Issue #108** PowerShell alias parity first cut; PR #115 merged 2026-04-19 (closes #108).
- **2026-04-12 -- Issue #64** Append managed block to existing .zshrc/.bashrc with sentinel markers (`# --- dev-setup managed block ---`).
- **Sprint 6** PowerShell aliases completion (#108 follow-up); AllScope alias guards established.

Lessons preserved verbatim in Learnings section above (worktree isolation pattern, gitconfig template shell-expansion limitation).

---

## Learnings

### 2026-05-18: CHANGELOG.md created (Issue #188, PR #203)
- Created CHANGELOG.md at repo root following Keep a Changelog format
- Backfilled 7 sprints of history from git log and .squad/log/ files
- Sprint boundaries inferred from retro files and explicit sprint-wrap PRs
- Grouped ~60 PRs into meaningful bullets by theme rather than listing each individually
- Branch: squad/188-add-changelog -> develop

### 2025-07-14: Tmux auto-attach opt-in (Issue #192)
- Wrapped `start_up` invocation in `.zshrc.template` behind `TMUX_AUTOSTART=1` guard
- Breaking change: auto-attach now OFF by default; users must export the var
- Used POSIX `[ "${VAR:-}" = "1" ]` for bash/zsh compatibility
- Branch: squad/192-tmux-opt-in -> develop

### Post-sprint configs/hooks audit (2026-05-16)
- Lens: configs / dotfiles / hooks
- 9 findings reported to coordinator; top 3: .ps1 CRLF in .gitattributes, [[ ]] POSIX compatibility in .aliases, PSScriptAnalyzer advisory mode in pre-push.

### Audit verification (V-9, V-15, V-17, V-11) - 2026-05-20
- **V-9 (PSScriptAnalyzer advisory):** CONFIRMED. Intentional design per CONTRIBUTING.md. Lint before PR, not before push. Advisory protects local developer flow. Current behavior matches shellcheck.
- **V-15 (dotfile .bak):** CONFIRMED. Linux overwrites .bak each run. Windows backs up once. Both lose history; no accumulation. Risk: prior backups deleted on re-run. Needs hybrid (timestamped or rotated) strategy.
- **V-17 (core.hooksPath docs):** CONFIRMED. Both setup scripts configure it, but README/CONTRIBUTING don't document automatic setup. CONTRIBUTING still says "install manually" (outdated). Low effort fix.
- **V-11 (.gitattributes CRLF for .ps1):** CONFIRMED. .ps1 files normalize to LF per global rule. Works fine on all PS versions. Missing explicit rule for clarity. Should add `*.ps1 text eol=lf` for intent transparency.
- **Phasing:** P1 = V-17 (docs), V-15 (backup strategy). P2 = V-9 (already acceptable), V-11 (nice-to-have clarity).

- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

### 2026-05-21: Protected branch guard in pre-commit (Issue #249)

- Recurring incident class: agents and humans committing directly to develop/main. Existing Check 1 catches ancestry bleed (squad/* not forked from develop) but does NOT block commits ON develop/main itself.
- Fix: added Check 5 to pre-commit hook using `git rev-parse --abbrev-ref HEAD` + case match on develop/main/master. Exits 1 with actionable error message.
- Renumbered existing shellcheck check from Check 5 to Check 6.
- Added 5 test cases (develop, main, master refuse; squad/* and pluto/* allow).
- Priority bumped to P0 this session due to 3+ recurrences.

### 2026-05-21: Pre-commit hygiene checks (Issue #240)

**Design decisions:**
- Ordered checks fastest-first: branch ancestry (single git command, sub-5ms), ASCII scan (only staged .ps1), rogue paths (pattern match), inbox check (grep). Shellcheck stays last.
- All 4 checks are HARD FAIL (exit 1). Inbox file staging should never happen legitimately; rogue paths indicate misunderstanding of structure; ancestry bleed is a workflow error; non-ASCII in .ps1 causes runtime failures.
- Used `grep -nP '[^\x00-\x7f]'` for ASCII detection. Requires GNU grep with PCRE (shipped with git-bash on Windows, standard on Linux). macOS ships BSD grep without -P; if needed, a `perl -ne` fallback could be added, but git-bash is the target (git hooks always run via git's bundled bash).
- Did NOT use `LC_ALL=C` with `-P` flag -- git-bash's grep errors with "supports only unibyte and UTF-8 locales". Default UTF-8 locale works correctly.
- Rogue path allowlist uses shell `case` statements with glob patterns -- fully POSIX, no external deps.
- Branch ancestry uses `git merge-base --is-ancestor develop HEAD` -- fast, portable, available in all git versions >= 1.8.0.
- Check scans staged content via `git show ":$file"` not working tree, so it validates what will actually be committed.

**Cross-platform gotchas:**
- `grep -P` is GNU-specific. BSD grep (macOS) doesn't support it. But git hooks run via git's bundled bash on all platforms, which ships GNU grep. Documented this limitation.
- `\x00-\x7f` hex range in bracket expressions (without -P) matches everything in C locale on git-bash -- broken. Must use -P flag for reliable hex matching.
- CRLF in test repos causes warnings but doesn't affect test correctness.

**Performance:**
- Branch ancestry check: ~2ms (single git plumbing command)
- ASCII check: <10ms for typical staged .ps1 files (pipes through grep)
- Rogue path check: <5ms (pure shell pattern matching)
- Total hook overhead for clean commit: ~20ms (well under 100ms goal)

---

## Sprint 9-10 entries (summary)

- **2026-05-16 -- Issue #227: Timestamp .bak backups (both platforms).** Replaced single `.bak` with timestamped pattern (`.bak.YYYYMMDD-HHMMSS`); newest-wins restore via `Get-ChildItem | Sort-Object LastWriteTime -Descending` / `ls -t`. Legacy `.bak` fallback preserved for backward compat.
- **2026-05-16 -- Sprint 10 PR for #271: Uninstall core.hooksPath scope mismatch.** Install set `core.hooksPath` at `--global` scope; uninstall tried to unset at `--local` -> orphan. Fix: scope parity (both `--global`). Root cause: scope inheritance trap in git config. Tests confirm idempotent uninstall.
- **2026-05-16 -- Sprint 9 PRs #266 + #269: HooksPath docs + .bak rotation + pipefail fix.** PR #266: README + CONTRIBUTING explain hooksPath model. PR #269: .bak rotation (timestamped) + pipefail fix in uninstall.sh (was masking failures in pipeline chain). Doc batch fact-check caught real bugs pre-merge (autocrlf in #267, pipefail in #269).
- **2026-05-17 -- PR #275: PowerShell .gitattributes CRLF rule (#231).** Added `*.ps1 text eol=crlf` to .gitattributes -- PS 5.1 strict-mode parser is sensitive to LF endings in certain script forms. Symmetric with `*.sh text eol=lf` rule.

## 2026-05-17 -- Sprint 11 (formerly Sprint T) Issue #233: docs(hooks) PSScriptAnalyzer advisory-only intent

**Branch:** `squad/233-pssa-advisory-docs`
**PR:** (pending push)
**Status:** Docs-only change; PSSA logic already advisory (`|| true` on inner pwsh call, line 51)

### What I did

- `hooks/pre-push`: Added a 14-line comment block (lines 29-43) above the PSSA section
  explaining advisory-only intent. Three reasons codified: (1) availability gap on hosts
  without pwsh + PSGallery access, (2) subjective rules like PSAvoidUsingWriteHost are
  style not bugs, (3) blocking would require version pin + cmdlet allowlist out of scope.
  Practical implication noted: `|| true` is load-bearing, do not remove. No env var
  opt-in to strict mode exists; flagged as potential future feature.
- `CONTRIBUTING.md`: Added "Why is PSSA advisory in `pre-push`?" subsection (3 bullet
  list) under existing "Installing PSScriptAnalyzer locally (optional)" block. Mirrors the
  inline rationale and points readers back to the inline comment so the `|| true` is
  not "fixed" away by well-meaning contributors.
- `CHANGELOG.md`: Two entries in `[Unreleased]` `### Changed` for the pre-push comment
  block and the CONTRIBUTING subsection, both closing #233.

### Confirmation: PSSA logic was already advisory

Verified `hooks/pre-push:51` ends with `|| true` and the surrounding `echo` on
line 49 already says `(advisory)`. The Group L test suite in
`tests/test_windows_setup.ps1` (L-1 through L-5) and `Tpp5` in
`tests/test_precommit_hygiene.sh` already enforce the advisory contract
(no `exit 1` on PSSA lines; pre-push exits 0 on feature branches even with .ps1 staged).
Therefore: NO behavior change in this PR, NO follow-up issue required.

### Validation

- `git diff --stat`: 3 files, +25/-1 lines.
- All Group L test invariants preserved: `command -v pwsh` still present, `Invoke-ScriptAnalyzer`
  still present, `Get-Module.*PSScriptAnalyzer` still present, no comment line contains both
  `PSScriptAnalyzer` and `exit 1`, shebang remains `#!/bin/sh`.
- Comment block sized at 14 lines (within 8-15 budget from task spec).

### Key learnings

- When the intent IS already implemented correctly but undocumented, the cheap fix is
  always an inline comment block adjacent to the load-bearing line. Future contributors
  who see `|| true` and think "bug" need the comment within eyeshot, not three docs away.
- README/CONTRIBUTING already said "advisory, never blocks" but never said WHY. The why is
  what prevents tightening. Always document the rationale, not just the behavior.

### Sprint 12 (Wave 1): Legacy priority label cleanup (issue #254)

**Context:** Issue #254 -- delete legacy `priority: high/medium/low` labels (with spaces) that
predated the canonical `priority:p0..p3` taxonomy. Reassigned from Mickey to Pluto since
this is config-engineering work (label inventory + workflow files).

**Pre-deletion audit:**
- Confirmed all three legacy labels existed (`gh label list --limit 100`).
- Confirmed canonical `priority:p0`, `priority:p1`, `priority:p2`, `priority:p3` all in place.
- Verified ZERO OPEN issues/PRs used legacy labels. 18 CLOSED issues (chip era: #178-194)
  had used them, but closed issues retaining history was acceptable per task scope (the
  explicit gate was `any OPEN issue/PR`).
- Grepped `.github/`, `.squad/`, `CONTRIBUTING.md`, `README.md`, issue templates for any
  references. Only matches were historical (a retro doc + decisions.md prose using
  `Priority: HIGH` as a severity ranking, NOT label names).
- Verified `.github/workflows/sync-squad-labels.yml` is additive-only (no delete pass) and
  defines PRIORITY_LABELS as p0/p1/p2 only -- does NOT reference legacy labels, so deletion
  is safe from auto-recreation.

**Deletion:** `gh label delete "priority: high" --yes` (and medium/low). All three confirmed
removed. Post-delete label list shows only `priority:p0..p3`.

**Side observation (out of scope, flagged for follow-up):** `sync-squad-labels.yml`
PRIORITY_LABELS list is missing `priority:p3` -- the label exists in the repo but the
workflow will not re-sync it if deleted. Not in scope for #254 (which is removal-only) but
worth tracking. `priority:p3` was likely added manually after the workflow was written.

**Takeaway -- label hygiene SOP:**
1. ALWAYS audit BEFORE delete: `gh label list --limit 100` (default limit 30 lies),
   `gh issue list --label "X" --state open` (not `--state all`), `gh pr list --label "X"`.
2. Grep the repo for the label name in workflows, issue templates, CONTRIBUTING, README,
   and `.squad/`. A label that is mechanically defined in a workflow will silently auto-
   recreate after manual deletion -- must be removed at the source.
3. Closed-issue history loss is acceptable if the canonical taxonomy supersedes it.
   Open-issue label loss is NOT -- would orphan triage signal.
4. Captured this pattern in `.squad/skills/label-hygiene/SKILL.md` for the team.

**PR:** #315 (filed end-of-session).
