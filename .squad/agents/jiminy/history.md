# Jiminy's History

## Core Context

- **Project:** dev-setup - Replicable setup scripts for Dev Containers and Codespaces
- **Owner:** Earl Tankard, Jr., Ph.D.
- **Universe:** Disney Classic
- **Role:** Squad Hygiene Auditor (reviewer-gate)
- **Joined:** 2026-05-16
- **Charter:** `.squad/agents/jiminy/charter.md`
- **Model:** `claude-opus-4.6` (premium - reviewer-gate role)

## Day-1 context (handed to Jiminy at creation)

### Why Jiminy exists

Earl's team had recurring squad hygiene failures that he had to catch manually:

1. **Branch ancestry bleed (Sprint 7, 3+ occurrences):** Squad branches forked from other squad branches instead of `develop`, polluting PR diffs with unrelated commits.
2. **Squash merges (Sprint 2, Sprint 3):** Ralph violated the MERGE GATE by squashing PRs that should have been regular merges. Earl's standing directive: ALL merges use regular merge commits, never squash.
3. **Uncommitted histories (recurring):** Agents append learnings to `history.md` but Coordinator forgets to fire Scribe, so edits sit uncommitted on `develop`. Caught by Earl manually each time.
4. **Rogue file paths (2026-05-16):** Verifier batch agents wrote `VERIFICATION_REPORT.md` files at random paths (`.squad/agents/{name}/VERIFICATION_REPORT.md`, `.squad/verification-report.md`) instead of using the Source of Truth Hierarchy. Donald cleaned up via `.squad/orchestration-log/2026-05-16-verification-evidence.md`.
5. **Stale branches (post-sprint):** Remote `squad/*` branches not cleaned after merge until Earl asks. Ralph now owns end-of-session cleanup per directive (2026-05-16).

### Key files to know about

- `.squad/decisions.md` - team decision ledger (read for context on every spawn)
- `.github/agents/squad.agent.md` (or platform-equivalent) - authoritative governance
- Source of Truth Hierarchy (see charter Section: Scope) - defines legal write locations per file type
- `hooks/` directory in repo root - pre-commit + commit-msg + pre-push hooks (Conventional Commits + shellcheck)
- `CHANGELOG.md` - `[Unreleased]` section is the staging area for the next release
- `.gitattributes` - has `merge=union` driver for append-only `.squad/` files

### Standing user directives (Earl)

- **Caveman speak** preferred (short, direct, no big words)
- **Em dashes and non-ASCII chars FORBIDDEN** in PowerShell string literals (CP1252 byte 0x94 issue)
- **ALL merges use regular merge commits** - never squash, no exceptions
- **Branches forked strictly from `develop`**, never from other squad branches
- **End-of-session: ALWAYS delete stale branches** (local + remote) - Ralph owns this
- **Bad commit messages hard-reject** (commit-msg hook enforces)
- **Verifier batches must use Source of Truth Hierarchy paths only** - 3 legal locations: `history.md` (learnings), `decisions/inbox/` (decisions), `orchestration-log/` (batch evidence)

### Roster context at hire-time

Active squad (Disney Classic universe):

- Mickey - Lead (architecture, code review, triage)
- Donald - Shell Dev (bash/zsh, Linux)
- Goofy - Cross-Platform Dev (PowerShell, Windows)
- Pluto - Config Engineer (dotfiles, hooks, env)
- Chip - Tester (CI, idempotency, edge cases)
- Scribe - Session Logger (mechanical, silent)
- Ralph - Work Monitor (queue, backlog, end-of-session cleanup)
- Jiminy (new) - Squad Hygiene Auditor (process QA)

### Open issues at hire-time

19 issues filed 2026-05-16 from post-sprint audit: #221-#239. Priorities P0/P1/P2/P3, all labeled with `squad:{member}`. None marked `go:yes` yet - Earl will mark sprint-ready when ready to start next sprint.

P0 issues Jiminy should know about:

- **#221** - nvm.ps1 path resolution bug (Goofy)
- **#222** - Git tag hygiene: retroactively tag 0.1.0-0.7.0 + cut 0.8.0 (Mickey)
- **#239** - E2E install smoke test in CI across Linux/macOS/Windows (Chip)

### First task assigned at hire

None. Jiminy begins auto-running on the next Coordinator return-to-user.

## Learnings

- **2026-05-16 -- First audit run.** Tree clean, branches clean, labels good. Main issues: 10 non-merge commits directly on main (Sprint 5 era hotfixes), 2 rogue files (.squad/commit-msg-temp.txt, .squad/agents/chip/audit-findings.md), duplicate log dirs (.squad/log/ vs .squad/logs/). Scribe history.md missing ## Learnings section. Patterns noticed: hotfix sessions historically bypass develop-first rule and commit straight to main.
- **2026-05-16 -- First audit resolution (coordinator-applied).** All 4 auto-fixable items resolved: (1) `.squad/commit-msg-temp.txt` deleted; (2) `.squad/agents/chip/audit-findings.md` content merged into canonical `.squad/orchestration-log/2026-05-16T07-00-25Z-chip-testing-audit.md` (was a stub manifest, now has full findings appended), rogue deleted; (3) `.squad/logs/session_log.md` migrated to `.squad/log/session_log.md` and `.squad/logs/` dir deleted (canonical = singular `log/`); (4) Scribe history.md got `## Learnings` section. Main-branch direct commits ACCEPTED as historical -- Earl confirmed no retroactive history rewrite; standing directive (develop-first, merge commits only on main) enforces going forward.
- **2026-05-16 -- Post-retro-batch audit (auto-trigger #2).** Audited 3-spawn batch (Coordinator direct-push 0431dc8 + Chip PR #241 merged c02d679 + Goofy PR #242 merged 0fc8dcf). 4 lanes checked. 2 findings total: (1) SKILL.md at 7770 bytes vs expected 7900+ (minor -- content intact, likely byte-count estimate was off); (2) PR #242 missing `squad:goofy` label pattern -- actually present but named differently in label list vs expected `squad:*` glob (FALSE POSITIVE on re-check -- label `squad:goofy` IS present). Net result: 1 minor finding (SKILL.md size). All other lanes clean: working tree clean, no stale branches, merge commits correct, Co-authored-by trailers present on both feature commits (60b1de1, 4614e25), history.md updated by both agents, decisions inbox drained, Scribe not yet fired (expected).
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.
