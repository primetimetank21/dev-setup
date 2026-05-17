# Scribe History

**Role:** Session Logger, Memory Manager & Decision Merger  
**Mode:** Always spawned as background task. Never blocks user conversation.

---

## Session Logs Created

All session logs written to `.squad/log/`.

| Date | Topic | Status |
|------|-------|--------|
| 2026-04-07 | Squad init | ✅ |
| 2026-04-07 | Issues created | ✅ |
| 2026-04-08 | Sprint 5 retro | ✅ |
| 2026-04-08 | Sprint 5 close | ✅ |
| 2026-04-13 | Session wrap | ✅ |
| 2026-04-18 | PS 5.x hotfix retro | ✅ |
| 2026-04-18 | setup.ps1 scriptdir fix | ✅ |
| 2026-04-18 | Sprint 6 kickoff | ✅ |
| 2026-04-18 | Sprint 6 alias parity | ✅ |
| 2026-04-18 | Sprint 6 wrapup | ✅ |
| 2026-04-18 | **Sprint 7 implementation** | ✅ |
| 2026-05-16 | PR #200 merge + Issue #197 closed | ✅ |

---

## Decisions Merged (2026-04-18)

Merged 6 decision inbox files into `decisions.md`:

1. **chip-121-hooks.md** — Git hooks implementation details
2. **chip-123-ci-triage.md** — CI triage findings & PS 5.1 fixes
3. **mickey-122-branch-isolation.md** — Branch isolation rule rationale
4. **mickey-bug-issues-124-125.md** — Bug issue context (Sprint 6 hotfix)
5. **mickey-hotfix-wrap.md** — Sprint 6 hotfix merge summary
6. **mickey-review-130.md** — PR #130 review outcomes

All inbox files deleted after merge.

---

## Orchestration Logs Created (2026-04-18T20-53-40Z)

Per-agent execution logs written to `.squad/orchestration-log/`:

1. `2026-04-18T20-53-40Z-hotfix-sprint-wrap.md` — Mickey (Sprint 6 hotfix to main)
2. `2026-04-18T20-53-40Z-chip-121-git-hooks.md` — Chip (Git hooks implementation)
3. `2026-04-18T20-53-40Z-mickey-122-branch-isolation.md` — Mickey (Branch isolation docs)
4. `2026-04-18T20-53-40Z-chip-123-ci-triage.md` — Chip (CI triage & PS guards)
5. `2026-04-18T20-53-40Z-mickey-review-129.md` — Mickey (PR #129 review)
6. `2026-04-18T20-53-40Z-mickey-review-130.md` — Mickey (PR #130 review)
7. `2026-04-18T20-53-40Z-sprint7-wrap.md` — Mickey (Sprint 7 wrap pending)

---

## Cross-Agent History Updates (2026-04-18)

Appended team updates to:
- **Chip:** Added Sprint 7 completion summary (Issues #121, #123, PR #130)
- **Mickey:** Added full Sprint 7 execution summary (all agents, PRs, issues)

---

## Final Status

✅ All orchestration logs created
✅ All decision inbox files merged and deleted
✅ All session logs written
✅ Cross-agent history updated
✅ Ready for git commit & push

---

## Learnings

- `git add .squad/` stages everything under `.squad/` including pre-existing untracked rogue files. Before staging, run `git status --porcelain -- .squad/` and confirm only intended files appear. If rogues exist, escalate to coordinator (do not auto-commit them).
- Decision inbox path (`.squad/decisions/inbox/`) is gitignored by design (`.gitignore:4`). Inbox files are drop-box drains, never committed. Drain by reading, merging content into `decisions.md`, then deleting the inbox file.
- Canonical squad write locations only: `agents/{name}/charter.md|history.md`, `decisions.md|decisions-archive.md`, `decisions/inbox/*.md`, `orchestration-log/*.md`, `log/*.md`, `skills/{name}/SKILL.md`, `templates/*.md`, `casting/*.json`, `identity/*.md`, `plugins/*.json`, `team.md|routing.md|ceremonies.md|config.json`. Any other path is rogue; flag to Jiminy.
- Canonical log dir is `.squad/log/` (singular). The stray `.squad/logs/` (plural) was deprecated 2026-05-16; do not write to `logs/`.
- Append-only convention for `casting/history.json`: mid-assignment additions use new entries with `type: "addendum"` and `parent_assignment_id`. Never mutate prior snapshots.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.


### 2026-05-16 -- Session drain: Sprint 8-hotfix (formerly Sprint Q) wrap
- Drained 3 inbox decisions: mickey-squad-0.9.4-upgrade (PR #262), mickey-hire-doc-fact-checker (PR #263), doc-pr-263-fact-check (Doc's first verification)
- Appended Doc's first-run reflections to .squad/agents/doc/history.md
- Appended Mickey's PR #262 audit reflection to .squad/agents/mickey/history.md (if missing)
- Created session log: .squad/log/2026-05-16-sprint-q-wrap-0.8.0-0.9.4-doc-hire.md

### 2026-05-16 -- Session drain: Sprint 9 (formerly Sprint R) wrap + retro + agent histories
- Drained 1 inbox decision: doc-sprint-r-batch-fact-check.md (Doc's batch verification of 5 PRs)
  - Incorporated Doc's verdicts into retro: 2 real bugs caught pre-merge (autocrlf in #267, pipefail in #269)
  - Documented Group X collision friction and CHANGELOG multi-PR conflicts
- Created .squad/retros/2026-05-16-sprint-r-retro.md with full Sprint 9 recap:
  - 5 PRs shipped (#265, #266, #267, #268, #269)
  - Follow-up #271 filed (uninstall hooksPath gap)
  - Wins: parallel worktrees, batch fact-check caught real bugs, E2E summary job
  - Learnings: pre-commit Check 5 blocks direct develops, CHANGELOG conflicts predictable
  - Action items: Group letter pre-assignment, charter clarification, lint checklist
- Appended Sprint 9 entries to 4 agent history files:
  - chip/history.md: PR #267 (hook behavioral tests, autocrlf fix, Group Y rename)
  - goofy/history.md: PR #268 (winget exit assertion, Assert-LastExit pattern, Group X)
  - pluto/history.md: PRs #266 (hooksPath docs) + #269 (.bak rotation, pipefail fix)
  - ralph/history.md: already written by Ralph, folded into drain PR (no direct develop commit)

### 2026-05-17 -- Session drain: Sprint 10 (formerly Sprint S) retro + agent histories fold
- Created `.squad/retros/2026-05-17-sprint-s-retro.md`: full Sprint 10 recap covering
  10 PRs (#274-#283), Doc batch fact-check verdicts, version-pin anti-pattern resolution,
  $LASTEXITCODE / YAML quoting / function-rename collision learnings, and action items
  for Sprint 11 (formerly Sprint T).
- Folded Jiminy's modified `.squad/agents/jiminy/history.md` (Sprint 10 end-of-sprint
  audit entry that he could not direct-commit per pre-commit Check 5) into the drain PR.
- Backfilled Mickey Sprint 10 entry in `.squad/agents/mickey/history.md` for PR #274
  (Sprint 9 retro action items: Ralph develop-commit ban, Group letter SOP, CHANGELOG
  conflict strategy). Mickey shipped #274 without writing his own history entry; Jiminy
  flagged the gap in his end-of-sprint audit.
- Drained 2 inbox decisions locally: `doc-sprint-s-batch-fact-check.md` and
  `doc-pr-282-fact-check.md`. Both already folded into `doc/history.md` via PRs #281
  and #283; deletion is non-tracked (inbox is gitignored).
- Skipped Ralph history.md write: Ralph has not been dispatched for Sprint 10 EOS yet;
  six stale remote `squad/*` branches survive post-merge. Recommended Coordinator
  dispatch Ralph after this PR merges.
- Logged session locally to `.squad/log/2026-05-17-sprint-s-retro-fold.md`
  (gitignored, local-only).

### 2026-05-17 -- Sprint 11 retrospective

- Created `.squad/retros/2026-05-17-sprint-t-retro.md`: full Sprint 11 recap covering
  6 PRs (#296-#302), first exercise of #293 SOPs (Jiminy gates fired clean both
  times), sequential Goofy pattern validation, Group EE test addition, and the
  gh --delete-branch quirk (#300).
- Sprint 11 was the first sprint with the post-batch Jiminy audit gate, session-end
  Jiminy gate, and Doc worktree pattern SOPs in effect. All exercisable gates passed.
- Action items for Sprint 12 (formerly Sprint U): #300 fix decision, Mickey's ARCHITECTURE.md follow-ups,
  continued SOP exercise.
- Precedent: PR #284 (Sprint 10 retro).

### 2026-05-17 -- Post-0.9.0 Action Items Closeout
- Amended `.squad/retros/2026-05-17-sprint-s-retro.md` in place with a new
  "Action Items Closed (post-0.9.0)" section at the bottom. No new retro
  file authored -- the 3-PR follow-up batch is too small to warrant its
  own doc. Section folds three closures into the existing Sprint 10 retro:
  - PR #291 (Mickey) -- `.squad/skills/pwsh-lastexitcode/SKILL.md` +
    CONTRIBUTING "PowerShell Exit Code Discipline" section + audit of
    `scripts/windows/`. Closes #288. Audit surfaced 5 unmitigated
    `$LASTEXITCODE` sites in `setup.ps1` + `auth.ps1`, filed as #292
    (Goofy, P2) and tracked as Sprint 11 spillover.
  - PR #293 (Mickey) -- combined decision + template changes for Doc
    worktree pattern (Option B: dedicated `..\dev-setup-doc` worktree on
    per-sprint `squad/doc-history-sprint-<N>` branch) and Jiminy
    auto-dispatch (Option A: 3-surface checklist in charter + loop.md +
    ceremonies.md). Closes #289 + #290. Replaces the dual-fold-PR pattern
    that produced #281 + #283 in Sprint 10.
- Verified no stale doc references in README.md or ARCHITECTURE.md (no
  mentions of "Doc commits to develop", "Jiminy dispatch is manual",
  Doc worktree pattern, or `pwsh-lastexitcode` at all -- those concepts
  live in CONTRIBUTING.md and `.squad/` only). CONTRIBUTING.md already
  updated by #291 + #293; CHANGELOG `[Unreleased]` already references
  #288/#289/#290 correctly via Mickey's entries. No stale-doc edits
  needed in this PR.
- Inbox state: empty (`.squad/decisions/inbox/` clean from Sprint 10
  drain). No additional drain required.
- Verification checklist seeded for Sprint 11: first multi-agent batch
  exercises Jiminy auto-dispatch gate; first Doc fact-check exercises
  the dedicated-worktree pattern; #292 picked up in Sprint 11 triage.
- Hard guardrails honored: no edits to `[0.9.0]` CHANGELOG section,
  no new retro file, no edits to other agents' history.md, no direct
  develop commits (branch `squad/scribe-post-090-retro` from develop @
  `94b696c`).

### 2026-05-17 -- Sprint 11 retro filed (PR #303)

- Filed `.squad/retros/2026-05-17-sprint-11-retro.md` (originally named
  `2026-05-17-sprint-t-retro.md`) via PR #303 on branch
  `squad/scribe-sprint-t-retro`. Merged at 04:16 UTC, before the 0.9.1 release cut.
- This retro covered Sprint 11 proper -- 4 work PRs (#296, #297, #298, #301)
  closing 4 issues (#229, #230, #233, #292), plus 2 bonus Jiminy audit PRs
  (#299, #302). First sprint exercising the PR #293 SOPs; all exercisable
  gates passed clean.
- The retro filename was renamed via `git mv` in PR #308 minutes later (Tier 3
  sprint-naming sweep). The H1 picked up the `(formerly Sprint T)` alias.

### 2026-05-17 -- Mini-event retro: 0.9.1 release + sprint naming rename

- Created `.squad/retros/2026-05-17-sprint-11-release-and-rename-retro.md`.
  Mini-event retro covering work that landed AFTER PR #303 in the same session:
  0.9.1 release (PRs #305 + #307, tag, GH release), the Tier 3 sprint-naming
  sweep (Mickey PR #308 + Doc commit `56c3c1f`), and the Sprint 12 backlog
  enumeration (2 new issues #309 + #310).
- Decision: mini-events get their own tighter retro file rather than folding
  into a session log. Rationale: (a) sprint naming convention is now permanent
  policy worth surfacing in retro history; (b) the Doc no-worktree decision
  and the `area:scripts` label gotcha are operational learnings that would get
  lost in `.squad/log/`. Two-page retro is the right size; full sprint retros
  remain the larger format.
- Updated `.squad/agents/mickey/history.md`: appended PR #308 merge outcome,
  Sprint 12 backlog summary, label gotcha note.
- Updated `.squad/agents/doc/history.md`: appended pattern note documenting
  the one-off fact-check NO-worktree decision rule (codified in the retro).
- Updated `.squad/agents/scribe/history.md` (this entry): logged Sprint 11
  retro PR #303 plus this mini-event retro.
- Hard guardrails honored: branch `squad/scribe-0.9.1-rename-retro` from
  `develop @ c93a54c`, no direct develop commits, ASCII only in new content,
  conventional commit prefix `docs(scribe):`, PR not merged (left for
  coordinator review). No inbox drop (no reusable decision worth recording --
  the policy is already in CONTRIBUTING.md).

## Learnings (Scribe)

- **Mini-event retros work.** When a session ships work that does not belong
  in a full sprint retro (release cut + meta-cleanup + backlog sweep), a
  smaller-scope retro file in `.squad/retros/` is the right home. Keep it
  to ~1-2 pages. Reference but do not rewrite any sprint retro the mini-event
  follows.
- **Label-vocab gotcha is worth a one-line entry in any retro that hits it.**
  Future Scribes filing retros that mention `gh issue create` failures
  (`area:scripts` not existing, missing `priority:p4`, etc.) should call out
  the actual label set in the retro so the next session does not repeat the
  lookup. Six area labels exist: ci, hooks, windows, macos, linux, meta.
- **Sprint rename sweeps require Scribe to think about retro filenames.** When
  a Tier 3 rename runs in the same session as a retro PR (this session: #303
  filed then #308 renamed it), the retro file itself gets `git mv`-ed and the
  H1 picks up the alias. Not a problem -- just a pattern worth flagging so
  future Scribes do not double-write or get confused about which filename is
  canonical.
- **`(formerly Sprint X)` aliasing on first-occurrence-per-file** is now the
  team convention for any historical reference. Applied automatically in
  this retro for `Sprint T` -> `Sprint 11` (the retro H1 itself uses the
  new name only; old references inside CHANGELOG headers and other retros
  carry the alias on first mention).
- **Sprint 12 Wave 1 fold (2026-05-17).** Folded 5-agent batch with 2 inbox
  decisions, 5 orchestration-log entries, 1 session log, and a Jiminy
  history-rescue. Patterns earned:
  - **5-agent batch fold pattern.** When Wave N closes with 4-5 merged PRs +
    1 audit-only issue close, one Scribe fold PR covers the whole wave.
    Spawn manifest goes straight from coordinator into individual
    orchestration-log entries -- one file per agent, ISO 8601 UTC timestamp
    with colons replaced by dashes (`2026-05-17T06-01-33Z-{agent}-{slug}.md`).
    Keep each entry small (~1-2 KB) using the template field table.
  - **Jiminy-history-rescue pattern.** When an agent has violated the
    develop-commit ban by writing loose to their own `history.md` on develop,
    Scribe rescues that file in the same fold PR as the inbox drain. Stage
    `.squad/agents/{agent}/history.md` explicitly with `git add -- <path>` --
    do NOT broaden the staging glob. Note the rescue in the PR body so the
    audit trail is clear ("pre-existed in main checkout before this PR --
    earlier rules violation now resolved"). This is the documented drain SOP.
  - **Obsolete fold-request handling.** A `history-fold-request` inbox file
    is OBSOLETE if the target agent self-appended the content directly
    (rules violation aside, the content is in place). Delete the inbox file
    without re-merging (would duplicate content). Document the disposition
    in decisions.md as a "Fold note (Scribe)" subsection on the partner
    decision entry so the audit trail survives the delete.
  - **Size-gated 7-day archive cut.** At >= 50 KB, the 7-day rule fires.
    Find the date boundary (entries dated > N-7 days are KEEP; <= N-7 days
    are ARCHIVE). Cut on the trailing `---` separator before the first
    KEEP entry so both files have clean section boundaries. Move content
    via PowerShell `[System.IO.File]::WriteAllText` with
    `UTF8Encoding($false)` (no BOM) to preserve existing em-dashes in
    archive without polluting the rewritten live file. Result this fold:
    164,339 B -> 44,473 B live, 122,314 B archive.
  - **History-summarization scope tension.** When a fold's staging scope
    is restricted (per-task spec) and the 15-KB hard gate fires on agents
    outside that scope, defer summarization and flag in the health report
    rather than expanding the staging glob. The hard gate fires next pass;
    discipline beats sprawl.

### 2026-05-17 -- Sprint 12 Wave 2 fold

- Drained 4 inbox decisions to .squad/decisions.md (appended under new
  "## 2026-05-17 entries (Sprint 12 Wave 2 fold)" section):
  - mickey-arch-windows-dep-20260517.md (ARCH Windows Dep Order, closes #310)
  - donald-test-harness-20260517.md (bash test harness pattern, closes #237)
  - goofy-install-guard-deferral-20260517.md (Case B closure, abstraction
    3-site rule, closes #235 as not_planned)
  - jiminy-wave-2-audit-20260517.md (worktree-isolation remediation, pre-commit
    ASCII scope gap surfaced as #322)
- Folded staged history modifications from MAIN checkout (goofy + jiminy) by
  copying file content into this worktree and staging via explicit git add --.
  Same content path as a normal commit -- coordinator will clear the M state
  on main after this PR merges with git checkout -- .squad/agents/{goofy,jiminy}/history.md.
- Decisions.md gate state: pre-fold 44,473 B -> post-fold 57,253 B. **50 KB
  hard gate crossed, but NO entries eligible for 7-day archive cut** -- the
  oldest live entry is dated 2026-05-14 (3 days old). Strict-rule reading: the
  archive step ran with empty eligibility set. File will remain at ~57 KB until
  next fold when the 2026-05-14 entries age past the 7-day window.
- Orchestration log entries written for the 5 wave events (PR #320, PR #321,
  Goofy #235 Case B close, Jiminy audit, issue #322 filing). Directory is
  gitignored -- entries are local-only operational logs.
- Session log: `.squad/sessions/2026-05-17.md` (gitignored, local-only) per
  dispatch instruction. Note: prior Scribe convention pointed at `.squad/log/`
  (singular) for session logs -- both are gitignored, both work, dispatch wins.
  Possible drift between dispatch template and Scribe charter convention worth
  reconciling in a future pass.
- CHANGELOG [Unreleased] -> ### Changed: one fold-note entry (Sprint 12
  Wave 2 fold).
- Hard guardrails honored: branch squad/scribe-sprint-12-wave-2-fold from
  develop @ def5e59, no direct develop commits, conventional commit prefix
  docs(scribe):, explicit-path staging only (no git add .squad/), worktree
  CWD pinned at every file write (per Jiminy Wave 2 audit remediation).
- **History gate WARNINGS (>= 15 KB, no archival this fold per #319 scope):**
  scribe 15.8 KB (this entry pushes past gate), chip 36.9 KB, donald 28.5 KB,
  goofy 39.9 KB, jiminy 24.3 KB, mickey 75.5 KB, pluto 29.7 KB, ralph 23.9 KB.
  Eight agents at or above the warn line. Pluto and Doc remain healthy / low.
  Recommend Coordinator schedule history-archival sweep (issue #319 scope)
  after Wave 2 settles.
- Main-checkout post-commit verification: see PR description / summary.
