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

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. CP1252 encoding trap + fix patterns.
! **LABEL HYGIENE:** `.squad/skills/label-hygiene/SKILL.md` -- audit-before-delete SOP. Always grep `.github/workflows/sync-squad-labels.yml` for the label name; if the workflow defines it, remove the definition or the label will auto-recreate on next push to `.squad/team.md`.

> Pre-Sprint-13 entries compressed 2026-05-17 (#319) and again 2026-05-17 (#347) per `.squad/skills/history-compression/SKILL.md`. Skill pointers + recurring-incident refs preserved verbatim. Sprint 14 W2/W3 entries archived to history-archive.md 2026-05-17.

## Pre-Sprint-13 work log (compressed)

- **2026-04-07 -- #10/#11/#8/#108** Dev Container + Codespace post-create, dotfile templates (`.gitconfig`, `.npmrc`, `.editorconfig`), shell alias first cut, PowerShell alias parity first cut (PR #115).
- **2026-04-08 -- #56 (worktree isolation)** `SQUAD_WORKTREES=1` env var; coordinator creates worktrees at `{repo-parent}/{repo-name}-{issue-number}`. Default-on in devcontainer.json. Full pattern in `.squad/skills/worktree-isolation/SKILL.md` + CONTRIBUTING "Parallel Agent Work". PR #58.
- **2026-04-12 -- #64** Managed-block append to `.zshrc`/`.bashrc` with sentinel markers `# --- dev-setup managed block ---`.
- **Sprint 6 / #108 f-up** PowerShell aliases completion; AllScope alias guards.
- **2026-04-XX -- #184 (gitconfig templates)** Git reads `.gitconfig` values as literal strings -- shell expansion `${EDITOR:-vim}` is NOT expanded. Rule: any tool-config template NOT processed by a shell at apply time must use literal values + override comment.
- **2026-05-16 audit** Configs/dotfiles/hooks lens; 9 findings; top 3: .ps1 CRLF in .gitattributes, `[[ ]]` POSIX compat in .aliases, PSScriptAnalyzer advisory mode in pre-push.
- **2026-05-16 -- Jiminy joins** Hygiene Auditor (process QA, not code review). See `.squad/agents/jiminy/charter.md`.
- **2026-05-18 -- #188 (PR #203)** Created CHANGELOG.md (Keep a Changelog format); backfilled 7 sprints from git log + `.squad/log/`.
- **2025-07-14 -- #192** Tmux auto-attach opt-in via `TMUX_AUTOSTART=1` guard; POSIX `[ "${VAR:-}" = "1" ]` pattern.
- **2026-05-16 -- #227** Timestamped `.bak.YYYYMMDD-HHMMSS` backups (both platforms); newest-wins restore; legacy `.bak` fallback preserved.
- **2026-05-16 -- Sprint 10 / #271** Uninstall `core.hooksPath` scope mismatch: install used `--global`, uninstall used `--local`. Fix: scope parity (both `--global`).
- **2026-05-16 -- Sprint 9 / PR #266 + #269** README + CONTRIBUTING hooksPath model; `.bak` rotation + pipefail fix in uninstall.sh (was masking pipeline failures).
- **2026-05-17 -- PR #275 (#231)** `*.ps1 text eol=crlf` in `.gitattributes` -- PS 5.1 strict-mode parser sensitive to LF in some script forms. Symmetric with `*.sh text eol=lf`.
- **2026-05-21 -- #249 (protected branch guard)** Added Check 5 to pre-commit: `git rev-parse --abbrev-ref HEAD` + case match on develop/main/master -> exit 1. Renumbered shellcheck to Check 6. 5 new test cases.
- **2026-05-21 -- #240 (pre-commit hygiene checks)** Checks ordered fastest-first; all HARD FAIL. `grep -nP '[^\x00-\x7f]'` for ASCII detection (requires GNU grep + PCRE, ships with git-bash). Do NOT set `LC_ALL=C` with `-P` on git-bash (breaks). Scans staged content via `git show ":$file"`.
- **2026-05-17 -- #233 (PSSA advisory docs)** 14-line comment block in `hooks/pre-push` above PSSA section explaining advisory-only intent (availability gap, subjective rules, scope). CONTRIBUTING "Why is PSSA advisory" subsection. Load-bearing `|| true` documented so future readers do not "fix" it away.
- **Sprint 12 W1 -- #254 (PR #315) legacy priority label cleanup (PRECEDENT for #347)** Deleted `priority: high/medium/low` (spaced legacy labels) after audit confirmed 0 open issues used them. Found `sync-squad-labels.yml` `PRIORITY_LABELS` missing `priority:p3` (label exists in repo but workflow will not re-sync if deleted). Captured pattern in `.squad/skills/label-hygiene/SKILL.md`. Same gap re-confirmed in #347.

---

## Sprint 14 W2/W3 (archived to history-archive.md 2026-05-17)

**Issues:** #347 (label taxonomy 45->32), #350 (sync-workflow follow-ups)

Summary: Label taxonomy cleanup completed (13 deletions, 3 renames). sync-squad-labels.yml gaps fixed (added priority:p3, PLATFORM_LABELS, removed dead hasCopilot code). Full details, methodology, and key learnings archived. Reference: `.squad/skills/label-hygiene/SKILL.md`.

---

## Sprints 16-19 (compressed 2026-05-27 per history-compression SKILL)

- 2026-05-27 #367 PR #368: skill-drift audit; 30 skills; 0 promotions; 27 zero-app; decisions drop pluto-skill-drift-2026-05-17.md
- 2026-05-27 #362 squad/362-ascii-docs-skill: ascii-docs-about-non-ascii SKILL.md; Unicode codepoint-name-only rule; 13-char mapping table; .copilot/skills/
- 2026-05-27 #364 squad/364-worktree-base-refresh-skill: worktree-base-refresh SKILL.md; stale-sprint recovery recipe; confidence low; detail in history-archive.md
- 2026-05-27 #383/#384 PR #386 @ 17c940b: worktree-remove-first high->medium; gh-pr-base-develop SKILL new; routing.md Spawn-Prompt Hygiene
- 2026-05-27 #398/#399 PR #402 @ a546421: history-md-pre-size-check SKILL (14336 B threshold); changelog-fold-completeness SKILL; both .copilot/skills/
- 2026-05-27 #417 PR #418: routing.md pre-spawn worktree clarification (2-3 lines); cross-ref worktree-isolation SKILL

---

## Sprint 20 -- Issue #441: v4 Architecture Grill

**Plan:** docs/plans/441-profile-path.md (v4, Jiminy revision)
**Date:** 2026-05-27
**Status:** Complete.

### v3 Blocking Regression Check

P1 (foreach stub empty): RESOLVED. Loop body now contains explicit strip code with
regex, Set-Content, and Write-Info log. No stub comment remains.

P2 (scope ambiguity): RESOLVED. Algorithm wrapped in Write-PowerShellProfile with an
explicit comment confirming dot-source does not execute resolution or writes.

### New Findings

A-1 [MEDIUM]: $ps51Fallback and $ps7Fallback referenced in Write-PowerShellProfile body
without being defined as parameters or local variables. Under Set-StrictMode -Version
Latest (active, production line 6) this throws VariableIsUndefined at runtime. Must be
defined as local constants at the top of the function before Resolve-ProfilePath calls
(consistent with production lines 17-19). Implementation note; no plan revision required.

A-2 [LOW]: Write-loop shown as comment stub pointing to "existing logic." Variable name
alignment ($profilePaths) is structurally correct; mutual exclusivity with legacy cleanup
verified. Documentation gap only.

A-3 [LOW]: Regex divergence between legacy cleanup strip and production writer-loop strip.
Missing \\r?\\n prefix before BEGIN marker; .+? vs .*?. May leave orphaned blank line
for non-end-of-file blocks. Post-#441 deferral acceptable.

A-4 [LOW]: No empty-$profilePaths guard; contingent on A-1 resolution (subsumed).

### Verdict: SHIP

Architecture is sound. One entry point, dot-source safe, idempotent, correct fallback,
mutually exclusive cleanup paths, clean mockability seam. No global-state leakage.
No conflict with production writer loop at lines 262-309.

Decision drop: .squad/decisions/inbox/pluto-441-v4-grill.md

---

## Sprint 20 -- Issue #441: v5.1 Architecture Grill (final)

**Date:** 2026-05-27 | **Verdict:** SHIP.

A-1 RESOLVED (H5+F-5): all four $local: vars defined at top of Write-PowerShellProfile,
values match production lines 12-13/17-18, no other StrictMode gaps. H1-H5/F-4/F-5 all
land correctly; no regressions, no scope leaks, no production global mutations.
PV-1 [LOW carry-over]: C-2/C-3 skip-as-pass (Chip NF-3v4); not blocking.

Decision drop: .squad/decisions/inbox/pluto-441-v5-grill.md

---

## Sprint 20 -- Issue #441: v5.2 Architecture Grill

**Date:** 2026-05-27 | **Verdict:** SHIP.

JN-1 RESOLVED: Mickey's `-Ps51Fallback`/`-Ps7Fallback` params fix the $local: shadow
bug I missed in v5.1. Parameters are optional with production-matching defaults; zero-arg
production call unchanged; test temp-path injection now works correctly. JN-2 RESOLVED
(Write-Warning applied). All BLOCKING/HIGH/MEDIUM items now closed.

PV-2 [INFO]: `Ps51`/`Ps7` casing non-idiomatic (vs `PS51`/`PS7`); harmless.
PV-3 [INFO]: GG-5 mock setup unspecified; implementer can infer; not a hole.

Lesson: I audited H5 in isolation in v5.1 but did not cross-check it against H3's
test-override language. The $local: shadow in test scope was a known PS scoping
subtlety -- I should have caught it. Applied here.

**PR:** #402 (squash-merged to develop @ a546421)
**Branch:** squad/398-399-skill-formalizations
**Status:** Complete.

Formalized two skills surfaced by Sprint 17 audit:

1. `.squad/skills/history-md-pre-size-check/SKILL.md` (8,283 B) -- mandatory pre-append size check at 14336 B threshold (90% of 15360 B hard gate). Recipe: `(Get-Item path).Length` measure -> compare -> compress via `history-archive.md` rotation if over -> then append. Cross-linked from `routing.md` Mandatory Hygiene Tail item 4 (PR #401).

2. `.copilot/skills/changelog-fold-completeness/SKILL.md` (9,751 B) -- pre-release CHANGELOG fold rule: enumerate ALL sprint PRs via `gh pr list --search 'merged:>SHA'` and ALL closed issues via `gh issue list --state closed --search "closed:>DATE"`; do NOT trust `[Unreleased]` section completeness. Recurring failure mode caught across Sprints 15/16/17 where only first-lander entry was captured.

Both SKILLs use YAML frontmatter (name/description/domain/confidence/source), Context, Recipe with PowerShell + bash snippets, Why-this-order rationale, real PR/SHA examples, Anti-Patterns, Related Skills, References. Meta-validation: this very append was pre-checked against the size-check skill being formalized.

**Lesson:** when formalizing a hygiene skill, eat your own dog food -- verify the very edit committing the skill follows the rule the skill teaches.
## Sprint 19 -- Issue #417: routing.md pre-spawn worktree clarification

**PR:** #418
**Status:** Complete.

Added 2-3 line clarification to routing.md "Pre-Spawn Worktree Creation" section: coordinators must pre-create N isolated worktrees BEFORE dispatching N parallel agents. Cross-references worktree-isolation SKILL (no duplication). Surfaces pattern already implicit in worktree-isolation/SKILL.md and issue-lifecycle.md.

- 2026-05-27 -- #441 -- formalized grill SKILL (.squad/skills/grill/SKILL.md). First formal capture of the adversarial plan-review ceremony. Canonical example: issue #441, Goofy plan + Mickey/Chip/Doc parallel grillers. Confidence: low.
Decision drop: .squad/decisions/inbox/pluto-441-v5.2-grill.md
