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

> Compressed 2026-05-17 per #319. Older entries summarized; full pre-Sprint-11 history at history-archive.md.

## Recent Work (pre-Sprint-11 summary)

Full detail in `history-archive.md`. Highlights:

- **2026-04-19 to 2026-05-04** Sprint 6 / 7 lead reviews: PR #145 (sentinel strip+re-inject for #144), PR #146 REJECTED (3 CI failures), PR #149 PSScriptAnalyzer pre-push hook (advisory only), #138 dual-path profile fix, #151 docs approval, #160 gcm/gcb AllScope alias bug, PR #169 (curl.exe), PR #170 (`ep` alias, two-pass review), PR #175/#176 + plan approvals.
- **2026-05-14 to 2026-05-16** PS 5.1 compat sprint: PR #198 (psmux skip-with-warning + profile diagnostics, #197), PR #200 merge gate (PS 5.1 test coverage + ASCII-safety skill), Batch 1/4/5 reviews (PRs #202-#210 across multiple waves), #222 retroactive 0.1.0-0.7.0 tag discipline.
- **2026-05-16 to 2026-05-17** Squad upgrade + retros: 0.9.4 upgrade audit (PR #262 -- rogue-file bug + git-workflow SKILL overwrite risk noted), Sprint 8-hotfix retro authored, Sprint 9 retro action items (PR #274), pwsh-lastexitcode skill authored for Sprint 11 (PR for #288), Sprint review batch learnings, Issue #239 (E2E install) framed and filed.

Lessons preserved verbatim in Learnings section above (CI=true, BOM-encoding gotcha, worktree isolation, commit-msg merge bypass, hire pattern for Doc, etc.).

---

## Sprint 11 entries (summary)

- **2026-05-17 -- pwsh-lastexitcode skill (PR for #288).** Authored `.squad/skills/pwsh-lastexitcode/SKILL.md` documenting the `$LASTEXITCODE` propagation anti-pattern across `&` boundaries; added CONTRIBUTING "PowerShell Exit Code Discipline" section + audit of `scripts/windows/`. 5 unmitigated sites flagged in setup.ps1/auth.ps1 (deferred to Goofy #292).
- **2026-05-19 -- Design pass PR for #289 + #290.** Single PR for Doc subagent worktree pattern (Option B: dedicated `..\dev-setup-doc` worktree) and Jiminy auto-dispatch (Option A: 3-surface checklist in charter + loop.md + ceremonies.md). Replaces dual-fold-PR pattern from Sprint 10 (#281+#283).
- **2026-05-19 -- ARCHITECTURE.md refresh (PR for #229).** Synced file tree (added lib/ dirs, uninstall.*, auth.ps1, dotfiles.ps1, .tool-versions, .gitattributes); refreshed workflows/hooks/tests lists; added new sections (Tool Version Pinning, Git Hooks, CI Workflows, Squad Roster). Held back Linux-only Dependency Order (Windows version became #310) and Script Conventions prose (became #309).
- **2026-05-20 -- Sprint rename Tier 3 sweep (chore/sprint-naming-convention).** 21 files, 6 categories. Mapping: Q->8-hotfix, R->9, S->10, T->11, U->12. Aliasing convention: `Sprint N (formerly Sprint X)` first-occurrence-per-file. PR #308 merged after Doc fact-check verdict "Verified".

## Sprint 12 entries (summary, except final release cut)

- **2026-05-17 -- PR #308 merge + Sprint 12 backlog.** PR #308 (Tier 3 rename) merged after Doc fact-check; 21 files, 297+/189-. Doc caught CHANGELOG `[0.8.0]` missing `(formerly Sprint Q)` alias (fixed via folded commit). Sprint 12 backlog: 7 inherited P3 + 2 new (#309, #310). Label gotcha: `area:scripts` does not exist (only 6 area labels: ci, hooks, windows, macos, linux, meta).
- **2026-05-17 -- PR #314 ARCHITECTURE Script Conventions rewrite (#309).** Replaced obsolete "copy from setup.sh/setup.ps1" advice with explicit named lib files (`scripts/linux/lib/log.sh`, `scripts/windows/lib/logging.ps1`, etc.) plus copy-paste loading patterns. Documented bash subshell-vs-PowerShell dot-source asymmetry. Version-pin pattern made canonical (read-tool-version.sh / Get-ToolVersion). Held back #310 Windows Dep Order to Wave 2.
- **2026-05-17 -- PR #321 Wave 2: Windows orchestrator Dependency Order (#310).** Added `### Windows orchestrator chain` subsection under existing `## Dependency Order`. 12-step chain documented verbatim from setup.ps1 Main() (Install-Git through Install-GitHook). Style: ASCII `->` arrows (defensive even though hook only enforces ASCII on `*.ps1`). Caught 3 stray U+2014 em-dashes pre-commit. Filed File-Structure-tree-stale follow-up (still shows auth.ps1 at scripts/windows/ root).
- **2026-05-17 -- PR #324 Wave 3: README refresh (#306).** GitHub auth blockquote names both auth.sh + auth.ps1; Repo Structure tree adds auth.ps1/dotfiles.ps1/uninstall.ps1 with corrected file count (9->11); `.tool-versions` example reflects all 7 pins; `.squad/` tree expanded; Contributing section names 9-agent roster + cross-links. CWD-pin discipline applied throughout (lesson from #310 violation).

## 2026-05-17 -- 0.9.2 release cut (Sprint 12 wrap)

Cut 0.9.2 from `release/0.9.2` (develop @ `5e0fb53`). Folded [Unreleased] -> [0.9.2] in CHANGELOG, harvested Ralph's Sprint 12 EOS hygiene tail (~50 lines) from main checkout into release worktree. Sprint 12 ships 9 issues across 10 PRs in a 3-wave doc-quality sweep. Three releases this session: 0.9.0 (Sprint 9+10), 0.9.1 (Sprint 11 architecture), 0.9.2 (Sprint 12 doc-quality). Identical flow each: release branch from develop -> PR to develop (CHANGELOG fold) -> coordinator merges develop -> main (REGULAR merge) -> tag bare X.Y.Z on main -> `gh release create --target main`.

**Worktree-isolation lesson:** My #310 PR earlier this sprint violated CWD-pin discipline and triggered cross-worktree write contamination (caught by Jiminy audit). Wave 3 #306 corrected the protocol: `Set-Location -LiteralPath` + path-mismatch guard at top of every powershell call, plus absolute path prefixes on every file write. Codified in Sprint 12 retro + every Mickey dispatch brief.
**Job ends here:** Coordinator merges this release/0.9.2 -> develop PR, then opens develop -> main with regular merge, tags  .9.2, and runs gh release create --target main. I do not touch main or tag anything.


## 2026-05-17 Sprint 13 Wave 1 (#325, #326)

Shipped two narrow doc fixes batched into one PR on `squad/325-326-doc-fixes` (off develop @ 38e9c79):

- **#325 ARCHITECTURE.md auth.ps1 path:** corrected both stale references (file-structure tree ~L54 and team-ownership map ~L505) from `scripts/windows/auth.ps1` to `scripts/windows/tools/auth.ps1`. Annotated the tree entry with `(moved from top-level in PR #297)` so the move is discoverable. Verified zero remaining `scripts/windows/auth.ps1` matches in the file.
- **#326 README.md hooks count:** verified `hooks/` directory contents (commit-msg, pre-commit, pre-push, prepare-commit-msg = 4 files) before editing. Changed `three hooks are active` -> `four hooks are active` and inserted a `prepare-commit-msg` subsection between `commit-msg` and `pre-push`, describing the merge/revert subject rewrite behaviour (sourced from the hook's own header comment). PR #212 reference included in CHANGELOG.

Both issues were originally surfaced as out-of-scope observations in my own Sprint 12 Wave 3 #306 history entry -- the filed issues paid off this sprint with a single small PR.

**CWD-pin protocol:** verified pre-edit; every powershell call prefixed by `Set-Location -LiteralPath` + drift guard. All edits used absolute worktree path prefix. Post-commit main-checkout audit clean.

**Files touched:** ARCHITECTURE.md (2 lines), README.md (2 chunks), CHANGELOG.md (+2 Unreleased/Fixed entries), .squad/agents/mickey/history.md (this entry), .squad/decisions/inbox/mickey-w1-2026-05-17-issues-325-326.md (new).

**Skill-pattern note:** "batch narrow doc fixes into one PR" -- 2nd application (Sprint 12 also did this). Not formalizing yet; one more application next sprint would justify a skill drop.
