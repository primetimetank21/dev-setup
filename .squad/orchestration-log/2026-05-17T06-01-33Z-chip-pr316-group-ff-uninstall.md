### 2026-05-17T06:01:33Z -- Chip: add Group FF coverage for uninstall (closes #238)

| Field | Value |
|-------|-------|
| **Agent routed** | Chip (Tester / QA) |
| **Why chosen** | Issue #238 adds Pester test coverage for the Windows uninstall path -- testing lane is Chip's per routing.md. |
| **Mode** | background |
| **Why this mode** | Independent test addition; no hard data dependency on other Wave 1 agents. |
| **Files authorized to read** | `tests/test_windows_setup.ps1`, `scripts/windows/uninstall.ps1`, `CHANGELOG.md`, `.squad/agents/chip/history.md`, `.squad/decisions.md`, issue #238 |
| **File(s) agent must produce** | `tests/test_windows_setup.ps1` (10 new Group FF tests for uninstall), `CHANGELOG.md` (Unreleased > Added entry), `.squad/agents/chip/history.md` (Sprint 12 PR #316 entry) |
| **Worktree** | `dev-setup-238` on `squad/238-group-ff-uninstall-tests` |
| **PR** | #316 -- test(chip): add Group FF coverage for uninstall (closes #238) |
| **Outcome** | Completed -- PR merged. 10 new Pester tests added (FF-1..FF-10 covering uninstall). ASCII-clean. Inbox drop `chip-uninstall-tests-20260517.md` queued for next fold (gitignored, untouched by this Scribe pass per scope). |
| **Sprint/Wave** | Sprint 12, Wave 1 |
| **Requested by** | Earl Tankard |
