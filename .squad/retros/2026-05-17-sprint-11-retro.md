# Sprint 11 (formerly Sprint T) Retro -- 2026-05-17

Sprint 11 was the FIRST sprint to exercise the new SOPs from PR #293
(`.squad/decisions/doc-and-jiminy-automation.md`). The post-batch Jiminy
audit gate and session-end Jiminy gate both fired and ran clean. Four PRs
shipped in parallel across worktree-isolated agents, one bonus pair of
Jiminy audits landed, and the Sprint 10 (formerly Sprint S) spillover issue #292 was closed.

## Sprint 11 at a Glance

| #   | Owner       | Title                                           | PR   | Status         |
|-----|-------------|-------------------------------------------------|------|----------------|
| #229 | Mickey     | ARCHITECTURE.md refresh                         | #298 | Merged         |
| #230 | Goofy      | Move auth.ps1 to scripts/windows/tools/         | #297 | Merged         |
| #233 | Pluto      | Document PSScriptAnalyzer advisory intent       | #296 | Merged         |
| #292 | Goofy      | Harden $LASTEXITCODE leakage (5 sites)          | #301 | Merged         |
| (bonus) | Jiminy | Wave 1 post-batch audit (clean)                 | #299 | Merged         |
| (bonus) | Jiminy | Session-end audit (clean)                       | #302 | Merged         |
| #300 | (Coordinator) | gh --delete-branch quirk tracker             | issue | Open           |
| (closed) | Mickey | squad-cli versioning design (resolved by #282) | #232 | Closed retroactively |

## What Went Well

- **First exercise of #293 SOPs -- Jiminy gates fired automatically, ran
  clean both times.** The post-batch audit (PR #299) and session-end audit
  (PR #302) both passed with zero findings. This validates the 3-surface
  enforcement model (charter + loop.md + ceremonies.md) introduced in
  Sprint 10's action-item closeout.
- **Sequential Goofy ordering worked cleanly.** #230 (file move) merged
  first, then #292 (LASTEXITCODE mitigation in the new location) merged
  with zero churn. The Coordinator's sequentialization call avoided the
  inter-PR collision class that hit Sprint 10.
- **4-PR parallel batch shipped cleanly.** Wave 1 (Mickey #298, Goofy
  #297, Pluto #296) plus Wave 2 (Goofy #301) all landed without
  cross-contamination, thanks to worktree isolation.
- **Test discipline maintained.** Goofy added Group EE tests (5 static-
  source assertions for the $LASTEXITCODE sites) in #301 -- the first new
  test group letter past DD.
- **SKILL.md audit table closed out.** The `pwsh-lastexitcode/SKILL.md`
  audit table had 5 known unmitigated sites; all 5 are now resolved by
  #301. Sprint 10 action item fully retired.
- **Issue #232 closed retroactively.** Mickey's squad-cli versioning
  design question was already resolved by the tool-version-pin sweep in
  Sprint 10 (#282). Closing it cleared a stale backlog item with no new
  work required.

## What Didn't Go Well

- **gh `--delete-branch` quirk hit 67% rate (6 of 9).** The GitHub CLI's
  `gh pr merge --delete-branch` flag silently fails to delete the remote
  branch in about two-thirds of merges. Issue #300 filed mid-sprint to
  track. No workaround deployed yet; stale branches accumulate until
  Ralph's EOS sweep.
- **CHANGELOG conflict on Mickey's #298.** Mickey and Pluto both wrote to
  `### Changed` in the same `[Unreleased]` block. Predictable per the
  CHANGELOG Conflict Strategy in CONTRIBUTING.md, but still cost one
  rebase round-trip on #298 after #296 merged first.
- **Mickey's #229 surfaced 2 out-of-scope ARCHITECTURE.md follow-ups.**
  The "Script Conventions" table and "Dependency Order Windows chain"
  sections were flagged as incomplete but declared out of scope for this
  sprint. They remain candidates for Sprint 12 (formerly Sprint U).

## Action Items

- **[Coordinator] Decide on #300 fix.** Options: CONTRIBUTING note
  advising manual `git push origin --delete`; a helper script in
  `scripts/`; or a PR template reminder. Pick one for Sprint 12.
- **[Coordinator] Triage Mickey's 2 ARCHITECTURE.md follow-ups.** "Script
  Conventions" table + "Dependency Order Windows chain" -- either file as
  Sprint 12 issues or skip.
- **[Standing] Continue exercising #293 SOPs in Sprint 12+.** The gates
  held this sprint; maintain the cadence.

## SOP Exercise Log

Sprint 11 was the first sprint with the SOPs from PR #293 in effect.
Status of each gate:

| Gate                        | Triggered? | Outcome        | Evidence |
|-----------------------------|------------|----------------|----------|
| Post-batch Jiminy audit     | Yes        | Ran clean      | PR #299  |
| Session-end Jiminy audit    | Yes        | Ran clean      | PR #302  |
| Doc worktree pattern        | No (Doc not dispatched) | SOP held | N/A |
| 3-surface enforcement       | Yes        | Intact         | charter + loop.md + ceremonies.md all reference the gates |

**Verdict:** All three exercisable gates passed. The Doc worktree pattern
was not triggered because no fact-check work was needed this sprint;
that is an expected no-op, not a gap.

## Sprint 12 Planning Hooks

- **5 P3 backlog items deferred from Sprint 10:** #235, #236, #237, #238,
  #254. Coordinator to re-triage at Sprint 12 kickoff.
- **Mickey's ARCHITECTURE.md follow-ups:** "Script Conventions" table,
  "Dependency Order Windows chain." Low effort, docs-only.
- **Issue #300:** gh --delete-branch quirk. May be absorbed into a
  CONTRIBUTING note or helper script.

## Stats

- **PRs merged this sprint:** 6 (#296, #297, #298, #299, #301, #302).
- **Agents dispatched:** 4 unique (Mickey, Goofy, Pluto, Jiminy). Goofy
  ran twice (sequential). Jiminy ran twice (post-batch + session-end).
- **Real bugs caught pre-merge:** 0 (Doc not dispatched; no fact-check
  needed).
- **Real bugs shipped post-merge:** 0.
- **New skills captured:** 0 (Sprint 10's `pwsh-lastexitcode` skill was
  completed this sprint via #301's mitigations, but no new SKILL.md
  authored).
- **New test groups:** 1 (Group EE in `tests/test_windows_setup.ps1`).
- **Issues filed mid-sprint:** 1 (#300, gh --delete-branch quirk).
- **Issues closed:** 2 (#292 via #301; #232 retroactively).
- **Stale issue carried forward:** 1 (#300, open).

## Reflection

Sprint 11 was a clean execution sprint. The headline result is that the
SOPs from PR #293 -- which were designed in Sprint 10's action-item
closeout -- ran for the first time and passed without human intervention.
The Jiminy audit gates fired on schedule, produced zero findings, and
merged cleanly. That is exactly the desired outcome: the gates exist so
that when something IS wrong, it gets caught; this sprint, nothing was.

The sequential Goofy pattern (file move first, then edit in new location)
validated the Coordinator's decision to not parallelize dependent work.
Zero churn, zero rebase conflicts on Goofy's PRs. Compare this to Sprint
S's inter-PR function-rename collision which cost 30 minutes of merge
sequencing.

The one process friction -- gh --delete-branch failing 67% of the time --
is external to the squad's control but worth tracking (#300). The
CHANGELOG conflict on Mickey's #298 is the same predictable class from
Sprint 10; the mitigation (union both entries per CONTRIBUTING strategy)
worked, but the single rebase round-trip remains a tax on the last PR to
merge in any wave that touches `### Changed`.

**Board status:** develop @ `0f3b7d7`, working tree clean except this
retro branch. 6 PRs merged, 0 inbox files drained, 1 retro authored.
Ready for Sprint 12 kickoff.
