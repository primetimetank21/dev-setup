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

## Sprint 8-hotfix (formerly Sprint Q) + 0.8.0 Release Cleanup -- 2026-05-16

- **Context:** After Sprint 8-hotfix P0 fixes (#249, #251, #252) merged via #257/#256/#258, cut 0.8.0 release (PR #259 + #260) and shipped GH release. Final EOS sweep.
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
- **Verdict:** CLEAN. Sprint 8-hotfix + 0.8.0 wrap complete.

## Sprint 9 (formerly Sprint R) EOS Cleanup -- 2026-05-16

- **Context:** Sprint 9 wrapped with 5 PRs merged (#265, #266, #267, #268, #269)
  and follow-up issue #271 filed. Final cleanup pass executed.
- **Cleanup actions:**
  - Fetched and pruned remote refs (stale refs from previous work removed)
  - Verified worktree list: 1 primary worktree (C:\Users\Earl Tankard\Coding\dev-setup)
  - Ran worktree prune (no stale worktrees found)
  - Local squad branches identified: squad/doc-Sprint-9-history (PR #270 OPEN)
  - Remote squad branches checked and status verified:
    * squad/224-hook-test-coverage -> PR #267 MERGED, deleted
    * squad/226-winget-exit-check -> PR #268 MERGED, deleted
    * squad/227-bak-rotation -> PR #269 MERGED, deleted
    * squad/228-hookspath-docs -> PR #266 MERGED, deleted
    * squad/253-e2e-summary -> PR #265 MERGED, deleted
    * squad/doc-Sprint-9-history -> PR #270 OPEN (retained locally)
  - Verified: no open PRs on any merged branches
  - Deleted all 5 remote squad/* branches via single push command
  - Ran final fetch --prune to drop stale tracking refs
- **Final repo state:**
  - develop: d71176e (current HEAD, working tree clean)
  - Local branches: develop, main, squad/doc-Sprint-9-history (open PR #270)
  - Remote branches: develop, main, origin/squad/doc-Sprint-9-history
  - Worktrees: 1 (primary)
  - Open PRs: 1 (PR #270 on squad/doc-Sprint-9-history)
  - Status: git status -sb shows clean
- **Branches retained (not deleted):**
  - squad/doc-Sprint-9-history: open PR #270 prevents local/remote deletion
  - main, develop, release/* (per charter: never touch release branches)
- **Verdict:** CLEAN. 5 stale sprint branches removed. Working tree verified
  clean. Ready for next session.

## Sprint 10 (formerly Sprint S) EOS Cleanup -- 2026-05-17

- **Context:** Sprint 10 wrapped. Jiminy retro (PR #283) and Scribe retro
  (PR #284) merged. Coordinator handed off to Ralph for final branch reaping
  per EOS sequence (Jiminy -> Scribe -> Ralph -> session complete).
- **Trigger:** End-of-Sprint-10 session-wrap; develop @ `8103195` (post-#284
  merge), working tree clean.
- **PR verification:** Re-verified all 6 candidate branches via
  `gh pr list --state merged --head <branch>`. All 6 confirmed MERGED:
  * squad/223-logging-consolidation -> PR #278 (merged 2026-05-17T00:24:54Z)
  * squad/231-ps1-gitattributes -> PR #275 (merged 2026-05-17T00:19:19Z)
  * squad/234-ps1-ascii-encoding -> PR #276 (merged 2026-05-17T00:19:28Z)
  * squad/255-squad-cli-warning -> PR #279 (merged 2026-05-17T01:34:44Z)
  * squad/255-tool-version-pins -> PR #282 (merged 2026-05-17T01:26:01Z)
  * squad/271-uninstall-hookspath -> PR #277 (merged 2026-05-17T00:51:50Z)
- **Cleanup actions:**
  - Deleted all 6 remote squad/* branches via single
    `git push origin --delete ...` call
  - Ran `git fetch --prune` to drop stale tracking refs
  - Local branches: only `develop` (current) + `main` -- no squad/* survived
    (Scribe's was auto-cleaned by `gh pr merge --delete-branch` on #284)
  - Worktrees: 1 primary worktree, no `..\dev-setup-*` strays
- **Refused / anomalies:** None. All 6 candidate branches had merged PRs;
  zero force-deletes required.
- **History-fold:** This entry committed on `squad/ralph-Sprint-10-eos`
  branch + PR opened (charter ban on direct develop commits, per #274).
  Coordinator will review and merge.
- **Final repo state:**
  - develop: `8103195` (working tree clean)
  - Local branches: develop, main, squad/ralph-Sprint-10-eos (this PR)
  - Remote branches: develop, main, origin/squad/ralph-Sprint-10-eos (this PR)
  - Worktrees: 1 (primary)
  - Open PRs: 1 (this history-fold)
- **Verdict:** CLEAN. 6 stale Sprint-10 branches reaped. Sprint 10 backlog
  complete.

## Post-0.9.0 Mini-Batch EOS Cleanup -- 2026-05-17

- **Trigger:** Post-0.9.0 action-item closeout sweep. 3 PRs merged (#291,
  #293, #294) plus issue #232 closed (resolved by #282). Coordinator
  requested Ralph EOS pass before Sprint 11 (formerly Sprint T) dispatch. develop @ `3630c31`
  (post-#294 merge), working tree clean.
- **PR verification:** Re-verified both candidate branches via
  `gh pr list --state merged --head <branch>`. Both confirmed MERGED with
  base `develop`:
  * squad/288-pwsh-lastexitcode -> PR #291 (merged 2026-05-17T02:35:56Z,
    sha `836a26f`): `docs(squad): add pwsh-lastexitcode skill (closes #288)`
  * squad/289-290-squad-automation -> PR #293 (merged
    2026-05-17T02:53:38Z, sha `f7a7bcf`):
    `docs(squad): codify Doc worktree pattern + Jiminy auto-dispatch SOP
    (closes #289, #290)`
- **Branches deleted (2):** Both remote refs successfully removed via
  single `git push origin --delete squad/288-pwsh-lastexitcode
  squad/289-290-squad-automation`. `git fetch --prune origin` cleaned
  tracking refs. Post-delete `git branch -r | findstr squad/` returns
  empty.
- **GitHub `gh pr merge --delete-branch` quirk:** Both PRs were merged
  with `--delete-branch` (GitHub UI reported success on each), yet the
  remote refs survived. Coordinator's pre-flight scan caught both via
  `gh api repos/.../branches/<name>`. Worth filing a tracking issue if it
  recurs on the next sprint -- pattern observed on 2 of 3 most recent
  merges (#291, #293; #294's `squad/scribe-post-090-retro` was reaped
  cleanly). Mitigation today: manual `git push origin --delete` works.
- **Local cleanups:** None needed -- pre-flight already showed only
  `develop` + `main` locally, 1 worktree, empty
  `.squad/decisions/inbox/`, and clean `.squad/agents/` (no uncommitted
  history.md drift).
- **Refused / anomalies:** None. Both branches met the delete criteria
  (PR MERGED, base=develop, no other open PRs). Zero force-deletes.
- **History-fold:** This entry committed on `squad/ralph-post-090-eos`
  branch + PR opened (charter ban on direct develop commits, per #274).
  Coordinator will review and merge.
- **Final repo state:**
  - develop: `3630c31` (working tree clean)
  - Local branches: develop, main, squad/ralph-post-090-eos (this PR)
  - Remote branches: develop, main, origin/squad/ralph-post-090-eos
    (this PR)
  - Worktrees: 1 (primary)
  - Open PRs: 1 (this history-fold)
- **Verdict:** CLEAN. 2 stale post-Sprint-10 branches reaped. Ready for
  Sprint 11 dispatch.

## Sprint 11 End-of-Session Cleanup -- 2026-05-17

- **Trigger:** Sprint 11 fully wrapped (Jiminy PR #302 merged, Scribe retro
  PR #303 merged). Coordinator handed off to Ralph as final EOS step.
  develop @ `d58576a`, working tree clean.
- **PR:** #304 (squad/ralph-Sprint-11-eos)
- **Previous EOS:** PR #295 (post-0.9.0 mini-batch cleanup)
- **Initial state snapshot:**
  - Local branches: develop, main (no squad/* branches)
  - Remote branches: origin/develop, origin/main (no squad/* branches)
  - Worktrees: 1 (primary at C:\Users\Earl Tankard\Coding\dev-setup)
- **Cleanup actions:** None -- state was already clean.
- **gh `--delete-branch` quirk (issue #300):** NOT encountered this session.
  All Sprint 11 PR merges appear to have reaped their branches cleanly via
  `--delete-branch`. No ghost refs found.
- **Final repo state:**
  - develop: `d58576a` (working tree clean)
  - Local branches: develop, main, squad/ralph-Sprint-11-eos (this PR)
  - Remote branches: origin/develop, origin/main,
    origin/squad/ralph-Sprint-11-eos (this PR)
  - Worktrees: 1 (primary)
  - Open PRs: 1 (this history-fold)
- **Verdict:** CLEAN. 0 straggler branches, 0 worktrees to remove. Sprint 11
  EOS complete.

## Post-0.9.1 Release + Sprint Rename EOS Cleanup -- 2026-05-17

- **Trigger:** Session-end after 0.9.1 release shipped and Sprint naming
  convention reverted to numbers (Q->8-hotfix, R->9, S->10, T->11, next=12).
  Coordinator handed off to Ralph as final EOS step after Jiminy audit ran
  clean. develop @ `e3418ac`, working tree clean.
- **PR:** #312 (squad/ralph-eos-0.9.1) -- this history-fold
- **Previous EOS:** PR #304 (Sprint 11 EOS, no stragglers)
- **Session PRs merged (all confirmed merged + branches reaped):**
  * PR #305 -- release/0.9.1 -> develop: 0.9.1 release fold
  * PR #307 -- chore(release): fold [Unreleased] into 0.9.1 CHANGELOG
    (merge commit 2b3afe1)
  * PR #308 -- chore/sprint-naming-convention: revert + rename sprints to
    numbers (merge commit c93a54c)
  * PR #311 -- docs(scribe): 0.9.1 release + sprint naming rename retro +
    history updates (squash-merged as e3418ac)
- **Initial state snapshot:**
  - Local branches: develop, main (no squad/* branches)
  - Remote branches: origin/develop, origin/main, origin/HEAD -> origin/develop
    (no squad/* branches)
  - Worktrees: 1 (primary at C:\Users\Earl Tankard\Coding\dev-setup)
  - Open PRs: 0 (clean board)
  - Inbox: 1 file (jiminy-2026-05-17-post-batch-audit-fold.md) -- gitignored,
    NOT Ralph's to action (Scribe will fold next dispatch)
- **Cleanup actions:** None -- state was already clean. `git fetch --prune`
  ran for hygiene and confirmed zero stale tracking refs.
- **gh `--delete-branch` quirk (issue #300):** NOT encountered this session.
  All 4 session PRs cleaned up their head branches cleanly. Post-Sprint-11
  release pattern (release branch + revert/rename PRs + retro PR) appears
  to leave nothing sticky -- the squash-merge in PR #311 also reaped its
  source branch successfully.
- **Final repo state:**
  - develop: `e3418ac` (working tree clean before branch creation)
  - main: `724c62c` (tagged 0.9.1, released)
  - Local branches: develop, main, squad/ralph-eos-0.9.1 (this PR)
  - Remote branches: origin/develop, origin/main,
    origin/squad/ralph-eos-0.9.1 (this PR)
  - Worktrees: 1 (primary)
  - Open PRs: 1 (this history-fold)
- **EOS pattern note:** Sprint 11 -> 0.9.1 release -> rename retro is now
  the second consecutive EOS where the release+rename cadence produces
  zero stragglers. The post-Sprint-10 cycle (PR #295) had 2 stragglers
  to reap; Sprint 11 wrap (PR #304) and this 0.9.1 wrap had zero each.
  Hypothesis: `gh pr merge --delete-branch` reliability has improved, OR
  the team has internalized the cleanup-on-merge habit. Worth watching
  for one more cycle before declaring the quirk obsolete.
- **Verdict:** CLEAN. 0 straggler branches, 0 worktrees, 0 stale remotes.
  0.9.1 release session fully reaped. Sprint 12 backlog staged and ready
  for next dispatch.

### Learnings (Ralph)

- **Post-release + post-rename combo runs clean.** Even with 4 session PRs
  spanning a release fold, a CHANGELOG cleanup, a naming revert, and a
  retro, the board ended at zero stragglers. The release branch
  (`release/0.9.1`) was reaped on merge; the chore/* and squad/* branches
  same. No special handling needed for the squash-merged retro PR (#311).
- **Inbox gitignore is the right pattern.** Jiminy's fold-request sitting
  in `.squad/decisions/inbox/` is gitignored (`.gitignore:4`), so it
  survives session boundaries without polluting develop. This is the
  precedent for Ralph too if a future EOS has nothing committable.
- **Default to PR over inbox fold-request when history.md is the only
  delta.** Earl's preference (per spawn prompt) is an explicit paper
  trail per session, and the cost of a tiny PR is low. Inbox path stays
  reserved for genuinely uncertain situations.
- **`git fetch --prune` on an already-clean board is a no-op but worth
  running.** Confirms remote state matches local belief in ~50ms. Cheap
  insurance against silent ghost refs.
- **No new EOS rules to codify.** Pattern is stable: audit -> prune ->
  history append -> PR. No skill extraction this round.

## 2026-05-17 -- Sprint 12 EOS sweep (Earl, post-retro merge)

- **Trigger:** Earl's EOS protocol after Sprint 12 wrap (3 waves, 10 PRs, 9
  issues closed). Retro fold landed as PR #327 (`5e0fb53`) just before
  dispatch. Coordinator had already drained 4 Wave-2 inbox drops inline
  post-Jiminy-audit; board reported clean entering this sweep.
- **Pre-sweep state:**
  - develop @ `5e0fb53`, main @ `724c62c` (still 0.9.1, untouched)
  - Working tree clean, 1 worktree (primary only)
  - Inbox empty, no rogue body files, no temp/backup rogues
- **Pruned (Step 1) -- 5 stale `origin/squad/*` tracking refs:**
  - `origin/squad/237-test-harness-pattern`
  - `origin/squad/306-readme-refresh`
  - `origin/squad/310-arch-windows-dep-order`
  - `origin/squad/scribe-sprint-12-retro` (Jiminy listed 4 -- this was the
    5th, branch reaped when PR #327 squash-merged minutes earlier; local
    tracking ref hadn't caught up yet)
  - `origin/squad/scribe-sprint-12-wave-2-fold`
- **Already clean (Steps 2-5) -- Jiminy session-end audit was thorough:**
  - Local `squad/*` branches: 0 (Coordinator's worktree-remove-first dance
    held discipline across all 3 waves)
  - Remote `squad/*` branches via `gh api .../branches --paginate`: 0
    (confirmed -- only `develop` and `main` on the remote)
  - Filesystem `dev-setup-*` orphan dirs at parent: 0
  - `.squad/decisions/inbox/`: empty
  - Rogue `issue_body*.md` at repo root: 0 (`gh issue create -F` + `Remove-Item`
    pattern held)
  - Rogue `*.tmp`, `*.bak`, `.DS_Store`, `Thumbs.db`: 0
- **Step 6 -- `git gc --auto`:** exit 0, no output. Heuristics did not
  trigger a pack -- expected, since the worktree-local strategy keeps
  most churn off the primary checkout's loose-object pile. 10 PRs of
  merge activity did not accumulate enough loose objects to cross the
  auto-gc threshold.
- **Final repo state:**
  - develop: `5e0fb53` (clean)
  - main: `724c62c` (0.9.1, untouched)
  - Local branches: develop, main
  - Remote branches (post-prune): origin/develop, origin/main, origin/HEAD
  - Worktrees: 1 (primary)
  - Open PRs: 0
- **Sprint 12 EOS verdict:** CLEAN. 5 stale tracking refs pruned, 0 actual
  orphans (no branches, no worktrees, no fs dirs, no rogue files). Jiminy's
  session-end audit handled everything except the local-tracking-ref
  catchup, which is the canonical Ralph job. Sweep complete.
- **EOS pattern note:** 3rd consecutive EOS (Sprint 11 wrap -> 0.9.1
  release -> Sprint 12 wrap) with zero orphan branches and zero worktree
  stragglers. The Sprint 11-era hypothesis ("the team has internalized
  cleanup-on-merge OR `gh pr merge --delete-branch` reliability improved")
  now has a 3rd data point in its favor. One more cycle and the
  `gh --delete-branch` quirk (issue #300) is effectively obsolete for
  this repo's workflow.
- **Multi-wave/multi-PR scaling note (new):** This is the first EOS
  following a 3-wave / 10-PR sprint. The cleanup load did NOT scale
  linearly with PR count -- the entire sweep produced 5 stale tracking
  refs (1 per active wave/release + the retro), not 10. Worktree-local
  strategy + Scribe's per-wave fold pattern keeps the EOS surface area
  bounded regardless of sprint size. Worth remembering when sizing
  future sprints: cleanup cost is per-wave, not per-PR.

### Learnings (Ralph)

- **Local tracking refs always lag a fresh merge.** When `gh pr merge`
  deletes the remote branch, the local `origin/squad/*` ref persists
  until the next `git fetch --prune` (or explicit `git remote prune`).
  Jiminy's session-end audit ran before PR #327 merged, so it counted
  4 refs; by the time Ralph dispatched, it was 5. Not a bug in Jiminy's
  count -- a timing artifact. Future EOS dispatches after a fresh
  merge should expect +1 ref vs. the prior audit.
- **`git gc --auto` on a worktree-local-strategy repo rarely triggers.**
  3rd consecutive EOS where `git gc --auto` no-ops. The primary checkout
  stays lean because feature work happens in dedicated worktrees that
  share the object DB but don't keep their loose objects "live" the way
  a single-checkout workflow would. Safe to keep running it as cheap
  insurance, but don't expect it to do anything on this repo.
- **`gh api ... --jq` quoting is brittle in PowerShell.** First attempt
  with embedded backslash-escaped quotes failed at the jq parser. The
  reliable pattern is: `--jq '.[].name'` (no embedded quotes), then
  filter the result list in PowerShell with `Where-Object { $_ -like
  'squad/*' }`. Saves a round-trip when the quote dance fails.