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

## Core Context

**Sprints 1-7 Summary (2026-04-07 to 2026-05-04):**

Lead architect; established foundational team process, architecture, and Windows/Linux integration across 7 sprints.

- **Sprint 1-4:** OS detection entry points (setup.sh Unix, setup.ps1 Windows); router pattern; full directory structure; 6 core tool scripts; dotfile templates; GitHub Actions workflows
- **Sprint 5:** Issue #54-#57 process items; bin cleanup; `exec 2>&1` stderr/stdout merge; devcontainer CRLF guard; CI=true Copilot CLI bypass
- **Sprint 6:** Windows regression tests (15 tests, Groups A-D); alias consolidation & parity; dual-profile PowerShell (PS 5.1 + PS 7+); alias guards for AllScope conflicts (11 aliases: rm, gc, gl, gcm, gcb, gp, grb, grs, ni, h, ep)
- **Sprint 7:** Git hooks (commit-msg Conventional Commits, pre-push branch protection + shellcheck), branch isolation rule, CI triage, PS 5.1 compatibility fixes
- **Sprint 8 (Gap Audit):** 26-item audit -> 17 issues (#178-#194); Windows setup split into per-tool files under tools/; highest-leverage refactor completed

**Key Patterns Established:**
- `CI=true` for postCreateCommand: when CLI gates on `IsCI()`, set env var rather than PTY wrapping
- Empty catch blocks: use `Write-Verbose` for intentional silence (PSScriptAnalyzer requirement)
- PSVersion-based guards (ONLY safe pattern for PS 5.1 strict mode): `$PSVersionTable.PSVersion.Major -ge 6 -and $IsVariable`
- Strip+re-inject for evolving config blocks (sentinel-based skip breaks incremental updates)
- `--admin` merge workflow for single-user repos (standard, not override)
- Process: Frame issues as problems, not implementations; consult decisions.md before planning
- Retro loop works: action items from sprint N ship in sprint N+1

**Key Files/Decisions:**
- `.squad/decisions.md` -- canonical decisions; decisions/inbox/ for agent-written docs
- CONTRIBUTING.md -- branch isolation rule, direct-push policy, PS 5.x checklist, hook workflow
- .gitattributes -- eol=lf for *.sh; devcontainer CRLF strip guard
- hooks/ -- commit-msg (Conventional Commits), pre-push (branch protection + shellcheck + optional PSScriptAnalyzer advisory)

**Tech Debt Addressed:**
- Branch ancestry bleed (fixed via rule in Sprint 7)
- Stale CI failures on main (em-dash UTF-8 bug, historical artifacts)
- Windows/Linux parity (aliases, setup.ps1 split into tools/)

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- **squad upgrade rogue-file bug (0.9.4):** `squad upgrade` dumps template files at `.squad/` root that should only live in `.squad/templates/`. Compare root files against templates -- if identical or older, delete. The pre-commit hook allow-list catches these, but clean up before committing.
- **git-workflow SKILL.md overwrite risk:** Upgrade overwrites customized skills with the built-in generic version. The 0.9.4 version assumes a 3-branch model (dev/insiders/main) and removes our project-specific rules (merge gates, branch protection, Mickey approval requirement). Always diff after upgrade.
- **New workflows from upgrade may target the squad CLI's own release pipeline** (squad-promote, squad-release, squad-insider-release, squad-preview, squad-docs) -- these assume package.json publishing and branches that don't exist in consumer repos. Delete or don't ship unless the repo actually uses that pipeline.

- `git add --renormalize` updates INDEX only, not working tree
- `script -q /dev/null -c 'command'` for isatty()-gated CLIs (general pattern, deprecated for Copilot CLI)
- Branch protection write via `gh api` blocked by Codespace token scope -- manual UI required
- PR body linkage matters (Closes #X vs #Y)
- Test framework emoji ([x]/[ ]) vs brackets -- pre-existing, flagged for housekeeping
- BOM-encoding gotcha: PS 5.1 `Set-Content -Encoding UTF8` writes UTF-8 WITH BOM. POSIX sh hooks read BOM bytes as line content, breaking regex. Fix: use `-Encoding ASCII` for test temp files (see `.squad/skills/ps51-runtime-file-encoding/SKILL.md`)
- Worktree isolation: batch 3 used separate worktrees per PR. Zero bleed across 3 parallel PRs. CHANGELOG conflicts are expected and trivial to resolve (combine both [Unreleased] entries).
- commit-msg hook rejects merge commit messages (non-conventional format). Use `--no-verify` for merge commits during conflict resolution. This is fine.
- Filed #239 e2e install P0 -- Earl emphasized this is the safety net for what really works on fresh machines. Notes: psmux is the Windows tmux with `tmux` alias; squad CLI is verified with `squad --version`, not the npx path; nightly cron approved.
- 2026-05-16 Hired Doc (Fact Checker) per Earl's request after Sprint 8-hotfix (formerly Sprint Q) retro. Universe: Disney Classic. Auto-triggers on review/verify/fact-check/audit keywords. Closes the verifier/validator gap. Hiring pattern: branch from develop, create .squad/agents/{name}/ dir with charter.md + history.md, update registry.json (after last active non-exempt agent, before scribe), update team.md (same position), update routing.md (table row + issue label + new rule + multi-agent scenarios), update CHANGELOG.md [Unreleased], drop decision to .squad/decisions/inbox/mickey-{slug}.md (gitignored, don't stage). Voice considerations: personalize from character source (Seven Dwarfs Doc = methodical, glasses-on, "Let's see now..." -- kind corrections, not snark). Consider squad-hire-agent skill after 2+ hire patterns confirmed -- pattern is now repeatable (Jiminy was first; Doc is second).
- 2026-05-26 Issue #423: For bash-to-PowerShell parity utilities, keep the bash CLI surface but use native PowerShell JSON handling and a sibling test file when that preserves existing bash coverage. Also strip carriage returns from generated bash driver fixtures so pwsh-on-Linux test runs do not inject CRLF into shim scripts.
- 2026-05-27T02:56:53.258-04:00: #444 domain-aligned PR review model delegates single-domain approvals to Donald, Goofy, Pluto, Chip, and Doc; Mickey keeps governance, architecture, conflicts, and 3+ domain PRs.

---

> Re-trimmed 2026-05-27 per #450 gate. Sprints 1-17 fully archived to history-archive.md; Sprint 19+ retained here.

## Recent Work (pre-Sprint-19 summary)

Full detail in `history-archive.md`. Pre-Sprint-11 highlights: Sprint 6/7 lead reviews (PRs #145, #146 REJECTED, #149 PSScriptAnalyzer pre-push, #138, #160 AllScope, #169, #170, #175/#176); Sprint 8 PS 5.1 compat (PRs #198, #200 merge gate + ASCII-safety skill, batch reviews #202-#210, #222 tag discipline); Sprint 8h/9/10 squad upgrade + retros (0.9.4 audit PR #262 rogue-file bug + git-workflow SKILL overwrite risk, Sprint 8h/9 retros, PR #274, pwsh-lastexitcode skill PR #288, #239 E2E filed). Sprints 11-17: 0.9.2-0.9.7 releases, history-compression + inbox-routing skills, README/CHANGELOG editorial patterns, decisions.md gate fix. Lessons preserved verbatim in Learnings above.


<!-- Sprints 11-17 history archived to history-archive.md on 2026-05-27 -->

## Sprint 19 -- #414, #430

2026-05-18: Squad-spawn helper + lint-spawn-prompt backstop (PR #420). Added scripts/squad-spawn.{ps1,sh} (auto-inject hygiene tail, idempotent, {name}/{N}/{worktree-path} substitution) and scripts/lint-spawn-prompt.{ps1,sh} (6-marker scan, exit 0/1). .squad/skills/spawn-prompt-lint/SKILL.md added (medium confidence). routing.md updated with helper/linter enforcement paths. 20 tests (4 files x 5 cases). Root-cause fix for Sprint 18 #406/#407 fixup pattern.
2026-05-18: test_changelog_fold.ps1 CI fix (PR #431, #430). New-TestEnv now creates git sandbox with tag 0.9.7 for tag-resolution self-containment. Rejected fetch-tags in validate.yml -- hermetic test sandboxes preferred.


## 2026-05-18 03:09 (PR #433-fix, Issue #433)
- **Outcome**: Fixed test_changelog_fold sandbox CWD regression
- **Lesson**: Sandbox tests must run from a neutral CWD to reproduce CI's
  stateless environment. Don't rely on host worktree's git state.
  The cd '\' && prefix ensures bash inherits the sandbox's
  git repo rather than whatever CWD the test runner happens to be in.
- **Files**: tests/test_changelog_fold.ps1
- 2026-05-27 -- Grilled #441 profile-path plan (architecture lens). Verdict: REVISE ($PROFILE.CurrentUserAllHosts contradiction + scope mismatch).
- 2026-05-27 -- Reviewed PR #443 (chore/scribe grill-441 log). Verdict: APPROVE. .squad/** entries well-formed; flagged own history.md warn-zone for trim follow-up.
