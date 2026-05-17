# Decision: Doc subagent worktree pattern + Jiminy auto-dispatch SOP

- **Date:** 2026-05-19
- **Status:** Accepted
- **Decided-by:** Mickey (Squad Lead)
- **Closes:** #289, #290
- **Source:** Sprint S retro (#284); follow-on to PR #280 (Jiminy charter dispatch SOP) and PRs #281/#283 (Doc fact-check fold PRs).

---

## Context

Two operational SOPs surfaced as fragile during Sprint S, and both are about *Coordinator behavior at dispatch time* rather than agent code. They share the same surface area (`.squad/templates/loop.md`, `.squad/templates/ceremonies.md`, and the Doc/Jiminy charters), so they are resolved in a single design pass to avoid template churn and keep the new patterns coherent.

**#289 (Doc fold-PR overhead):** Doc (Fact Checker) is spawned as a `general-purpose` subagent in the Coordinator's primary worktree. Every time Doc appends to `.squad/agents/doc/history.md`, the edit lands as `M` on `develop` in the primary worktree. Because no agent (including the Coordinator) may commit directly to `develop`, the only safe way to land those edits is a short-lived "fold" PR. Sprint S produced two of these (PR #281 for the 6-PR batch fact-check, PR #283 for the PR #282 single-PR fact-check). The cost compounds: each fold is review overhead + merge ceremony + risk that the next agent dispatched from the primary worktree stages the dirty file accidentally.

**#290 (Manual Jiminy invocation):** PR #280 codified the Jiminy dispatch SOP ("Coordinator MUST invoke Jiminy after every 3+ agent batch and at session-end"), but the SOP is enforced by Coordinator instruction-following alone. Sprint S already produced one regression: the Coordinator forgot the post-batch dispatch after the first 3-agent batch, which is precisely why the rogue `bradygaster-squad-sdk-0.9.4.tgz` artifact survived long enough to require PR #280 in the first place. Manual SOPs decay; we need a checklist-driven gate that two independent template surfaces reinforce.

---

## Options considered

### Doc worktree pattern (#289)

| Option | Description | Trade-offs |
|--------|-------------|------------|
| **A. Pre-created sprint branch** | At sprint kickoff, create `squad/doc-history-<sprint>`. Doc dispatches with explicit instructions to commit + push to that branch only. | Cheap to set up, but Doc still runs in the Coordinator's primary worktree CWD. Switching branches mid-session corrupts any sibling agent that thinks it is on `develop`. Forces git plumbing gymnastics (`update-ref`, detached HEAD writes) that are brittle. |
| **B. Dedicated worktree (chosen)** | At sprint kickoff, `git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>`. Doc's spawn prompt prefixes a `Set-Location` to that worktree. All Doc writes land there. One fold PR at sprint end. | One additional worktree on disk per active sprint. Coordinator must remember to create it at kickoff (mitigated by the new ceremony checklist). Cleanly isolates Doc's `M` edits from the primary worktree's index. Matches the existing "Parallel Agent Work" pattern in CONTRIBUTING.md. |
| **C. Inline fact-checks (no history.md)** | Amend Doc charter so fact-check reports are written only to PR bodies / comments, never to `.squad/agents/doc/history.md`. | Eliminates the fold-PR problem entirely but loses cross-sprint searchability. Doc's history.md is one of his highest-value artifacts: it captures recurring fact-check patterns (e.g., "`set -euo pipefail` + bare glob expansion"), and we keep referring back to it in subsequent sprints. Permanently throwing that away to dodge a fold-PR is the wrong trade. |
| **D. Coordinator manual fold (status quo)** | Keep doing exactly what Sprint S did. | Two fold PRs per sprint, growing with batch count. Already proven fragile. Rejected. |

### Jiminy dispatch automation (#290)

| Option | Description | Trade-offs |
|--------|-------------|------------|
| **A. Loop.md + ceremonies.md checklist (chosen)** | Extend `.squad/templates/loop.md` with a "Squad Operational Gates" section that the Coordinator consults on every dispatch tick. Extend `.squad/templates/ceremonies.md` with explicit sprint-kickoff + sprint-wrap ceremonies referencing those gates. Two-source enforcement. | Zero infrastructure cost. Relies on Coordinator instruction-following, but the cost of forgetting is now visible at TWO checklist surfaces, not zero. Cheap to evolve as we learn. |
| **B. GitHub Action** | Workflow that triggers on develop changes and checks for Jiminy commits. | Rejected by the issue author: GH only sees pushed state; uncommitted-by-design squad activity is invisible to Actions. Not viable. |
| **C. Local pre-push hook** | Extend `hooks/pre-push` to refuse pushes from `squad/*` branches if recent `develop` commits include 3+ squad-authored merges without a Jiminy audit commit. | Heavy and brittle: requires the hook to inspect commit authorship + recency + audit-log presence; would block legitimate work when the Coordinator chooses to defer the audit to session-end (already an allowed pattern). False-positive risk too high. |
| **D. Coordinator runtime reminder** | Out-of-repo system reminder ("you have N agents dispatched, last Jiminy run was at T"). | Requires runtime support outside the repo. Not portable across Coordinator implementations. Out of scope for a docs PR. |

---

## Decision

**Doc (#289): Option B - Dedicated worktree at `..\dev-setup-doc` with a per-sprint branch.**

At each sprint kickoff, the Coordinator creates one Doc worktree:

```bash
git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>
```

Every Doc spawn prompt MUST begin with an explicit CWD directive pointing the agent at that worktree. Doc commits + pushes after every fact-check. At sprint wrap, the Coordinator opens ONE fold PR from `squad/doc-history-sprint-<N>` into `develop`. This collapses N fold-PRs per sprint into exactly one and eliminates the "dirty file on develop in the primary worktree" failure mode entirely.

**Jiminy (#290): Option A - Loop.md + ceremonies.md two-source checklist.**

Codify the existing PR #280 SOP at two checklist surfaces:

1. `.squad/templates/loop.md` gains a "Squad Operational Gates" section that lists the post-batch and session-end Jiminy triggers with their exact conditions ("after >= 3 spawns in the same Coordinator turn" and "before returning final control to the user at session-end").
2. `.squad/templates/ceremonies.md` gains explicit `Sprint Kickoff` and `Sprint Wrap` ceremony entries that reference those gates (kickoff = create Doc worktree + remind about Jiminy gate; wrap = Jiminy session-end audit + fold Doc PR).

The Jiminy charter's existing `Triggers` table already names these moments. The amendment is to make the table point at the new checklist surfaces so the SOP is reinforced at three locations (charter, loop, ceremonies) instead of one.

---

## Consequences

**Positive**

- Sprint S's dual fold-PR pattern (#281 + #283) collapses to a single fold-PR per sprint.
- Doc's `history.md` edits never appear as `M` in the primary worktree's index, removing the "sibling agent stages the dirty file" failure mode.
- Jiminy auto-dispatch is now reinforced at three independent surfaces (charter `Triggers` table + loop.md gates + ceremonies.md kickoff/wrap), making "Coordinator forgot to invoke Jiminy" a multi-surface miss rather than a single-line miss.
- Sprint kickoff and sprint wrap are now first-class ceremonies in `ceremonies.md`. Previously they were implicit.

**Negative / cost**

- Coordinator must remember to `git worktree add` at sprint kickoff. Mitigated by the new `Sprint Kickoff` ceremony checklist. If the kickoff step is skipped, Doc falls back to the Option D path (write to primary worktree, fold via PR), which is no worse than current.
- One additional on-disk worktree per active sprint (`..\dev-setup-doc`). Disk cost is negligible (same `.git` object store).
- Sprint T is the first sprint to run under this pattern. Coordinator MUST verify the worktree exists before the first Doc spawn; if missed, the next Jiminy audit will flag the missed kickoff step.

**Migration cost**

- Existing Sprint S Doc fold PRs (#281, #283) stay merged as-is. No retroactive cleanup.
- No agent code changes. No CI changes. No hook changes.
- Charter diffs are surgical: Doc gets a new "Where Doc writes history.md" section; Jiminy's `Triggers` table gains pointer text to the new templates. No deletions.

**What existing docs change**

- `.squad/templates/loop.md` - new "Squad Operational Gates" section appended.
- `.squad/templates/ceremonies.md` - two new ceremonies (`Sprint Kickoff`, `Sprint Wrap`).
- `.squad/agents/doc/charter.md` - new "Where Doc writes history.md" section + amended `Git Rules`.
- `.squad/agents/jiminy/charter.md` - `Triggers` table cross-references the new templates.
- `CONTRIBUTING.md` - new "Squad Operational Gates (Coordinator dispatch)" section so human contributors see the pattern.
- `CHANGELOG.md` `[Unreleased]` - one `### Changed` entry covering both issues.

---

## Implementation

Files modified in this PR (with one-line description each):

- `.squad/decisions/doc-and-jiminy-automation.md` - this file; canonical decision record.
- `.squad/templates/loop.md` - appended "Squad Operational Gates" section with Jiminy post-batch + session-end triggers and Doc worktree pre-spawn check.
- `.squad/templates/ceremonies.md` - added `Sprint Kickoff` (create Doc worktree + remind Jiminy gate) and `Sprint Wrap` (Jiminy session-end audit + fold Doc PR) ceremonies.
- `.squad/agents/doc/charter.md` - added "Where Doc writes history.md" section; amended `Git Rules` to point at `squad/doc-history-sprint-<N>` and the `..\dev-setup-doc` worktree.
- `.squad/agents/jiminy/charter.md` - `Triggers` table cross-references `loop.md` gates and `ceremonies.md` kickoff/wrap.
- `CONTRIBUTING.md` - new "Squad Operational Gates (Coordinator dispatch)" section.
- `CHANGELOG.md` - `[Unreleased]` entry under `### Changed`.
- `.squad/agents/mickey/history.md` - Sprint T design-pass entry capturing the rationale for combining #289 + #290 into one PR.

---

## Explicitly NOT in scope (follow-up issues if needed)

- **No Coordinator code changes.** This PR is documentation + templates only. If a future iteration wants to encode the gates as a runtime check (e.g., a `squad pre-dispatch` hook), file a separate issue.
- **No static-source test.** Considered adding a `tests/test_squad_sops.sh` grep test that verifies the SOP phrases live in the templates. Rejected: the SOPs are purely human-facing (Coordinator behavior, not script behavior), and phrase-pinning tests turn template edits into test churn. The triple-surface enforcement (charter + loop + ceremonies) is itself the audit signal.
- **No retroactive history rewrite** for Sprint S Doc fold PRs (#281, #283). They merged correctly under the old SOP and stay as-is.

---

## Sprint T verification plan

The acceptance criteria for both issues call for "Sprint T verified" outcomes. The Coordinator should remember the following pre-conditions when dispatching the first multi-agent batch of Sprint T:

1. **Before first Doc spawn:** `git worktree list` should show `..\dev-setup-doc` on branch `squad/doc-history-sprint-T`. If absent, create it: `git worktree add ../dev-setup-doc -b squad/doc-history-sprint-T`.
2. **First multi-agent batch (>= 3 spawns):** Jiminy is invoked as the final step of the batch, BEFORE the Coordinator returns results to the user. Jiminy reports `Jiminy clear` or a fix-offer.
3. **Sprint wrap:** Coordinator opens one fold PR from `squad/doc-history-sprint-T` into `develop` (Doc-authored, Mickey reviews). If Sprint T produced zero Doc spawns, no fold PR is needed and the worktree can be removed at session-end.

Verification artifacts to capture in the Sprint T retro:

- Count of Doc fold PRs (target: <= 1).
- Whether Jiminy was auto-dispatched at every >= 3-agent batch (target: 100%).
- Whether the kickoff `git worktree add` happened (target: yes; if no, Coordinator self-flags as missed step).
