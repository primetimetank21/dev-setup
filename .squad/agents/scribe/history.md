# Scribe History

**Role:** Session Logger, Memory Manager & Decision Merger  
**Mode:** Always spawned as background task. Never blocks user conversation.

---

> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place). Re-compressed post-Sprint 15 per history-compression skill + #363 gate.

## Pre-2026-05-16 Activity (summary)

- **2026-04-07 to 2026-04-18:** Squad init, sprints 5-7, hotfix retro; merged 6 inbox drops; cross-agent histories appended.

---

## Learnings

- git add .squad/ stages everything under .squad/ including pre-existing untracked rogue files. Before staging, run git status --porcelain -- .squad/ and confirm only intended files appear. If rogues exist, escalate to coordinator (do not auto-commit them).
- Decision inbox path (.squad/decisions/inbox/) is gitignored by design (.gitignore:4). Inbox files are drop-box drains, never committed. Drain by reading, merging content into decisions.md, then deleting the inbox file.
- Canonical squad write locations only: gents/{name}/charter.md|history.md, decisions.md|decisions-archive.md, decisions/inbox/*.md, orchestration-log/*.md, log/*.md, skills/{name}/SKILL.md, 	emplates/*.md, casting/*.json, identity/*.md, plugins/*.json, 	eam.md|routing.md|ceremonies.md|config.json. Any other path is rogue; flag to Jiminy.

## Sprint 13-15 (compressed)

- **Sprint 12 W2 (2026-05-17):** Folded 5-agent batch. Lessons: atomic inbox drain (per-file discipline, NO glob), .NET APIs use process CWD.
- **Sprint 13:** Compressed 8 over-gate histories, formalized history-compression skill. Retro: 8 lessons, 5 issues.
- **Sprint 14:** 6 issues, 0.9.4 shipped, 84-issue label migration. history-compression + per-topic-inbox-routing HIGH confidence (5+ applications). Retro: skill graduation noted.
- **Sprint 15 (current):** 6 issues, 0.9.5 shipped. Scribe charter scope catch (CHANGELOG routed to Mickey). Doc dual-worktree validated. 8 lessons.

### 2026-05-17 Sprint 16 Archival Pass (#363)

**By:** Scribe (via Copilot)  
**Date:** 2026-05-17T19:06:31-04:00  
**Issue:** #363 -- Archival pass, decisions.md exceeded 51200 byte hard gate.

**What:** Executed archival fold for entries dated 2026-05-09 or earlier. Found 1 qualifying entry:
- 2025-07-14 Gitconfig decision (1153 bytes)

**Outcome:**  
- decisions.md: 60270 -> 59116 bytes (1154 bytes removed) -- STILL OVER hard gate
- decisions-archive.md: 121949 -> 123109 bytes (1160 bytes added)
- Entry count verified: 1 moved, no loss
- Header note updated to reference "2026-05-09 second fold"

**Note:** Hard gate (51200 bytes) NOT met. Archiving the single entry before 2026-05-10 was insufficient. Next fold should consider earlier cutoff (e.g., 2026-05-04 or aggressive pruning of 2026-05-14+ entries).
