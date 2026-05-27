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

> Re-compressed 2026-05-17 (W2 fold) per #319 gate. Sprint 13+ entries kept verbatim; older Sprint 11/12 entries condensed.

## Recent Work (pre-Sprint-11 summary)

Full detail in `history-archive.md`. Highlights: Sprint 6/7 lead reviews (PRs #145, #146 REJECTED, #149 PSScriptAnalyzer pre-push, #138, #160 AllScope, #169, #170, #175/#176); Sprint 8 PS 5.1 compat (PRs #198, #200 merge gate + ASCII-safety skill, batch reviews #202-#210, #222 tag discipline); Sprint 8h/9/10 squad upgrade + retros (0.9.4 audit PR #262 rogue-file bug + git-workflow SKILL overwrite risk, Sprint 8h/9 retros, PR #274, pwsh-lastexitcode skill PR #288, #239 E2E filed). Lessons preserved verbatim in Learnings (CI=true, BOM gotcha, worktree isolation, commit-msg merge bypass, Doc hire pattern).

## Sprint 11-13 entries

- 2026-05-17: Sprint 11-12 -- PRs #288 (pwsh-lastexitcode skill + CONTRIBUTING), #289/#290 (Doc worktree + Jiminy dispatch, replaces dual-fold), #229 (ARCH refresh: lib/, auth.ps1, .tool-versions), #308 (sprint rename T3: 21 files, Q->8h/R->9/S->10/T->11/U->12), #314 (Script Conventions rewrite), #321 (Windows Dep Order 12-step chain), #324 (README W3: 9->11 tree entries, 9 agents); 0.9.2 cut (9 issues, 10 PRs). CWD-pin lesson: #310 violated, #306 corrected, codified.
- 2026-05-17: Sprint 13 W1 -- #325/#326 doc fixes (ARCH auth.ps1 path, README hooks count three->four) batched off develop @ 38e9c79. W2 -- #322B pre-commit extended .ps1->.ps1|.md|.sh (26/26 PASS); dogfood incident: new hook blocked history.md staging (60 pre-existing non-ASCII bytes) -- correct behavior, append deferred.
- 2026-05-17: 0.9.3 release fold -- [Unreleased]->[0.9.3] (8 entries: 1 Added, 4 Changed, 3 Fixed). Scribe PR #339 retro landed post-tag -> Sprint 14 W1 fold.
- 2026-05-17: Sprint 14 W1 -- #343 CHANGELOG editorial: retroactive fold of Scribe retro (PR #339) into [0.9.3] ### Added; 0.9.3 tag immutable. Codified in `.squad/decisions/changelog-retro-placement.md`: fold post-tag retros, never re-tag, Lead owns call. Pattern: "post-tag retro fold".
- 2026-05-17: Sprint 14 W1.5 -- #342 README refresh on `squad/342-readme-edit`. **F3-first ordering critical:** 645 non-ASCII bytes in fenced file-tree block (box-drawing U+251C/U+2502/U+2514/U+2500 + U+2014 em-dashes); ascii-sweep.py skips fences by design; pre-commit scans full staged content regardless. Hand-converted to `+--` / `\--` ASCII patterns via PowerShell substitution table. Then F1 (6-check pre-commit table), F2 (ascii-sweep.py docs + --dry-run), F4 (tree entry), F5 (one-liner expanded). README.md: 11015->13039 B. CHANGELOG.md: +1 ### Changed. Every write: `[System.IO.File]` ASCII encoding + byte-scan + CWD-pin re-check.

## 2026-05-17 Sprint 14 wrap -- 0.9.4 release cut

6 issues shipped: #340 (history-compression skill formalized: confidence medium, 4-step heuristic, 13 KB target / 2 KB headroom / 15360 B hard gate), #341 (per-topic inbox routing skill formalized: confidence medium, routing decision tree, atomic-rm model, dual-model coexistence), #342 (README refresh, 5 Doc audit findings applied -- see W1.5 entry), #343 (CHANGELOG editorial: Sprint 13 retro folded retroactively into [0.9.3] via "post-tag retro fold" pattern), #347 (label taxonomy 45->32: drop 8 GH-default dupes + 4 stale version labels + 1 status label; rename area:* -> platform:*; 84 issues migrated), #350 (sync-squad-labels.yml: priority:p3 + platform:* added, dead hasCopilot code removed).

CHANGELOG [Unreleased] folded to [0.9.4] - 2026-05-17 (2 Added, 3 Changed). New empty [Unreleased] boilerplate at top. PR #1: release/0.9.4 -> develop (squash). Decision drop: `.squad/decisions/release-094-2026-05-17.md`. History compressed: Sprint 11-13 + W1.5 to dated bullets per history-compression skill.

Coordinator next: develop -> main (regular merge), tag 0.9.4 on main, `gh release create --target main`. Sprint 14 retro: dispatch before release-cut per `.squad/decisions/changelog-retro-placement.md` (fold post-tag retros pattern).

## 2026-05-17 Sprint 16 dispatch

Filed 6 GitHub issues for Sprint 16: #363 (Scribe decisions.md archival), #362/#364 (Pluto ascii-docs/worktree-base-refresh SKILL.md drafts), #367/#366 (Pluto skill drift + graduation audits), #365 (Mickey tag sanity). Proposed wave shape: Wave A (#363, #362, #364, #365 parallel) then Wave B (#367 -> #366 serialized). Decision drop: `.squad/decisions/inbox/mickey-s16-dispatch.md`.

## 2026-05-17 Sprint 16 wrap -- 0.9.6 release cut

6 issues closed: #362 (PR #369, ascii-docs-about-non-ascii SKILL.md, medium confidence), #363 (direct push 5f07514, decisions.md archival -- 1 stale entry moved, hard gate not met mid-sprint, follow-up #371), #364 (PR #370, worktree-base-refresh SKILL.md, low confidence), #365 (comment-close, tag sanity 14/14 pass), #366 (comment-close, skill graduation audit -- 0 candidates), #367 (PR #368, skill drift watchlist -- 30 skills audited, 0 graduations).

Forward-merge recovery context: PR #368 (skill drift audit) landed on main by mistake at 128218a. Forward-merged back to develop via merge commit d102a7c. develop is an ancestor of main; develop->main release merge brought main forward via regular merge PR #373 (merge commit 10d203f).

CHANGELOG [Unreleased] folded to [0.9.6] - 2026-05-17 (3 Added, 2 Changed). New empty [Unreleased] boilerplate at top. PR #372: release/0.9.6 -> develop (squash, merge commit 7172ae7). PR #373: develop -> main (regular merge, merge commit 10d203f). Tag 0.9.6 (bare X.Y.Z) at 38c0942. GitHub release: https://github.com/primetimetank21/dev-setup/releases/tag/0.9.6. Decision drop: `.squad/decisions/inbox/mickey-s16-wrap.md`.

## Sprint 17 Wave 1 -- #371

Issue #371: decisions.md hard gate policy review. decisions.md was 65,737 bytes, over the 51,200 byte (50 KB) hard gate. Chose Option 3+5 hybrid: per-sprint sub-folders with auto-archive on sprint wrap. Archived Sprint 12 decisions (2026-05-14 to 2026-05-16) to .squad/decisions/sprint-12.md (55,958 bytes) and Sprint 15 content (dispatch + retro) to .squad/decisions/sprint-15.md (3,337 bytes). decisions.md trimmed to Sprint 16+ content (7,228 bytes, PASS). Updated Jiminy charter (added decisions.md gate check) and Scribe charter (added sprint archival step 7). Decision drop: .squad/decisions/inbox/copilot-directive-20260517203933-decisions-gate-policy.md. PR: squad/371-decisions-gate -> develop.


## Sprint 17 release cut -- 0.9.7

Cut release/0.9.7 from develop@792646e. Folded [Unreleased] to [0.9.7] - 2026-05-17 (3 Added, 3 Changed, 1 Fixed) covering #371 #381 #382 #383 #384 (Sprint 17: Hygiene gate restoration + label automation + skill formalization). PR #393: release/0.9.7 -> develop (squash). PR #394: develop -> main (regular merge, fe83af3). Tag 0.9.7 bare at f596202. GitHub release: https://github.com/primetimetank21/dev-setup/releases/tag/0.9.7.

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
- 2026-05-27 -- Reviewed PR #443 (chore/scribe: grill session log for #441 orphan recovery). Verdict: APPROVE. All .squad/** entries well-formed; gate notice: mickey/history.md at 14794 B warn zone, trim pass warranted.
