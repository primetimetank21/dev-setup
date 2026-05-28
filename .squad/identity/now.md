---
updated_at: 2026-05-28T03:26:31-04:00
focus_area: "[TARGET] Triage new issues #466/#467/#468 (flag framework first, then delta + lazygit in parallel). #461 deferred behind these."
active_issues:
  - 468
  - 466
  - 467
  - 461
pending_prs: []
---

# What's Next (Next Session)

## [TARGET] Primary work -- triage + sequence

Three new issues filed this session. Recommended order is **#468 first, then #466 + #467 in parallel, then #461**.

### Step 1 -- Grill #468 first (architectural prerequisite)
**Issue #468** -- Customizable install: pick-and-choose tools (flags vs interactive prompt vs manifest file vs hybrid).
- Owners: Mickey (Lead -- architectural decision) + Goofy (cross-platform: bash + pwsh parity).
- Labels: `squad`, `squad:goofy`, `squad:mickey`, `go:needs-research`.
- Why first: doing the flag framework first means #466 + #467 land cleanly inside it instead of being bolted on and refactored later.
- Open design question -- needs to be grilled and recorded in `decisions.md` before any code:
  - **Flags** (`--only=`, `--skip=`) -- CI-friendly, terse, poor discovery.
  - **Interactive prompt** (`select` / `Out-GridView`) -- best human UX, breaks headless.
  - **Manifest file** (`tools.manifest`) -- reproducible, indirect.
  - **Hybrid** -- flags for CI + prompt for humans + optional manifest. Likely answer but most surface area.
- Backward-compat gate: default behavior (no flags) MUST match current behavior.
- Suggested dispatch: `Mickey, scope #468 -- write a v1 plan picking one of flags / prompt / manifest / hybrid, with bash + pwsh parity in mind. Grill before implementation.`

### Step 2 -- Independent tools in parallel (after #468 lands)
**Issue #466** -- Install delta (git-delta) as an opt-in tool.
- Owners: Goofy + Chip.
- New `scripts/{linux,windows}/tools/delta.{sh,ps1}` installers + post-install global git config:
  ```
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.dark true
  git config --global merge.conflictStyle zdiff3
  ```
- Suggested dispatch: `Goofy, pick up #466 -- delta installer + global git config wiring, parity test pair.`

**Issue #467** -- Install lazygit as an opt-in tool.
- Owners: Goofy + Chip.
- New `scripts/{linux,windows}/tools/lazygit.{sh,ps1}` installers. No config needed.
- Suggested dispatch: `Goofy, pick up #467 -- lazygit installer + parity test pair.`

### Step 3 -- Deferred follow-up
**Issue #461** -- replace `$IsWindows` check with explicit POSIX platform detection (PS 5.1 defensiveness).
- Owners: Goofy + Chip. Filed during #451 grill cycle (out-of-scope hazard).
- Why it matters: `$IsWindows` is `$null` (falsy) on PS 5.1, which can silently mis-branch platform-specific code paths.
- Labels: `squad`, `squad:goofy`, `squad:chip`, `go:needs-research`.
- Status: needs-research first; deferred behind #466-#468 because the tool-install work touches more of the same scripts.

## Backlog
- (none beyond #461, #466, #467, #468)

## Recently Shipped
- PR #462 -> 31aa228: close pwsh parity gaps in `test_sprint_end_labels_pwsh.ps1` (closed #451) -- 6 -> 9 tests, T_C/T_D/T7 added, validate.yml PS 5.1 step.
- PR #463 -> 9aea27d: Scribe hygiene -- #451 grill-cycle decisions + logs fold.
- PR #464 -> ff85502: hygiene -- folded stranded Goofy/Mickey grill-review history appends.

Updated by Coordinator at 2026-05-28T03:15:03-04:00 -- Earl directive: "add 461 to now.md for next session".
