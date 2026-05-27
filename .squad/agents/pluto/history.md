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

## Sprint 16 W1 -- Issue #367: Skill drift watchlist audit

**Branch:** `squad/367-skill-drift-audit`
**PR:** #368
**Status:** Complete.

### What I did

Audited 30 .copilot/skills/ + 0 .squad/skills/ for confidence freshness, application counts, and graduation candidates. Extracted per-skill metadata via git log timestamps and grep scanning of .squad/agents/*/history.md.

**Findings:**
- 0 skills eligible for low->medium promotion
- 0 skills eligible for medium->high promotion
- 27 skills with zero observed applications (monitoring phase)
- 3 skills with unknown/inconsistent confidence frontmatter (cli-wiring, model-selection, personal-squad, nap)

**Methodology:** Extracted skill name (folder), confidence (frontmatter field), last update (git log -1 --format=%ai), and mention count (grep across agent history). Applied drift thresholds: low->medium if 3+ applications, medium->high if 5+ applications, stale if >90 days old + 0 mentions, never-applied if 0 mentions anywhere.

All 30 skills updated 2026-05-17 (fresh worktree) with high confidence (22 high, 2 medium, 3 low, 3 unknown). Most skills not yet deployed in active agent workflows; report recommends continued monitoring as history accumulates.

Audit feeds issue #366 (graduation audit) for executing actual promotions once thresholds met.

Decision drop: `.squad/decisions/pluto-skill-drift-2026-05-17.md`

---

## Sprint 16 W1 -- Issue #362: ascii-docs-about-non-ascii SKILL.md

**Branch:** `squad/362-ascii-docs-skill`
**Issue:** #362
**Status:** Complete.

Drafted and committed `.copilot/skills/ascii-docs-about-non-ascii/SKILL.md` formalizing the "self-documenting non-ASCII" discipline at medium confidence. The pattern: when any agent writes documentation about non-ASCII characters, they must reference the character by its Unicode codepoint name only (e.g., "em-dash U+2014") and never include the literal character anywhere in the committed file -- not in prose, not in parens, not in a code fence, not in a table column. The skill includes a full ASCII substitution mapping table covering 13 common characters and a pre-commit verification command. Confidence is medium because two independent incidents demonstrated the same failure mode: Sprint 14 #340 (Doc audit notes with literal arrow chars) and Sprint 15 #356/#359 (decision file for the ASCII sweep whose own mapping table contained the literal chars being mapped). Both required Coordinator recovery. The SKILL.md file itself was verified at 0 non-ASCII bytes before commit -- the skill must follow the rule it teaches. Skill placed in `.copilot/skills/` (not `.squad/skills/` as originally suggested) to match the existing 30-skill convention. Decision drop at `.squad/decisions/inbox/pluto-362-ascii-docs-skill.md`.

---

## Sprint 16 W1 -- Issue #364: worktree-base-refresh SKILL.md (detailed version in archive)

**Branch:** `squad/364-worktree-base-refresh-skill`
**Issue:** #364
**Status:** Complete.

Drafted and landed `.copilot/skills/worktree-base-refresh/SKILL.md` -- the first formal writeup of the stale-sprint-branch recovery pattern that surfaced in Sprint 15 PR #359. Skill documents branch-ancestry hook behavior, git reset --soft pitfalls, 3-phase recovery recipe, acceptance checks, and anti-patterns. Confidence set to low (1 application: Sprint 15 #359, recovery commit d3229c8). Will graduate to medium on second observation.

Full documentation archived to `.squad/agents/pluto/history-archive.md`.

Decision drop: `.squad/decisions/inbox/pluto-364-worktree-base-refresh.md`

---

## Sprint 17 W1 -- Issues #383 + #384: skill formalization wave

**PRs:** #386 (squash-merged to develop @ 17c940b)
**Status:** Complete.

Updated `worktree-remove-first` SKILL.md (confidence high->medium, harvest as primary ordering rationale, Sprint 15+16 citations). Created `gh-pr-base-develop` SKILL.md (new -- codifies --base develop rule from PR #368 incident). Updated `routing.md` with Spawn-Prompt Hygiene section.

---

## Sprint 18 W1 -- Issues #398 + #399: history-md-pre-size-check + changelog-fold-completeness SKILLs

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

---

## Team Update: 2026-05-27 -- Domain-Aligned PR Reviewers (Issue #444, PR #445)

**Status:** Pluto now authorized to approve PRs wholly within the dotfile configs/templates domain.

**What:** Implemented domain-aligned PR reviewers model to parallelize review and unblock the single-reviewer bottleneck on Mickey. Agents with domain expertise are now authorized to approve PRs that are wholly inside their review lane, with Mickey retained for governance, architecture, and cross-domain reviews.

**Pluto's domain:** dotfile configs, templates, and config defaults (dotfiles/*, template files, shell-specific config management)

**Operating rule:** Use `.squad/routing.md` as the source of truth for path-based PR review routing. Rejections follow the existing lockout rule: original author may not revise rejected artifact; next revision requires a different agent.

**Related:** PR #440 (idempotency fix) approved by Mickey; PR #445 implements the new model.
