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

## [2026-05-18] Sprint 11 (formerly Sprint T) -- Issue #230: Move auth.ps1 under tools/ (Wave 1)

**Branch:** `squad/230-auth-to-tools`
**Status:** PR open

### Background

After PR #195's per-tool refactor, `scripts/windows/auth.ps1` was the lone
top-level installer left at `scripts/windows/`. Issue #230 (P2 chore) called
for relocating it under `tools/` to match the established layout.

### What I did

- `git mv scripts/windows/auth.ps1 scripts/windows/tools/auth.ps1` (git
  reports 96% similarity, rename history preserved).
- Updated the dot-source path inside `auth.ps1` from
  `\lib\logging.ps1` to `\..\lib\logging.ps1`
  to match the pattern used by every other `tools/*.ps1` script. Also
  updated the file's header comment to reflect the new path. No logic
  changes; `Invoke-GhAuth` body is byte-identical.
- `scripts/windows/setup.ps1` line 34: updated dot-source from
  `\auth.ps1` to `\tools\auth.ps1`.
- `tests/test_windows_setup.ps1` line 1195 (Group S setup): added
  `tools` segment to `Join-Path` chain.
- CHANGELOG.md: added an `[Unreleased]` `### Changed` entry.

### Files I did NOT touch

- **ARCHITECTURE.md** -- no auth.ps1 reference present anyway, and Mickey
  owns the file in concurrent worktree #229. Confirmed clean grep.
- **CHANGELOG.md line 76** -- historical entry under 0.8.0 ("Windows
  GitHub auth step via scripts/windows/auth.ps1 (closes #191)") is a
  historically accurate description of the original add and must remain
  pinned to the path at the time. New `[Unreleased]` entry documents
  the move.
- **auth.ps1 function body** -- the four `& gh ...` `0`
  read-without-reset sites flagged in the pwsh-lastexitcode SKILL are
  out of scope for this issue. Wave 2 (#292) handles that hardening.

### Verification

- `Test-Path scripts/windows/tools/auth.ps1` -> True
- `Test-Path scripts/windows/auth.ps1` -> False
- PowerShell parser: all three modified files parse cleanly
- Dot-source from new location succeeds; `Invoke-GhAuth` function defined
- Full `tests/test_windows_setup.ps1` run: Group S 3/3 PASS; 114 total
  PASS, 8 baseline FAIL (Group O alias / live Copilot) -- identical to
  `develop` baseline, unrelated to this change

### Wave 2 queued

- **#292** -- harden the 4 `0` sites in `auth.ps1` plus
  any in `setup.ps1` (per pwsh-lastexitcode SKILL). Next task.

## [2026-05-19] Sprint 11 -- Issue #292: Harden $LASTEXITCODE at 5 sites (Wave 2)

**Branch:** `squad/292-lastexitcode-hardening`
**Status:** PR open
**Predecessor:** Sprint 11 Wave 1 (Issue #230, PR #297 -- moved auth.ps1 to tools/)

### Background

PR #291 (Mickey) created `.squad/skills/pwsh-lastexitcode/SKILL.md` documenting
5 unmitigated `$LASTEXITCODE` leak sites. Wave 1 (PR #297) moved auth.ps1 under
`tools/`; this Wave 2 applies the canonical mitigation pattern at all 5 sites.

### What I did

Applied `$global:LASTEXITCODE = 0` reset after each expected-failure native
command, matching the canonical pattern from `uninstall.ps1:117-125`:

1. `scripts/windows/tools/auth.ps1` -- 4 sites (2x `gh auth status`, 2x `gh api user`)
2. `scripts/windows/setup.ps1` -- 1 site (`git rev-parse` in `Install-GitHook`)

Added Group EE tests (EE-1 through EE-5) in `tests/test_windows_setup.ps1`:
static source assertions confirming each site has the reset within proximity
of the native call.

Updated `.squad/skills/pwsh-lastexitcode/SKILL.md` audit table -- all 5 sites
now marked as mitigated.

### Files Modified

- `scripts/windows/tools/auth.ps1` -- 4 `$global:LASTEXITCODE = 0` lines added
- `scripts/windows/setup.ps1` -- 1 `$global:LASTEXITCODE = 0` line added
- `tests/test_windows_setup.ps1` -- Group EE (5 tests)
- `.squad/skills/pwsh-lastexitcode/SKILL.md` -- audit table updated
- `CHANGELOG.md` -- Fixed entry added
- `.squad/agents/goofy/history.md` -- this entry

### Key Pattern

The canonical mitigation (from SKILL.md and uninstall.ps1):
```powershell
& <native-command> ...
if ($LASTEXITCODE -eq 0) { ... }
else { ... }
$global:LASTEXITCODE = 0   # reset after classification
```

Must use `$global:LASTEXITCODE` (not local `$LASTEXITCODE = 0` which only
shadows the automatic variable).


### Sprint 12 Wave 2 -- #235 install-guard deferral (Case B, 2026-05-17)

**Reassigned from Mickey** mid-sprint to fit my cross-platform scripts lane.
Investigated, applied the dispatch decision flow's Case B (helper does not exist;
only proposed), closed the issue as `not planned`. No code changes, no PR.

**Investigation summary:**
- Searched `scripts/lib/`, `scripts/{linux,windows}/lib/`, both `setup.{sh,ps1}`,
  and every `scripts/{linux,windows}/tools/*` for `install-guard` /
  `Install-Guard` / `is_installed` / `Test-IsInstalled` / `IsInstalled`.
  Zero hits in code. Only mentions are in Mickey's history (V-8 audit, 2026-05-16)
  and the Sprint 11 retro.
- Mapped the current "already installed?" idioms across ~12 tool scripts and
  found three distinct shapes (simple presence, version-pinned regex, composite
  presence + secondary probe). A premature helper would either undercover or
  over-engineer.

**Threshold rule formalized (Case B closure note):** revisit when 3+ tools
sharing a single check shape land (e.g., 3+ version-pinned tools using
`Read-ToolVersion`). Until then, the inline idiom plus `Read-ToolVersion.ps1` /
`read-tool-version.sh` is the canonical pattern -- already documented in
CONTRIBUTING.md "Tool Version Pin Enforcement".

**Files touched in worktree (NOT committed -- per Case B "no PR" instruction):**
- `.squad/decisions/inbox/goofy-install-guard-deferral-20260517.md` -- decision drop
- `.squad/agents/goofy/history.md` -- this entry

**Worktree status:** branch `squad/235-defer-install-guard` has zero commits.
Worktree `C:\Users\Earl Tankard\Coding\dev-setup-235` is safe to remove. No
remote-branch cleanup needed (the branch was created locally and never pushed).
Coordinator/Scribe should harvest the two `.squad/` files above into the main
checkout before `git worktree remove` runs, or they will be lost.

**Coordination notes:**
- Mickey (working on #310, ARCHITECTURE.md Windows Dep Order): no overlap --
  I did not touch ARCHITECTURE.md.
- Donald (working on #237, CONTRIBUTING.md test harness): no overlap --
  I did not touch CONTRIBUTING.md. Future deferral revisit may add a brief
  note under "Tool Version Pin Enforcement" but only when the 3-site threshold
  is met, which is post-Sprint 12.

**Skill candidate noted:** "abstraction-threshold" rule (the 3-site shared-pattern
test) is potentially reusable beyond this issue. Did NOT formalize as
`.squad/skills/abstraction-threshold/SKILL.md` yet -- one application is not
enough to confirm. Will lift to a skill the next time we defer a premature
helper for the same reason (e.g., a future "shared CLI auth helper" or "shared
PATH-refresh helper" deferral). At that point the pattern earns `low` confidence.

## 2026-05-17 Sprint 13 Wave 2 -- Issue #322 part A: ASCII sweep all .md files

- Scope: 163 .md files scanned; 124 edited; 2,501 non-ASCII chars replaced.
- Outside fenced code blocks: 0 remaining (verified). Inside fences: ~1,686 preserved intentionally (tree diagrams, raw-byte tables, code samples that need literal glyphs).
- Tool: scripts/lib/ascii-sweep.py -- preserves ``` and ~~~ fences; maps em/en dashes, smart quotes, arrows, math ops, box-drawing (U+2500..U+257F), status emoji, and circled digits to ASCII. Rerunnable + idempotent.
- Biggest offenders: .squad/decisions-archive.md (359), .github/agents/squad.agent.md (315), .squad/templates/squad.agent.md (293), .squad/agents/mickey/history-archive.md (177).
- Intentional preservation: code fences (per repo policy). Checkmarks U+2705 -> [x], crosses U+274C -> [ ] across team.md and status tables to preserve task-list semantics.
- Coordinated with Mickey (parallel worktree, hooks/pre-commit patch -- Issue #322 part B). No overlap; only CHANGELOG.md is a predicted rebase conflict (Changed vs Fixed sections).
- Lessons: fence-aware sweep is essential -- naive global replace would mangle ARCHITECTURE.md tree diagrams. Script generalizable -> candidate skill if applied a second time.
