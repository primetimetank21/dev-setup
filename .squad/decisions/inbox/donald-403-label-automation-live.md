# Decision: Sprint 18 Wave 1 Label Automation Live Run (#403)

## Date
2026-05-19

## Context
First live production run of sprint-end-labels.sh script completed. Decision documents input scheme, label infrastructure created, and bugs surfaced during execution.

## Input Scheme (A) Selected: Backfill Sprint 17

- Rationale: Established retroactive sprint labels for S17 closed issues (#371, #381-#384) and merged PRs (#385-#396) to create historical record.
- Alternative (B) considered: start fresh from S18 only. Rejected to maintain label continuity across all completed sprints.

## Label Infrastructure Established

Created three labels with standardized naming and color scheme:
- sprint:17 (#FFA500) -- Orange, identifies S17 work
- sprint:18 (#FF8C00) -- Dark Orange, identifies S18 work  
- elease:shipped-0.9.7 (#0E8A16) -- Green, marks shipped release

Scheme applied to all Sprint 17 closed issues and merged PRs. Going forward, sprint labels will be created at sprint start per this standard.

## Bugs Surfaced and Fixed

1. **gh issue list --search silently appends is:issue** (excludes PRs)
   - Manifested: combined backfill of issues and PRs required separate queries
   - Fix: gh issue list --state closed + gh pr list --state merged, deduplicate with jq

2. **Windows jq CRLF breaks idempotency guard**
   - Manifested: Windows jq outputs \r\n line endings; trailing \r attached to label field prevented grep match
   - Fix: pipe jq through 	r -d '\r' before loop

## Test Coverage

Added Test G to 	ests/test_sprint_end_labels.ps1 to detect CRLF regression. Uses function-override shim pattern to inject bad data into has_label mock.

## Verification

- All 17 label adds verified on first read (0 retries, Earl directive satisfied)
- Idempotency confirmed on 3rd run: total=17 changed=0

## Lessons

- gh issue list --search is issues-only even with the search API; must pair with gh pr list for batch automation
- Windows jq CRLF is a latent trap in any bash script parsing TSV output on Windows