---
name: "changelog-fold-completeness"
description: "Before folding [Unreleased] into a versioned release block, verify every PR merged and every issue closed since the last release tag has an entry in [Unreleased]. Add any missing entries first. Only then fold and restore the empty [Unreleased] block."
domain: "release-flow"
confidence: "high"
source: "earned (issues #399, Sprints 15/16/17 -- 3 consecutive releases, binary rule)"
---

## Context

The `CHANGELOG.md` file follows Keep a Changelog format. The `[Unreleased]` block is
supposed to accumulate entries as PRs merge to develop throughout a sprint. In practice,
only the first agent to land a feature PR adds their entry. Subsequent agents either
skip the update (single-PR scope feels too small) or defer it to "someone else." By
release time, the `[Unreleased]` block contains only the first-lander's entry --
typically 1 of N contributions.

The release agent (Mickey) folds `[Unreleased]` to `[X.Y.Z]` and ships. The missing
entries are gone from the release notes permanently.

This pattern has repeated identically in Sprints 15, 16, and 17. The fix is a
mandatory completeness check before every fold. This skill codifies that check.

**Rule:** The fold step is GATED on completeness. Do not fold until every merged PR
and every closed issue has a corresponding entry in `[Unreleased]`.

## Recipe

Run these steps IN ORDER during every release cut. Run from the main checkout (not a
worktree).

```bash
# Step 1. Identify the last release tag.
git fetch --tags origin
LAST_TAG=$(git describe --tags --abbrev=0 origin/main)
echo "Last release tag: $LAST_TAG"
# Expected format: X.Y.Z (bare, no 'v' prefix -- see tag convention)

# Step 2. Identify the last release date (needed for gh queries).
LAST_RELEASE_DATE=$(git log -1 --format=%ci "$LAST_TAG" | cut -d' ' -f1)
echo "Last release date: $LAST_RELEASE_DATE"

# Step 3. List all merge commits on develop since the last tag.
echo "=== Merge commits on develop since $LAST_TAG ==="
git log --oneline "$LAST_TAG"..develop --merges

# Step 4. List all PRs merged to develop since the last release date.
echo "=== PRs merged to develop since $LAST_RELEASE_DATE ==="
gh pr list --state merged --base develop --limit 50 \
  --json number,title,mergedAt,labels \
  --jq ".[] | select(.mergedAt >= \"$LAST_RELEASE_DATE\") | \"#\(.number) \(.title)\""

# Step 5. List all issues closed since the last release date.
echo "=== Issues closed since $LAST_RELEASE_DATE ==="
gh issue list --state closed \
  --search "closed:>$LAST_RELEASE_DATE" \
  --json number,title,closedAt \
  --limit 50 \
  --jq '.[] | "#\(.number) \(.title)"'

# Step 6. Open CHANGELOG.md [Unreleased] and cross-reference.
# For each PR number and each issue number from Steps 4-5:
#   - Search CHANGELOG.md [Unreleased] for "(#NNN)"
#   - If NOT found: ADD a one-line entry under the correct section
#     (Added / Changed / Fixed / Removed) before proceeding.
grep -n "Unreleased" CHANGELOG.md  # find the block boundary

# Step 7. ONLY AFTER all entries are confirmed present, fold [Unreleased].
# Replace:  ## [Unreleased]
# With:     ## [X.Y.Z] - YYYY-MM-DD -- Sprint NN: <theme>
# (Use sed, a text editor, or a script -- whatever the release runbook specifies.)

# Step 8. Restore the empty [Unreleased] block immediately after the fold.
# The block must be present at the top of CHANGELOG.md for the next sprint.
# Template:
#
# ## [Unreleased]
#
# ### Added
#
# ### Changed
#
# ### Fixed
#
# ### Removed
```

### PowerShell equivalent for Steps 1-5

```powershell
$lastTag = git describe --tags --abbrev=0 origin/main
Write-Host "Last tag: $lastTag"
$lastDate = (git log -1 --format="%ci" $lastTag).Split(" ")[0]
Write-Host "Last release date: $lastDate"

# Merges on develop since the tag
git log --oneline "$lastTag..develop" --merges

# PRs -- gh outputs UTC timestamps; compare as strings (ISO8601 sorts correctly)
gh pr list --state merged --base develop --limit 50 `
  --json number,title,mergedAt,labels `
  --jq ".[] | select(.mergedAt >= `"$lastDate`") | `"#\(.number) \(.title)`""

# Closed issues
gh issue list --state closed `
  --search "closed:>$lastDate" `
  --json number,title,closedAt --limit 50 `
  --jq '.[] | "#\(.number) \(.title)"'
```

### Why this order

- **Steps 3-5 before touching CHANGELOG.md.** Gathering the complete PR + issue list
  first gives a concrete checklist. Without it, "add missing entries" is subjective --
  you can't add what you don't know is missing.
- **Step 6 (cross-reference) before fold.** Once the fold happens, the window to add
  missing entries closes. The release is immutable. The completeness check must be
  inside the release transaction, not a best-effort beforehand.
- **Step 8 (restore empty block) immediately after fold.** If the fold succeeds but
  the restore is skipped, the next sprint starts without a `[Unreleased]` block, which
  causes the first agent to manually edit CHANGELOG structure instead of appending
  to a predictable location.

## Examples

**Sprint 17 release (0.9.7, PR #393, commit 71d2ffe):**
At release time, `[Unreleased]` contained only the `#382` (sprint-end label automation)
entry -- 1 of 6 total PRs merged to develop that sprint. Mickey-14 ran the completeness
check and added 5 missing entries (PRs #383, #384, #385, #388, #390 plus issues #371,
#381) before folding. Without this check, 0.9.7 release notes would have been ~85%
incomplete. Cited in Sprint 17 retro under "Key learnings."

**Sprint 16 release (0.9.6, PR #372, commit 7172ae7):**
`[Unreleased]` had sparse coverage -- only the first-lander entry. Mickey-12 added
missing Sprint 16 entries (PRs #368, #369, #370, #363, #365, #367) before folding to
`[0.9.6] - 2026-05-17 -- Sprint 16: Skill formalization + hygiene gate review`.

**Sprint 15 release (0.9.5, PR #360, commit 0c8d710):**
Same pattern. Only 1 entry in `[Unreleased]` at release time. Mickey added the missing
Sprint 15 PR entries (#355 normalization, #356 ASCII sweep, #357-#359 Doc wave) before
folding. Sprint 15 retro noted this as a process gap; it was not fixed structurally
until this skill was formalized.

**Pattern summary:** Three consecutive releases (0.9.5, 0.9.6, 0.9.7) had incomplete
`[Unreleased]` blocks at release time. The merge PR template asks contributors to
update CHANGELOG.md, but agents on single-PR scopes routinely skip it. The live block
contains only the first agent's entry by release time. The completeness check has
never failed to find missing entries when applied.

## Anti-Patterns

- **Trusting that `[Unreleased]` is complete.** It never is by release time. The
  pattern is binary: the first lander adds one entry; subsequent agents skip. Every
  sprint, every release.
- **Skipping Steps 3-5 because the sprint was "small."** Sprint 17 had 6 PRs; only 1
  entry was in `[Unreleased]`. Sprint 16 had 7 Sprint PRs; same pattern. There is no
  sprint small enough that the completeness check is unnecessary.
- **Adding entries AFTER the fold.** Once `[0.9.7]` is committed and pushed, adding
  to it requires a second commit amending the release block -- noisy and confusing for
  readers of the git log.
- **Folding without restoring `[Unreleased]`.** Leaves CHANGELOG.md with no top-level
  Unreleased block. First agent next sprint either forgets to add the block and
  appends under the versioned section, or adds the block incorrectly.
- **Relying on the PR template alone.** The template asks for a CHANGELOG update on
  every PR. Agents on single-PR scope treat it as optional. The release gate is the
  only reliable enforcement point.

## Placement decision

This skill lives in `.copilot/skills/` (coordinator level) rather than `.squad/skills/`
(team level). Rationale: the fold step is performed by Mickey (or the coordinator
directly) during a release cut -- it is release-process governance, not day-to-day
agent workflow. The coordinator is responsible for ensuring the fold is gated on
completeness. If Mickey is the release agent, the coordinator must include this skill
reference in Mickey's release spawn prompt.

Compare with `.squad/skills/history-md-pre-size-check/SKILL.md`, which governs
individual agent appends and therefore lives at the team level.

## Related Skills

- `.squad/skills/gh-pr-base-develop/SKILL.md` -- every squad PR must pass
  `--base develop`; if any PR was misrouted (base=main), the gh queries in Steps 4-5
  will miss it; verify develop ancestry with `git log $LAST_TAG..develop --merges`
  as the authoritative source.
- `.copilot/skills/release-process/SKILL.md` -- the full release runbook; this skill
  is a pre-step for the fold phase of that runbook.
- `.squad/skills/history-md-pre-size-check/SKILL.md` -- companion hygiene check
  (agent-level); ensures agents' own history files are within gate before the sprint
  closes and before the release audit.

## References

- Issue #399 -- formalization request (Sprint 18)
- Sprint 17 retro (`.squad/retros/2026-05-18-sprint-17-retro.md`) -- "Key learnings:
  RECURRING: Pre-append history.md size check missing" and release completeness notes
- PR #393 (commit 71d2ffe) -- Sprint 17 release (0.9.7); completeness check applied,
  5 missing entries added
- PR #372 (commit 7172ae7) -- Sprint 16 release (0.9.6); completeness check applied
- PR #360 (commit 0c8d710) -- Sprint 15 release (0.9.5); same pattern
- `CHANGELOG.md` -- Keep a Changelog format reference
- `https://keepachangelog.com/en/1.1.0/` -- canonical format spec

## Codified Script

This SKILL has been codified as executable scripts (Issue #415):

- `scripts/changelog-fold.sh` -- POSIX bash implementation
- `scripts/changelog-fold.ps1` -- PowerShell mirror

**Usage (bash):**
```
bash scripts/changelog-fold.sh \
  --release-version X.Y.Z \
  --last-tag X.Y.W \
  --release-date YYYY-MM-DD \
  [--changelog-path path/to/CHANGELOG.md] \
  [--dry-run | --apply]
```

Default mode is `--dry-run`. Pass `--apply` to write changes in-place.

The scripts:
- Resolve the last-tag commit date from git
- Query `gh pr list` and `gh issue list` for items since that date
- Deduplicate, categorize by label or title prefix
- Check for items missing from `[Unreleased]` and warn to stderr
- Build a correctly formatted section and either print (dry-run) or splice it in

**Last reviewed:** 2026-05-18 (Sprint 19, Issue #415)
