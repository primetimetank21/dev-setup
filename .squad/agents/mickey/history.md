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

## Sprint 11-13 entries (summary)

- **2026-05-17 -- pwsh-lastexitcode skill (PR for #288).** Authored `.squad/skills/pwsh-lastexitcode/SKILL.md` documenting `\0` propagation anti-pattern across `&` boundaries; added CONTRIBUTING "PowerShell Exit Code Discipline" + audit. 5 unmitigated sites flagged in setup.ps1/auth.ps1 (deferred to Goofy #292).
- **2026-05-19 -- PR for #289 + #290.** Single PR for Doc subagent worktree pattern (Option B: dedicated `..\dev-setup-doc`) + Jiminy auto-dispatch (Option A: 3-surface checklist). Replaces dual-fold pattern from Sprint 10 (#281+#283).
- **2026-05-19 -- ARCHITECTURE.md refresh (PR for #229).** Synced file tree (lib/, uninstall.*, auth.ps1, dotfiles.ps1, .tool-versions, .gitattributes); refreshed workflows/hooks/tests; added Tool Version Pinning, Git Hooks, CI Workflows, Squad Roster sections. Held back Linux-only Dep Order (->#310) and Script Conventions (->#309).
- **2026-05-20 -- Sprint rename Tier 3 sweep (PR #308).** 21 files, 6 categories. Q->8-hotfix, R->9, S->10, T->11, U->12. Aliasing: `Sprint N (formerly Sprint X)` first-occurrence-per-file. Merged after Doc fact-check "Verified". Doc caught CHANGELOG [0.8.0] missing `(formerly Sprint Q)` alias (folded fix). Label gotcha: `area:scripts` doesn't exist (6 area labels only).
- **2026-05-17 -- PR #314 ARCH Script Conventions rewrite (#309).** Replaced obsolete "copy from setup.sh/setup.ps1" advice with explicit named lib files + copy-paste loading patterns. Bash-subshell vs PowerShell-dot-source asymmetry documented. Version-pin pattern canonical.
- **2026-05-17 -- PR #321 W2 Windows Dep Order (#310).** Added `### Windows orchestrator chain` (12-step setup.ps1 Main()). ASCII `->` arrows. Caught 3 stray U+2014 em-dashes pre-commit. Filed File-Structure-tree-stale follow-up.
- **2026-05-17 -- PR #324 W3 README refresh (#306).** Auth blockquote names auth.sh + auth.ps1; Repo Structure tree adds auth.ps1/dotfiles.ps1/uninstall.ps1 (9->11); .tool-versions example covers 7 pins; .squad/ tree expanded; 9-agent roster named. CWD-pin discipline applied (lesson from #310 violation).
- **2026-05-17 -- 0.9.2 release cut (Sprint 12 wrap).** Release/0.9.2 (develop @ 5e0fb53). Folded [Unreleased] -> [0.9.2]. 9 issues, 10 PRs, 3-wave doc-quality sweep. Three releases (0.9.0/0.9.1/0.9.2) identical flow: release branch -> PR to develop -> coordinator merges develop->main REGULAR -> tag X.Y.Z on main -> `gh release create --target main`. **Worktree-isolation lesson:** #310 PR violated CWD-pin (Jiminy caught contamination); W3 #306 corrected via `Set-Location -LiteralPath` + drift guard + absolute path prefixes; codified in Sprint 12 retro + Mickey dispatch brief.
- **2026-05-17 -- Sprint 13 W1 (PR for #325, #326).** Two narrow doc fixes batched on `squad/325-326-doc-fixes` (off develop @ 38e9c79). #325 fixed stale `scripts/windows/auth.ps1` -> `scripts/windows/tools/auth.ps1` in ARCH tree + ownership map (annotated PR #297 move). #326 fixed README hooks count three->four; inserted `prepare-commit-msg` subsection. Both originated in my own Sprint 12 W3 #306 observations -- file-and-fix loop paid off. CWD-pin protocol verified pre-edit on every powershell call. Skill-pattern note: "batch narrow doc fixes" = 2nd application.
- **2026-05-17 -- Sprint 13 W2 (PR #334, #322 part B).** Extended hooks/pre-commit Check 2 from .ps1 only to .ps1|.md|.sh. T2c-T2f added (26/26 PASS). Coordinated with Goofy parallel part A sweep (PR #335) -- CHANGELOG Changed-vs-Fixed conflict resolved at rebase as planned. **Dogfood incident (healthy):** new hook BLOCKED staging history.md (60 pre-existing non-ASCII bytes from earlier sprints). Correct behavior; rule is rule. Append deferred until Goofy sweep cleaned the file; captured in inbox + PR Deferred Items. **Skill candidate:** ship-test + eat-dogfood (own enforcement catches own legacy debt) -- 1st clean application; watch for 2nd.
- **2026-05-17 -- 0.9.3 release fold (Sprint 13 wrap).** [Unreleased] -> [0.9.3] - 2026-05-17 -- Sprint 13: Documentation accuracy and ASCII policy hardening. 8 entries (1 Added, 4 Changed, 3 Fixed). Theme: doc accuracy (#325, #326) + ASCII policy hardening (#322A sweep + #322B hook extension). Sprint 13 retro authored separately by Scribe (PR #339 post-tag -> Sprint 14 W1 fold; see below).
- **2026-05-17 -- Sprint 14 W1 (PR for #343 CHANGELOG editorial).** Resolved Jiminy EOS CONCERN: Scribe PR #339 retro pointer landed in `[Unreleased]` AFTER 0.9.3 was tagged at edc67e2 while prior convention (Sprint 11 under [0.9.1], Sprint 12 under [0.9.2]) places retros under their own sprint's release section. Chose Option A: retroactive fold into `[0.9.3] ### Added` with annotation; 0.9.3 tag stays immutable; edit rides next regular develop->main. Codified in `.squad/decisions/changelog-retro-placement.md`: (1) fold post-tag retros, (2) never re-tag, (3) Lead owns call at EOS, (4) batch drops, (5) preferred Sprint dispatch sequences retro PR BEFORE release-cut. **Pattern formalized:** "post-tag retro fold". Watch Sprint 14 wrap.

## 2026-05-17 Sprint 14 Wave 1.5 -- Issue #342: README refresh applying Doc audit

Applied Doc's README fact-check audit (`.squad/decisions/doc-readme-audit-2026-05-17.md`, 8 findings: 3 HIGH, 2 MEDIUM, 3 LOW) on `squad/342-readme-edit` (off develop @ 234ee08). Ordering was load-bearing: **F3 first** -- the README's file-tree fenced block carried 645 non-ASCII bytes (box-drawing glyphs U+251C / U+2502 / U+2514 / U+2500 + em dashes U+2014) that Sprint 13's pre-commit Check 2 (#322B / PR #334) would block on any subsequent stage. Goofy's ascii-sweep.py (#322A) preserves fenced code by design and does NOT clean these, so hand-conversion was mandatory. Did the conversion via a PowerShell substitution table (multi-char swaps first: `[U+251C][U+2500][U+2500]` -> `+--`, `[U+2514][U+2500][U+2500]` -> `\--`, then standalones), wrote back via `[System.IO.File]::WriteAllText` with ASCII encoding, verified 0 non-ASCII before layering F1/F2/F4/F5.

F1 rewrote `### pre-commit` from a single shellcheck one-liner to the 6 ordered hygiene checks straight from the hook's own header comment (#322B scope-extension callout embedded in Check 2). F2 added a dedicated "ASCII sweep helper" subsection with `--dry-run` usage + the fenced-code preservation caveat. F4 added `ascii-sweep.py` to the `scripts/lib/` tree as the new last entry (`\--`). F5 expanded the pre-commit one-liner in the `hooks/` tree to "6-check hygiene gate ... see Git Hooks below". LOW findings: F6 (per-OS `lib/` subdirs) skipped -- README runs coarser than ARCHITECTURE.md; F7 (develop/main commit refusal) covered inside the new F1 bullet 5; F8 ("nine agents") explicitly NOT changed to 10 per Doc's verified-against-`.squad/team.md` verdict.

**Files touched:** README.md (645 non-ASCII -> 0; size 11015 -> 13039 B), CHANGELOG.md (+1 [Unreleased] ### Changed bullet), this history (Sprint 13 + Sprint 14 W1 entries compressed to dated bullets per history-compression skill; new W1.5 entry appended).

**Pattern note:** "audit-then-edit" handoff (Doc audits on dedicated branch; Mickey applies on its own branch) is now 2nd application after Sprint 13 #322B coordination with Goofy. **F3-first ordering** (clean non-ASCII inside fenced blocks BEFORE any other README edit) is the specific gotcha to remember -- ascii-sweep.py won't help; the pre-commit hook scans the full staged content regardless of fences.

**ASCII discipline:** every file write went through `[System.IO.File]` + ASCII encoding + byte-scan verify before stage. CWD-pin re-checked before every write (worktree `dev-setup-342`).