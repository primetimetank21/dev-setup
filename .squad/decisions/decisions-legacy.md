# Legacy Decisions Archive

Pre-Sprint-17 decision files, consolidated 2026-05-17 per Earl's "one-shot dump" choice.
Original filenames preserved as section headers. Pre-dates per-sprint archival policy.
No sorting attempted -- this is a flat archive for searchable retention only.


---

## changelog-retro-placement.md

# CHANGELOG: Sprint retro entry placement

**Decided:** 2026-05-17
**By:** Mickey (Lead)
**Triggered by:** Sprint 13 retro (#339) merged after 0.9.3 tag; Jiminy CONCERN in EOS audit.

## Decision

**Option A -- Move the Sprint 13 retro entry to `[0.9.3]`.** CHANGELOG.md is a curated narrative, not a commit-by-commit replay of the tagged ref. Prior-sprint convention places the retro entry under the sprint's release section (Sprint 11 retro lives under `[0.9.1]` line 65; Sprint 12 retro lives under `[0.9.2]` line 51). Diverging from this for Sprint 13 just because PR #339 merged a few hours after the `0.9.3` tag (`edc67e2`) was pushed would create an inconsistent reader experience and bury the retro under a future release header. The tag is immutable; the CHANGELOG-on-develop is a living document and is allowed to be edited retroactively for editorial coherence as long as the change is itself documented (which this decision file does).

## Rule going forward

When a sprint retro PR merges to develop AFTER the sprint's release tag has already been pushed:

1. **Fold the retro entry into the already-released sprint's section** of `CHANGELOG.md` on `develop` (under `### Added`), matching the prior-sprint format `` `.squad/retros/<file>.md`: Sprint N retrospective (#PR; folded retroactively into X.Y.Z -- PR merged after tag) ``.
2. **Do NOT re-tag the released version.** The tag stays at the commit it was pushed to. The retroactive CHANGELOG edit ships with the next regular `develop -> main` merge.
3. **The Lead (Mickey) owns this editorial call** at sprint wrap or during EOS audit. Codify each instance via a per-topic file in `.squad/decisions/` so the retroactive edit is auditable.
4. **If multiple post-tag drops accumulate** before the next release cut, batch them under the released section and reference each PR.
5. **Coordinator preference:** Scribe should target the retro PR to land BEFORE the release-cut PR whenever possible, which avoids this whole class of issue. Sprint 14 dispatch sequencing should put `retro write -> retro PR merge -> release fold PR -> develop->main merge -> tag` in that order.

## Applied to

- Sprint 13 retro (#339) -- moved from `[Unreleased]` to `[0.9.3]` ### Added with a retroactive-fold annotation referencing this decision file.


---

## copilot-directive-2026-05-17-label-automation-live-run.md

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


---

## doc-356-ascii-sweep.md

# Decision: Sprint 15 #356 ASCII sweep methodology + scope

**Date:** 2026-05-17  
**By:** Doc (Fact Checker)  
**What:** Sprint 15 legacy non-ASCII cleanup (#356) scope definition, file selection, and hand-conversion methodology for fenced code blocks.  
**Why:** Issue #356 identified 60+ pre-existing .md files with non-ASCII chars (em-dashes, smart quotes, box-drawing) that pre-date the #334 ASCII hook expansion. The hook only catches NEW additions; legacy debt required manual sweep. This decision documents scope, methodology, and file count for team reference.

## Scope

- **In scope:** All tracked .md files outside .squad/ (coordinator may handle separately)
  - 30 files: .copilot/skills/*.md
  - 3 files: ARCHITECTURE.md, tests/README.md, .github/agents/squad.agent.md
  - Total: 33 files, ~1,250 non-ASCII bytes removed

- **Explicitly out of scope:** 
  - .squad/ files (coordinator decision)
  - CHANGELOG.md (Mickey editing on #355 in parallel; merge conflict risk)
  - .yml workflow files (pre-existing em-dashes intentionally exempt per past decisions)

## Methodology

1. **Tool:** scripts/ascii-sweep.py (handles non-fenced content; preserves ``` ... ``` by design)
2. **Fence handling:** Manual replacement for non-ASCII inside code blocks using standard mapping table
3. **Mapping:** U+2500 (-) -> -, U+2502 (|) -> |, U+251C (|--) -> |--, U+2014 (--) -> --, U+2018/2019/2032/2033 (quotes) -> ', U+201C/201D/201E (double-quotes) -> ", U+2026 (...) -> ...
4. **Verification:** Python-based `ord(ch) > 127` check (Unicode character counting, not UTF-8 byte counting)
5. **Tool limitations noted:** PowerShell [System.IO.File]::WriteAllText may not persist changes reliably; Python pathlib preferred.

## Files cleaned  

Box-drawing trees (ARCHITECTURE.md), emoji/special chars (.copilot/skills/), test output templates (tests/README.md), agent roster (.github/agents/squad.agent.md).

## Residual count

0 files with remaining non-ASCII after cleanup. Pre-commit hook verification: PASS.

## Ship status

- PR #358 (squad/356-md-ascii-sweep off develop @ caf5c64)
- All staged, committed, pushed, PR created
- Ready for review


---

## doc-and-jiminy-automation.md

# Decision: Doc subagent worktree pattern + Jiminy auto-dispatch SOP

- **Date:** 2026-05-19
- **Status:** Accepted
- **Decided-by:** Mickey (Squad Lead)
- **Closes:** #289, #290
- **Source:** Sprint 10 (formerly Sprint S) retro (#284); follow-on to PR #280 (Jiminy charter dispatch SOP) and PRs #281/#283 (Doc fact-check fold PRs).

---

## Context

Two operational SOPs surfaced as fragile during Sprint 10, and both are about *Coordinator behavior at dispatch time* rather than agent code. They share the same surface area (`.squad/templates/loop.md`, `.squad/templates/ceremonies.md`, and the Doc/Jiminy charters), so they are resolved in a single design pass to avoid template churn and keep the new patterns coherent.

**#289 (Doc fold-PR overhead):** Doc (Fact Checker) is spawned as a `general-purpose` subagent in the Coordinator's primary worktree. Every time Doc appends to `.squad/agents/doc/history.md`, the edit lands as `M` on `develop` in the primary worktree. Because no agent (including the Coordinator) may commit directly to `develop`, the only safe way to land those edits is a short-lived "fold" PR. Sprint 10 produced two of these (PR #281 for the 6-PR batch fact-check, PR #283 for the PR #282 single-PR fact-check). The cost compounds: each fold is review overhead + merge ceremony + risk that the next agent dispatched from the primary worktree stages the dirty file accidentally.

**#290 (Manual Jiminy invocation):** PR #280 codified the Jiminy dispatch SOP ("Coordinator MUST invoke Jiminy after every 3+ agent batch and at session-end"), but the SOP is enforced by Coordinator instruction-following alone. Sprint 10 already produced one regression: the Coordinator forgot the post-batch dispatch after the first 3-agent batch, which is precisely why the rogue `bradygaster-squad-sdk-0.9.4.tgz` artifact survived long enough to require PR #280 in the first place. Manual SOPs decay; we need a checklist-driven gate that two independent template surfaces reinforce.

---

## Options considered

### Doc worktree pattern (#289)

| Option | Description | Trade-offs |
|--------|-------------|------------|
| **A. Pre-created sprint branch** | At sprint kickoff, create `squad/doc-history-<sprint>`. Doc dispatches with explicit instructions to commit + push to that branch only. | Cheap to set up, but Doc still runs in the Coordinator's primary worktree CWD. Switching branches mid-session corrupts any sibling agent that thinks it is on `develop`. Forces git plumbing gymnastics (`update-ref`, detached HEAD writes) that are brittle. |
| **B. Dedicated worktree (chosen)** | At sprint kickoff, `git worktree add ../dev-setup-doc -b squad/doc-history-sprint-<N>`. Doc's spawn prompt prefixes a `Set-Location` to that worktree. All Doc writes land there. One fold PR at sprint end. | One additional worktree on disk per active sprint. Coordinator must remember to create it at kickoff (mitigated by the new ceremony checklist). Cleanly isolates Doc's `M` edits from the primary worktree's index. Matches the existing "Parallel Agent Work" pattern in CONTRIBUTING.md. |
| **C. Inline fact-checks (no history.md)** | Amend Doc charter so fact-check reports are written only to PR bodies / comments, never to `.squad/agents/doc/history.md`. | Eliminates the fold-PR problem entirely but loses cross-sprint searchability. Doc's history.md is one of his highest-value artifacts: it captures recurring fact-check patterns (e.g., "`set -euo pipefail` + bare glob expansion"), and we keep referring back to it in subsequent sprints. Permanently throwing that away to dodge a fold-PR is the wrong trade. |
| **D. Coordinator manual fold (status quo)** | Keep doing exactly what Sprint 10 did. | Two fold PRs per sprint, growing with batch count. Already proven fragile. Rejected. |

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

- Sprint 10's dual fold-PR pattern (#281 + #283) collapses to a single fold-PR per sprint.
- Doc's `history.md` edits never appear as `M` in the primary worktree's index, removing the "sibling agent stages the dirty file" failure mode.
- Jiminy auto-dispatch is now reinforced at three independent surfaces (charter `Triggers` table + loop.md gates + ceremonies.md kickoff/wrap), making "Coordinator forgot to invoke Jiminy" a multi-surface miss rather than a single-line miss.
- Sprint kickoff and sprint wrap are now first-class ceremonies in `ceremonies.md`. Previously they were implicit.

**Negative / cost**

- Coordinator must remember to `git worktree add` at sprint kickoff. Mitigated by the new `Sprint Kickoff` ceremony checklist. If the kickoff step is skipped, Doc falls back to the Option D path (write to primary worktree, fold via PR), which is no worse than current.
- One additional on-disk worktree per active sprint (`..\dev-setup-doc`). Disk cost is negligible (same `.git` object store).
- Sprint 11 (formerly Sprint T) is the first sprint to run under this pattern. Coordinator MUST verify the worktree exists before the first Doc spawn; if missed, the next Jiminy audit will flag the missed kickoff step.

**Migration cost**

- Existing Sprint 10 Doc fold PRs (#281, #283) stay merged as-is. No retroactive cleanup.
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
- `.squad/agents/mickey/history.md` - Sprint 11 design-pass entry capturing the rationale for combining #289 + #290 into one PR.

---

## Explicitly NOT in scope (follow-up issues if needed)

- **No Coordinator code changes.** This PR is documentation + templates only. If a future iteration wants to encode the gates as a runtime check (e.g., a `squad pre-dispatch` hook), file a separate issue.
- **No static-source test.** Considered adding a `tests/test_squad_sops.sh` grep test that verifies the SOP phrases live in the templates. Rejected: the SOPs are purely human-facing (Coordinator behavior, not script behavior), and phrase-pinning tests turn template edits into test churn. The triple-surface enforcement (charter + loop + ceremonies) is itself the audit signal.
- **No retroactive history rewrite** for Sprint 10 Doc fold PRs (#281, #283). They merged correctly under the old SOP and stay as-is.

---

## Sprint 11 verification plan

The acceptance criteria for both issues call for "Sprint 11 verified" outcomes. The Coordinator should remember the following pre-conditions when dispatching the first multi-agent batch of Sprint 11:

1. **Before first Doc spawn:** `git worktree list` should show `..\dev-setup-doc` on branch `squad/doc-history-sprint-T`. If absent, create it: `git worktree add ../dev-setup-doc -b squad/doc-history-sprint-T`.
2. **First multi-agent batch (>= 3 spawns):** Jiminy is invoked as the final step of the batch, BEFORE the Coordinator returns results to the user. Jiminy reports `Jiminy clear` or a fix-offer.
3. **Sprint wrap:** Coordinator opens one fold PR from `squad/doc-history-sprint-T` into `develop` (Doc-authored, Mickey reviews). If Sprint 11 produced zero Doc spawns, no fold PR is needed and the worktree can be removed at session-end.

Verification artifacts to capture in the Sprint 11 retro:

- Count of Doc fold PRs (target: <= 1).
- Whether Jiminy was auto-dispatched at every >= 3-agent batch (target: 100%).
- Whether the kickoff `git worktree add` happened (target: yes; if no, Coordinator self-flags as missed step).

---

## 2026-05-17 Sprint 13 Wave 1 -- formalize worktree-remove-FIRST as a Squad skill (#317)

**By:** Jiminy (Hygiene Auditor). **PR:** #331 against `develop`.

**What shipped:** Created `.squad/skills/worktree-remove-first/SKILL.md` codifying the five-step PR-merge sequence proven 5-of-5 in Sprint 12 Wave 2 (PRs #320, #321, #323, #324, #327, plus release PR #328 with `--merge`). Front matter declares `confidence: high` and `source: earned (issue #317)`. Added a one-paragraph pointer to the new skill under `CONTRIBUTING.md` "Parallel Agent Work" so the merge tail is discoverable next to the worktree-spawn head. `CHANGELOG [Unreleased]` -> `### Added` notes the skill addition.

**Why now:** The pattern reproduced deterministically across Sprint 12 Wave 2 merges after issue #300 was closed prematurely as "no longer reproducible". Sprint 12 evidence reframed the root cause as the worktree-owns-branch precondition (gh's local pre-flight aborts the remote-delete step when a worktree owns the branch), not a gh upstream regression. The fix is procedural and can be locked in as a skill rather than waiting on tooling. Codifying now prevents the 100% failure mode from re-surfacing under any future coordinator who skips the sequence.

**Where it lives -- new skill vs extending `worktree-isolation/`:** The existing `worktree-isolation` skill covers the agent-dispatch race condition (spawn-time concern); this new skill covers the PR-merge tail (teardown-time concern). Separate skills keep each one tightly scoped and independently citeable; the new skill's `References` section cross-links back to `worktree-isolation` and to issue #300.

**Out of scope:** No code changes (hooks, scripts). Pre-commit hook `.md` ASCII-scan gap (#322) remains open and is not in this PR's scope.

**Topic-file scope note:** This file is the home for Squad hygiene-automation decisions (Doc worktree pattern, Jiminy dispatch SOP, and now the worktree-remove-FIRST merge skill). Future merge-flow / dispatch-flow decisions should land here.


---

## doc-readme-audit-2026-05-17.md

# README Fact-Check Audit -- 2026-05-17 (Issue #342)

**Auditor:** Doc
**Target:** README.md (commit bf1b44f baseline; branch squad/342-readme-audit)
**Method:** Cross-referenced README.md line-by-line against:

- hooks/pre-commit (active hook script, 193 lines)
- hooks/pre-push, hooks/commit-msg, hooks/prepare-commit-msg
- scripts/lib/ (read-tool-version.sh, Read-ToolVersion.ps1, ascii-sweep.py)
- scripts/linux/, scripts/linux/tools/, scripts/linux/lib/
- scripts/windows/, scripts/windows/tools/, scripts/windows/lib/
- .tool-versions
- ARCHITECTURE.md (file-tree section)
- CHANGELOG.md (Unreleased + 0.9.3 entries)
- .squad/team.md (active roster)
- .squad/agents/ (directory enumeration)
- .squad/retros/2026-05-17-sprint-13-retro.md

## Summary

**8 divergences found** (3 high, 2 medium, 3 low).

The most consequential is **F3**: the README itself contains 645 non-ASCII
bytes (box-drawing glyphs + em dashes) inside the file-tree fenced code block
at L80-L130. Sprint 13's pre-commit ASCII extension (#322B / PR #334) scans
the entire staged file -- it does NOT skip fenced code blocks -- so any
in-place edit to README.md in Wave 2 will fail Check 2 unless those bytes are
converted to ASCII first. `scripts/lib/ascii-sweep.py` will NOT clean them
(the sweep deliberately preserves fenced code verbatim). Mickey must
hand-convert the file-tree block or risk a blocked commit.

Sprint 13 also added two artifacts the README does not mention:
1. The pre-commit ASCII scan was extended from .ps1 only to .ps1 + .md + .sh
   (#322B / PR #334). README's pre-commit description (L194-L196) still
   describes only the shellcheck step.
2. `scripts/lib/ascii-sweep.py` is a new reusable tool (#322A / PR #335) that
   contributors should know about when they hit ASCII-check failures.

## Findings

### F1 (HIGH): pre-commit description omits Sprint 13 ASCII scan and 4 other checks

- **README line(s):** L194-L196 (and indirectly the file-tree summary at L115)
- **Current claim:**
  > Runs shellcheck on staged `.sh` files. Blocks commit if shellcheck fails.
  > Silently skips if shellcheck not installed.
- **Actual:** `hooks/pre-commit` performs six ordered checks (per the header
  comment at L3-L9 of the hook):
  1. Branch ancestry (squad/* must descend from develop)
  2. ASCII-only on staged `*.ps1`, `*.md`, `*.sh` (extended in #322B / PR #334)
  3. Rogue path check under `.squad/`
  4. Staged inbox file check (`.squad/decisions/inbox/` must be gitignored)
  5. Refuse commits directly on develop / main / master
  6. Shellcheck on staged .sh files
  Check 2's scope expansion to `.md` and `.sh` (was `.ps1` only) is the
  Sprint 13 change explicitly called out in CHANGELOG 0.9.3 ("Fixed" entry
  for #322 part B).
- **Suggested fix:** Replace L194-L196 with a short bulleted list mirroring
  the six checks. Explicitly mention that ASCII enforcement covers `.ps1`,
  `.md`, and `.sh` so contributors editing Markdown understand the policy.
  Cross-link `scripts/lib/ascii-sweep.py` (see F2) as the recommended
  remediation tool.

### F2 (HIGH): scripts/lib/ascii-sweep.py is not mentioned anywhere

- **README line(s):** Absent -- searched README.md for "ascii-sweep", "ASCII",
  "non-ASCII"; zero matches.
- **Current claim:** N/A (omission)
- **Actual:** `scripts/lib/ascii-sweep.py` exists (230 lines), was added in
  PR #335 (Goofy, #322 part A) and used to sweep all repo Markdown.
  Usage: `python scripts/lib/ascii-sweep.py [--dry-run] [--root <path>]`.
  The script maps em/en dashes, smart quotes, arrows, box-drawing glyphs,
  status emoji, etc. to ASCII equivalents while preserving fenced code
  blocks verbatim.
- **Suggested fix:** Add a short paragraph under "Contributing" (near L244)
  or as a sub-bullet inside the new pre-commit description (F1) along the
  lines of: "If pre-commit rejects your commit for non-ASCII bytes in a
  `.md` file, run `python scripts/lib/ascii-sweep.py --dry-run` to preview
  fixes, then drop `--dry-run` to apply them. The sweep preserves fenced
  code blocks verbatim, so non-ASCII inside ``` ... ``` must be cleaned
  manually."

### F3 (HIGH): README.md itself violates the ASCII policy (645 non-ASCII bytes inside the file-tree fence)

- **README line(s):** L80-L130 (the entire file-tree fenced code block) plus
  L82-L129 (em dashes used as separators inside the tree). Total: 645
  non-ASCII bytes per `[System.IO.File]::ReadAllBytes` count.
- **Current claim:** N/A -- this is a latent state issue, not a claim.
- **Actual:** The file-tree code block uses Unicode box-drawing glyphs:
  - `U+251C` ("|--") box-drawing tee
  - `U+2502` ("|") box-drawing vertical
  - `U+2514` ("`--") box-drawing corner
  - `U+2500` ("--") box-drawing horizontal
  - `U+2014` ("--") em dash as separator
  These were preserved by Goofy's #322A sweep because the sweep explicitly
  skips fenced code blocks (`sweep_text` in `scripts/lib/ascii-sweep.py`
  L154-L175 -- "Sweep a markdown document, preserving fenced code blocks").
  Pre-commit Check 2 (post-#322B), however, scans the full staged content
  via `git show ":$file" | grep -nP '[^\x00-\x7f]'` and does NOT respect
  code-fence boundaries. Therefore: **any in-place edit + stage of
  README.md will trip the ASCII check on these 645 bytes** and fail to
  commit.
- **Suggested fix:** Before Mickey makes any other Wave 2 edit, replace the
  file-tree glyphs with ASCII equivalents in a single sweep:
  - `U+251C` -> `+--` or `|--`
  - `U+2502` -> `|`
  - `U+2514` -> `+--` or `\` + `--`
  - `U+2500` -> `--`
  - `U+2014` -> `--`
  Optionally, the file-tree block can also be regenerated from ARCHITECTURE.md's
  file-tree (which uses `#` as separator and may already be ASCII-clean -- worth
  checking before copy-pasting). Without this step, Wave 2 is blocked or has
  to land via `--no-verify`, which violates the hooks contract.

### F4 (MEDIUM): scripts/lib/ tree entry is incomplete

- **README line(s):** L88-L90
- **Current claim:**
  ```
  scripts/
  +-- lib/
  |   +-- read-tool-version.sh  -- POSIX sh: reads pinned version ...
  |   +-- Read-ToolVersion.ps1  -- PowerShell: Get-ToolVersion function
  ```
- **Actual:** `scripts/lib/` now contains THREE files:
  - `read-tool-version.sh`
  - `Read-ToolVersion.ps1`
  - `ascii-sweep.py` (added Sprint 13 / PR #335)
- **Suggested fix:** Add an `ascii-sweep.py` line to the tree under
  `scripts/lib/` with a one-line description ("Sweep `.md` files for
  non-ASCII characters; preserves fenced code blocks").

### F5 (MEDIUM): file-tree pre-commit one-liner is understated

- **README line(s):** L115
- **Current claim:**
  > pre-commit            -- Shellcheck on staged .sh files
- **Actual:** As detailed in F1, pre-commit performs six checks; shellcheck
  is only the last (Check 6) and is silently skipped if shellcheck is not
  installed.
- **Suggested fix:** Either expand the one-liner ("Branch ancestry + ASCII
  on .ps1/.md/.sh + .squad/ allow-list + shellcheck") to match
  ARCHITECTURE.md L83 style, or replace with a short cross-reference
  ("Hygiene checks; see Git Hooks section below"). The expansion is
  preferred because the file-tree should self-document.

### F6 (LOW): scripts/linux/ and scripts/windows/ trees omit lib/ subdirs

- **README line(s):** L91-L100 (linux/), L101-L109 (windows/)
- **Current claim:** No `lib/` subdir shown under either `scripts/linux/`
  or `scripts/windows/`.
- **Actual:**
  - `scripts/linux/lib/log.sh` exists (added Sprint 9 / #223 -- shared
    `log_info`/`log_ok`/`log_warn`/`log_error` helpers)
  - `scripts/windows/lib/logging.ps1` exists (Write-Info/Write-Ok/Write-Warn
    /Write-Err + Assert-LastExit)
  - `scripts/windows/lib/path.ps1` exists (Refresh-SessionPath)
  Both are documented in ARCHITECTURE.md (L41-L42, L55-L57) but invisible
  from README.
- **Suggested fix:** Optional. README operates at a coarser detail level
  than ARCHITECTURE.md, so omission is defensible. If included, add one
  `lib/` line per OS subtree mirroring ARCHITECTURE.md's wording.

### F7 (LOW): README does not surface that pre-commit also rejects direct commits on develop/main/master

- **README line(s):** L194-L196 (pre-commit), L214 (pre-push)
- **Current claim:** Pre-push "Blocks direct pushes to `main` (hard stop)".
  No mention that pre-commit also refuses develop/main/master commits.
- **Actual:** `hooks/pre-commit` Check 5 (L168-L179) hard-rejects commits
  authored directly on develop, main, or master regardless of push state.
- **Suggested fix:** Roll into the F1 rewrite -- the new pre-commit
  description should list "refuses direct commits on develop/main/master"
  as one of the bullets.

### F8 (LOW): "team of nine specialized AI agents" -- VERIFIED against repo, divergent from task brief

- **README line(s):** L246
- **Current claim:**
  > a team of nine specialized AI agents (Mickey, Donald, Goofy, Pluto,
  > Chip on engineering; Jiminy, Doc, Scribe, Ralph on process and hygiene)
- **Actual:** `.squad/team.md` lists exactly 9 active members (Mickey,
  Donald, Goofy, Pluto, Chip, Jiminy, Doc, Scribe, Ralph). The
  `.squad/agents/` directory has 9 entries: chip, doc, donald, goofy,
  jiminy, mickey, pluto, ralph, scribe. Sprint 13 retro (L9) confirms
  "nine agent dispatches". README's claim matches repo state.
- **Note:** The dispatch task brief stated "10 agents now (was 8/9)", which
  does NOT match current repo state. No 10th agent charter exists. Either
  the task brief is aspirational (a 10th hire is pending and the README
  count will need bumping when it lands) or it is a typo. **Confidence:
  Verified** against current repo; recommend Mickey confirm with Earl
  whether a 10th agent is in flight before Wave 2.
- **Suggested fix:** Leave at "nine" pending Mickey's confirmation. If a
  10th agent is landing in Sprint 14, defer the L246 bump to that PR.

## Cross-checks that PASSED (no finding)

These items were inspected and confirmed accurate; included so Mickey does
not waste cycles re-verifying:

- **L40 -- auth.sh / auth.ps1 paths.** `scripts/linux/tools/auth.sh` and
  `scripts/windows/tools/auth.ps1` both exist (auth.ps1 moved into tools/ in
  PR #297, Sprint 11 #230). No stale top-level reference remains.
- **L192 -- "four hooks are active".** Verified: `hooks/` contains exactly
  four files (commit-msg, pre-commit, prepare-commit-msg, pre-push). The
  3-to-4 fix landed in PR #330 / #326.
- **L198-L210 -- commit-msg + prepare-commit-msg descriptions.** Match the
  active hook scripts (Conventional Commits regex; merge/revert rewrite
  cases).
- **L213-L217 -- pre-push behaviour.** Block-main + advisory shellcheck +
  advisory PSScriptAnalyzer all match `hooks/pre-push` (with `|| true`
  load-bearing on PSSA per #233).
- **L226-L227 -- .tool-versions reader paths.** `scripts/lib/read-tool-version.sh`
  (POSIX) and `scripts/lib/Read-ToolVersion.ps1` (Get-ToolVersion) both
  exist and match the README claim.
- **L229-L236 -- .tool-versions excerpt.** Byte-for-byte match with the
  on-disk `.tool-versions` (nodejs 22.11.0, nvm 0.39.7, nvm-windows 1.2.2,
  uv 0.4.18, copilot-cli 1.0.48, squad-cli 0.9.4, gh 2.92.0).
- **L249-L250 -- CONTRIBUTING/CHANGELOG references.** Both files exist and
  contain the sections the README cross-links to (sprint naming convention,
  Keep a Changelog format with letter-named-sprint aliases).
- **Supported platforms (L22-L28).** Linux native, macOS, WSL, Windows
  PowerShell, Dev Container/Codespace all still supported per setup.sh /
  setup.ps1 routers. No platform claim divergence.
- **Quick-start install snippets (L32-L48).** `git clone` URL
  (`https://github.com/primetimetank21/dev-setup.git`) matches the
  configured remote (origin: primetimetank21/dev-setup). PowerShell
  invocation `powershell -ExecutionPolicy Bypass -File setup.ps1` still
  matches setup.ps1's CLI surface.

## Recommendations for Mickey (Wave 2)

1. **Apply F3 FIRST** -- the file-tree ASCII conversion is a hard
   prerequisite. Without it, pre-commit Check 2 blocks every subsequent
   edit. Suggested approach: replace `|-- | +-- - --` glyphs with their
   ASCII counterparts (`|`, `+--`, `|--`, `--`) in one focused pass, then
   stage to confirm the hook is clean before layering F1/F2/F4/F5 edits.
2. **Bundle F1, F2, F5, F7** -- all touch the Git Hooks section (L184-L218)
   and the related file-tree summary line (L115). Single coherent rewrite
   of the pre-commit description, with a contributor-facing note pointing
   at `scripts/lib/ascii-sweep.py`. Cross-reference the SKILL file at
   `.squad/skills/pwsh-lastexitcode/` style if a similar skill is ever
   formalized for ASCII hygiene.
3. **Apply F4** in the same pass -- one new line in the `scripts/lib/`
   tree, matching the indentation style already used.
4. **Skip or defer F6** -- README's level of detail does not require
   per-OS lib/ visibility; ARCHITECTURE.md handles it.
5. **Skip F8 unless Earl confirms a 10th agent** -- current "nine" is
   correct against `.squad/team.md`. The task brief's "10" appears to be
   ahead of repo state.
6. **Preserve README's existing tone and structure** -- the file is
   contributor-facing and lightly humorous (e.g., the "team of nine
   specialized AI agents" framing). Don't switch to a clinical
   reference-doc tone in the rewrite.
7. **Maintain ASCII cleanliness** throughout. After the F3 conversion,
   keep new prose ASCII-clean so the pre-commit hook stays green.

---

**Confidence:** Verified for all 8 findings (each citation includes
line/file reference; no hand-waving). Counter-hypotheses considered:

- "F3 is a false alarm because the sweep handles it." Counter: the sweep
  preserves fenced code blocks by design (L154-L175 of ascii-sweep.py),
  so running it on README leaves the 645 bytes intact. The pre-commit
  hook does not share that exemption.
- "F8 is wrong because Earl said 10." Counter: source of truth is
  `.squad/team.md` (9 entries) and `.squad/agents/` (9 dirs). Until a
  charter for a 10th agent is committed, "nine" is the correct claim.
- "F1 is over-broad because most checks predate Sprint 13." Counter: F1
  is scoped to the documentation gap; whether the gap was opened in
  Sprint 9 or Sprint 13 is irrelevant to Mickey's Wave 2 fix. The
  Sprint 13 ASCII scope expansion is the immediate trigger and the
  rewrite addresses both the pre-existing and the new gaps in one pass.

**Verdict:** PROCEED to Wave 2 (Mickey edit pass). F3 is the only finding
that gates further edits and is mechanical to fix.


---

## goofy-ascii-sweep.md

# Decision: Goofy ASCII sweep methodology

**By:** Goofy (Cross-Platform Dev)
**Topic:** ``.md`` ASCII-sweep methodology + ``scripts/lib/ascii-sweep.py`` reference
**Created:** 2026-05-17 (Sprint 13 Wave 2)

This file is the per-topic decisions store for Goofy's ASCII-sweep methodology. Seed for a future ``.squad/skills/ascii-sweep/SKILL.md`` formalization once the pattern has a second application.

---

## 2026-05-17 Sprint 13 Wave 2 -- ASCII-sweep repo .md corpus

**By:** Goofy (folded from inbox drop ``goofy-w2-2026-05-17-ascii-sweep.md``)
**Issue:** #322 part A
**Branch:** ``squad/322-goofy-md-sweep`` (PR #335)

### Scope

All ``.md`` files in the repo (163 files). Excludes ``.git/``, ``node_modules/``, ``.copilot/``. Excludes non-``.md`` files (``hooks/``, ``scripts/``, ``*.ps1``, ``*.sh``). Mickey owns part B (``hooks/pre-commit`` ASCII gate) in a parallel worktree.

### Exclusions

- Fenced code blocks (``` and ~~~) preserved verbatim per repo policy. Tree diagrams in ARCHITECTURE.md and README.md, hex/byte tables, and code samples are inside fences and remain intact.
- CHANGELOG.md prior-release entries untouched; only added new ``[Unreleased] / Changed`` line for this sweep.

### Before / After

- Files scanned: 163
- Files with hits pre-sweep: 125 (4,187 non-ASCII chars)
- Files edited: 124
- Chars replaced: 2,501
- Non-ASCII outside fences after sweep: **0**
- Non-ASCII inside fences (preserved): 1,686 (intentional)

### Mapping highlights

- ``--`` (em) -> ``--``, ``-`` (en) -> ``-``
- Smart quotes -> ASCII quotes
- Arrows (``->``, ``<-``, ``<->``) -> ``->``, ``<-``, ``<->``
- Box-drawing U+2500..U+257F -> ``+``, ``-``, ``=``, ``|``
- Checkmarks (``[x]``, ``[x]``) -> ``[x]``; crosses (``[ ]``, ``[ ]``) -> ``[ ]`` (preserves task-list semantics in team.md and status tables)
- Status emoji (``[RED]``, ``[GREEN]``, ``[YELLOW]``, ...) -> ``[RED]``, ``[GREEN]``, ``[YELLOW]``, ...
- Tooling emoji ([NOTE], [TOOL], [SEARCH], ...) -> bracketed ASCII tokens

### Tool

``scripts/lib/ascii-sweep.py`` -- idempotent, fence-aware, re-runnable. Could underpin Mickey's pre-commit hook check or become a ``.squad/skills/ascii-sweep/`` skill on second application.

### Skill candidate

First clean application of the fence-aware ASCII-sweep methodology. The script (``scripts/lib/ascii-sweep.py``, 6342 B) and the mapping table above are the seed. Formalize as ``.squad/skills/ascii-sweep/SKILL.md`` on the second application -- per Squad abstraction-threshold rule. At that point also add a CONTRIBUTING.md cross-reference (Jiminy W2 audit Sec 6 flagged the missing reference).


---

## label-taxonomy-2026-05-17.md

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


---

## mickey-architecture-entry-point.md

# Decision: Architecture Entry Point and File Structure

**By:** Mickey (Lead)
**Issue:** #3
**Date:** 2026-04-07T00:00:00Z

---

## Decision

### Entry Points

Two root-level entry points -- one per platform family:

- `setup.sh` -- Unix (Linux, macOS, WSL). Uses `uname -s` + `/proc/version` for OS detection.
- `setup.ps1` -- Windows. Uses PowerShell's `$IsWindows` builtin.

Neither entry point installs tools. They are thin routers only.

### File Structure

```
dev-setup/
+---- setup.sh              # Unix entry point (router)
+---- setup.ps1             # Windows entry point (router)
+---- scripts/
|   +---- linux/
|   |   +---- setup.sh      # Core Linux/macOS/WSL installer
|   |   \---- tools/        # One script per tool
|   \---- windows/
|       \---- setup.ps1     # Core Windows installer
+---- config/dotfiles/      # Dotfile templates
\---- .github/workflows/    # CI
```

### WSL Handling

WSL is detected by grepping `/proc/version` for "microsoft". WSL is **routed as Linux** -- it gets `scripts/linux/setup.sh`, not the Windows path. WSL users have a full Linux environment; treating them as Windows would install the wrong toolset.

### Tool Script Pattern

Each tool in `scripts/linux/tools/` is a standalone bash script:
- Check if already installed -> skip if so (idempotency)
- Install if missing
- `exit 0` on success or skip, `exit 1` on failure

The core `scripts/linux/setup.sh` runs them via `bash <script>` (not `source`) to keep each script isolated with its own environment.

---

## Rationale

### Why two entry points at the root?

The cold-start constraint is real: on a brand-new machine, a user needs exactly one command to remember. `bash setup.sh` is that command for Unix; `powershell -File setup.ps1` for Windows. Hiding these under `scripts/` would add friction.

### Why separate the router from the installer?

The router (`setup.sh`) needs to be stable -- it's what people bookmark or put in onboarding docs. The installer (`scripts/linux/setup.sh`) will change as tools are added/removed. Keeping them separate means the public API is stable.

### Why run tool scripts via `bash <script>` not `source`?

`source` pollutes the caller's environment with any variables the tool script sets. Each tool script should be independently runnable and testable. Running via `bash` gives each tool its own subshell.

### Why no package manager abstraction layer?

Over-engineering. We support two platforms (apt/brew for Linux+macOS, winget for Windows). A package-manager abstraction adds complexity with no current payoff. If a third package manager is needed, add it directly in the relevant tool script.

---

## 2026-05-17 Sprint 13 Wave 1 -- ARCH and README accuracy fixes (#325, #326)

**By:** Mickey (Lead). **PR:** #330 against `develop`.

Two narrow doc-accuracy fixes shipped together:

- `ARCHITECTURE.md`: corrected stale `scripts/windows/auth.ps1` references (file-structure tree near line 54 and ownership map near line 505) to `scripts/windows/tools/auth.ps1`. Reflects the PR #297 move into `tools/`. Closes #325.
- `README.md`: "three hooks are active" became "four hooks are active" and added a `prepare-commit-msg` subsection between `commit-msg` and `pre-push`. Reflects PR #212 (Sprint 8-hotfix). Closes #326.
- `CHANGELOG.md`: two entries under `[Unreleased] / Fixed`.

**Related prior PRs:** #297 (auth.ps1 move into `tools/`), #212 (prepare-commit-msg hook).

**Lessons captured:**

- Batching two narrow related doc fixes (same domain, same review surface) into one PR keeps reviewer load minimal and CHANGELOG noise low. This is the 2nd time the pattern has been useful (Sprint 12 also batched two doc fixes); flagged as skill candidate if it recurs again next sprint.
- Out-of-scope observations recorded in `history.md` during a prior PR (here: Mickey's #306 entry) were the exact source of these two follow-up issues. Cheap follow-up filing beats scope creep.

**Scope note:** This topic file is broadened in practice from "Architecture Entry Point" to "ARCH and README accuracy" -- subsequent doc-accuracy fixes to the entry-point / file-structure surface should land here.


---

## mickey-hook-policy.md

# Decision: Mickey hook policy

**By:** Mickey (Lead, architecture + hooks owner)
**Topic:** ``hooks/pre-commit`` and related guard policy
**Created:** 2026-05-17 (Sprint 13 Wave 2)

This file is the per-topic decisions store for Mickey-owned hook decisions. Append future hook scope / policy choices here.

---

## 2026-05-17 Sprint 13 Wave 2 -- extend pre-commit Check 2 ASCII scan beyond .ps1

**By:** Mickey (folded from inbox drop ``mickey-w2-2026-05-17-hook-extension.md``)
**Issue:** #322 part B
**Status:** Implemented (PR #334)

### Context

``hooks/pre-commit`` Check 2 globbed only ``*.ps1`` for non-ASCII bytes. Real-world audit: ``ARCHITECTURE.md`` had 134 non-ASCII hits, ``README.md`` 60, ``CONTRIBUTING.md`` 12 -- every one escaped the hook. Goofy swept the existing content (#322 part A); Mickey's job was preventing regression.

### Decision

Extend the Check 2 glob to scan ``.ps1``, ``.md``, and ``.sh`` files. Single-pass loop. No allow-list carve-outs.

### Alternatives considered

1. **Add only ``.md``.** Insufficient -- ``.sh`` files are equally vulnerable to copy-paste em-dashes; defensive scan is cheap.
2. **Add ``.py`` and ``.yml`` too.** Skipped: no ``.py`` files exist in repo; ``.yml`` is mostly CI template scaffolding where non-ASCII risk is low and false-positive risk (e.g. action descriptions) is non-zero. Revisit if a future incident lands in ``.yml``.
3. **Allow-list ``.squad/retros/*.md`` (semantic prose).** Rejected. Cleanest model is "scan all .md, no exceptions" -- retros that need em-dashes can use ``--`` like every other doc. Goofy is sweeping retros in part A regardless.

### Implementation

- ``hooks/pre-commit`` Check 2 regex: ``\.ps1$`` -> ``\.(ps1|md|sh)$``
- Error message generalized: "staged PowerShell file(s)" -> "staged file(s)" with extension list
- Help text expanded: added en-dash (U+2013) and ellipsis (U+2026) hints
- Tests: ``tests/test_precommit_hygiene.sh`` -- flipped T2c, added T2d (.sh), T2e (.txt allowed), T2f (.md ASCII passes). 26/26 PASS.

### Pattern note (skill candidate)

"Hook scope decision" pattern: when extending a guard to new file types, the bar is (a) does the file type appear in the repo, (b) is the failure mode similar, (c) is false-positive risk acceptable. Not yet generalizable -- one more application would justify formalizing as ``.squad/skills/hook-scope-decision/SKILL.md``.

### Dogfood incident (cross-reference)

The new hook BLOCKED Mickey's own history.md append in the same PR because the file carried 60 pre-existing non-ASCII bytes from earlier sprints. Correct behavior. Deferral handled by Jiminy auto-fix catch-up entry post-Goofy-sweep. Captured in PR #334 body Deferred Items section. Skill candidate: "ship-test + eat-dogfood" (1st clean application; watch for second).


---

## mickey-release-process.md

# Decision: Mickey release-process pattern

**By:** Mickey (Lead)
**Topic:** release / sprint-wrap
**Date:** 2026-05-17

---

## 2026-05-17 Sprint 13 -- 0.9.3 release fold

**By:** Mickey (folded from inbox drop `mickey-release-093-2026-05-17.md` by Jiminy session-end audit)
**Source:** develop @ d33691c -> release/0.9.3 -> PR #337 -> develop @ 031f317 -> PR #338 -> main @ edc67e2 -> tag `0.9.3`

**Scope:** Cut 0.9.3 CHANGELOG fold from develop. Eight entries folded under [0.9.3]:

- 1 Added: #317 worktree-remove-FIRST skill
- 4 Changed: #322A ASCII sweep, #319 history compress, W1 fold, W2 fold
- 3 Fixed: #325 ARCH path, #326 README hooks count, #322B hook ASCII extension
- 0 Removed

**Theme chosen:** "Sprint 13: Documentation accuracy and ASCII policy hardening" -- captures the two structural shifts (doc fixes #325/#326 + ASCII sweep #322A and hook extension #322B). Skipped the broader "markdown ASCII enforcement and squad hygiene" framing because doc-accuracy was the louder signal.

## Release pattern (3rd clean application: 0.9.1, 0.9.2, 0.9.3)

Same sequence each cut:

1. Mickey opens release/0.9.X branch from develop.
2. Mickey edits CHANGELOG to fold `[Unreleased]` entries under `[0.9.X] - YYYY-MM-DD -- <theme>`.
3. Mickey opens PR to develop (regular merge, preserve history).
4. Coordinator opens develop -> main PR (regular merge).
5. Coordinator tags `0.9.X` on main + `gh release create`.

Mickey's job ends at PR-open in step 3. No squash; no force-push.

**Why the pattern works:** Regular merge preserves the per-PR merge commits in the develop -> main mainline. Tag lands on main only. develop history stays linear-by-PR.

## Next-sprint hints (Sprint 14 candidates)

- Remaining ASCII gaps in non-`.md` / `.sh` / `.ps1` files; possible expansion of pre-commit ASCII scan to `.yml` / `.json` / `.txt`.
- Doc subagent worktree exercise (still untriggered as of Sprint 11 retro).
- Revisit history.md gate thresholds now that 15 KB has held two sprints with re-compress headroom.
- Watch the dogfood-incident pattern (own hook blocks own commit on legacy debt) -- if it recurs in Sprint 14, formalize as a skill per Mickey's #334 history note.

**Scope boundaries:** This file documents Mickey-owned release-cut pattern only. Tag / release-creation / develop -> main merge belong to Coordinator workflow (separate topic). Per-release CHANGELOG content lives in `CHANGELOG.md`, not here.


---

## pluto-dotfiles.md

# Decision: Dotfile Install Strategy (issue #11)

**By:** Pluto (Config Engineer)
**Date:** 2026-04-07
**Issue:** #11 -- [Config] Dotfile templates

---

## Decisions Made

### 1. Copy templates, don't symlink (for .gitconfig and .npmrc)

**Decision:** `.gitconfig.template` and `.npmrc.template` are **copied** to
`$HOME` rather than symlinked, so users can edit them freely without touching
the repo.

**Why:** These files routinely contain machine-specific values (name, email,
tokens). If symlinked, editing `$HOME/.gitconfig` would corrupt the repo template.

**Trade-off:** Changes to the repo template won't auto-propagate to existing
installs. Acceptable -- the install script's idempotency check handles
re-installs safely with backups.

---

### 2. Symlink .editorconfig (not copy)

**Decision:** `.editorconfig` is **symlinked** to `$HOME/.editorconfig`.

**Why:** Editor config is project-agnostic and not machine-specific. Symlinking
means updates to the canonical template in the repo propagate to all projects
automatically.

---

### 3. Placeholder substitution via sed, not envsubst

**Decision:** Use `sed -i` to substitute `YOUR_NAME` / `YOUR_EMAIL` placeholders
rather than `envsubst` or a templating engine.

**Why:** `envsubst` is not available on all platforms (notably macOS without
Homebrew). `sed` is universally available. The substitution is simple enough
that a regex approach is readable and safe.

---

### 4. .gitconfig backup on overwrite (not skip)

**Decision:** When `$HOME/.gitconfig` already exists and differs from the
template, **back it up** (`.bak`) and overwrite it -- rather than skipping.

**Why:** In Codespaces/Dev Containers, an existing `.gitconfig` may have been
auto-generated with wrong defaults. The template is the source of truth; the
backup preserves the user's previous state for recovery.

---

### 5. No .zshrc in this issue

**Decision:** This issue creates no `.zshrc` template.

**Why:** Issue #8 (shell aliases/shortcuts) owns `.zshrc`. Mixing concerns
would create a merge conflict risk and blur ownership.


---

## pluto-skill-drift-2026-05-17.md

# Sprint 16 Skill Drift Watchlist Audit

**Date:** 2026-05-17
**By:** Pluto
**Scope:** 30 .copilot/skills + 0 .squad/skills

## Summary

- Total skills audited: 30
- Eligible for graduation (low -> medium): 0
- Eligible for graduation (medium -> high): 0
- Stale watchlist (>90 days, no recent mentions): 0
- Never-applied: 27

## Per-skill findings

| Skill | Confidence | Last update | Mentions | Recommendation |
|---|---|---|---|---|
| agent-collaboration | "high" | 2026-05-17 | 0 | monitor |
| agent-conduct | "high" | 2026-05-17 | 0 | monitor |
| architectural-proposals | "high" | 2026-05-17 | 0 | monitor |
| ci-validation-gates | "high" | 2026-05-17 | 0 | monitor |
| cli-wiring | unknown | 2026-05-17 | 0 | monitor |
| client-compatibility | "high" | 2026-05-17 | 0 | monitor |
| cross-squad | "medium" | 2026-05-17 | 0 | monitor |
| distributed-mesh | "high" | 2026-05-17 | 0 | monitor |
| docs-standards | "high" | 2026-05-17 | 0 | monitor |
| economy-mode | "low" | 2026-05-17 | 0 | monitor |
| error-recovery | "high" | 2026-05-17 | 0 | monitor |
| external-comms | "low" | 2026-05-17 | 1 | keep |
| gh-auth-isolation | "high" | 2026-05-17 | 0 | monitor |
| git-workflow | "high" | 2026-05-17 | 2 | keep |
| github-multi-account | high | 2026-05-17 | 0 | monitor |
| history-hygiene | high | 2026-05-17 | 0 | monitor |
| humanizer | "low" | 2026-05-17 | 0 | monitor |
| init-mode | "high" | 2026-05-17 | 0 | monitor |
| model-selection | unknown | 2026-05-17 | 0 | monitor |
| nap | unknown | 2026-05-17 | 3 | keep |
| personal-squad | unknown | 2026-05-17 | 0 | monitor |
| project-conventions | "medium" | 2026-05-17 | 0 | monitor |
| release-process | "high" | 2026-05-17 | 0 | monitor |
| reskill | "high" | 2026-05-17 | 0 | monitor |
| reviewer-protocol | "high" | 2026-05-17 | 0 | monitor |
| secret-handling | high | 2026-05-17 | 0 | monitor |
| session-recovery | "high" | 2026-05-17 | 0 | monitor |
| squad-conventions | "high" | 2026-05-17 | 0 | monitor |
| test-discipline | "high" | 2026-05-17 | 0 | monitor |
| windows-compatibility | "high" | 2026-05-17 | 0 | monitor |

## Graduation candidates

No skills meet graduation thresholds at this time.

## Watchlist (stale or never-applied)

Skills with zero observed applications (monitor for utility):

- agent-collaboration (last updated 2026-05-17, confidence: "high", never applied)
- agent-conduct (last updated 2026-05-17, confidence: "high", never applied)
- architectural-proposals (last updated 2026-05-17, confidence: "high", never applied)
- ci-validation-gates (last updated 2026-05-17, confidence: "high", never applied)
- cli-wiring (last updated 2026-05-17, confidence: unknown, never applied)
- client-compatibility (last updated 2026-05-17, confidence: "high", never applied)
- cross-squad (last updated 2026-05-17, confidence: "medium", never applied)
- distributed-mesh (last updated 2026-05-17, confidence: "high", never applied)
- docs-standards (last updated 2026-05-17, confidence: "high", never applied)
- economy-mode (last updated 2026-05-17, confidence: "low", never applied)
- error-recovery (last updated 2026-05-17, confidence: "high", never applied)
- gh-auth-isolation (last updated 2026-05-17, confidence: "high", never applied)
- github-multi-account (last updated 2026-05-17, confidence: high, never applied)
- history-hygiene (last updated 2026-05-17, confidence: high, never applied)
- humanizer (last updated 2026-05-17, confidence: "low", never applied)
- init-mode (last updated 2026-05-17, confidence: "high", never applied)
- model-selection (last updated 2026-05-17, confidence: unknown, never applied)
- personal-squad (last updated 2026-05-17, confidence: unknown, never applied)
- project-conventions (last updated 2026-05-17, confidence: "medium", never applied)
- release-process (last updated 2026-05-17, confidence: "high", never applied)
- reskill (last updated 2026-05-17, confidence: "high", never applied)
- reviewer-protocol (last updated 2026-05-17, confidence: "high", never applied)
- secret-handling (last updated 2026-05-17, confidence: high, never applied)
- session-recovery (last updated 2026-05-17, confidence: "high", never applied)
- squad-conventions (last updated 2026-05-17, confidence: "high", never applied)
- test-discipline (last updated 2026-05-17, confidence: "high", never applied)
- windows-compatibility (last updated 2026-05-17, confidence: "high", never applied)

## Methodology notes

- **Mentions counted via** grep across .squad/agents/*/history.md files, case-insensitive skill name matching
- **Last-update timestamps** extracted from git log -1 --format=%ai for each SKILL.md file
- **Confidence** values read from SKILL.md frontmatter (confidence: field)
- **Drift criteria:**
  - Low -> Medium: confidence still 'low' after 3+ applications observed
  - Medium -> High: confidence still 'medium' after 5+ applications observed
  - Stale watchlist: last update >90 days ago AND zero history mentions
  - Never-applied: zero mentions across all agent history.md files

## Observations

All 30 skills in .copilot/skills were recently updated (2026-05-17), indicating fresh initialization of the worktree. The audit reveals 27 skills with zero observed applications in agent history, suggesting either:
1. History data is fresh/limited (early in sprint)
2. Skills are not yet integrated into agent workflows
3. Agent history files do not exist or are empty

Zero skills currently meet graduation thresholds. Once agents begin using skills and history accumulates, future audits will identify promotion candidates.

The presence of some "unknown" confidence values (cli-wiring, model-selection, nap, personal-squad) indicates inconsistent frontmatter in SKILL.md files - recommend standardization pass.

## Next steps

- Continue monitoring application counts in .squad/agents/*/history.md
- Issue #366 (graduation audit) will execute the recommended promotions once thresholds are met
- Consider standardizing confidence frontmatter across all skills
- Track future audits to identify drift patterns


---

## readme-edit-decisions-2026-05-17.md

# README Edit Decisions -- 2026-05-17 (Issue #342, Sprint 14 Wave 1.5)

**Author:** Mickey (Lead/Planner)
**Companion to:** `.squad/decisions/doc-readme-audit-2026-05-17.md` (Doc, 8 findings)
**Branch:** `squad/342-readme-edit` (off develop @ 234ee08)

This drop records the per-finding edit decisions applied to README.md in
response to Doc's fact-check audit. Captures what was changed verbatim,
what was deferred or skipped, and the load-bearing F3-first ordering so
the next "audit-then-edit" loop is mechanical.

## Decision Index

| Finding | Severity | Action | Implementation |
|---------|----------|--------|----------------|
| F1      | HIGH     | APPLIED | `### pre-commit` rewritten to 6-bullet list mirroring `hooks/pre-commit` header (Checks 1-6). Sprint 13 `.md`/`.sh` scope extension callout embedded in Check 2 along with `ascii-sweep.py` cross-reference. |
| F2      | HIGH     | APPLIED | New `### ASCII sweep helper (scripts/lib/ascii-sweep.py)` subsection at end of Git Hooks. Includes `--dry-run` usage + the fenced-code-preservation caveat. |
| F3      | HIGH     | APPLIED FIRST | File-tree fenced block at L80-L130 hand-converted from box-drawing glyphs (U+251C / U+2502 / U+2514 / U+2500) + em dashes (U+2014) to ASCII (`+--`, `|`, `\--`, `-`, `--`). 645 non-ASCII bytes -> 0. |
| F4      | MEDIUM   | APPLIED | `scripts/lib/ascii-sweep.py` line added under the `scripts/lib/` tree entry as the new `\--` last child. |
| F5      | MEDIUM   | APPLIED | `hooks/pre-commit` one-liner in the file-tree expanded from "Shellcheck on staged .sh files" to "6-check hygiene gate (branch ancestry + ASCII on .ps1/.md/.sh + .squad/ allow-list + inbox guard + branch refusal + shellcheck); see Git Hooks below". |
| F6      | LOW      | SKIPPED | Per-OS `lib/` subdirs (`scripts/linux/lib/`, `scripts/windows/lib/`) omitted from README tree. Defensible: README operates at coarser granularity than ARCHITECTURE.md, which already documents these (L41-L42, L55-L57). No reader confusion observed. |
| F7      | LOW      | FOLDED into F1 | The develop/main/master direct-commit refusal is Check 5 of the new 6-bullet `### pre-commit` description. No standalone bullet needed. |
| F8      | LOW      | EXPLICITLY SKIPPED | "team of nine specialized AI agents" left at "nine" per Doc's verified count against `.squad/team.md` (9 active rows) and `.squad/agents/` (9 dirs). Sprint 13 retro L9 confirms "nine agent dispatches". Task brief's "10 agents" did NOT match repo state; no 10th charter exists. If a 10th agent is hired, the L246 bump rides that PR. |

## Load-bearing F3-first ordering (skill candidate)

The audit flagged 645 non-ASCII bytes inside the README's file-tree fenced
code block. Two facts combine to make F3 the mandatory first step:

1. **`scripts/lib/ascii-sweep.py` (#322A) preserves fenced code by design.**
   See `sweep_text` in `scripts/lib/ascii-sweep.py` -- non-ASCII inside
   ``` ... ``` is left verbatim so code examples stay literal.
2. **`hooks/pre-commit` Check 2 (#322B / PR #334) does NOT respect fences.**
   It scans the full staged content via
   `git show ":$file" | grep -nP '[^\x00-\x7f]'`.

Therefore: running the sweep on README would have left the 645 bytes
intact, and staging README with those bytes still present would have
failed Check 2. Hand-conversion was the only path. Implementation:

```powershell
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
# Multi-char swaps first (preserve "+-- " / "\-- " idioms)
$text = $text.Replace([string][char]0x251C + [string][char]0x2500 + [string][char]0x2500, '+--')
$text = $text.Replace([string][char]0x2514 + [string][char]0x2500 + [string][char]0x2500, '\--')
# Then standalones
$text = $text.Replace([string][char]0x2502, '|')
$text = $text.Replace([string][char]0x2500, '-')
$text = $text.Replace([string][char]0x2014, '--')
# ...plus en-dash, smart quotes, nbsp, ellipsis
[System.IO.File]::WriteAllText($path, $text, [System.Text.Encoding]::ASCII)
```

**Skill candidate (2nd application if it recurs):** "audit-then-edit with
fenced-block precondition" -- when Doc audits a doc that contains fenced
non-ASCII, Mickey (or whoever applies) MUST hand-convert the fenced block
BEFORE any other edit lands, or `--no-verify` is the only path. Goofy's
sweep is necessary but insufficient for fenced content. Watch for the
3rd application before formalizing in `.squad/skills/`.

## Rejected alternatives

- **"Regenerate the file-tree from ARCHITECTURE.md's tree."** ARCHITECTURE.md
  uses a similar tree style; copying would risk introducing the same glyphs.
  Hand-conversion of the existing tree was lower-risk.
- **"Add F2 under `## Contributing` (Doc's alternative placement)."**
  Rejected: contributors hit the ASCII issue via pre-commit, not via
  Contributing. Putting the helper subsection adjacent to the
  `### pre-commit` description keeps the cross-reference one screen away.
- **"Add per-OS `lib/` subdirs (F6) for completeness."** Rejected as
  scope creep: README sits one level above ARCHITECTURE.md and the
  current tree is already at the deepest detail it should go. Promote
  to a follow-up issue only if a contributor reports confusion.

## Out-of-scope follow-ups (NOT addressed here)

- README's `hooks/` tree shows three entries (commit-msg, pre-commit,
  pre-push); the prose at L193 says "four hooks are active" and the
  fourth (`prepare-commit-msg`) has its own subsection at L216. The
  tree-vs-prose count mismatch is pre-existing and was NOT in Doc's
  audit (Doc verified "four hooks" prose as correct). File a separate
  issue if visible tree completeness matters.
- Sprint 13 ARCH/README accumulated other small staleness signals
  (e.g. `.gitattributes` not mentioned in README tree). Out of scope
  for #342; the next periodic Doc audit will surface them.

## Verification

- README.md: 11015 B -> 13039 B; 645 non-ASCII bytes -> 0.
- CHANGELOG.md: +1 bullet under `[Unreleased] ### Changed`.
- Pre-commit Checks 1-6 all green on the staged commit (verified before push).

## Confidence

HIGH on all 5 HIGH/MEDIUM applications (F1, F2, F3, F4, F5).
HIGH on F6/F7/F8 disposition (F8 verified by Doc against `.squad/team.md`;
F6/F7 explicit judgment recorded above).


---

## release-094-2026-05-17.md

# Decision: 0.9.4 Release Flow -- Sprint 14 Wrap

**Date:** 2026-05-17
**Author:** Mickey (Lead/Planner)
**Status:** executed

## Context

Sprint 14 shipped 6 issues across 6 PRs. Release/0.9.4 branch cut from develop @ 9e93fca.

## Issues shipped

| Issue | What | PR | CHANGELOG category |
|------:|------|----|-------------------|
| #340 | history-compression skill formalization | #345 | Added |
| #341 | per-topic inbox routing skill formalization | #345 | Added |
| #342 | README refresh (Doc audit + Mickey edits) | #346 + #348 | Changed |
| #343 | CHANGELOG editorial -- Sprint 13 retro moved to [0.9.3] | #344 | meta (fold itself is entry) |
| #347 | Label taxonomy 45->32 + 84 issues migrated | #349 | Changed |
| #350 | sync-squad-labels.yml follow-ups | #351 | Changed |

## Release flow executed

1. Worktree: `C:\Users\Earl Tankard\Coding\dev-setup-release-094` on `release/0.9.4`
2. CHANGELOG: [Unreleased] folded to [0.9.4] - 2026-05-17; new empty [Unreleased] boilerplate added.
3. mickey/history.md: Sprint 11-13 entries + Sprint 14 W1.5 prose compressed to dated bullets (14678 B -> 10275 B); Sprint 14 wrap appended. history-compression skill applied.
4. PR #1: release/0.9.4 -> develop (squash merge, --admin).

## Deviations from standard flow

- None. Standard 3-step flow: CHANGELOG fold -> commit+push worktree -> PR#1 squash to develop.

## Invariants confirmed

- Tags bare X.Y.Z format (no v prefix); latest was 0.9.3.
- Release branch -> develop: SQUASH.
- develop -> main: REGULAR merge (coordinator handles).
- Tag 0.9.4 on main AFTER develop->main merge (coordinator handles).
- `gh release create --target main` (coordinator handles).

## Coordinator next steps

1. Merge PR #1 (squash) to develop -- if not already done.
2. From main worktree: `git checkout main && git merge --no-ff develop` (regular merge, not squash).
3. `git tag 0.9.4` on main merge commit.
4. `git push origin main --tags`.
5. `gh release create 0.9.4 --target main --title "0.9.4" --notes "Sprint 14 wrap. See CHANGELOG."`.
6. Sprint 14 retro: dispatch Scribe BEFORE next release-cut per changelog-retro-placement.md.

## History compression note

history.md was at 14678 B pre-wrap (already over 13 KB target). history-compression skill
(confidence: medium, formalized in #340) applied: Sprint 11-13 section and Sprint 14 W1.5
prose compressed to one-line dated bullets. Final: 10275 B (well under 13 KB target and
15360 B hard gate).


---

## scribe-history-compression.md

# Decision: Scribe history-compression workflow

**By:** Scribe (Session Logger / Knowledge Keeper)
**Issue:** #319
**Date:** 2026-05-17

---

## 2026-05-17 Sprint 13 Wave 1 -- history archival sweep

**What shipped:** Compressed 8 over-gate `.squad/agents/*/history.md` files per the Scribe charter 15 KB HARD GATE.

Two compression options were applied per file size:

- **Option B (split with `history-archive.md`):**
  - `mickey` -- 80823 -> 12076 B live + archive 57671 B
  - `goofy` -- 39857 -> 13923 B live + archive 24057 B
  - `chip` -- 36943 -> 12470 B live + archive 19911 B
- **Option A (summarize-in-place, no archive file):**
  - `pluto` -- 29712 -> 14792 B
  - `donald` -- 28539 -> 12712 B
  - `jiminy` -- 28051 -> 8630 B
  - `ralph` -- 28464 -> 9503 B
  - `scribe` -- 20511 -> 13334 B (including the Sprint 13 hygiene-tail entry)

All 9 agent histories under 15 KB after the sweep.

**Why:** The charter HARD GATE was breached on 8 of 9 agents. Jiminy's Sprint 12 session-end audit (PR #318) and PR #323 surfaced the size pressure; #319 was filed as Sprint 13 P0.

## Compression heuristic (lesson candidate for `.squad/skills/history-compression/SKILL.md`)

1. Keep front-matter sections verbatim (`Project Context`, `Key Details`, `Core Context`, `Learnings` preamble).
2. Keep most-recent-sprint entries verbatim (Sprint 11+ during the Sprint 13 sweep, since Sprint 12 was just wrapped).
3. Reduce older sessions to dated one-line bullets: `YYYY-MM-DD -- <what shipped> (PR/issue refs)`.
4. Preserve literally: skill triggers, recurring-incident patterns (worktree-isolation, ASCII gaps, autocrlf, AllScope alias, CP1252 trap), and PR/issue cross-refs that future archaeology needs.
5. Defer formalization to `.squad/skills/history-compression/SKILL.md` until a 2nd application confirms the heuristic generalizes.

## Scope boundaries honored

- No edits to `decisions/*.md` topic files (separate workflow).
- No edits to non-`history.md` files (except the `CHANGELOG.md` entry per spec).
- No retroactive review/judgement of agent past decisions -- Scribe is custodian, not critic.

## Forward-fix reminder (from PR #323 atomic-drain bug)

When folding `.squad/decisions/inbox/` drops in a future cycle, the per-topic-file append AND the removal of the source drop file MUST land in the SAME commit so drain is atomic with merge. The Sprint 13 Wave 1 fold (this PR's companion) explicitly re-tests this guarantee.

## 2026-05-17 Sprint 13 Wave 1 fold -- jiminy/history.md re-compression

Post-sweep regression: `.squad/agents/jiminy/history.md` regressed from 8630 B to 22548 B after Sprint 12 hygiene tails + the Sprint 13 Wave 1 post-batch audit tail were rebased back in. Re-compressed in this fold under Option A: older Sprint 12 verbose audit blocks reduced to one-line bullets; Sprint 13 Wave 1 entries (Jiminy's own + post-batch audit) preserved verbatim per spec; recurring-incident references (worktree-isolation, ASCII gap, atomic-drain) preserved verbatim.

This is the **2nd application** of the compression heuristic (1st was the Sprint 13 Wave 1 sweep above). One more application would justify formalizing as `.squad/skills/history-compression/SKILL.md`.


## 2026-05-17 Sprint 13 Wave 2 -- Scribe W1 fold outcome (forward-fix verification)

**By:** Scribe (folded from inbox drop `scribe-w1-fold-2026-05-17.md`)
**Issue:** follow-on to #319; forward-fix of PR #323 atomic-drain bug
**PR:** Sprint 13 W1 fold companion PR

**What happened:**

- Drained 3 Sprint 13 Wave 1 inbox drops into per-topic decisions files (atomic with this commit):
  - `mickey-w1-2026-05-17-issues-325-326.md` -> appended to `mickey-architecture-entry-point.md` (broadened topic to ARCH+README accuracy; 2710 -> 4207 B)
  - `jiminy-w1-2026-05-17-issue-317-skill.md` -> appended to `doc-and-jiminy-automation.md` (hygiene-automation theme; 12115 -> 14152 B)
  - `scribe-w1-2026-05-17-history-archival.md` -> NEW `scribe-history-compression.md` (this file; 3242 B)
- Re-compressed `.squad/agents/jiminy/history.md` from 22548 B back to 13078 B (Option A summarize-in-place). Sprint 13 Wave 1 entries kept verbatim per spec; older Sprint 12 verbose audits reduced to one-line bullets; recurring-incident references (worktree-isolation, ASCII gap, atomic-drain) kept literal.

**Atomic-drain verification (canonical model going forward):**

Inbox is gitignored (`.gitignore:4: .squad/decisions/inbox/`), so `git rm` cannot stage tracked deletions. The drain is enforced by physically removing the source drop files from the main-checkout inbox in the same wall-clock action as the per-topic append. Validation: `Get-ChildItem .squad/decisions/inbox/` in the main checkout must NOT contain the drained files when this PR merges. **A future Scribe should not look for `git rm` of inbox files -- physical delete IS the atomic action.** This forward-fix decision drop (`scribe-w1-fold-2026-05-17.md`) was itself folded in the next cycle (Sprint 13 W2 fold).

**Sizes:**

- jiminy/history.md before W1 fold: 22548 B; after: 13078 B (target was <13312 B, achieved 234 B headroom)
- scribe/history.md after Sprint 13 W1 Fold hygiene-tail: 15076 B (still under 15 KB hard gate, but tight -- prompted W2 fold re-compress of scribe + 3 others)
- Target topic files written: `mickey-architecture-entry-point.md`, `doc-and-jiminy-automation.md`, `scribe-history-compression.md` (new)

**Scope boundaries honored:** No other agent histories compressed in W1 fold (jiminy was the only regression). No hooks/scripts/code touched. No consolidated `decisions.md` reintroduced -- per-topic model is current state.


## 2026-05-17 Sprint 13 Wave 2 fold outcome (3rd application)

**By:** Scribe (folded from inbox drop `scribe-w2-fold-2026-05-17.md` by Jiminy session-end audit)
**Issue:** follow-on to #319; 2nd application of atomic-rm forward-fix (PR #323 origin)
**PR:** #336 (Sprint 13 W2 fold)

**What shipped:**

- Drained 3 Sprint 13 Wave 2 inbox drops into per-topic decisions files:
  - `scribe-w1-fold-2026-05-17.md` -> appended to this file (3190 -> 5603 B). Continues history-management thread.
  - `mickey-w2-2026-05-17-hook-extension.md` -> NEW `mickey-hook-policy.md` (2833 B). Mickey-owned hook policy topic.
  - `goofy-w2-2026-05-17-ascii-sweep.md` -> NEW `goofy-ascii-sweep.md` (2661 B). Seed for future ascii-sweep SKILL.md.
- Re-compressed 4 over-gate `.squad/agents/*/history.md` files (Option A summarize-in-place): jiminy 18091 -> 13550 B, goofy 15158 -> 10925 B, scribe 15076 -> 15169 B (tight), mickey 15024 -> 12988 B.

**Skill-formalization readiness (3rd application of compression heuristic):**

This Wave 2 fold is the 3rd clean application of the WHAT-to-preserve heuristic from PR #332: (a) front-matter / Core Context / Learnings preamble verbatim; (b) current-sprint entries verbatim per spec; (c) older sessions to dated bullets; (d) skill triggers + recurring-incident patterns preserved literal. Threshold met across 3 distinct contexts (initial sweep, single-file re-compress, multi-file re-compress). **READY** to formalize as `.squad/skills/history-compression/SKILL.md` with `confidence: medium`. Sprint 14 issue candidate.

**Atomic-rm canonical model confirmed (going forward):**

Inbox is gitignored (`.gitignore:4: .squad/decisions/inbox/`), so `git rm` cannot stage tracked deletions. The drain is enforced by **physically removing** the source drop files from the main-checkout inbox in the same wall-clock action as the per-topic append. Validation: `Get-ChildItem .squad/decisions/inbox/` in main checkout must NOT contain the drained files when the fold commit lands. **A future Scribe should not look for `git rm` of inbox files -- physical delete IS the atomic action.** Two clean applications now (PR #333 W1 fold, PR #336 W2 fold) -- model is stable.

**Scope boundaries honored:** No `decisions.md` / `decisions-archive.md` edits (parallel chronological journal). No code/hooks/scripts. No chip/donald/pluto/ralph/doc histories compressed (all under gate).


---

## sync-workflow-followups-2026-05-17.md

# Decision: sync-squad-labels.yml Follow-up Fixes

**Date:** 2026-05-17
**Issue:** #350 (closes)
**PR:** squad/350-sync-workflow-followups
**Sprint:** 14 Wave 3 (pulled from Sprint 15 candidates per Earl's call)
**Surfaces from:** #347 Phase 6 workflow audit

---

## Context

Three mechanical gaps in `.github/workflows/sync-squad-labels.yml` were
identified during the #347 Phase 6 audit and filed as #350. The workflow
was not managing three label groups that exist in the repo:
`priority:p3`, and the `platform:*` set created in PR #349. Additionally,
dead code left over from an abandoned @copilot integration path was
cluttering the script.

---

## Fix 1: Add `priority:p3` to PRIORITY_LABELS (line ~93)

`priority:p3` has existed in the repo since Sprint 12 W1 (#254) but was
never added to the workflow's `PRIORITY_LABELS` array. Without this entry,
the workflow cannot re-create the label if it is ever deleted, and will not
sync description or color changes.

**Entry added:**
```js
{ name: 'priority:p3', color: 'D4E5F7', description: 'Backlog / icebox' }
```

### Color choice rationale

Two options were presented in the issue:
- `0E8A16` (green) -- same as `go:yes` (Ready to implement)
- `D4E5F7` (light blue) -- same as `release:backlog` (Not yet targeted)

**Chosen: `D4E5F7`**

Rationale: "Backlog / icebox" is semantically equivalent to
`release:backlog` -- both signal "not yet targeted / deferred". Using the
same cool-tone light blue (`D4E5F7`) groups them visually and avoids
conflating `priority:p3` with `go:yes`, which carries a "ready" signal.
Green (`0E8A16`) connotes readiness; light blue connotes deferral. The
choice is self-documenting.

Note: The existing repo label had color `0075CA` and description
"Enhancement -- nice to have". The workflow will update it to `D4E5F7` /
"Backlog / icebox" on next sync run per the `updateLabel` path.

---

## Fix 2: Add PLATFORM_LABELS array + push (lines ~96-100, ~122)

Three `platform:*` labels were created in PR #349 (`platform:linux`,
`platform:macos`, `platform:windows`, all color `0052CC`). The workflow
had no `PLATFORM_LABELS` array, so these labels were unmanaged -- they
could not be re-created or synced if deleted.

**Array added after PRIORITY_LABELS:**
```js
const PLATFORM_LABELS = [
  { name: 'platform:linux',   color: '0052CC', description: 'Linux-specific' },
  { name: 'platform:macos',   color: '0052CC', description: 'macOS-specific' },
  { name: 'platform:windows', color: '0052CC', description: 'Windows-specific' }
];
```

**Push added with the other static label groups:**
```js
labels.push(...PLATFORM_LABELS);
```

Color `0052CC` matches the labels created in PR #349 (confirmed via
`gh label list --search "platform:"`).

---

## Fix 3: Remove dead `hasCopilot` code (Option A)

Three code blocks were removed:

1. **`const hasCopilot` check** (was line 62-63):
   ```js
   // Check if @copilot is on the team
   const hasCopilot = content.includes('...robot emoji... Coding Agent');
   ```

2. **`COPILOT_COLOR` const** (was line 68):
   ```js
   const COPILOT_COLOR = '10b981';
   ```

3. **`if (hasCopilot)` conditional push** (was lines 114-121):
   ```js
   if (hasCopilot) {
     labels.push({
       name: 'squad:copilot',
       color: COPILOT_COLOR,
       description: 'Assigned to @copilot (Coding Agent) for autonomous work'
     });
   }
   ```

**Rationale for Option A (remove, not integrate):**

Earl did not specify @copilot integration plans for #350. Option A was the
explicit fallback in the issue body. The `content.includes()` check searched
for a robot emoji string that never matched any actual `team.md` content
(no team.md has ever included that exact emoji + text combination). The
code was dead from birth. Removing it eliminates 4 bytes of non-ASCII
(the robot emoji U+1F916 UTF-8 encoding) as a side benefit.

If @copilot integration is later desired, a new issue should be filed to
design the team.md marker format and workflow behavior explicitly.

---

## Pre-existing non-ASCII em-dashes in workflow YAML

The workflow YAML contains 5 em-dashes on lines 31, 80, 86, 106, 132
(15 non-ASCII bytes total in UTF-8). These are **deliberately left in
place** and are out of scope for this PR.

The pre-commit ASCII Check 2 (`grep -nP '[^\x00-\x7f]'`) does NOT scan
`.yml` files -- its scope is `.ps1`, `.sh`, and `.md` only. Therefore
these em-dashes do not violate any enforced policy. This was documented in
the #347 decision drop and confirmed again here.

**Post-Fix 3 workflow YAML non-ASCII byte count: 15**
(was 19 before Fix 3; delta is exactly 4 bytes -- the U+1F916 UTF-8
four-byte sequence that was removed with the dead code)

---

## References

- Closes #350
- Surfaces from #347 Phase 6 audit (Sprint 14 W2)
- Sprint 14 Wave 3 attribution (pulled from Sprint 15 candidates)
- PR #349: platform:* labels created (Pluto, Sprint 14 W2)
- Sprint 12 W1 precedent: #254 / PR #315 (same gap for priority:p3 first noted)
- `.squad/skills/label-hygiene/SKILL.md`: audit-before-delete SOP

