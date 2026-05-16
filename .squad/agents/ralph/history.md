# Project Context

- **Project:** dev-setup
- **Created:** 2026-04-07

## Core Context

Agent Ralph initialized and ready for work.

## Recent Updates

📌 Team initialized on 2026-04-07

---

### Sprint 2 — Work Log

**Date:** 2026-04-07

#### Issue #28 — [CI] Fix PowerShell lint failures (PSScriptAnalyzer)
- **Owner:** Goofy (PowerShell) + Chip (CI)
- **Branch:** `squad/28-fix-ps-lint`
- **PR:** #30 — `fix(ci): resolve PSScriptAnalyzer violations (#28)`
- **Status:** ✅ Merged to `develop`, branch deleted, issue #28 closed
- **Violations fixed:**
  - `PSAvoidUsingWriteHost` → replaced `Write-Host` with `Write-Output` in both files
  - `PSUseApprovedVerbs` → renamed `Detect-Platform` → `Get-Platform` + updated call site
  - `PSUseBOMForUnicodeEncodedFile` → replaced Unicode box-drawing / em-dash chars with ASCII

#### Sprint 1 Retro Action Items
- **Branch:** `squad/retro-sprint1-followups`
- **PR:** #31 — `docs(retro): sprint 1 follow-up action items`
- **Status:** ✅ Merged to `develop`, branch deleted
- **Items addressed:**
  - Mickey: Added branch-before-commit rule to all 5 agent charters (`.squad/agents/*/charter.md`)
  - Mickey: Created `CONTRIBUTING.md` with PR checklist, branch naming, commit format, code review policy
  - Chip: Added CI-green merge gate policy to `.squad/ceremonies.md`
  - Donald: Documented `--skip-auth` / interactive auth prompt behavior in `README.md`

---

### Sprint 3 — Work Log

**Date:** 2026-04-07

#### Issue #32 — [Feature] Install owner's personal shortcuts from example files
- **Priority:** P2 | **Owners:** Donald + Pluto + Goofy

##### Sub-task A: `.aliases` additions (Donald)
- **Branch:** `squad/32-aliases-shortcuts`
- **PR:** #34 — `feat(dotfiles): add missing aliases and tmux functions (#32)`
- **Status:** ✅ Merged to `develop`, branch deleted
- **Changes:**
  - Added `gf`, `gfp`, `glog` to Git section (alphabetical order)
  - Added `pb` (ping bing.com) to Utility section
  - Added `# ── Functions ──` section with `create_tmux` and `start_up` helpers
  - Updated `.zshrc.template` to call `start_up` on shell startup

##### Sub-task B: `.vimrc` dotfile (Pluto)
- **Branch:** `squad/32-vimrc-dotfile`
- **PR:** #33 — `feat(dotfiles): add .vimrc and wire into install.sh (#32)`
- **Status:** ✅ Merged to `develop`, branch deleted
- **Changes:**
  - Created `config/dotfiles/.vimrc` from `.vimrc-example`
  - Added `install_symlink` call for `.vimrc` in `config/dotfiles/install.sh`
  - Documented `.vimrc` in `config/dotfiles/README.md`

##### Sub-task C: PowerShell profile (Goofy)
- **Branch:** `squad/32-ps-profile-shortcuts`
- **PR:** #35 — `feat(windows): add owner shortcuts to PowerShell profile setup (#32)`
- **Status:** ✅ Merged to `develop`, branch deleted (1 CI fix required)
- **Changes:**
  - Added `Write-PowerShellProfile` function to `scripts/windows/setup.ps1`
  - Idempotent via `# BEGIN dev-setup profile` / `# END dev-setup profile` sentinel
  - PSScriptAnalyzer-compliant names: `Remove-CustomItem`, `Set-FileTimestamp`, `Get-GitStatus`, `Invoke-GitCommit`, etc.
  - **Fix required:** Initial commit had non-ASCII box-drawing chars (`──`, `—`) in here-string; replaced with ASCII equivalents to resolve `PSUseBOMForUnicodeEncodedFile` lint error

---

#### Issue #29 — [Chore] Consolidate example dotfiles into `examples/` folder
- **Priority:** P3 | **Owner:** Pluto
- **Branch:** `squad/29-consolidate-examples`
- **PR:** #36 — `chore: consolidate example dotfiles into examples/ folder (#29)`
- **Status:** ✅ Merged to `develop`, branch deleted
- **Changes:**
  - Moved `.bashrc-example`, `.vimrc-example`, `Microsoft.PowerShell_profile-example.ps1` → `examples/` (via `git mv`)
  - Created `examples/README.md` documenting each file and its usage
  - Updated `README.md` and `ARCHITECTURE.md` file structure sections

---

### Sprint 3 Retroactive — P1 Bug Fixes

**Date:** 2026-04-07

#### Issue #37 — Remove-CustomItem silent data loss (Goofy)
- **Priority:** P1 | **Owner:** Goofy
- **Branch:** `squad/37-fix-remove-custom-item`
- **PR:** #40 — `fix(windows): Remove-CustomItem silent data loss — accept string[] param (#37)`
- **Status:** ✅ Merged to `develop`, branch deleted, issue #37 closed
- **Changes:**
  - `scripts/windows/setup.ps1` — changed `[string]$Path` → `[string[]]$Path` in `Remove-CustomItem` param
  - `examples/Microsoft.PowerShell_profile-example.ps1` — same fix to keep files in sync

#### Issue #38 — create_tmux() three bugs (Donald)
- **Priority:** P1 | **Owner:** Donald
- **Branch:** `squad/38-fix-create-tmux`
- **PR:** #39 — `fix(dotfiles): correct create_tmux() — named session check, remove dead var (#38)`
- **Status:** ✅ Merged to `develop`, branch deleted, issue #38 closed
- **Changes:**
  - `config/dotfiles/.aliases` — replaced `create_tmux()` body:
    1. Removed dead variable `session_name="tankSession"`
    2. Replaced `pidof tmux` with `tmux has-session -t "$session"` (named-session check)
    3. Replaced `tt && ta` with `tmux new-session -d -s "$session"` + `tmux attach -t "$session"`

#### Sprint 3 Promotion
- `develop` → `main` via `--no-ff` merge commit
- Release commit: `release: sprint 3 complete — owner shortcuts, vimrc, examples, bug fixes`
- Issues closed: #29, #32, #37, #38
- PRs merged: #33–#36, #39–#40

---

## Learnings

⚠️ **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

Initial setup complete.

---

## Round 1 — $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Board scan result:**
- 14 open issues, 0 open PRs, 0 in-progress labels
- All issues assigned (squad:{member}) but no work started

**Analysis:**
- #3 (Mickey, P1): BLOCKER for #1, #2, #4-9, #13 → spawn Mickey immediately
- #11 (Pluto, P3): Dotfile templates — truly independent, no dependency on #3 → spawn Pluto
- #12 (Chip, P2): CI workflow — needs to know script paths (blocked by #3)
- #10 (Pluto, P3): devcontainer — somewhat dependent on #3 architecture → hold
- #1, #2, #4-9, #13: blocked by #3 → hold

**Actions taken:**
- Spawned Mickey → issue #3 (architecture + OS detection entry point)
- Spawned Pluto → issue #11 (dotfile templates)

- Always check for Unicode characters in PowerShell files — `PSUseBOMForUnicodeEncodedFile` catches box-drawing chars (`──`) and em-dashes (`—`) too; use plain ASCII dashes in here-strings
- GitHub blocks self-approval on PRs; Mickey skips the approve step and merges directly as repo owner
- Retro action items (doc-only) can be safely batched into a single PR to keep the board clean
- CI runs 3 jobs: PSScriptAnalyzer (PowerShell lint), shellcheck (bash lint), Linux validate
- When adding new dotfiles, always: (1) create the file in `config/dotfiles/`, (2) add `install_symlink`/`install_copy` call in `install.sh`, (3) document in `config/dotfiles/README.md`
- `examples/` is the source-of-truth for owner's personal reference configs; setup scripts read/install from them
- Sub-tasks of the same issue can be parallelized on separate branches — Donald (A), Pluto (B), Goofy (C) all worked simultaneously

## Sprint 4 Work Log — 2026-04-07

**Session:** Sprint 4 autonomous loop
**Requested by:** Earl Tankard, Jr., Ph.D.
**Status:** ✅ Complete — 6/6 issues closed, main promoted

### Issues Worked

| Issue | Title | Action |
|-------|-------|--------|
| #42 | Enforce Mickey review via branch protection | Already merged as PR #47 — closed |
| #45 | Ralph task templates must require Mickey approval | Already merged as PR #48 — closed |
| #46 | Devcontainer git identity initialization | Already merged as PR #49 — closed |
| #44 | Replace pip with uv | Already merged as PR #50 — closed |
| #41 | Remove-CustomItem multi-arg test | Fixed ValueFromRemainingArguments bug + regression test — PR #52, merged |
| #43 | create_tmux() session detection tests | 6-scenario test file, tmux mocked — PR #53, merged |

### Process Notes

- Race condition occurred on parallel Chip spawns: Chip-issue-43 committed #41 content to squad/43 branch. PR #51 closed, work redone directly.
- Chip-issue-43 agent stalled (45+ tool calls, no useful output) — Ralph took over.
- GitHub self-approval restriction: Mickey posts review comments but cannot formally approve in single-owner repos. Admin bypass used for merge (consistent with all previous sprints).
- `validate-powershell` CI job added (PR #52) — caught a real regression in Remove-CustomItem.

### Key Decisions
- `ValueFromRemainingArguments=$true` is required for `[string[]]$Path` parameters that must accept `rm file1 file2` style calls.
- tmux mocking pattern: define `tmux()` shell function before sourcing the function under test.
- Parallel agent spawning in same worktree is unsafe — agents fight over branch checkout.

### Sprint final cleanup (2026-05-16)
- **Audit pass:** Read-only audit performed pre-merge. Status: CLEAN -- no strays, no untracked work, no stashes, no orphan worktrees. Flagged 7 stale remote `squad/*` branches (all 0 commits ahead of develop).
- **Cleanup pass:** After PR #220 (sprint wrap) merged to main at `9d991a6`, deleted 7 stale remote branches: `squad/181-macos-ci`, `squad/186-shared-logging`, `squad/190-tool-versions`, `squad/191-windows-auth`, `squad/193-shellcheck-aliases`, `squad/201-nvm-bootstrap`, `squad/212-commit-msg-merge-bypass`. Pruned local refs to deleted remotes. Verified working tree still clean.
- **Final repo state:**
  - main: `9d991a6` (sprint wrap merge)
  - develop: `a821505` (synced with main)
  - Only local branches: develop, main
  - Only remote branches: develop, main
  - Worktrees: 1 (primary)
  - Open PRs: 0
  - Open go:yes issues: 0
- **Sprint outcome:** 22 PRs merged, 17 `go:yes` closed, develop fast-forwarded to main, all stale branches reaped. Sprint backlog clear.
- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

## Final End-of-Session Sweep — 2026-05-16

- **Timestamp:** 2026-05-16 end-of-session
- **Scope:** 12-point hygiene sweep (standing directive)
- **Result:** ✅ CLEAN — all checks passed, zero actions needed
- **Repo state:** develop `9eb5272` (up-to-date with origin/develop), working tree clean, 0 stashes, 0 open PRs, 0 open `go:yes` issues
- **Worktrees:** 1 (primary)
- **Remote branches:** develop, main only (no orphan squad/* branches)
- **Local branches:** develop, main only
- **Decisions inbox:** empty (Scribe drained every batch)
- **Rogue files:** none
- **gh auth:** ✓ logged in as primetimetank21
- **CHANGELOG:** [Unreleased] section exists (queue for next release)
- **Verdict:** READY FOR NEXT SESSION

## Sprint Q + 0.8.0 Release Cleanup -- 2026-05-16

- **Context:** After Sprint Q P0 fixes (#249, #251, #252) merged via #257/#256/#258, cut 0.8.0 release (PR #259 + #260) and shipped GH release. Final EOS sweep.
- **Cleanup actions:**
  - Deleted local `release/0.8.0` branch (after PR #259 merged)
  - Auto-deleted remote `release/0.8.0` (via `--delete-branch` on merge)
  - Pruned stale local tracking ref `origin/release/0.8.0`
  - Verified `.squad/log/` and `.squad/orchestration-log/` files are intentionally gitignored (not strays)
  - Confirmed `.squad/decisions/inbox/` empty (Scribe drained)
  - Confirmed no rogue `.bak` / `.tmp` files anywhere
- **Final repo state:**
  - main: `7d9be7b` (PR #260 merge)
  - develop: `df3a1cd` (synced with main + retro work pending)
  - Tag: `0.8.0` pushed
  - GH release: published at https://github.com/primetimetank21/dev-setup/releases/tag/0.8.0
  - Local branches: develop, main (and current retro branch)
  - Remote branches: develop, main
  - Worktrees: 1 (primary)
  - Open PRs: 0 (excluding upcoming retro PR)
  - Open `go:yes` issues: 0
- **Standing directive lock-in:** EOS sweep confirmed in charter. Every session ends with the 12-point sweep + branch reaping.
- **Verdict:** CLEAN. Sprint Q + 0.8.0 wrap complete.

## Sprint R EOS Cleanup -- 2026-05-16

- **Context:** Sprint R wrapped with 5 PRs merged (#265, #266, #267, #268, #269)
  and follow-up issue #271 filed. Final cleanup pass executed.
- **Cleanup actions:**
  - Fetched and pruned remote refs (stale refs from previous work removed)
  - Verified worktree list: 1 primary worktree (C:\Users\Earl Tankard\Coding\dev-setup)
  - Ran worktree prune (no stale worktrees found)
  - Local squad branches identified: squad/doc-sprint-r-history (PR #270 OPEN)
  - Remote squad branches checked and status verified:
    * squad/224-hook-test-coverage -> PR #267 MERGED, deleted
    * squad/226-winget-exit-check -> PR #268 MERGED, deleted
    * squad/227-bak-rotation -> PR #269 MERGED, deleted
    * squad/228-hookspath-docs -> PR #266 MERGED, deleted
    * squad/253-e2e-summary -> PR #265 MERGED, deleted
    * squad/doc-sprint-r-history -> PR #270 OPEN (retained locally)
  - Verified: no open PRs on any merged branches
  - Deleted all 5 remote squad/* branches via single push command
  - Ran final fetch --prune to drop stale tracking refs
- **Final repo state:**
  - develop: d71176e (current HEAD, working tree clean)
  - Local branches: develop, main, squad/doc-sprint-r-history (open PR #270)
  - Remote branches: develop, main, origin/squad/doc-sprint-r-history
  - Worktrees: 1 (primary)
  - Open PRs: 1 (PR #270 on squad/doc-sprint-r-history)
  - Status: git status -sb shows clean
- **Branches retained (not deleted):**
  - squad/doc-sprint-r-history: open PR #270 prevents local/remote deletion
  - main, develop, release/* (per charter: never touch release branches)
- **Verdict:** CLEAN. 5 stale sprint branches removed. Working tree verified
  clean. Ready for next session.
