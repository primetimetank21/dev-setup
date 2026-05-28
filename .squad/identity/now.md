---
updated_at: 2026-05-28T03:47:00Z
focus_area: "[READY] #451 (Chip -- pwsh parity gaps) -- plan v3 grilled + draft PR #462 open"
active_issues:
  - 451
pending_prs:
  - 462
---

# What's Next (Next Session)

## [TARGET] Primary work
**Issue #451** -- close pwsh parity gaps in `tests/test_sprint_end_labels_pwsh.ps1`.
- Owner: Chip (squad:chip label already set)
- Plan: v3 at `docs/plans/451-pwsh-parity-gaps.md` -- **grilled (Mickey APPROVE, Goofy APPROVE, Jiminy clear)**
- Draft PR: #462 (open, ready for implementation)
- Scope: T_C (--release-label alone validation), T_D (bad prefix validation), T7 (CRLF lock), validate-ps51 CI step
- Follow-up: #461 ($IsWindows PS 5.1 defensiveness, out of scope)
- Type: tests-only (Chip's review-authority domain)
- Labels: squad:chip
- Suggested dispatch: `Chip, implement #451 from draft PR #462`
- Worktree path: `C:\Users\Earl Tankard\Coding\dev-setup-451` on branch `squad/451-pwsh-parity-gaps`
- Next steps: implement T_C, T_D, T7 + validate-ps51 step; mark PR ready when tests pass

## Backlog
- (none beyond #451)

## Recently Shipped
- PR #458 -> fe64139: v5.2 profile-path fix (closed #441 + #442)
- PR #459 -> 995c502: session wrap (re-review artifacts, 2 new SKILLs)

Updated by Scribe at 2026-05-27T22:45:28-04:00 -- Earl directive: "update that into now.md too so i can handle that next session".
