# Label Taxonomy Cleanup -- 2026-05-17 (Issue #347)

- **Date:** 2026-05-17
- **Status:** Applied
- **Owner:** Pluto (Config Engineer)
- **Sprint:** 14 Wave 2
- **Closes:** #347
- **Prerequisites:** Sprint 14 Wave 1 + 1.5 (#340, #341, #342, #343) all CLOSED before execution.

## Summary

Repo label taxonomy reduced from **45 -> 32** labels via a triple-verified
migration. 13 labels removed (8 GitHub-default duplicates, 4 stale release
version labels, 1 lonely status label). 3 labels renamed under a new
`platform:*` prefix (`area:linux/macos/windows` -> `platform:linux/macos/windows`).
84 unique issues relabelled; per-issue PRE/OP/POST verification produced
zero post-op failures and zero PRE-check mismatches.

## Counts

| Snapshot | Labels | Notes |
|----------|-------:|-------|
| Pre  | 45 | Captured via `gh label list --limit 200` |
| New (Phase 3)  | 48 | After creating 3 `platform:*` labels |
| Post (Phase 5) | 32 | After deleting 16 deprecated labels |
| Delta | -13 | Matches issue body header "12 deletes" + 1 lonely status |

## Lists

### DELETE (13)

| Label | Bucket | Pre count | Migration |
|-------|--------|-----------|-----------|
| `bug`                | GitHub default | 28 | replaced by `type:bug` |
| `documentation`      | GitHub default |  9 | replaced by `type:docs` |
| `enhancement`        | GitHub default | 42 | replaced by `type:feature` |
| `duplicate`          | GitHub default |  0 | drop, no replacement |
| `invalid`            | GitHub default |  0 | drop, no replacement |
| `wontfix`            | GitHub default |  0 | drop, no replacement |
| `question`           | GitHub default |  0 | drop, no replacement |
| `feedback`           | GitHub default |  0 | drop, no replacement |
| `release:v0.4.0`     | Stale release  |  0 | drop, no replacement |
| `release:v0.5.0`     | Stale release  |  0 | drop, no replacement |
| `release:v0.6.0`     | Stale release  |  0 | drop, no replacement |
| `release:v1.0.0`     | Stale release  |  0 | drop, no replacement |
| `status:in-progress` | Lonely status  | 16 | drop (no `status:*` siblings to retain) |

### RENAME (3) -- create-new-then-migrate-then-delete-old

| Old              | New                | Issues migrated |
|------------------|--------------------|-----------------|
| `area:linux`     | `platform:linux`   | 1 (#255) |
| `area:macos`     | `platform:macos`   | 1 (#252) |
| `area:windows`   | `platform:windows` | 3 (#251, #288, #292) |

### KEEP (32 final)

- `squad`, `squad:chip`, `squad:doc`, `squad:donald`, `squad:goofy`, `squad:jiminy`, `squad:mickey`, `squad:pluto`, `squad:ralph`, `squad:scribe` (10) -- automation hard-dependency, not touched
- `type:bug`, `type:chore`, `type:docs`, `type:epic`, `type:feature`, `type:spike` (6)
- `priority:p0`, `priority:p1`, `priority:p2`, `priority:p3` (4)
- `area:ci`, `area:hooks`, `area:meta` (3) -- component prefix retained
- `go:yes`, `go:no`, `go:needs-research` (3)
- `release:backlog` (1)
- `good first issue`, `help wanted` (2) -- GitHub UI features
- `platform:linux`, `platform:macos`, `platform:windows` (3) -- newly created

Total: 10 + 6 + 4 + 3 + 3 + 1 + 2 + 3 = **32**. Math checks.

## Issues migrated

**84 unique issues** had at least one touched label. Per-bucket relabel counts:

| Op | Count |
|----|------:|
| `bug` -> `type:bug`              | 28 |
| `documentation` -> `type:docs`   |  9 |
| `enhancement` -> `type:feature`  | 42 |
| `status:in-progress` -> drop     | 16 |
| `area:*` -> `platform:*`         |  5 |

(Sum exceeds 84 because some issues carried multiple touched labels, e.g. an
`enhancement` + `status:in-progress` issue counted in two buckets.)

## Triple-verification protocol

Each of the 84 issues passed three checks before being marked PASS in
`tmp-label-migration-checklog.txt`:

1. **PRE-op:** `gh issue view <num> --json labels` snapshot compared to
   `expected_before` from the migration plan; mismatch -> log + skip (no run-abort).
2. **OP:** `gh issue edit <num> --remove-label <csv> --add-label <csv>` applied
   atomically (single call so the labels swap together).
3. **POST-op:** snapshot compared to `expected_after`; mismatch -> HARD HALT.

Results:

- PRE-check mismatches handled: **0** (no skips)
- POST-check failures: **0** (no halts)
- Labels deleted via 0-count gate: **16** (Phase 5 verified count before each `gh label delete`)

## Workflow + docs audit (Phase 6)

Files updated:

- `.github/workflows/sync-squad-labels.yml` -- removed `release:v0.4.0`,
  `release:v0.5.0`, `release:v0.6.0`, `release:v1.0.0` from `RELEASE_LABELS`;
  removed `SIGNAL_LABELS` block (`bug`, `feedback`) and the corresponding
  `labels.push(...SIGNAL_LABELS)`. Replaced with an inline comment referencing
  this PR so the next reader knows where the labels went. `type:bug` and
  `type:docs` definitions retained (they are part of the kept taxonomy).

Files NOT updated (refs are plain English, not label references):

- `.github/workflows/e2e-install.yml` L5 -- comment "nvm.ps1 path bug #221"
  (narrative bug reference, not a label).
- `.github/workflows/squad-triage.yml` L56, L169 -- `goodFitKeywords` array
  and `issueText.includes(...)` use the words `bug` and `documentation` as
  fuzzy-match keywords against issue body text, not as label names.
- `CONTRIBUTING.md`, `CHANGELOG.md`, `ARCHITECTURE.md` -- "documentation",
  "bug", "feedback" appear only as English nouns in narrative prose.

ASCII scan on YAML edit: the workflow file has pre-existing non-ASCII bytes
(em-dashes on lines 31, 84, 103, 137, 148 and a U+1F916 emoji on line 63 used
as a `hasCopilot` marker). These predate this PR and are out of scope. The
pre-commit hook ASCII gate (`hooks/pre-commit` Check 2) only scans
`*.ps1, *.md, *.sh` -- `*.yml` is not subject to the check, so the workflow
file ships as-is.

## Out-of-scope follow-ups (not filed; tracking here for visibility)

- `sync-squad-labels.yml` `PRIORITY_LABELS` is missing `priority:p3`, which
  was created manually and survives independently because the workflow only
  creates/updates labels in its list and never deletes. Pre-existing gap; left
  alone.
- The new `platform:*` labels are NOT added to the workflow's `labels`
  array. Same rationale as above: they will persist; the workflow only
  creates/updates labels in its list. If automated re-creation is wanted
  later, file a follow-up.
- `.github/workflows/sync-squad-labels.yml` L63 `hasCopilot` check looks for
  the literal string `'<U+1F916> Coding Agent'` but `.squad/team.md` contains
  no such emoji, so `hasCopilot` is currently always false. Pre-existing,
  unrelated to label taxonomy; not fixed here.

## Audit artifacts (consumed, then deleted before PR commit)

Raw evidence files used during the run; the per-issue checklog summary is
folded above and the raw files are not committed (too noisy):

- `tmp-label-snapshot-pre.json` -- full pre-state of all 45 labels
- `tmp-label-snapshot-post.json` -- full post-state of all 32 labels
- `tmp-issues-labels-pre.json` -- 146 issues x labels (pre)
- `tmp-issues-labels-post.json` -- 146 issues x labels (post)
- `tmp-label-counts-pre.json` -- per-label issue counts for the 16 touched labels
- `tmp-label-migration-plan.json` -- per-issue PRE/AFTER + ops triplets (84 entries)
- `tmp-label-migration-checklog.txt` -- 84 PASS lines + 16 DELETED lines + SUMMARY

Per-bucket counts and the SUMMARY line are reproduced above so future
auditors do not need the raw files.
