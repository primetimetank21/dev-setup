---
updated_at: 2026-05-28T03:15:03-04:00
focus_area: "[TARGET] Start #461 (Goofy + Chip -- replace `$IsWindows` with explicit POSIX detection for PS 5.1)"
active_issues:
  - 461
pending_prs: []
---

# What's Next (Next Session)

## [TARGET] Primary work
**Issue #461** -- replace `$IsWindows` check with explicit POSIX platform detection (PS 5.1 defensiveness).
- Owners: Goofy (cross-platform) + Chip (tests). Both labels set.
- Origin: filed during #451 grill cycle (out-of-scope hazard surfaced by Mickey/Goofy review of `tests/test_sprint_end_labels_pwsh.ps1`).
- Why it matters: `$IsWindows` is `$null` (falsy) on PS 5.1, which can silently mis-branch platform-specific code paths.
- Labels: `squad`, `squad:goofy`, `squad:chip`, `go:needs-research`
- Status: needs-research first -- no implementation until scope is grilled.
- Suggested dispatch: `Goofy, scope out #461 -- audit every $IsWindows reference in the repo and propose an explicit POSIX detection pattern.`

## Backlog
- (none beyond #461)

## Recently Shipped
- PR #462 -> 31aa228: close pwsh parity gaps in `test_sprint_end_labels_pwsh.ps1` (closed #451) -- 6 -> 9 tests, T_C/T_D/T7 added, validate.yml PS 5.1 step.
- PR #463 -> 9aea27d: Scribe hygiene -- #451 grill-cycle decisions + logs fold.
- PR #464 -> ff85502: hygiene -- folded stranded Goofy/Mickey grill-review history appends.

Updated by Coordinator at 2026-05-28T03:15:03-04:00 -- Earl directive: "add 461 to now.md for next session".
