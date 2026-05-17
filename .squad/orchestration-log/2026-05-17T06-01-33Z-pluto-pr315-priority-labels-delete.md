### 2026-05-17T06:01:33Z -- Pluto: delete legacy priority labels (closes #254)

| Field | Value |
|-------|-------|
| **Agent routed** | Pluto (Config / DevOps) |
| **Why chosen** | Issue #254 retires three legacy GitHub priority labels -- repo config / label hygiene is Pluto's lane per routing.md. |
| **Mode** | background |
| **Why this mode** | Independent GH label cleanup + skill capture; no hard data dependency on other Wave 1 agents. |
| **Files authorized to read** | `CHANGELOG.md`, `.squad/agents/pluto/history.md`, `.squad/decisions.md`, `.squad/skills/` (read for skill-template format), issue #254, `gh label list` |
| **File(s) agent must produce** | `CHANGELOG.md` (Unreleased > Removed entry), `.squad/agents/pluto/history.md` (Sprint 12 PR #315 entry), `.squad/skills/label-hygiene/SKILL.md` (NEW skill captured), `.squad/decisions/inbox/pluto-label-hygiene-20260517.md` (inbox drop, gitignored) |
| **GH side effect** | Deleted 3 legacy priority labels via `gh label delete` (recorded in history.md). |
| **Worktree** | `dev-setup-254` on `squad/254-delete-legacy-priority-labels` |
| **PR** | #315 -- chore(pluto): delete legacy priority labels (closes #254) |
| **Outcome** | Completed -- PR merged. 3 GH labels deleted; new label-hygiene SKILL.md captured for reuse. ASCII-clean. Inbox drop queued for next fold (out-of-scope for this Scribe pass). |
| **Sprint/Wave** | Sprint 12, Wave 1 |
| **Requested by** | Earl Tankard |
