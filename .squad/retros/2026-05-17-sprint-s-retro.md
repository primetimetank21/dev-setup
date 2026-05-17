# Sprint S Retro -- 2026-05-17

Sprint S folded the Sprint R action items into the codebase and tackled the
HYGIENE backlog that Sprint Q bumped to P0/P1. Ten PRs (#274-#283) merged.
Doc's batch fact-check caught 2 real bugs pre-merge (the `--global` /
`$LASTEXITCODE` interaction in #277 and a wrong-npm-package pin in #282), and
the version-pin anti-pattern that produced the original #255 squad-cli warning
was codified into a new skill.

## What Shipped

| PR  | Owner       | One-liner                                                                                       |
|-----|-------------|-------------------------------------------------------------------------------------------------|
| #274 | Mickey     | Sprint R retro action items: Ralph develop-commit ban, Group letter SOP, CHANGELOG strategy doc |
| #275 | Pluto      | `.gitattributes` CRLF rule for `*.ps1` / `*.psm1` / `*.psd1` (closes #231)                      |
| #276 | Goofy      | `-Encoding ASCII` migration across `scripts/windows/**.ps1` + Group Z tests (closes #234)       |
| #277 | Pluto      | `uninstall` core.hooksPath fix: drop `--global`, reset `$LASTEXITCODE`, use `log_ok` (closes #271) |
| #278 | Donald     | Logging consolidation in `setup.sh` + `uninstall.sh` -- `log_ok` helper (closes #223)           |
| #279 | Chip       | #255 squad-cli persistence-warning regression sentinel + YAML single-quote escape fix; Group T10/T11 |
| #280 | Jiminy     | `.gitignore *.tgz` + Coordinator-must-invoke-Jiminy SOP after every 3+ agent batch              |
| #281 | Coordinator | Doc history fold #1 -- Sprint S 6-PR batch fact-check entry into `doc/history.md`              |
| #282 | Goofy      | Tool-version pin sweep: squad-cli 0.9.4, copilot-cli 1.0.48, gh 2.92.0 + `tool-version-pin` skill |
| #283 | Coordinator | Doc history fold #2 -- PR #282 fact-check entry into `doc/history.md`                          |

## What Went Well

- **Doc's batch fact-check caught two real bugs before merge.** PR #277 had a
  scope mismatch (`git config --global core.hooksPath` against a `--local`
  write) that combined with `$LASTEXITCODE` leakage through pwsh `& .\script`
  boundaries to kill the Windows E2E step. PR #282 pinned
  `@githubnext/github-copilot-cli@0.0.339` -- a package version that has
  never existed on npm. Both would have shipped without Doc's verification.
- **Version-pin anti-pattern eliminated.** The original #255 bug (Linux still
  installing squad-cli 0.8.25 long after `.tool-versions` pinned 0.9.4) was
  traced to idempotency guards like `command -v X && exit 0` that silently
  freeze stale installs. Fix landed in #282 and was codified in
  `.squad/skills/tool-version-pin/SKILL.md` plus CONTRIBUTING's new "Tool
  Version Pin Enforcement" section. `.tool-versions` is now actually honored
  by both Linux and Windows installers via `scripts/lib/read-tool-version.sh`
  + `Read-ToolVersion.ps1`.
- **Sprint R action items shipped as a single docs-only PR.** PR #274 cleared
  three Sprint R retro items (Ralph develop-commit ban, Group letter SOP,
  CHANGELOG conflict strategy) in 42 LOC. Retro -> action -> code loop closed
  in one sprint.
- **Jiminy auto-trigger gap closed mid-sprint.** Earl flagged that Coordinator
  had not invoked Jiminy after the first multi-agent batch, leaving a rogue
  `bradygaster-squad-sdk-0.9.4.tgz` on develop. Jiminy's recovery PR #280 not
  only deleted the file and gitignored `*.tgz`, it SOP'd the Coordinator
  dispatch requirement ("invoke Jiminy after every 3+ agent batch and at
  session-end") into CONTRIBUTING.md.
- **Doc history fold pattern executed cleanly twice.** PRs #281 and #283
  folded Doc's `history.md` writes via short-lived branches +
  `docs(squad):` commits, keeping develop hook-clean throughout.

## What Could Be Better

- **`$LASTEXITCODE` leaks across pwsh `&` script boundaries.** PR #277's
  initial revision passed locally but failed Windows E2E because `git config
  --global --unset core.hooksPath` returns 5 when the key is absent, and the
  GitHub Actions pwsh-step wrapper propagates `$LASTEXITCODE` as the step
  exit code. Mitigation now standard: `$global:LASTEXITCODE = 0` after any
  expected-failure native command in a `.ps1` we run via `& .\script.ps1`.
  ACTION: bake this into `.squad/skills/tool-version-pin/SKILL.md` or a new
  `pwsh-lastexitcode` skill.
- **YAML single-quote escaping inside `bash -lc '...'`.** PR #279 added a
  regression sentinel for #255 but the first revision broke the workflow YAML
  because the embedded warning message contained an apostrophe. Fix: doubled
  single quote (`'\''` is wrong here; YAML single-quoted scalar uses `''`).
  The bash-inside-YAML quoting matrix is small enough to document.
- **Inter-PR function-rename collision.** PR #277 introduced a fresh `log_ok`
  call site while PR #278 was renaming the legacy `ok` -> `log_ok` in the
  same `uninstall.sh`. The CI rebase exposed the collision; no production
  bug, but ~30 minutes of merge sequencing to resolve. ACTION: when two open
  PRs touch the same shell-helper namespace, Coordinator should either
  sequentialize them or coordinate names up-front at spawn time.
- **Test-group letter collision repeated.** Chip's #279 initially used T6/T7;
  Goofy's #282 used T6-T9 for pin-enforcement tests. Resolved at rebase by
  renumbering Chip to T10/T11. The Group-letter SOP from #274 should also
  reserve letters at sprint-plan time, not at PR-open time. ACTION: extend
  Coordinator's spawn checklist to pre-assign Group letters across BOTH
  `tests/test_windows_setup.ps1` (X, Y, Z, AA, ...) AND
  `tests/test_precommit_hygiene.sh` (T1, T2, ...).
- **Jiminy dispatch was manual.** Coordinator forgot to invoke Jiminy after
  the first 3-agent batch (Pluto/Goofy/Donald early in Sprint S), leaving
  dirty develop. The SOP added in #280 fixes this going forward, but the
  trigger is still operator-enforced rather than auto.
- **Doc subagent worktree pattern is high-friction.** Doc runs as a
  `general-purpose` subagent inside the primary worktree, so his
  `.squad/agents/doc/history.md` writes show up as uncommitted changes on
  develop after each batch. This sprint required TWO history-fold PRs
  (#281 + #283). ACTION: Consider running Doc in a dedicated worktree, or
  routing his history writes to a pre-created `squad/doc-history-<sprint>`
  branch so the fold is a single PR per sprint.
- **CHANGELOG conflicts at every sprint.** Predictable because every PR
  appends to `[Unreleased]`. The "CHANGELOG Conflict Strategy" added to
  CONTRIBUTING.md in #274 (union both entries, no duplicates) worked
  perfectly when applied -- e.g. #277 / #279 both touched `### Fixed`. But
  the strategy is still operator-enforced; no tooling enforces it.

## Doc's Batch Fact-Check Verdicts

Doc reviewed PRs #274-#279 as a batch and PR #282 as a deep-dive. Key
findings (full reports lived in
`.squad/decisions/inbox/doc-sprint-s-batch-fact-check.md` and
`doc-pr-282-fact-check.md`; both drained this PR after confirming the
content is folded into `doc/history.md` via #281 + #283):

- **#274 PASS, #275 PASS, #276 PASS, #278 PASS, #279 PASS.**
- **#277 REVISE (P1, small fix).** Two coupled bugs: (a) `git config
  --global --unset core.hooksPath` targets a config file the key was never
  written to (setup writes `--local`); git returns non-zero. (b) On Windows
  CI that non-zero leaks through `$LASTEXITCODE` and the pwsh-step wrapper
  kills the step. Fix: drop `--global`, reset `$global:LASTEXITCODE = 0`,
  and convert the success log to the new `log_ok` helper. Plus: a fresh
  `log_ok` call site collided with the rename in #278; sequencing was the
  fix.
- **#282 BLOCK (P0).** `@githubnext/github-copilot-cli@0.0.339` does not
  exist on npm; the package is deprecated and frozen at 0.1.36, and the old
  version number was a relic of the prior `curl gh.io/copilot-install`
  installer. Revised pin: `@github/copilot@1.0.48` (the modern, actively-
  maintained CLI). Verified via `npm view "@github/copilot@1.0.48" version`.
  Windows pivoted from `winget GitHub.Copilot` (which is the **Visual
  Studio extension**, NOT the CLI) to the same npm install path. Group
  letter DD did not collide.

Recommended merge order honored: #274, #275, #276, #278, #277 (post-fix),
#279 for the batch; #282 (post-pin-correction), #283 for the tail.

## Learnings

- **Idempotency guards freeze stale versions.** Patterns like
  `command -v squad >/dev/null && exit 0` short-circuit before the
  `.tool-versions` pin is consulted. The fix is a two-step gate: check
  presence AND check version match against the pinned value before
  skipping. Codified in `.squad/skills/tool-version-pin/SKILL.md`.
- **`.tool-versions` pins that aren't honored are worse than no pin.** A
  pin file creates a false sense of safety. The install scripts must read
  the file (we now do via `scripts/lib/read-tool-version.sh` and
  `Read-ToolVersion.ps1`) AND the test harness must assert the installed
  version equals the pinned value (we now do via #282's T6-T9 + DD-1..DD-5).
- **Validate npm package names AND versions before pinning.** Pre-PR
  validation step: `npm view "@pkg@version" version` must return the
  version number (not an error) before the pin is committed. Now part of
  the tool-version-pin SKILL.md validation checklist.
- **`winget` package IDs are ambiguous.** `GitHub.Copilot` is the Visual
  Studio extension, not the CLI. Any winget pin should be cross-checked
  against `winget show <id>` description before commit.
- **`$LASTEXITCODE` leaks through pwsh `&` script call boundaries.** The
  Actions pwsh-step wrapper appends `if (Test-Path variable:\LASTEXITCODE)
  { exit $LASTEXITCODE }`, so any unhandled non-zero from a native command
  inside a `.ps1` we invoke with `& .\script.ps1` propagates as the step
  exit code. Always reset `$global:LASTEXITCODE = 0` after expected-failure
  native commands.
- **YAML single-quote escaping inside `bash -lc '...'`.** Use doubled
  single-quote (`''word''`) to embed apostrophes inside a YAML single-
  quoted bash payload. The escape sequence is per the YAML spec, not bash.
- **Inter-PR function-rename collisions are predictable.** When one PR
  renames a shared helper, every concurrent PR touching the same file is
  at risk of orphaning the old name or duplicating the new one. Either
  sequentialize or pin names up-front.
- **Doc fact-check is highest-ROI on pin sweeps and shell-heavy PRs.** Two
  consecutive sprints (R and S) caught two real pre-merge bugs each. This
  is now a standing pattern; Coordinator should auto-spawn Doc on any PR
  matching: tool pins, install scripts, `set -euo pipefail` shell, or
  cross-platform parity changes.
- **Test-group letters need sprint-plan-time reservation.** Sprint R had a
  Group X collision; Sprint S had a Group T collision. The #274 SOP
  reserves at PR-open time, which is too late when 2+ agents are in flight
  simultaneously. Coordinator must reserve at spawn time.
- **Coordinator dispatch SOPs need auto-enforcement.** The Jiminy "invoke
  after every 3+ agent batch" rule was missed once this sprint. SOP doc
  exists (#280); next step is either a checklist gate in the spawn skill
  or a process-level reminder.

## Action Items (Sprint T)

- **[Coordinator] Pre-assign test-group letters at sprint plan time.** Both
  `tests/test_windows_setup.ps1` (Groups A..ZZ) and
  `tests/test_precommit_hygiene.sh` (T-prefix). Bake into the spawn
  checklist; reject spawns that don't declare their reserved group(s).
- **[Mickey] Author a `pwsh-lastexitcode` skill (or expand
  `tool-version-pin`).** Capture the `$global:LASTEXITCODE = 0` mitigation
  + the pwsh-step wrapper propagation pattern + a few canonical
  expected-failure sites (git config --unset, npm uninstall, gh api 404).
- **[Mickey] Extend the CHANGELOG conflict strategy to function-rename
  collisions.** Add a CONTRIBUTING.md note: when a PR renames a shared
  helper, coordinator should sequentialize concurrent PRs touching the
  same file or freeze the rename until they merge.
- **[Coordinator + Earl] Decide Doc worktree pattern.** Either move Doc to
  a dedicated worktree (so his `history.md` writes don't dirty the
  primary), or pre-create a `squad/doc-history-<sprint>` branch at sprint
  start so all his writes accumulate on one branch and fold in a single PR.
  Two PRs per sprint (#281 + #283) is unsustainable as Doc's review
  cadence grows.
- **[Ralph] EOS sweep for Sprint S.** Six stale remote `squad/*` branches
  survive post-merge (per Jiminy's end-of-sprint audit in
  `jiminy/history.md`): `223-logging-consolidation`, `231-ps1-gitattributes`,
  `234-ps1-ascii-encoding`, `255-squad-cli-warning`, `255-tool-version-pins`,
  `271-uninstall-hookspath`. Plus the Coordinator + Doc fold branches.
  Dispatch after this PR merges.
- **[Coordinator] Make Jiminy dispatch auto-enforced, not advisory.** SOP
  in #280 is the right rule. Add a session-end checklist gate that fails
  the wrap if Jiminy wasn't invoked after the last batch.
- **[Standing pattern] Auto-spawn Doc on:** tool-version pins; install
  scripts (`scripts/*/tools/*`); `set -euo pipefail` shell additions;
  cross-platform parity PRs; any PR that switches a tool's install
  mechanism (e.g., winget -> npm).

## Stats

- **PRs merged this sprint:** 10 (#274 through #283).
- **Agents dispatched:** 9 -- Mickey (#274), Pluto (#275 + #277), Goofy
  (#276 + #282), Donald (#278), Chip (#279), Jiminy (#280), Coordinator
  (#281 + #283), Doc (batch fact-check on #274-#279, deep-dive on #282).
- **Lines changed (develop @ Sprint R wrap -> develop @ 6e8995a):**
  28 files changed, 1,165 insertions, 126 deletions.
- **Real bugs caught pre-merge by Doc:** 2 (#277 scope/`$LASTEXITCODE`
  combo; #282 nonexistent npm package).
- **Real bugs shipped post-merge:** 0.
- **New skills captured:** 1 (`.squad/skills/tool-version-pin/SKILL.md`).
- **CONTRIBUTING.md sections added:** 3 (Ralph develop-commit ban, Group
  letter SOP, CHANGELOG conflict strategy in #274; Coordinator Jiminy
  dispatch SOP in #280; Tool Version Pin Enforcement in #282).
- **Decisions inbox drained:** 2 (`doc-sprint-s-batch-fact-check.md`,
  `doc-pr-282-fact-check.md`) -- both already folded into
  `doc/history.md` via #281 + #283.
- **History.md fold PRs:** 2 (#281 Doc Sprint S batch; #283 Doc PR #282
  deep-dive). Scribe drain PR (this one) folds Jiminy + Mickey backfill.
- **Stale branches awaiting EOS sweep:** 6 remote `squad/*` (per Jiminy
  end-of-sprint audit) + 2 Doc-fold branches + this retro branch.

## Reflection

Sprint S was the first sprint where the squad's quality gates -- Doc's
batch fact-check, Jiminy's hygiene audits, the pre-commit hooks, the
Group-letter SOP, the CHANGELOG strategy -- all ran simultaneously across
ten PRs. The gates held. Two real bugs caught pre-merge, zero post-merge
fixes, and the one process miss (Jiminy not auto-dispatched after the
first batch) was caught by Earl and immediately SOP'd in-sprint via #280.

The version-pin work (#282) was the highest-leverage change of the
sprint. The original #255 squad-cli warning was a one-line symptom of a
structural pattern: `command -v X && exit 0` silently freezes stale
installs across an entire fleet. Codifying that anti-pattern into
`tool-version-pin/SKILL.md` and asserting actual installed versions in
the test suite means the next squad upgrade (or gh, or copilot-cli) will
not need to rediscover the lesson.

The friction points -- inter-PR function-rename collision, test-group
letter collision, Doc worktree dirty state -- are all coordination
problems, not technical ones. They are addressable in Sprint T's spawn
checklist without code changes.

**Board status:** develop @ `6e8995a`, working tree clean except this
retro branch. 10 PRs merged, 2 inbox files drained, 1 retro authored, 2
agent history.md files brought up to date. Ready for Ralph's EOS sweep
and Sprint T.

## Action Items Closed (post-0.9.0)

Following the 0.9.0 release, Sprint S retro action items were closed in a mini-batch:

| Action item | Resolution |
|---|---|
| Author `pwsh-lastexitcode` skill | PR #291 (closes #288) -- skill + CONTRIBUTING section + audit of `scripts/windows/` |
| Decide Doc subagent worktree pattern | PR #293 (closes #289) -- Option B: dedicated `..\dev-setup-doc` worktree on per-sprint `squad/doc-history-sprint-<N>` branch |
| Auto-enforce Jiminy post-batch dispatch | PR #293 (closes #290) -- Option A: 3-surface checklist (charter + loop.md + ceremonies.md) |

### Spillover into Sprint T

- **Issue #292** -- 5 unmitigated `$LASTEXITCODE` sites in `scripts/windows/setup.ps1` + `auth.ps1` (surfaced by #291 audit; assigned to Goofy, P2)
- All other action items closed.

### Verification
- [ ] Sprint T's first multi-agent batch will exercise the new Jiminy auto-dispatch gate
- [ ] Sprint T's first Doc fact-check will exercise the new dedicated-worktree pattern
- [ ] Issue #292 will be picked up in Sprint T triage
