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

**Sprints 1-8 Summary (2026-04-07 to 2026-05-04):**

Implemented Windows PowerShell setup, utility alias framework, and architectural refactors:

- **Sprints 1-4:** Root setup.ps1 OS detection, scripts/windows/setup.ps1 core setup, 5 Install-* functions (Git, Uv, Nvm, GhCli, CopilotCli), utility aliases (ta, tt, tls, tks, gpl, ggsls), Remove-Item guards for PS 5.1 AllScope conflicts
- **Sprint 5:** PS 5.1 source-level guards (`Test-Path Variable:IsWindows`), vim PATH refresh after winget, empty catch block pattern (Write-Verbose), UTF-8 em-dash removal
- **Sprint 6:** curl.exe / wget.exe alias bypass, ep alias for profile editor, Remove-Item guard on profile ops
- **Sprint 7:** Git hooks implementation, PS variable guard regressions fixed (reverted to PSVersion pattern)
- **Sprint 8 (Gap Audit):** Refactored monolithic setup.ps1 (451 lines) into 9 per-tool files under tools/ (git, uv, nvm, gh, vim, psmux, copilot, squad-cli, profile); orchestrator reduced to 76 lines; highest-leverage refactor

**Key Patterns Established:**
- Always use `$PSScriptRoot` (not `$MyInvocation.MyCommand.Path` -- null in hosted contexts)
- PSVersion-based guards (ONLY safe for PS 5.1 strict mode): `$PSVersionTable.PSVersion.Major -ge 6 -and $IsVariable` -- RHS never evaluated on PS 5.x
- AllScope alias override: Must `Remove-Item -Force Alias:\name` before `Set-Alias -Force` (all 11 PS 5.1 conflicts: rm, gc, gl, gcm, gcb, gp, grb, grs, ni, h, ep)
- Strip+re-inject for config blocks: Never skip if sentinel present (breaks incremental updates); always strip old + inject fresh
- Empty catch blocks: Use `Write-Verbose` (satisfies PSScriptAnalyzer PS3109 requirement; provides debug logging without breaking idempotency)
- curl.exe / wget.exe: Always use explicit .exe in PowerShell scripts (bypass alias resolver to real Win32 binary)
- Dot-source tool files in orchestrator: `. "$PSScriptRoot\tools\*.ps1"` with relative paths works correctly via `powershell -File`

**Key Files:**
- `scripts/windows/setup.ps1` -- 76-line orchestrator (was 451)
- `scripts/windows/tools/*.ps1` -- 9 per-tool files (install functions + Write-PowerShellProfile)
- `tests/test_windows_setup.ps1` -- 61 tests, 11 groups (A-L)
- `.squad/agents/goofy/history.md` -> split off highest-leverage learnings to this Core Context

**Tech Decisions:**
- winget as sole Windows package manager (covers all required tools)
- npm-dependent tools (squad-cli) skip+warn if npm absent (don't force Node install)
- Dual-profile approach: PS 5.1 (`WindowsPowerShell/`) + PS 7+ (`PowerShell/`) both updated
- Nested Join-Path for PS 5.1: 2-arg syntax only (no array join)

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- CP1252 encoding trap: Em dash U+2014 encodes as UTF-8 E2 80 94; byte 0x94 is RIGHT DOUBLE QUOTATION MARK in CP1252; PS 5.1 treats as string terminator -- always use ASCII hyphen in literals
- Invoke-Expression for function loading: Load at Group scope before Test-Scenario; `& ([scriptblock]::Create(...))` creates child scope where functions vanish
- PSScriptAnalyzer PS3109: Empty catch blocks forbidden; Write-Verbose satisfies requirement
- PSUseSingularNouns: PowerShell cmdlets/functions MUST use singular nouns (Install-GitHook not Install-GitHooks)
- When refactoring variable names, grep tests for old names -- static-analysis tests break silently
- Set-Alias -Force insufficient for AllScope aliases -- must Remove-Item first
- Registry SetEnvironmentVariable for PATH persists across terminal sessions: `[System.Environment]::SetEnvironmentVariable('PATH', ..., 'User')`
- Em dash fix pattern (PR #198): When PS 5.1 CI fails with TerminatorExpectedAtEndOfString, scan ALL .ps1 files on the branch for non-ASCII (bytes > 0x7F). Replace em dashes and other non-ASCII with ASCII equivalents in both comments and string literals. Use a byte-level scan (not just grep) to catch multi-byte UTF-8 sequences.

---

## Recent Work

> Compressed 2026-05-17 per #319. Older entries summarized; full pre-Sprint-11 history at history-archive.md.

## Recent Work (pre-Sprint-9 summary)

Full detail in `history-archive.md`. Highlights:

- **2026-04-18 to 2026-04-19** Issue #132 regression fixes (PR #133), Issue #144 sentinel strip+re-inject pattern (PR #145).
- **2026-05-14 to 2026-05-16** AllScope alias override verification (Groups N, O, P), Issue #197/#198 em-dash fix + ASCII-only enforcement, Issue #226 winget exit-code assertion, Issue #179 psmux winget package ID fix.
- **2026-05-16 to 2026-05-17** Post-Sprint Windows/PS audit, Issue #180 Windows dotfiles installer, #190 .tool-versions pinning, #201 nvm LTS + squad-cli bootstrap, #186 shared logging helpers, #251 session PATH refresh after winget, audit-finding verification deep-dive, PR template + hygiene checklist (retro action), Issue #221 nvm.ps1 lib path off-by-one, PR #245 / PR #257 revisions for e2e assertions.

Lessons preserved verbatim in Learnings section above (CP1252 trap, AllScope alias guards, Assert-LastExit pattern, etc.).

---

## Sprint 9-10 entries (summary)

- **2026-05-16 -- Sprint 9 (PR #268): Winget exit-code assertion (#226).** Added `Assert-LastExit` helper to `scripts/windows/lib/logging.ps1`; wrapped every winget install call. Pattern: winget can exit non-zero on benign cases (already-installed, no-update-available); helper classifies via known-good exit codes (0, -1978335189). Group X collision with Chip #267 (renamed Chip's group to Y).
- **2026-05-17 -- Sprint 10 (PR for #255): Silent version drift (`.tool-versions`).** Created `Read-ToolVersion.ps1` + `read-tool-version.sh` cross-platform pair. Refactored nvm.ps1 + nvm.sh to read pinned version from `.tool-versions`. Added test_tool_versions.sh for verification. Authored `.squad/skills/tool-version-pin-enforcement/SKILL.md`. Audit logged unmitigated drift sites for follow-up.
- **2026-05-18 -- Sprint 10 revision (PR #282): Copilot package name + pin (P0 BLOCKER).** GitHub Copilot CLI is a Node npm package (`@github/copilot`), not a winget package -- prior winget install path was a no-op. Switched Windows to `npm install -g`. Researched + pinned. Refactored install logic across both platforms. Constraint: copilot-cli requires Node 22+ (drove #252 nodejs bump).

---

> Re-compressed 2026-05-17 (W2 fold) per #319 gate. Sprint 13+ entries kept verbatim; older summarized.

## Sprint 11-12 entries (summary)

- **2026-05-18 -- Sprint 11 Wave 1 (PR #297, issue #230): moved `scripts/windows/auth.ps1` -> `scripts/windows/tools/auth.ps1`** via `git mv` (96% similarity, rename preserved). Fixed dot-source path `\lib\logging.ps1` -> `\..\lib\logging.ps1` to match tools/ pattern. Updated `setup.ps1:34` dot-source + `tests/test_windows_setup.ps1` Group S setup Join-Path. CHANGELOG entry added. `Invoke-GhAuth` body byte-identical. Group S 3/3 PASS, full suite 114 PASS + 8 unrelated baseline FAIL. Did NOT touch ARCHITECTURE.md (Mickey owned #229 in parallel worktree) nor the 4 `$LASTEXITCODE` leak sites (deferred to Wave 2). CHANGELOG.md:76 historical 0.8.0 entry left pinned.
- **2026-05-19 -- Sprint 11 Wave 2 (PR for #292): hardened `$LASTEXITCODE` at 5 sites** per the `pwsh-lastexitcode` SKILL.md authored by Mickey in PR #291. Applied `$global:LASTEXITCODE = 0` reset (canonical pattern from `uninstall.ps1:117-125`) after each expected-failure native command: 4 sites in `scripts/windows/tools/auth.ps1` (2x `gh auth status`, 2x `gh api user`) + 1 site in `scripts/windows/setup.ps1` (`git rev-parse` in `Install-GitHook`). Added Group EE (EE-1..EE-5) static-source assertion tests. Updated SKILL.md audit table -- all 5 sites mitigated. Must use `$global:LASTEXITCODE` (not local `$LASTEXITCODE = 0` which only shadows the automatic var).
- **2026-05-17 -- Sprint 12 Wave 2 #235 install-guard deferral (Case B, NOT_PLANNED).** Reassigned from Mickey mid-sprint. Searched `scripts/lib/`, `scripts/{linux,windows}/lib/`, both `setup.{sh,ps1}`, and every tool script for `install-guard` / `Install-Guard` / `is_installed` / `Test-IsInstalled` / `IsInstalled` -- zero code hits (only Mickey-history mentions). Mapped current "already installed?" idioms across ~12 tool scripts: 3 distinct shapes (simple presence, version-pinned regex, composite presence+probe) -- premature helper would undercover or over-engineer. Closed as `not_planned` with Case B flow (no code, no PR). **Threshold rule formalized:** revisit when 3+ tools share a single check shape (e.g., 3+ version-pinned tools using `Read-ToolVersion`). Inline idiom + `Read-ToolVersion.ps1` / `read-tool-version.sh` remains canonical (documented in CONTRIBUTING.md "Tool Version Pin Enforcement"). Worktree `dev-setup-235` had zero commits, branch never pushed. **Skill candidate noted:** "abstraction-threshold" rule (3-site shared-pattern test) -- did NOT formalize (one application insufficient); lift to skill on next deferral.

## 2026-05-17 Sprint 13 Wave 2 -- Issue #322 part A: ASCII sweep all .md files

- Scope: 163 .md files scanned; 124 edited; 2,501 non-ASCII chars replaced.
- Outside fenced code blocks: 0 remaining (verified). Inside fences: ~1,686 preserved intentionally (tree diagrams, raw-byte tables, code samples that need literal glyphs).
- Tool: scripts/lib/ascii-sweep.py -- preserves ``` and ~~~ fences; maps em/en dashes, smart quotes, arrows, math ops, box-drawing (U+2500..U+257F), status emoji, and circled digits to ASCII. Rerunnable + idempotent.
- Biggest offenders: .squad/decisions-archive.md (359), .github/agents/squad.agent.md (315), .squad/templates/squad.agent.md (293), .squad/agents/mickey/history-archive.md (177).
- Intentional preservation: code fences (per repo policy). Checkmarks U+2705 -> [x], crosses U+274C -> [ ] across team.md and status tables to preserve task-list semantics.
- Coordinated with Mickey (parallel worktree, hooks/pre-commit patch -- Issue #322 part B). No overlap; only CHANGELOG.md is a predicted rebase conflict (Changed vs Fixed sections).
- Lessons: fence-aware sweep is essential -- naive global replace would mangle ARCHITECTURE.md tree diagrams. Script generalizable -> candidate skill if applied a second time.

## Sprint 19

- **2026-05-18 -- Sprint 19 (PR #419, issue #416): pre-commit history.md size gate.** Added Check 7 to hooks/pre-commit: rejects staged .squad/agents/*/history.md blobs > 15360 B, warns > 14336 B. 29/29 tests pass (3 new Check 7 cases). Updated SKILL.md with Layered enforcement section + corrected Check 4 -> Check 7 reference.
