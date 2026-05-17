# Sprint 12 Retro -- 2026-05-17

Sprint 12 was a single-day intensive bridge sprint, executed during the
transition from the 0.9.1 release to the next iteration. Nine backlog
issues closed across three waves with ten PRs landed in total (eight
work PRs plus two Scribe fold PRs). Scope was rebalanced mid-flight to
lighten Mickey's load given his Wave 2 and Wave 3 ownership: #254 moved
Mickey -> Pluto, and #235 moved Mickey -> Goofy. The sprint also
surfaced two real process gaps (worktree-isolation discipline and the
pre-commit ASCII-scan scope) that became remediation work for Sprint 13.

## Sprint Summary

- Duration: 2026-05-17 (single-day intensive, bridge sprint)
- Scope: 9 backlog issues closed
- PRs: 10 total (8 work PRs + 2 Scribe fold PRs)
- Mid-sprint scope rebalance: #254 Mickey -> Pluto, #235 Mickey -> Goofy
- 2 Jiminy audits ran (Wave 2 post-batch + session-end)

## Sprint 12 at a Glance

| #    | Owner   | Title                                                  | PR / Status        |
|------|---------|--------------------------------------------------------|--------------------|
| #309 | Mickey  | ARCH `Script Conventions` rewrite (lib/ source of truth) | #314 Merged       |
| #236 | Donald  | `.aliases` bash/zsh-only header                          | #313 Merged       |
| #238 | Chip    | uninstall.ps1 Group FF coverage                          | #316 Merged       |
| #254 | Pluto   | Legacy `priority: high/medium/low` label deletion         | #315 Merged       |
| #300 | Jiminy  | gh --delete-branch quirk tracker (Case D close)          | closed direct      |
| #310 | Mickey  | ARCH Windows Dep Order chain                              | #321 Merged       |
| #237 | Donald  | CONTRIBUTING Test Harness Pattern + new skill             | #320 Merged       |
| #235 | Goofy   | `.aliases` install-guard (Case B deferral)                | closed NOT_PLANNED |
| #306 | Mickey  | README refresh for Sprints 8-12                           | #324 Merged       |
| (fold) | Scribe | Wave 1 consolidation                                     | #318 Merged       |
| (fold) | Scribe | Wave 2 consolidation                                     | #323 Merged       |

## Wave Breakdown

- **Wave 1 (5 parallel):** Mickey #309, Donald #236, Chip #238, Pluto
  #254, Jiminy #300. Jiminy #300 was a Case D close (closed directly --
  the gh --delete-branch quirk has been 6-of-6 clean since the tracker
  was filed). Followed by Scribe Wave 1 fold (PR #318).
- **Wave 2 (3 parallel):** Mickey #310, Donald #237, Goofy #235. Goofy
  #235 was Case B (no PR, no branch -- helper not yet built; abstraction
  threshold not met). Followed by Jiminy post-batch audit and Scribe
  Wave 2 fold (PR #323).
- **Wave 3 (solo):** Mickey #306 README refresh -- executed last so all
  prior changes were reflected in the doc. Followed by Jiminy session-
  end audit.

## What Went Well

- **Worktree-remove-first dance dodged gh quirk #317 four-for-four in
  Waves 2 and 3.** Zero ghost-branch failures during the post-merge
  cleanup window.
- **Hygiene-tail compliance was 100%.** All nine agents wrote their
  history.md entries; Jiminy's session-end audit verified this directly
  (Mickey 3/3, Donald 2/2, Chip 1/1, Pluto 1/1, Goofy 1/1, Jiminy 3/3
  prior plus the audit entry, Scribe 2/2).
- **CWD-pin remediation worked in Wave 3.** After Mickey's #310
  worktree-isolation violation, the dispatch prompt protocol was
  hardened to require `Set-Location -LiteralPath` plus a CWD verify
  step. Mickey #306 in Wave 3 (and Scribe Wave 2 fold) executed the
  protocol cleanly -- the post-flight main-checkout audit returned zero
  stray modifications.
- **Pluto's audit-before-delete pattern (Sprint 12 / #254) caught zero
  false positives.** All 3 legacy priority labels were confirmed unused
  before deletion. The pattern is now formalized as
  `.squad/skills/label-hygiene/SKILL.md`.
- **Donald's test harness pattern docs (#237) were ground-truthed.**
  The `set -uo` (not `set -euo`) convention, failure-tally pattern, and
  helper conventions were derived from reading all seven bash test
  files directly, not inferred -- pattern then captured in
  `.squad/skills/test-harness-pattern/SKILL.md`.
- **Scope rebalance was clean.** Moving #254 and #235 off Mickey
  mid-sprint kept the sprint on schedule and gave Pluto and Goofy
  appropriate ownership of the work.

## What We Learned / What to Improve

- **Worktree isolation violation (Mickey #310).** Files were written
  to the main checkout from a worktree agent. Root cause: PowerShell
  ambient CWD vs string-path resolution -- the dispatch prompt did not
  pin CWD to the worktree before file writes, so tooling silently
  resolved relative paths against the process CWD (main checkout).
  Donald's parallel spawn for #237 wrote correctly into its own
  worktree, so the failure mode is non-deterministic and environment-
  state-dependent. Remediation: mandatory CWD-pin protocol in dispatch
  prompts, adopted starting Wave 3. Decision drop:
  `.squad/decisions/inbox/jiminy-wave-2-audit-20260517.md` (folded into
  decisions.md via PR #323).
- **Pre-commit hook ASCII-scope gap (Issue #322).** `hooks/pre-commit`
  Check 2 globs only `*.ps1` files. `.md` files in HEAD already carry
  non-ASCII bytes routinely: 134 hits in ARCHITECTURE.md, 60 in
  README.md, 12 in CONTRIBUTING.md, plus dozens in `.squad/` and
  `.copilot/` files (em-dashes U+2014, box-drawing U+2500/2502/251C/
  2514, smart-arrow U+2192). Filed #322 for Sprint 13.
- **Scribe inbox-drain bug (this Scribe's own bug -- fix forward).**
  Wave 2 fold (PR #323) merged drop CONTENT into `decisions.md` but did
  not `git rm` the source drop files. Coordinator manually deleted them
  post-Jiminy audit. **Fix forward:** future Scribe folds MUST
  atomically `git rm -- .squad/decisions/inbox/*.md` (or per-file) in
  the SAME commit as the `decisions.md` append, so drain is atomic with
  merge. Documenting in Scribe history.md this sprint.
- **PR label enforcement gap.** Only 2 of 9 Sprint 12 work PRs carried
  the full label set (priority/type/area/squad). Specifically PR #320
  (Donald) and PR #321 (Mickey) -- both auto-fixed by Jiminy post-Wave-
  2 audit. PRs #313/#314/#315/#316/#318/#323/#324 merged with no labels
  at all. Surfaced by Jiminy session-end audit. Sprint 13 candidate:
  GitHub Actions auto-label-from-linked-issue, OR PR template guidance.
- **Mickey self-lesson (from #310 retro).** Mickey verified every lib
  file before writing examples (correct discipline), but in the same
  run committed the worktree-isolation error. Discipline is not uniform
  across all axes of an agent's work -- worth a dispatch-prompt-level
  guard rather than relying on per-agent self-policing.
- **Goofy Case B (#235): 3-site abstraction threshold rule
  formalized but NOT codified as a skill.** Goofy correctly deferred
  `.squad/skills/abstraction-threshold/SKILL.md` until a second
  application of the pattern shows up. Appropriate restraint;
  formalize on next encounter.
- **Jiminy self-lesson.** The `edit` tool's substring-replace
  semantics interact poorly with multi-KB single-line history.md
  bullets. Prefer atomic `[System.IO.File]::WriteAllText` (or
  equivalent line append) for long-line history additions.
- **`squad:scribe` label is missing from the GitHub label set.** When
  follow-up issue #319 (history archival) needed a `squad:*` label it
  could not be tagged correctly because `squad:scribe` does not exist
  as a label. The 8 active engineering agents have labels; service-role
  agents (Scribe, Ralph) do not. Pluto next label sweep should create
  `squad:scribe` and audit whether `squad:ralph` warrants creation.

## Backlog Carried to Sprint 13

- **#317** -- gh --delete-branch quirk (worktree variant). Workaround
  proven 6-of-6 clean; no code fix needed, but procedural guard stays.
- **#319** -- history archival. Eight `history.md` files are over the
  archival gate, including Scribe's own at ~18 KB. Per-agent
  summarization + archive sweep is owed.
- **#322** -- pre-commit ASCII-scope gap (extend Check 2 to `*.md` or
  explicitly scope to `*.ps[m,d]?1`).
- **#325** -- ARCHITECTURE.md stale `auth.ps1` path reference.
- **#326** -- README hooks count (3 -> 4) refresh.

## Metrics

- PRs merged: 10 (8 work + 2 Scribe folds)
- Issues closed: 9 Sprint-12 backlog + 7 earlier-session = 16 total
  this session
- Follow-ups filed: 5 (#317, #319, #322, #325, #326)
- `.squad/decisions.md` size: 44 KB -> 57 KB (+13 KB). 4 Wave 2 drops
  folded. Archive gate (50 KB / 7-day cut) was crossed but no entries
  were old enough yet (oldest live entry 2026-05-14, 3 days).
- `history.md` total growth across 6 agent files: ~120 lines.

## Release Readiness

- `[Unreleased]` CHANGELOG: 9 entries (2 Added + 6 Changed + 1 Removed).
- 7 entries close issues (#306, #309, #310, #236, #237, #238, #254).
- 2 entries are internal/process (Sprint naming Tier 3 sweep, Wave 2
  fold note).
- Doc-quality sweep is substantial: README, ARCHITECTURE x2,
  CONTRIBUTING.
- No breaking changes, no public API surface change -- pure patch
  level.
- **Recommendation: cut 0.9.2** (consistent with Jiminy session-end
  audit Section 7).

## Action Items into Sprint 13

1. Adopt CWD-pin protocol in standard dispatch prompts (already
   informally in effect Wave 3+). Codify in `.squad/templates/` or in
   loop.md alongside the worktree-remove-first dance.
2. Extend pre-commit ASCII-scan to `.md` after a one-time normalize
   sweep (or explicitly scope to `*.ps?1` and document the choice).
   Tracked by #322.
3. Atomic Scribe drain: future folds MUST `git rm` the source drop
   files in the same commit that appends content to decisions.md.
   Update Scribe charter or skill if one exists.
4. PR label enforcement: GitHub Actions auto-label-from-linked-issue
   recipe, OR PR template guidance.
5. Pluto label sweep: create `squad:scribe`; audit `squad:ralph`.
6. History archival sweep (#319): run before Sprint 13 lands its first
   PRs so agent history files start the sprint under the gate.
