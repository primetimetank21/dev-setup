# Sprint 11 Release + Sprint Naming Rename Retro -- 2026-05-17

> Mini-event retro covering work that landed AFTER `.squad/retros/2026-05-17-sprint-11-retro.md`
> (PR #303) was filed. This is not a sprint retro -- it is the wrap-up of the 0.9.1 release cut
> and the Earl-driven sprint-naming convention revert, plus Sprint 12 backlog enumeration.

## Summary

Three things shipped between the Sprint 11 retro and Sprint 12 kickoff:

1. **0.9.1 released.** Fifth tagged release for this team (after 0.7.0, 0.8.0, 0.9.0,
   and the Sprint 11 retro PR). Standard release pattern: `release/0.9.1` branch
   from `develop`, CHANGELOG fold of `[Unreleased]` to a versioned section, PR back
   to develop (#305), PR develop -> main (#307, merged with `--admin --merge`),
   annotated tag pushed, GH release created.
2. **Sprint naming convention reverted -- letters to numbers.** Earl spotted mid-release
   that Sprints 1-7 were numeric but Sprints Q/R/S/T were letters. Tier 3 sweep
   shipped via PR #308 (Mickey, 21 files, ~170 refs, 4 retro files renamed via
   `git mv`) + a Doc fact-check commit `56c3c1f` that fixed one missing alias in
   the CHANGELOG 0.8.0 header. CONTRIBUTING.md gained a "Sprint Naming Convention"
   section codifying the mapping table, first-occurrence aliasing convention
   (`(formerly Sprint X)` parenthetical on first mention per file), and the
   `-hotfix` suffix rule for out-of-cadence sprints.
3. **Sprint 12 backlog enumerated.** 7 inherited P3 issues plus 2 newly filed issues
   (#309, #310) surfaced by PR #298 review and deferred from Sprint 11.

## Timeline (this mini-event)

| When           | What                                                                 |
|----------------|----------------------------------------------------------------------|
| 04:16 UTC      | PR #303 merged: Sprint 11 retro filed (closes the prior retro scope) |
| ~04:30 UTC     | Coordinator cut `release/0.9.1` from develop; CHANGELOG fold applied |
| 04:39 UTC      | PR #305 merged (release/0.9.1 -> develop)                            |
| mid-release    | Earl flags letter/number sprint-naming inconsistency; picks Tier 3   |
| ~05:00 UTC     | Mickey dispatched to chore/sprint-naming-convention branch           |
| 05:24 UTC      | PR #308 merged (21-file rename sweep, 297+/189-)                     |
| post-#308      | Doc dispatched without worktree for one-off fact-check               |
| 56c3c1f        | Doc commit: fixed 0.8.0 CHANGELOG header missing `(formerly Sprint Q)` alias |
| 05:29 UTC      | PR #307 merged (develop -> main) via `--admin --merge`               |
| 05:29 UTC      | Tag `0.9.1` annotated and pushed                                     |
| 05:29 UTC      | GH release created at https://github.com/primetimetank21/dev-setup/releases/tag/0.9.1 |
| post-release   | Sprint 12 backlog enumerated; 2 follow-up issues filed (#309, #310)  |

## What Went Well

- **Release pattern is muscle memory now.** Fifth release in a row using the same
  flow (release branch -> CHANGELOG fold -> PR to develop -> PR develop -> main ->
  `--admin --merge` -> tag -> GH release). Zero deviation from the SOP; total cycle
  under an hour despite the rename detour mid-flight.
- **Aliasing convention preserved grep continuity.** The `(formerly Sprint X)`
  first-occurrence parenthetical means anyone searching for old PR titles, commit
  messages, or external references to Sprint Q/R/S/T will still find the new
  numeric retros and CHANGELOG sections. The mapping table in CONTRIBUTING.md acts
  as the canonical lookup.
- **Doc fact-check caught a real consistency gap.** Mickey's rename sweep was
  thorough but missed one header: CHANGELOG.md `[0.8.0]` lacked the `(formerly
  Sprint Q)` alias that `[0.9.0]` and `[0.9.1]` both carried. Doc's full 9-lane
  audit (mapping consistency, alias convention, filename renames, orphan check,
  historical narrative, CHANGELOG headers, CONTRIBUTING section, issue #306 body,
  Mickey's own history entry) caught it. Verdict: Verified after the one-line fix.
- **Sprint 11 retro filename rename was clean.** When the rename sweep ran, the
  Sprint 11 retro itself (filed minutes earlier as Sprint T) needed renaming.
  `git mv` plus the alias convention in the H1 header preserved chronology
  without any narrative rewrite required.
- **Issue #306 caught the in-flight body update need.** Mickey updated #306 mid-
  sweep from "Sprint U" -> "Sprint 12" so the issue body stays consistent with
  the new naming when picked up in Sprint 12.

## What Went Wrong / Surprises

- **`area:scripts` label does not exist.** When filing #309 and #310 (both touch
  `scripts/`-adjacent ARCHITECTURE prose), the Coordinator's first attempt used
  `area:scripts`. Only six area labels exist in this repo: `ci`, `hooks`,
  `windows`, `macos`, `linux`, `meta`. Settled on `area:meta` for both. Worth
  codifying as a one-line check before any `gh issue create`.
- **Mickey overloaded for Sprint 12.** Sprint 12 backlog has 9 open P3 issues
  routed by label, of which 5 are `squad:mickey` (#235, #254, #306, #309, #310).
  Coordinator flagged this load imbalance to Earl. Either some of Mickey's
  tickets need re-triage to other agents, or Sprint 12 is intentionally a
  Mickey-heavy docs sprint.
- **Sprint 11 retro filename had to be renamed mid-release.** The retro itself
  shipped under the old `2026-05-17-sprint-t-retro.md` name in PR #303, then
  got renamed via `git mv` to `2026-05-17-sprint-11-retro.md` in PR #308.
  Minor friction, fully expected once Tier 3 was chosen, but worth noting:
  any retro shipped in a window where naming is in flux will get touched twice.
- **Doc worked WITHOUT a dedicated worktree.** Per the SOP from PR #293, Doc's
  default is a dedicated `..\dev-setup-doc` worktree on a per-sprint branch.
  This dispatch was a one-off fact-check + 1-line fix on the same branch as
  Mickey's sweep, not a cumulative history.md write. Acceptable deviation, but
  surface it as a pattern (see Learnings).

## Learnings to Codify

1. **Sprint Naming Convention** -- already codified in `CONTRIBUTING.md` lines
   271-300+ (mapping table + aliasing convention + `-hotfix` suffix rule +
   history). No additional codification needed; cross-reference only.
2. **Label vocabulary check before `gh issue create`.** Run
   `gh label list --limit 100` (or scope to `area:*` / `priority:*` / `type:*`
   prefixes) before assuming a label exists. The six area labels are
   `area:ci`, `area:hooks`, `area:windows`, `area:macos`, `area:linux`,
   `area:meta`. There is no `area:scripts` or `area:tests`; map to `area:meta`
   or omit. Worth a one-line note in CONTRIBUTING if it bites again.
3. **Doc one-off fact-check pattern (no worktree).** For SINGLE-PR fact-checks
   on an in-flight branch that produce at most a small follow-up commit, the
   dedicated worktree from PR #293 is overkill. For CUMULATIVE history.md
   writes spanning multiple PRs in a sprint, the worktree pattern is still
   the canonical SOP. Decision rule: if Doc's output is "verdict + at most
   one fixup commit on the same branch," no worktree. Anything that touches
   `.squad/agents/doc/history.md` across a sprint -> worktree.

## Action Items / Future Tickets

None beyond what is already filed. Sprint 12 backlog (P3, open):

| # | Owner | Title | Source |
|---|---|---|---|
| #235 | Mickey | refactor(scripts): defer install-guard helper until more tools added | pre-existing |
| #236 | Donald | docs(.aliases): mark file as bash/zsh-only; do not chase POSIX | pre-existing |
| #237 | Donald | docs(tests): document test harness pattern -- set -uo vs set -euo | pre-existing |
| #238 | Chip | test: add basic coverage for uninstall scripts (idempotency + restore) | pre-existing |
| #254 | Mickey | chore(meta): delete legacy 'priority: high/medium/low' labels | pre-existing |
| #300 | Jiminy | chore(squad): track `gh pr merge --delete-branch` ghost-remote-branch quirk | Sprint 11 |
| #306 | Mickey | docs(readme): refresh README.md to reflect Sprint Q-T changes | pre-existing |
| #309 | Mickey | docs(architecture): rewrite Script Conventions section | Sprint 11 (#298 review) |
| #310 | Mickey | docs(architecture): document Windows orchestrator Dependency Order chain | Sprint 11 (#298 review) |

Coordinator's load-balancing call (rebalance Mickey vs leave Sprint 12 docs-heavy)
deferred to Sprint 12 kickoff with Earl.

## Files Touched (this mini-event)

**PRs:**

- **PR #305** (`release/0.9.1` -> `develop`) -- CHANGELOG fold of `[Unreleased]`
  to `[0.9.1] - 2026-05-17 -- Sprint 11 (formerly Sprint T): Architecture refresh
  and tools hardening`. Merged 04:39 UTC.
- **PR #307** (`develop` -> `main`) -- release merge. Merged with `--admin --merge`
  at 05:29 UTC. Triggers the 0.9.1 tag + GH release.
- **PR #308** (`chore/sprint-naming-convention` -> `develop`) -- Mickey's Tier 3
  sweep, 21 files, 297+/189-. Renames 4 retros via `git mv`, applies ~170 ref
  updates, adds first-occurrence aliases, rewrites CONTRIBUTING.md Sprint Naming
  Convention section. Merged 05:24 UTC.
- **Commit `56c3c1f`** (on `chore/sprint-naming-convention` before merge) -- Doc
  fact-check fixup: added `(formerly Sprint Q)` alias to CHANGELOG `[0.8.0]`
  header. Single-line fix folded into PR #308.

**Issues:**

- **#306** -- body updated mid-flight: "Sprint U" -> "Sprint 12"; new acceptance
  criterion (#8) added referencing the new naming.
- **#309** (NEW) -- ARCHITECTURE Script Conventions section rewrite, surfaced
  by PR #298 review. P3 / `squad:mickey` / `type:docs` / `area:meta`.
- **#310** (NEW) -- ARCHITECTURE Windows Dependency Order chain documentation,
  surfaced by PR #298 review. P3 / `squad:mickey` / `type:docs` / `area:meta`.

**Tags + release:**

- **Tag `0.9.1`** (annotated) -- pushed to origin, sits on commit `724c62c` (main).
- **GH release** -- https://github.com/primetimetank21/dev-setup/releases/tag/0.9.1
  (name: "0.9.1 - Sprint 11: Architecture refresh and tools hardening").

## Reflection

This was a clean mini-event: a release ship plus a meta-cleanup plus a backlog
sweep, all inside a one-hour window after the Sprint 11 retro merged. The two
things that justify a retro file (rather than folding into a `.squad/log/`
session note) are (a) the sprint-naming convention is now a permanent policy
worth surfacing in retro history, and (b) the Doc no-worktree decision and the
`area:scripts` label gotcha are the kind of small operational learnings that get
lost in a session log but will save a minute next time someone hits them.

Sprint 12 picks up next session. Backlog enumerated, Mickey loaded heavy
(coordinator flagged), 0.9.1 in the rear-view mirror. Board status:
`develop @ c93a54c`, `main @ 724c62c` (tagged 0.9.1), working tree clean
(this retro branch excepted), no open PRs, no worktrees.
