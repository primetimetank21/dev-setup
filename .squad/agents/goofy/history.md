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
- Cross-platform parity audits apply to top-level `scripts/*.{sh,ps1}` utilities and every file in `tests/`, but not platform installers under `scripts/linux/` or `scripts/windows/`. For function-exporting PowerShell libs, parity smoke tests should dot-source the file and call the function, and skip cleanly when `pwsh` is unavailable.
- 2026-05-28 -- PR #462 grill (#451): parity count reached 9 pwsh vs 7 bash and T7 byte checks are PS 5.1-safe; trap spotted: T_C/T_D used non-zero instead of exact exit 2 validation contracts.
- 2026-05-28 -- PR #462 re-grill (#451): commit 93b339f tightened T_C to exit 2 plus missing-release-label text and T_D to exit 2 before the release:shipped- substring; verified PR-head pwsh test passes 9/0/0 in a clean worktree. Trap avoided: local dirty test file differed from PR head and failed unrelated dry-run/idempotency cases, so PR-head validation used a detached worktree.

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

## Sprint 11-20 entries (archived)

Sprints 11-20 moved to history-archive.md per hygiene gate 2026-05-27. Key patterns: AllScope alias guards, $LASTEXITCODE hardening, ASCII sweep automation, history.md size gates, cross-platform test patterns.

## 2026-05-28 -- Grill Panel: Issue #451 Vertical Slice Plan (Rounds 1-3)

- **Role:** Cross-platform reviewer (PS 5.1 + POSIX concerns)
- **R1 verdict:** APPROVE-WITH-CHANGES. Identified True PS 5.1 fragility (pre-existing code, acceptable for #451 scope). Flagged byte-read safety (OK), CRLF handling (OK), no PS 7+ features (OK). Deferred launcher byte-determinism question to R2 analysis.
- **R2 verdict:** APPROVE-WITH-MINOR-CAVEATS. Caveat: True undefined on PS 5.1 causes -not $null = $true, chmod fails silently on Windows. Acceptable (PS 5.1 is Windows-only). Offered two mitigation options; recommended clarifying comment or OS-platform check during impl.
- **R3 verdict:** APPROVE. Caveat fully addressed by plan v3 out-of-scope section + filed #461. Scope boundary clean; plan ready for implementation.
- **Key learning:** Cross-platform caveats should be explicitly acknowledged and tracked separately (#461) rather than blocking the implementation slice (#451). Deferred defensiveness improvements are sustainable when documented.

## 2026-05-28 -- PR #470: #468 Plan v2 (Grill Revision)

- **Role:** v2 author (Mickey locked out per reviewer protocol)
- **Commit:** 7e284de -- docs(plan): #468 v2
- **Findings addressed:** 12 (3 Duck, 3 Donald, 2 Chip, 4 synthesis)

## Learnings

- **Default order encoding:** Hardcoded arrays (bash DEFAULT_TOOLS, pwsh $DefaultTools) are the only safe mechanism for tool execution order. Filesystem scan is alphabetical and breaks implicit dependency chains (nvm before npm-tools, gh before auth). The array IS the opt-in gate.
- **Registry contract pick:** Chose explicit $ToolRegistry with 3-line extension pattern over auto-discovery. Reason: Windows tool files have no naming convention mapping filename -> function (Install-Git vs Invoke-GhAuth vs Write-PowerShellProfile). Auto-discovery would require a refactor that's out of scope.
- **Baseline fixture strategy:** Committed text files (tests/fixtures/baseline-tools-{platform}.txt) as the regression contract. Slice 0 captures them; Slice 1's first test diffs against them. This is the backward-compat enforcement that v1 lacked.
- **PowerShell grammar pick:** `-Only "a,b"` (quoted comma-string, [string] param type) over unquoted (becomes [string[]], allows -Only a -Only b which breaks comma-canonical rule) and double-dash (breaks tab-completion, not idiomatic PS). Split internally with .Split(',') -- parity with bash IFS split.

## 2026-05-30 -- Sprint 19: #468 Plan v12 Cross-Platform Syntax Regrill

- **Role:** Cross-platform reviewer (Goofy lane)
- **Verdict:** APPROVE (commit 8dfb9b4 vs f212ef1)
- **Duck finding addressed:** Windows npm-absent bullets at lines 793-796 now use correct PowerShell syntax (`-Only 'copilot'` / `-Only 'squad-cli'`) and correct Windows registry key (`copilot` not `copilot-cli`). Single-quote convention consistent with all `-Only '...'` usages.
- **Full sweep clean:** No Windows code/test blocks use `--only=` / `--skip=` Linux syntax. No Linux examples use PowerShell flags. Tool names consistent across platforms (Windows: `copilot`, Linux: `copilot-cli`).
- **Pre-existing non-blockers noted:** Grammar table (line 739) uses double-quote `-Only "a,b,c"` (valid PS, predates v12); prose line 803 omits quotes around `git-hook` in flowing text (predates v12, not a code block).

## 2026-05-30 -- Sprint 19: #468 Plan v14 Authoring (PowerShell Quoting Nits)

- **Role:** v14 author (nano-fix per Earl directive)
- **Source:** Doc-2 v13 fact-check findings on 2 pre-existing quoting nits from v5
- **Fixed line 831** (formerly ~815): `` `-Only git-hook` `` -> `` `-Only 'git-hook'` `` (bare token quoted)
- **Fixed line 1124** (formerly ~1108): `` `-Only "gh"` `` -> `` `-Only 'gh'` `` (double-quote -> single-quote)
- **Final sweep result:** All `-Only 'X'` / `-Skip 'X'` usages in Windows prose/tests use single-quote convention. Grammar table (lines 767-768) and Syntax Rules (line 778) and Summary synopsis (line 182) retain double-quote for spec-level comma-string syntax -- intentional (pre-doc grammar convention). Additional bare-token occurrences `` `-Skip winget-check` `` at lines 104-106 (v7 changelog) and 860 (foot-gun docs) noted and reported; NOT fixed per scope discipline (mandate was 2 lines only). `--only=` / `--skip=` usages confirmed Linux/bash contexts only.
- **Scope confirmation:** Surgical 2-line fix + author line + v14 changelog. No structural changes, no slice changes.

### Addendum (v14 Amend, 2026-05-30)

- **Amend SHA:** b5cb3dc (was fe8c3f1)
- **Scope expansion approved by Earl:** 3 bare `` `-Skip winget-check` `` occurrences (lines 104, 106, 860) -- same class as v14 nits, surfaced during v14 sweep and reported at the time.
- **Fixes:** Lines 104, 106 (v7 changelog) and 860 (foot-gun docs): `` `-Skip winget-check` `` -> `` `-Skip 'winget-check'` ``
- **Note:** Task brief said 4 occurrences; 3 actual occurrences existed. No 4th found.
- **Final sweep (post-amend):** All value-bearing `-Only`/`-Skip` in Windows prose/tests use single-quote convention. Grammar-spec double-quote forms remain intentional. `--only=`/`--skip=` all Linux/bash. Clean.
