## Mickey -- Verification + Synthesis Report

### V-5: Release tag overdue

- **Verdict:** CONFIRMED (and worse than claimed)
- **Citations:** 
  - CHANGELOG.md lines 8-49: [Unreleased] section = 42 lines, 32 entries
  - Breakdown: 20 Added, 11 Changed (duplicate header at line 32 and 36), 1 Fixed
  - `git tag -l`: NO TAGS EXIST IN REPOSITORY
  - CHANGELOG.md documents 7 historical releases: [0.1.0] through [0.7.0]
  - **Critical gap:** Not just "0.8.0 overdue" -- ALL 7 past releases are undocumented in git tags
- **Nuance:** 
  - My original audit claim was soft: it said "should cut a release tag now that develop is fast-forwarded to main"
  - Reality is harsher: the repo has NEVER had git tags, despite documenting 7 sprints worth of releases
  - This breaks semantic versioning workflows, GitHub release automation, and `git describe`
  - The [Unreleased] section is substantial (42 lines) but not yet "overdue" by count alone
  - However, the CHANGELOG header says "adheres to Semantic Versioning" but the repo has no tags to prove it
- **Recommended phase:** P0 (blocking -- fix retroactively for all 7 releases + cut 0.8.0)
- **Effort estimate:** M (bulk tag 0.1.0-0.7.0 from CHANGELOG dates + merge commits, then cut 0.8.0)
- **Notes:** 
  - Suggested workflow: 
    1. `git log --oneline --grep="Sprint [1-7]"` to find merge commits for each sprint
    2. Tag each retroactively: `git tag -a 0.1.0 <commit> -m "Sprint 1: Foundation"`
    3. Rename [Unreleased] to [0.8.0] - YYYY-MM-DD
    4. Add empty [Unreleased] section
    5. `git tag -a 0.8.0 -m "Sprint 8: ..."`
    6. `git push --tags`
  - Versioning: Already using 0.x so stick with it (0.8.0 next)

---

### V-6: ARCHITECTURE.md drift

- **Verdict:** PARTIALLY CONFIRMED (some drift, but less than claimed)
- **Citations:**
  - ARCHITECTURE.md line 44 mentions "Refreshed ARCHITECTURE.md and README.md file trees to match current repo layout" in CHANGELOG
  - ARCHITECTURE.md lines 22-93: File structure tree shows:
    - scripts/lib/ listed (lines 31-32) with both Read-ToolVersion files
    - scripts/linux/lib/ NOT shown in detail (no log.sh mention)
    - scripts/windows/lib/ NOT shown in detail (no logging.ps1 mention)
    - hooks/ section (lines 66-69) lists 3 hooks: commit-msg, pre-commit, pre-push (MISSING prepare-commit-msg)
    - .github/workflows/ section (line 89) shows only "validate.yml" with no job breakdown
  - Actual state:
    - scripts/lib/ exists with 2 files (read-tool-version.sh, Read-ToolVersion.ps1)
    - scripts/linux/lib/ exists with log.sh (added PR #186)
    - scripts/windows/lib/ exists with logging.ps1 (added PR #186)
    - hooks/ has 4 hooks: commit-msg, pre-commit, pre-push, prepare-commit-msg (last added #212)
    - validate.yml has 6 CI jobs: validate-linux, validate-macos, lint-shell-scripts, lint-powershell, validate-powershell, validate-ps51
- **Nuance:**
  - The file tree WAS refreshed recently (CHANGELOG line 44), so it's not "stale since sprint 6"
  - The drift is FORWARD drift (prepare-commit-msg hook added AFTER the refresh)
  - scripts/lib/ IS documented correctly
  - scripts/linux/lib/ and scripts/windows/lib/ are the real gaps (logging consolidation not reflected)
  - CI job enumeration is missing (just says "validate.yml" with no breakdown)
- **Recommended phase:** P2 (nice-to-have; doesn't block development)
- **Effort estimate:** S (add 3 lines to file tree + 1 hook + expand CI section)
- **Notes:**
  - Not a "big rewrite" -- just additions:
    1. Add scripts/linux/lib/log.sh to tree (line ~35)
    2. Add scripts/windows/lib/logging.ps1 to tree (line ~53)
    3. Add prepare-commit-msg to hooks/ tree (line ~69)
    4. Expand validate.yml description to list 6 jobs (line ~89)

---

### V-8: Install-guard helper / command detection abstraction

- **Verdict:** PARTIALLY CONFIRMED (pattern exists but nuance matters)
- **Citations:**
  - Spot-checked 5 tool scripts:
    - scripts/linux/tools/gh.sh:13 -- `if command -v gh &>/dev/null`
    - scripts/linux/tools/uv.sh:13 -- `if command -v uv &>/dev/null`
    - scripts/linux/tools/zsh.sh:13 -- `if command -v zsh &>/dev/null`
    - scripts/linux/tools/nvm.sh:20-27 -- `if command -v node` + version check + comparison
    - scripts/linux/tools/copilot-cli.sh:20 -- `if [[ -x "$COPILOT_BIN" ]]` (file test, not command)
    - scripts/windows/tools/gh.ps1:12 -- `if (Get-Command gh -ErrorAction SilentlyContinue)`
    - scripts/windows/tools/uv.ps1:12 -- `if (Get-Command uv -ErrorAction SilentlyContinue)`
    - scripts/windows/tools/nvm.ps1:26-34 -- `Get-Command node` + version extraction + comparison
    - scripts/windows/tools/vim.ps1:13 -- `if (Get-Command vim -ErrorAction SilentlyContinue)` + PATH registration
- **Nuance:**
  - WITHIN each platform, the pattern IS consistent:
    - Linux: `command -v <tool>` for simple checks
    - Windows: `Get-Command <tool> -ErrorAction SilentlyContinue` for simple checks
  - BUT: Not all install-guards are "is this installed?" checks:
    - nvm.sh checks if CURRENT version matches PINNED version (lines 20-27)
    - copilot-cli.sh checks file existence, not command (line 20: `[[ -x "$COPILOT_BIN" ]]`)
    - vim.ps1 does PATH registration after winget install (lines 20-30)
  - A helper would need multiple modes:
    - `is_command_available <tool>` (simple presence)
    - `is_version_current <tool> <expected>` (version match)
    - `is_file_executable <path>` (file test)
  - Current idioms are appropriate to each tool's needs
- **Recommended phase:** P3 (defer until pattern pain outweighs abstraction cost)
- **Effort estimate:** M (design + refactor 18 tool scripts across 2 platforms)
- **Notes:**
  - Value gained: Reduced duplication, easier to add install-guards to new tools
  - Cost: Abstraction complexity, testing burden, potential for over-engineering
  - After #186 logging consolidation, command-detection IS the next duplication target
  - BUT: The variation (version checks, file checks) suggests a helper might be premature
  - Wait until 3+ more tools are added and the pattern pain is clearer

---

### V-cross: Biggest gap synthesis

- **Theme:** Git tag hygiene is broken (all 7 releases untagged)
- **Why it matters most:** 
  - The repo documents adherence to Semantic Versioning in CHANGELOG.md (line 6) but has ZERO git tags to prove it
  - This breaks GitHub release workflows, `git describe`, and any automation that relies on tags
  - The [Unreleased] section is ready for 0.8.0, but the foundation is missing: 0.1.0 through 0.7.0 were never tagged
  - Retroactive tagging is possible (CHANGELOG has dates, git log has merge commits) but the longer we wait, the harder it gets
  - This is a process gap, not a code gap: someone forgot to `git tag` after each sprint
- **Suggested epic:** "Establish release tagging discipline"
  - Issue 1 (P0): Retroactively tag 0.1.0 through 0.7.0 from CHANGELOG dates + merge commits
  - Issue 2 (P0): Cut 0.8.0 tag for current [Unreleased] work
  - Issue 3 (P1): Document release workflow in CONTRIBUTING.md (when to tag, how to push tags)
  - Issue 4 (P1): Add CI check that fails if [Unreleased] grows beyond N lines without a tag

---

### Summary

**V-5 (Release tags):** CONFIRMED and WORSE. The repo has documented 7 releases but zero git tags. This is a P0 blocker -- fix retroactively + cut 0.8.0 now.

**V-6 (ARCHITECTURE.md drift):** PARTIALLY CONFIRMED. The file tree was refreshed recently, but forward drift exists (prepare-commit-msg hook, logging lib details, CI job breakdown missing). P2 fix, S effort.

**V-8 (Install-guard helper):** PARTIALLY CONFIRMED. Patterns ARE consistent within each platform, but variation in check types (version match, file test) suggests a helper is premature. P3 defer until more tools added.

**Surprise:** The git tag situation is worse than I thought. My original audit flagged "0.8.0 overdue" but the root cause is that NO releases have ever been tagged. This is the single biggest process gap in the repo.

**Architect call:** Fix git tag hygiene first (P0). ARCHITECTURE.md refresh is cosmetic (P2). Install-guard helper is speculative (P3). The tag gap undermines semantic versioning claims and blocks release automation.
