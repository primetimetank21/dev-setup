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

## Learnings

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
