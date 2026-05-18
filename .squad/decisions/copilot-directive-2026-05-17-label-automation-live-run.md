# Decision: sprint-end-labels.sh First Live Production Run (#400)

**Date:** 2026-05-17T22:10:23-04:00
**Author:** Donald (Copilot, Sprint 18 Wave 1)
**Issue:** #400

## Input Scheme Chosen: (A) Backfill

Applied `sprint:17` retroactively to Sprint 17 closed issues and merged PRs,
then ran the script against that label. Rationale: simplest path, exercises
the real code path, validates Earl's verification requirement under live
conditions, and documents Sprint 17 retroactively for future reference.

Items backfilled:
- Issues: #371, #381, #382, #383, #384
- PRs: #385, #386, #387, #388, #389, #390, #391, #392, #393, #394, #395, #396

## Items Processed

- Total: 17 (5 issues + 12 PRs)
- `release:shipped-0.9.7` added to all 17
- `release:backlog` removed from 0 (none present)

## Bugs Surfaced

**Bug 1 -- PRs excluded from gh issue list --search**

`gh issue list --search` silently appends `is:issue` to the search query.
PRs are never returned. The script's original comment claimed otherwise.

Fix: use `gh issue list --state closed` + `gh pr list --state merged`
separately, combined via `jq -n '$issues + $prs | unique_by(.number)'`.

**Bug 2 -- Windows jq CRLF breaks idempotency guard**

Windows `jq` emits CRLF line endings. `bash read` strips `\n` but leaves `\r`
on the last field of a TSV line. The grep pattern `,label-name,` failed to
match because the actual string ended with `label-name\r`. Result: already-
labeled items appeared to need re-labeling on every run.

Fix: pipe jq TSV output through `tr -d '\r'` before the `while read` loop.

Both fixes committed to `scripts/sprint-end-labels.sh`.
Regression test added: Test G in `tests/test_sprint_end_labels.ps1` (7 total).

## Label Scheme Convention Going Forward

Sprint labels (`sprint:NN`) are now established as a first-class label type:
- Color convention: orange family (FFA500 / FF8C00 for adjacent sprints)
- Apply `sprint:NN` at issue/PR creation time going forward
- `sprint:17` and `sprint:18` labels now exist in the repo
- `release:shipped-X.Y.Z` labels created once per release, applied by
  `scripts/sprint-end-labels.sh` at sprint-end

## Idempotency

Confirmed on 3rd run: `total=17 changed=0 already-correct=17 dry-run=no`

## Verification Retries

0 retries triggered. Earl's directive (double/triple-check every add/remove)
satisfied via `verify_with_retry` on all 17 items.
