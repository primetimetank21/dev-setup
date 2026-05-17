---
name: "label-hygiene"
description: "Safe deletion and lifecycle management for GitHub labels -- audit before destroy, prevent auto-recreation, preserve open-issue triage signal"
domain: "repo-meta, ci"
confidence: "medium"
source: "earned (issue #254, Sprint 12)"
---

## Context

GitHub repo labels accrete over time -- legacy names, alternate taxonomies, abandoned
prefixes. Cleaning them up is dangerous if done carelessly: deleting a label in active
use orphans triage signal on open issues, and labels mechanically defined in workflows
will silently auto-recreate after manual deletion, making the cleanup a no-op.

This skill applies whenever an agent is asked to:
- Delete a GitHub label
- Rename a label
- Consolidate two label namespaces into one
- Audit label taxonomy alignment

## Patterns

### Pattern 1 -- Audit before delete (mandatory pre-flight)

Run all three checks in parallel. Each one must come back clean before deletion.

```bash
# 1. Confirm the label actually exists. ALWAYS use --limit 100; default is 30 and lies.
gh label list --limit 100 --json name --jq '.[].name' | grep -F "<label-name>"

# 2. Confirm zero OPEN issues use it. --state all hides the signal you need.
gh issue list --label "<label-name>" --state open --limit 50

# 3. Confirm zero OPEN PRs use it.
gh pr list --label "<label-name>" --state open --limit 50
```

If any OPEN issue or PR has the label, STOP. Either:
- Migrate the issues/PRs to the canonical label first, OR
- Defer the deletion and report back to the coordinator.

Closed-issue label loss is acceptable when superseded by a canonical taxonomy.
Open-issue label loss is NEVER acceptable -- it strips active triage signal.

### Pattern 2 -- Grep for mechanical definitions (prevent auto-recreation)

Workflows that sync labels will silently recreate any label they define after manual
deletion. ALWAYS grep before destroy:

```bash
rg -i "<label-name>" .github/workflows/
rg -i "<label-name>" .github/ISSUE_TEMPLATE/
rg -i "<label-name>" CONTRIBUTING.md README.md
rg -i "<label-name>" .squad/
```

For prefix-based label families (e.g., `priority:`), check whether the sync workflow
is **additive-only** (creates/updates from a hard-coded list) or **destructive**
(also deletes anything not in the list). On this repo, `sync-squad-labels.yml` is
additive-only, so labels not in its list survive -- but anything in its list gets
re-created if manually deleted.

### Pattern 3 -- Delete with `gh label delete --yes`

```bash
gh label delete "<label-name>" --yes
```

Then re-run `gh label list --limit 100` to confirm. Take screenshots/logs of the
before/after state for the PR body.

### Pattern 4 -- Document in CHANGELOG

Add a `### Removed` entry under `## [Unreleased]`. Include the exact label names
(quoted, including any spaces) and reference the closing issue.

### Pattern 5 -- File the decision

Label taxonomy is a team-relevant decision. Drop a record in
`.squad/decisions/inbox/{agent}-label-hygiene-{date}.md` declaring:
- What the canonical taxonomy is now
- What was deleted
- Audit evidence (open issue count, workflow grep results)
- Any out-of-scope follow-up gaps

## Examples

**Issue #254 (this skill's origin):**
- Three legacy labels existed: `priority: high`, `priority: medium`, `priority: low`.
- Canonical taxonomy: `priority:p0..p3` (colon-direct, no space).
- Audit found 18 CLOSED issues used legacy labels, 0 OPEN issues/PRs.
- Grep found two historical references (a retro doc, decisions.md prose) but no
  workflow re-creation risk.
- Deletion executed cleanly; only canonical labels remained post-delete.
- Side gap found and flagged (not fixed): `sync-squad-labels.yml` PRIORITY_LABELS
  list is missing `priority:p3`. Out of scope for #254 since it's not legacy cleanup.

## Anti-Patterns

- **Deleting without `--state open` check.** Using `--state all` shows both open AND
  closed -- the closed count is irrelevant for safety; only the open count gates deletion.
- **Trusting `gh label list` default limit.** Default is 30. Repos with more labels
  (this one has ~45) will silently truncate. ALWAYS `--limit 100`.
- **Skipping the workflow grep.** A workflow that defines the label in code will
  silently re-create it on next run -- and your "fix" becomes a noisy no-op.
- **Renaming instead of deleting when consolidating.** GitHub label renames preserve
  history, but if the canonical name already exists, rename fails and you end up with
  both labels anyway. Prefer migrate-then-delete.
- **Deleting `bug`, `enhancement`, `documentation`, `good first issue`, `help wanted`,
  `question`, `invalid`, `duplicate`, `wontfix`.** These are GitHub defaults and tooling
  (e.g., issue templates, "good first issue" discovery) keys off them. Leave unless the
  team has an explicit policy to remove.
