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

---

> Re-compressed 2026-05-17 (W2 fold) per #319 gate. Sprint 13+ entries kept verbatim; older Sprint 11/12 entries condensed.

## Recent Work (pre-Sprint-11 summary)

Full detail in `history-archive.md`. Highlights: Sprint 6/7 lead reviews (PRs #145, #146 REJECTED, #149 PSScriptAnalyzer pre-push, #138, #160 AllScope, #169, #170, #175/#176); Sprint 8 PS 5.1 compat (PRs #198, #200 merge gate + ASCII-safety skill, batch reviews #202-#210, #222 tag discipline); Sprint 8h/9/10 squad upgrade + retros (0.9.4 audit PR #262 rogue-file bug + git-workflow SKILL overwrite risk, Sprint 8h/9 retros, PR #274, pwsh-lastexitcode skill PR #288, #239 E2E filed). Lessons preserved verbatim in Learnings (CI=true, BOM gotcha, worktree isolation, commit-msg merge bypass, Doc hire pattern).

## Sprint 11-12 entries (summary)

- **2026-05-17 -- pwsh-lastexitcode skill (PR for #288).** Authored `.squad/skills/pwsh-lastexitcode/SKILL.md` documenting `\0` propagation anti-pattern across `&` boundaries; added CONTRIBUTING "PowerShell Exit Code Discipline" + audit. 5 unmitigated sites flagged in setup.ps1/auth.ps1 (deferred to Goofy #292).
- **2026-05-19 -- PR for #289 + #290.** Single PR for Doc subagent worktree pattern (Option B: dedicated `..\dev-setup-doc`) + Jiminy auto-dispatch (Option A: 3-surface checklist). Replaces dual-fold pattern from Sprint 10 (#281+#283).
- **2026-05-19 -- ARCHITECTURE.md refresh (PR for #229).** Synced file tree (lib/, uninstall.*, auth.ps1, dotfiles.ps1, .tool-versions, .gitattributes); refreshed workflows/hooks/tests; added Tool Version Pinning, Git Hooks, CI Workflows, Squad Roster sections. Held back Linux-only Dep Order (->#310) and Script Conventions (->#309).
- **2026-05-20 -- Sprint rename Tier 3 sweep (PR #308).** 21 files, 6 categories. Q->8-hotfix, R->9, S->10, T->11, U->12. Aliasing: `Sprint N (formerly Sprint X)` first-occurrence-per-file. Merged after Doc fact-check "Verified". Doc caught CHANGELOG [0.8.0] missing `(formerly Sprint Q)` alias (folded fix). Label gotcha logged: `area:scripts` doesn't exist (6 area labels only).
- **2026-05-17 -- PR #314 ARCH Script Conventions rewrite (#309).** Replaced obsolete "copy from setup.sh/setup.ps1" advice with explicit named lib files + copy-paste loading patterns. Bash-subshell vs PowerShell-dot-source asymmetry documented. Version-pin pattern canonical (read-tool-version.sh / Get-ToolVersion).
- **2026-05-17 -- PR #321 Wave 2: Windows orchestrator Dep Order (#310).** Added `### Windows orchestrator chain` under `## Dependency Order`. 12-step chain from setup.ps1 Main(). ASCII `->` arrows. Caught 3 stray U+2014 em-dashes pre-commit. Filed File-Structure-tree-stale follow-up.
- **2026-05-17 -- PR #324 Wave 3: README refresh (#306).** GitHub auth blockquote names auth.sh + auth.ps1; Repo Structure tree adds auth.ps1/dotfiles.ps1/uninstall.ps1 (count 9->11); .tool-versions example covers 7 pins; .squad/ tree expanded; 9-agent roster named. CWD-pin discipline applied throughout (lesson from #310 violation).
- **2026-05-17 -- 0.9.2 release cut (Sprint 12 wrap).** Cut from release/0.9.2 (develop @ 5e0fb53). Folded [Unreleased] -> [0.9.2], harvested Ralph EOS tail. Sprint 12: 9 issues, 10 PRs, 3-wave doc-quality sweep. Three releases this session (0.9.0, 0.9.1, 0.9.2) -- identical flow: release branch from develop -> PR to develop (CHANGELOG fold) -> coordinator merges develop->main (REGULAR) -> tag X.Y.Z on main -> `gh release create --target main`. **Worktree-isolation lesson:** my #310 PR violated CWD-pin discipline (Jiminy caught contamination). Wave 3 #306 corrected: `Set-Location -LiteralPath` + path-mismatch guard + absolute path prefixes everywhere. Codified in Sprint 12 retro + Mickey dispatch brief.


## 2026-05-17 Sprint 13 Wave 1 (#325, #326)

Shipped two narrow doc fixes batched into one PR on `squad/325-326-doc-fixes` (off develop @ 38e9c79):

- **#325 ARCHITECTURE.md auth.ps1 path:** corrected both stale references (file-structure tree ~L54 and team-ownership map ~L505) from `scripts/windows/auth.ps1` to `scripts/windows/tools/auth.ps1`. Annotated the tree entry with `(moved from top-level in PR #297)` so the move is discoverable. Verified zero remaining `scripts/windows/auth.ps1` matches in the file.
- **#326 README.md hooks count:** verified `hooks/` directory contents (commit-msg, pre-commit, pre-push, prepare-commit-msg = 4 files) before editing. Changed `three hooks are active` -> `four hooks are active` and inserted a `prepare-commit-msg` subsection between `commit-msg` and `pre-push`, describing the merge/revert subject rewrite behaviour (sourced from the hook's own header comment). PR #212 reference included in CHANGELOG.

Both issues were originally surfaced as out-of-scope observations in my own Sprint 12 Wave 3 #306 history entry -- the filed issues paid off this sprint with a single small PR.

**CWD-pin protocol:** verified pre-edit; every powershell call prefixed by `Set-Location -LiteralPath` + drift guard. All edits used absolute worktree path prefix. Post-commit main-checkout audit clean.

**Files touched:** ARCHITECTURE.md (2 lines), README.md (2 chunks), CHANGELOG.md (+2 Unreleased/Fixed entries), .squad/agents/mickey/history.md (this entry), .squad/decisions/inbox/mickey-w1-2026-05-17-issues-325-326.md (new).

**Skill-pattern note:** "batch narrow doc fixes into one PR" -- 2nd application (Sprint 12 also did this). Not formalizing yet; one more application next sprint would justify a skill drop.

## 2026-05-17 Sprint 13 Wave 2 -- Issue #322 part B: pre-commit ASCII glob extension (catch-up, post-dogfood)

Shipped PR #334 extending hooks/pre-commit Check 2 from .ps1 only to .ps1|.md|.sh. Test harness grew T2c/T2d/T2e/T2f (26/26 PASS). Coordinated with Goofy's parallel part A (.md content sweep, PR #335) -- predictable CHANGELOG section conflict (Changed vs Fixed) resolved at rebase as planned.

**Dogfood incident (healthy):** my own new hook BLOCKED staging this very history.md entry because the file carried 60 pre-existing non-ASCII bytes from earlier sprints. Correct behavior -- the rule is rule. Deferred the hygiene-tail append into a follow-up after Goofy's sweep cleaned the file. Captured the deferral in .squad/decisions/inbox/mickey-w2-2026-05-17-hook-extension.md and in the PR body's Deferred Items section.

**Skill candidate noted:** ship-test + eat-dogfood (your own enforcement catches your own legacy debt on first run) -- 1st clean application of the pattern; watch for second.

This catch-up entry was appended by Jiminy as part of the Sprint 13 Wave 2 post-batch audit, with my PR #334 body as the source of truth (per Jiminy auto-fix charter). All content ASCII-clean by construction.
