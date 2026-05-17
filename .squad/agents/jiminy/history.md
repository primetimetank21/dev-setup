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

> Re-compressed 2026-05-17 (W1 fold) per #319 gate. Sprint 13+ entries kept verbatim; older summarized.

- **2026-05-16 -- Audit runs 1-3 (summary).** First-audit baseline: clean tree, 10 pre-Sprint-5 main-direct commits accepted as historical, 2 rogue files cleaned, duplicate log dirs reconciled to singular `.squad/log/`, Scribe got Learnings section. Post-retro audit #2: 1 minor SKILL.md size finding + 1 false-positive label flag. Hygiene retro shipped 4 items (pre-spawn-checklist skill, squad-history-check CI gate, PR template, 6 standing rules). Post-batch audit #3 (4-PR sprint #243-#246): 4 findings (type-label, PR body, area-label, tmux assertion).
- **2026-05-16 to 2026-05-18 -- Sprint 10 audits.** Mid-sprint: Doc history.md modified (deferred to Scribe), `bradygaster-squad-sdk-0.9.4.tgz` rogue (PR #280: `*.tgz` to .gitignore + delete). Gap: Coordinator manual dispatch vs charter "auto-trigger after 3+ batches". EOS: clean tree, 4 known inbox drops pending Scribe drain, Mickey PR #274 missing history.md entry, 6 stale `squad/*` remote branches (Ralph EOS scope).
- **2026-05-19 -- Sprint 11 Wave 1 + session-end audits (first under #293 SOP).** All 11 lanes clean across PRs #296-#298 (Mickey #229, Goofy #230, Pluto #233). Session-end + bonus PRs #299/#301/#302: clean, `Jiminy clear`. Pattern: `gh pr merge --delete-branch` ghost-branch recurrence 75%, tracked as #300.
- **2026-05-17 -- Sprint 12 Wave 1 audits.** Closed #300 (Option A, 6-for-6 clean post-filing #299/#301/#302/#303/#311/#312); Ralph EOS `git push --delete` fallback retained. Post-batch audit after 4 merges (#313/#314/#315/#316): 11-lane clean, label gap on #317 flagged. Verdict: `0 fixes, 1 minor flag`.
- **2026-05-17 -- Sprint 12 Wave 2 post-batch audit.** 3-agent batch (Mickey #310/PR #321, Donald #237/PR #320, Goofy #235 NOT_PLANNED Case B). Findings: (i) **CRITICAL worktree-isolation violation by Mickey** -- inbox drop landed in MAIN checkout instead of `dev-setup-310`; 2nd distinct write-to-wrong-CWD event same run. Root cause: dispatch prompt didn't pin CWD; tooling resolved against process CWD. Donald's parallel spawn wrote correctly -- non-deterministic. Remediation drop filed. (ii) **MEDIUM pre-commit ASCII-scan scope gap** -- `hooks/pre-commit` Check 2 globs only `*.ps1`; ARCH/README/CONTRIBUTING have 200+ non-ASCII hits (em-dash U+2014, box-drawing U+2500/U+2502/U+251C/U+2514, smart-arrow U+2192). Filed as #322. (iii) Auto-fixed: PR #321 + #320 full label sets, `go:yes` removed from closed #235. Verdict: `3 fixes, 2 flags`.
- **2026-05-17 -- Sprint 12 session-end audit (develop `5dfc476`).** All 9 Sprint 12 issues closed across 3 waves + 2 fold PRs (10 PRs: #313/#314/#315/#316/#318/#320/#321/#323/#324). Tree clean, 0 worktree orphans, 4-5 stale `origin/squad/*` tracking refs (Ralph EOS). Label state: 8 squad:* present, `squad:scribe` MISSING (#319 gap). PR labels: only #320/#321 carry full set among Sprint 12 merges -- process gap. History-tails: ALL agents compliant. Skills: `label-hygiene` + `test-harness-pattern` template-compliant; `abstraction-threshold` not formalized. **Scribe inbox-drain bug surfaced:** decisions.md grew 44473->57253 B (drain content done) but 4 inbox files NOT deleted. CHANGELOG `[Unreleased]`: 9 entries -- 0.9.2 cut justified.
- **Lesson (Scribe inbox-drain bug):** When folding inbox decisions, the per-topic-file `git add` AND `git rm -- decisions/inbox/*.md` MUST land in the SAME commit so drain is atomic with merge. Forward-fix expectation for next Scribe cycle (PR #319 spec; re-tested in Sprint 13 W1 fold).
- **Lesson (squad: label set incomplete):** Standard label set covers 8 engineering agents but omits `squad:scribe`. Service-role follow-ups force routing miss. Recommend next label sweep create `squad:scribe` (and audit `squad:ralph` usage; precedent exists for service-role labels).
- **Recurring incident references preserved:** worktree-isolation (Sprint 4 race condition + Sprint 12 W2 CWD-resolution variant), ASCII scope gap (#322, `*.ps1`-only pre-commit), CP1252 byte 0x94 trap in PowerShell string literals, `autocrlf` and `AllScope` alias hazards, atomic-drain (PR #323 bug).

## 2026-05-17 Sprint 13 Wave 1

- **2026-05-17 -- Sprint 13 Wave 1: formalized worktree-remove-FIRST as a Squad skill (issue #317).** Created `.squad/skills/worktree-remove-first/SKILL.md` (full frontmatter: `confidence: high`, `source: earned (issue #317)`, `domain: repo-meta, release-flow`) capturing the five-step merge sequence proven 5-of-5 in Sprint 12 Wave 2: harvest -> `git worktree remove --force` -> `git branch -D` -> `gh pr merge --admin --squash --delete-branch` -> verify. Documented the `--merge` swap for release PRs (PRs #328 / 0.9.2), the recovery path for "forgot and merged with worktree attached" (Ralph EOS fallback from PR #295), and the precise reason the order matters (gh's local pre-flight aborts the remote-delete step when a worktree owns the branch). Cited 5 successful applications: PRs #320, #321, #323, #324, #327 plus release #328. Cross-linked to the existing `worktree-isolation` skill (spawn-head concern) and to issue #300 (the prematurely-closed earlier tracker -- this skill is the actual fix).
- **Decision: new skill over extending `worktree-isolation`.** Reviewed `.squad/skills/worktree-isolation/SKILL.md` -- it documents the Sprint 4 agent-dispatch race condition (spawn-time concern). The merge tail is a distinct teardown-time concern with a different trigger surface, different mitigation, and different audience (coordinator/Ralph vs spawning dispatcher). Separate skills stay tightly scoped and independently citeable; the new skill's References section cross-links back. Format follows the `label-hygiene` SKILL convention (YAML frontmatter + Context/Patterns/Examples/Anti-Patterns sections) since `worktree-isolation` predates the template.
- **Companion doc edits:** appended a 2-line "Merging Squad PRs from worktrees" subsection to CONTRIBUTING.md under "Parallel Agent Work" pointing readers at the new skill (full content stays in the skill file, not duplicated). CHANGELOG `[Unreleased]` -> `### Added` notes the skill addition.
- **Hygiene tail:** this history entry + decision drop at `.squad/decisions/inbox/jiminy-w1-2026-05-17-issue-317-skill.md`. No code changed (skill formalization is pure docs). Stayed in custodian voice -- codifying a proven pattern is hygiene formalization, not feature work.

## 2026-05-17 Sprint 13 Wave 1 Post-Batch Audit

FYI -- this file is over 15KB gate (19852 bytes pre-append). Forward fix needed in Scribe W1 fold or via re-compress; Scribe's W1 fold preserved both her baseline AND this agent's Wave 1 hygiene-tail entry through rebase.

- **Scope:** PRs #330 (Mickey #325+#326), #331 (Jiminy #317), #332 (Scribe #319). Develop @ 114ea63, tree clean, only main worktree, no local squad/* branches.
- **Sec 1 (cleanliness):** Tree clean. One stale remote tracking ref `origin/squad/319-history-archival` still present -- Ralph EOS scope (Jiminy cannot delete branches per charter). No rogue files at repo root.
- **Sec 2 (squad hygiene):** 9 agent history.md files present (chip 12470, donald 12712, goofy 13923, mickey 13830, pluto 14792, ralph 9503, scribe 13334, doc 10169 -- all under gate; **jiminy 19852 OVER**). Inbox has 3 drops all well-named per `<agent>-<batch>-<date>-<topic>.md`. decisions.md does not exist as a single file -- per-topic files only (doc-and-jiminy-automation 12115, mickey-architecture-entry-point 2710, pluto-dotfiles 2074). Skills dir has 13 entries incl new `worktree-remove-first/`.
- **Sec 3 (labels):** PRs #330/#331/#332 all carry full 4-label set (priority + type + area + squad). Process discipline restored vs Sprint 12.
- **Sec 4 (hygiene-tail):** Mickey, Jiminy, Scribe each appended own history.md AND dropped inbox note. 3/3 compliant.
- **Sec 5 (skill drift):** Mickey flagged "batch narrow doc fixes into one PR" as 2nd application -- candidate surfaced, NOT formalized (one more application would justify). Scribe flagged "history-compression heuristic" as 1st application -- watch for second.
- **Sec 6 (forward-fix):** Scribe history Wave 1 entry explicitly re-confirms atomic-rm forward-fix from PR #323 bug. Captured.
- **Sec 7 (backlog):** Only #322 (pre-commit ASCII scope gap) open under `release:backlog` -- Wave 2 candidate.
- **Sec 8 (recommendation):** GO for Wave 2 (#322 fan-out to Goofy + Mickey). Suggest 0.9.3 cut AFTER Wave 2 ships; current Unreleased delta is light.
- **Flags for Coordinator:** (a) `.squad/agents/doc/` is NOT a stray -- has full charter (Fact Checker, hired 2026-05-16, 7101 B charter.md). Roster of 9 in this audit brief omits it. DECISION NEEDED: formally adopt doc into roster + add `squad:doc` label, or surface intent to retire. NOT auto-fixed. (b) jiminy/history.md over-gate. (c) stale remote tracking ref `origin/squad/319-history-archival` -- Ralph EOS.
- **Auto-fixes applied:** None. Inbox drain not performed (Scribe W1 fold owns that; content not yet in decisions store).
- **Verdict:** Jiminy fixed 0 items, flags 3 (1 roster gap, 1 over-gate file, 1 stale ref).
