# Squad Decisions

## Decision Records

(Entries dated on or before 2026-05-04 archived to .squad/decisions-archive.md
at the 2026-05-17 fold; live file exceeded 50KB hard gate.)
## [2026-05-14] Decision: Issue #197 Implementation Plan (PS 5.1 Compatibility Fix)

**Date:** 2026-05-14  
**Issue:** #197 -- PS 5.1 compatibility -- psmux install fails + aliases broken  
**Triage Owner:** Mickey (Lead)  
**Implementation Owner:** Goofy  
**Status:** [x] Plan complete, implementation in progress

### Root Cause Summary

1. **psmux Installation Fails:** `winget install --id psmux` uses invalid package ID (related to issue #179)
2. **Aliases Not Applied:** PowerShell 5.1 built-in AllScope aliases (gcm, gcb, gc, gl, gp, ni, rm, h, grb, grs, ep) cannot be overridden with `Set-Alias` alone -- require explicit pre-removal with `Remove-Item -Force Alias:\<name>` first
3. **Profile Write Suspected:** May be silent errors in `Write-PowerShellProfile` function during directory creation or content write

### Implementation Strategy

| Component | Priority | Action | Owner |
|-----------|----------|--------|-------|
| psmux fix | P0 | Skip-with-warning pattern + research alternative package managers | Goofy |
| Alias fix | P0 | Add verbose logging to `Write-PowerShellProfile`, verify pre-removal guards | Goofy |
| Test coverage | P1 | Groups N (PS 5.1 profile), O (alias override), P (psmux install) | Chip |
| CI enhancement | P1 | Add PS 5.1 profile validation to existing `validate-ps51` job | Chip |

### Affected Files

- `scripts/windows/tools/profile.ps1` -- Alias guards, profile write diagnostics
- `scripts/windows/tools/psmux.ps1` -- Skip logic with warning
- `tests/test_windows_setup.ps1` -- New test groups N, O, P

### PR Strategy

**Single PR:** `squad/197-ps51-compat-fix` -> `develop`
- All fixes tightly coupled (psmux unblocks script, alias + diagnostics solve user issue, tests validate both)
- Branch ready for implementation

### Success Criteria

1. `./setup.ps1` completes without fatal error on PS 5.1
2. psmux install either succeeds OR skips with clear warning
3. PS 5.1 profile file written to correct path
4. Profile contains all expected aliases
5. All conflicting aliases have `Remove-Item -Force` guards
6. New tests pass on PS 5.1 CI
7. Idempotency maintained

**Full detailed plan:** `.squad/decisions/inbox/mickey-ps51-fix-plan.md` (archived after merge)

---

## [2026-05-14] Finding: PowerShell 5.1 AllScope Alias Limitation

**Date:** 2026-05-14  
**Captured By:** Scribe (via Earl Tankard report)  
**Issue:** #197

### What

On PowerShell 5.1 (built-in Windows PowerShell), `./setup.ps1` fails in two ways:
1. psmux installation error (winget package ID broken)
2. Custom aliases not applied

### Root Cause: AllScope Alias Scope

PowerShell 5.1 has built-in aliases marked with the `AllScope` scope modifier:
- `gcm`, `gcb`, `gc`, `gl`, `gp`, `ni`, `rm`, `h`, and others

These cannot be overridden with `Set-Alias -Force` alone. The solution:

```powershell
Remove-Item -Force Alias:\gcm -ErrorAction SilentlyContinue
Set-Alias -Name gcm -Value <custom-function> -Force
```

Without the pre-removal, `Set-Alias` appears to succeed but the built-in remains bound.

### Why

PS 5.1 (and earlier) uses a different alias scoping mechanism than PS 6+. The AllScope modifier prevents override unless the built-in is explicitly removed first.

### Affected Files

- `scripts/windows/tools/profile.ps1` -- Already has removal pattern for known conflicts
- `scripts/windows/tools/psmux.ps1` -- Installation failure (issue #179)

### Fix Pattern

All custom aliases conflicting with built-ins must follow:
```powershell
Remove-Item -Force Alias:\<name> -ErrorAction SilentlyContinue
Set-Alias -Name <name> -Value <custom-function> -Scope Global -Force
```

**Status:** Implementation tracked in issue #197, test coverage in progress (groups N, O, P)
## [2026-05-14] Decision: PS 5.1 Compatibility Implementation -- Issue #197

**Author:** Goofy (Cross-Platform Dev)
**Date:** 2026-05-14
**Issue:** #197
**PR:** #198 (squad/197-ps51-compat-fix -> develop)

### Decisions Made

#### 1. psmux: Skip-With-Warning (Option D from Mickey's plan)

**Decision:** Replace broken `winget install --id psmux` with a `[WARN]` skip pattern.

**Rationale:**
- `psmux` is not a valid winget package ID -- this has been broken since #179 and affects every Windows setup, not just PS 5.1.
- Failing hard on an unknown winget ID aborts the entire setup script, blocking users from getting any other tools installed.
- Option D (skip-with-warning) unblocks setup immediately. Options A/B/C (find correct package ID, Scoop, direct install) are follow-up work.
- Idempotency is preserved: `Get-Command psmux -ErrorAction SilentlyContinue` guard remains at the top of `Install-Psmux`.

**Pattern used:**
```powershell
Write-Warn "psmux is not yet available via winget (see #179, #197)."
Write-Warn "Install manually from: https://github.com/nicowillis/psmux"
Write-Warn "Skipping psmux install -- continuing setup."
```

#### 2. profile.ps1: Verbose Diagnostics Over Code Changes

**Decision:** Add diagnostics to `Write-PowerShellProfile` rather than changing the write logic itself.

**Rationale:**
- The AllScope `Remove-Item -Force Alias:\<name>` guards were already in place for all 11 PS 5.1 conflicting aliases (PR #195). No alias logic needed to change.
- The root cause of "aliases not working" on Earl's PS 5.1 machine is unknown -- could be profile not written, profile directory creation failing silently, or execution policy blocking load.
- Diagnostics at each step (dir path, dir exists, file path, file exists + size, exec policy) will reveal the actual failure point when Earl re-runs setup.
- `try/catch` + `continue` per path is the correct pattern under `$ErrorActionPreference = 'Stop'` -- prevents one path failure from aborting the entire function.

#### 3. Single PR (not split)

**Decision:** Ship both psmux fix and profile diagnostics in one PR.

**Rationale:** Both fixes are needed to unblock PS 5.1 users. Splitting would require two review cycles for tightly coupled work. Chip's test groups N, O, P will follow in a separate PR.

### What Was NOT Changed

- AllScope `Remove-Item` guards: already complete from PR #195, no changes needed.
- No changes to test files in this PR -- Chip owns Groups N, O, P.
- No changes to CI workflow -- the `validate-ps51` job already runs; Chip will add the profile write step per Mickey's plan.

### References

- Issue #179: psmux winget ID broken (original report)
- Issue #197: PS 5.1 compat (this issue)
- PR #195: Profile writer implementation (AllScope guards added here)
- PR #198: This fix
- Mickey's plan: `.squad/decisions/inbox/mickey-ps51-fix-plan.md`

---

## [2026-05-14] Decision: PS 5.1 ASCII-Only Rule for .ps1 Files

**Date:** 2026-05-14
**Author:** Goofy (#2)
**Status:** Finalized
**Context:** PR #198, branch `squad/184-gitconfig-editor-fix`

### Problem

PowerShell 5.1 on Windows uses the system's default code page (typically CP1252) when reading script files. The UTF-8 encoding of em dash (U+2014) is `E2 80 94`. Byte `0x94` maps to RIGHT DOUBLE QUOTATION MARK in CP1252, which PS 5.1 interprets as a string terminator. This causes `ParserError: TerminatorExpectedAtEndOfString` at parse time - the script won't even load.

### Decision

**All `.ps1` files in this repository MUST contain only ASCII characters (U+0000 - U+007F).**

This applies to:
- String literals
- Comments
- Variable names and identifiers
- Any other source content

#### Specific replacements:
- Em dash (`--`) -> ` - ` (space-hyphen-space)
- Smart quotes -> straight quotes
- Any other non-ASCII -> closest ASCII equivalent or removal

### Rationale

- PS 5.1 is still the default PowerShell on Windows 10 and Windows Server 2019
- We explicitly support PS 5.1 (see CI job "Validate PowerShell 5.1 Compatibility")
- BOM markers are fragile and not all editors/tools preserve them
- ASCII-only is the simplest, most portable rule with zero edge cases

### Enforcement

- CI already validates PS 5.1 compatibility via syntax parsing
- Developers should run byte-level scans when modifying .ps1 files
- Code review should flag any non-ASCII characters in .ps1 files

---

## [2026-05-14] Decision: ASCII-only rule for PS test files

**Proposed by:** Chip (Tester)
**Date:** 2026-05-14
**Status:** Finalized

### Decision

All `.ps1` test files must use only ASCII characters (bytes 0x00-0x7F) to be safe under PS 5.1 CP1252 encoding.

### Context

PowerShell 5.1 on Windows reads `.ps1` files using the system's default encoding (typically CP1252). UTF-8 multi-byte sequences for characters like em dashes (U+2014), arrows (U+2192), and emojis produce bytes that CP1252 interprets as control characters or punctuation (e.g., byte 0x94 = right double quote), causing `ParseException` crashes.

The validate-ps51 CI job runs `tests/test_windows_setup.ps1` directly via `powershell -File`, so any non-ASCII content in the test file will cause CI failures.

### Rules

- No emojis in string literals (use `[PASS]`, `[FAIL]`, `[SKIP]` tags instead)
- No em dashes in comments (use ` - ` instead)
- No arrows in comments (use `->` instead)
- No smart quotes, accented characters, or any byte > 0x7F
- Validate with: `Get-Content file.ps1 -Encoding UTF8 | Where-Object { $_ -cmatch '[^\x00-\x7F]' }`

---

## [2026-05-14] Decision: PS 5.1 Test Patterns for Issue #197

**Author:** Chip (Tester)
**Date:** 2026-05-14
**Issue:** #197 -- PS 5.1 compatibility: psmux install fails + aliases broken
**Branch:** `squad/197-ps51-compat-fix`

### Decisions Made

#### 1. CP1252 string-literal encoding rule
**Decision:** Never use Unicode dashes or other non-ASCII characters in test string literals.

**Why:** PS 5.1 reads UTF-8 files without BOM using the system default encoding (Windows-1252). The em dash `--` (U+2014) encodes as UTF-8 bytes `E2 80 94`. Byte `0x94` is the RIGHT DOUBLE QUOTATION MARK in CP1252, which the PS 5.1 parser treats as a string terminator. This causes a cascade of parse errors, making every subsequent test fail silently.

**Rule:** Use plain ASCII hyphen `-` wherever a dash is needed in test string literals, `Write-Skip` messages, and test names.

#### 2. Invoke-Expression for cross-group tool loading
**Decision:** Load psmux.ps1 (and any other tool script) via `Invoke-Expression` at Group scope, not inside `Test-Scenario` scriptblocks.

**Why:** `Test-Scenario` uses `& $Test` to invoke the scriptblock, which runs in a child scope. Functions dot-sourced or defined inside `& $scriptblock` are only available within that child scope and are gone after the test block completes. `Invoke-Expression` at the outer scope makes functions available for all subsequent tests.

**Pattern:**
```powershell
$psmuxToolContent = Get-Content $psmuxToolPath -Raw
Invoke-Expression $psmuxToolContent
# Now Install-Psmux is in scope for all subsequent tests
```

#### 3. Conditional skip pattern for binary-dependent tests
**Decision:** Tests that require a binary to be absent (like P-2 for psmux) use an if/else outside Test-Scenario: `Write-Skip` if binary is present, `Test-Scenario` if absent.

**Why:** This is the cleanest way to handle machine-dependent paths. In CI (no psmux), P-2 runs and validates the `[WARN]` output. On a dev machine with psmux installed, it skips gracefully without false failures.

#### 4. CI profile write step is separate from unit test suite
**Decision:** Added a dedicated `Test PS 5.1 profile write` step to `validate-ps51` BEFORE the test runner step.

**Why:** The unit tests (Groups N-1, N-2) also verify profile write, but having a CI-level step provides a clearer failure message at the job level. If `Write-PowerShellProfile` fails silently, the CI step catches it with `Write-Error` and `exit 1`, which surfaces in the GitHub Actions summary without having to dig into test output.

### Open Questions

None -- all decisions made with full confidence.

---

## [2026-05-14] Decision: PR #198 Review -- PS 5.1 Compat Fix

**PR:** #198
**Issue:** #197
**Reviewer:** Mickey (Lead)
**Date:** 2026-05-14
**Verdict:** [x] APPROVED

### What Was Reviewed

- `scripts/windows/tools/psmux.ps1` -- skip-with-warning for broken winget ID (#179)
- `scripts/windows/tools/profile.ps1` -- verbose diagnostics for PS 5.1 debugging
- Em dash (U+2014) removal from both files -- fixes CP1252 parsing crash on PS 5.1

### Assessment

1. **Correctness:** psmux skip is the right call -- no valid winget ID exists. Profile diagnostics cover all failure points (dir creation, file write, post-write validation, execution policy).
2. **Quality:** Code is clean, try/catch blocks are well-scoped with `continue` for graceful degradation. Idempotency preserved.
3. **No regressions:** All changes are Windows-only PowerShell. No impact on Linux/macOS paths.
4. **Em dash fix:** Both files verified clean of non-ASCII characters via automated scan.
5. **CI:** 5/5 checks green.

### Approval Method

GitHub API self-approval blocked (single-user repo). Approval posted as PR comment per `--admin` merge pattern documented in CONTRIBUTING.md and decisions.md.

---

## # Decision: PS 5.1 ASCII Safety Skill

**Agents:** Chip (Tester), Coordinator (Memory Manager)  
**Date:** 2026-05-16  
**Branch:** squad/197-ps51-compat-fix  

### Context

User directive: **Always learn from PS 5.1 encoding issues (em dashes, non-ASCII chars) as the team builds out. Capture as a reusable skill so all agents know the rule before touching any .ps1 file.**

Root cause: UTF-8 em dash (U+2014) ends with byte 0x94, which CP1252 treats as a right double-quote, terminating string literals in PS 5.1. Same class of bug can recur with any non-ASCII char. Confirmed by two fixes in issue #197 (PR #198, PR #200).

### Decision

**Formalize PS 5.1 ASCII safety as a reusable team skill.** All agents MUST read `.squad/skills/ps51-ascii-safety/SKILL.md` before writing or reviewing any .ps1 file.

**Why:** 
- Reduces recurring debugging cycles for encoding issues
- Captures permanent institutional knowledge
- Provides detection scripts and fix patterns reusable across all scripts
- Aligns with user's directive to learn and formalize team practices

### Outcome

[x] Skill authored at `.squad/skills/ps51-ascii-safety/SKILL.md`  
[x] Committed and pushed to squad/197-ps51-compat-fix  
[x] Will land in develop when PR #200 merges  

---

## # Decision: PR #200 -- Merge Gate Review

**Date:** 2026-05-16
**Author:** Mickey (Lead)
**PR:** [#200](https://github.com/primetimetank21/dev-setup/pull/200)
**Branch:** `squad/197-ps51-compat-fix`
**Verdict:** [x] APPROVED

### Summary

PR #200 is the companion test coverage + ASCII safety skill for Issue #197 (PS 5.1 compatibility). PR #198 (already merged) fixed the runtime scripts; this PR hardens the test suite and documents the encoding rule as a reusable skill.

### What Was Reviewed

| File | Assessment |
|------|-----------|
| `tests/test_windows_setup.ps1` (Groups N, O, P) | Clean test design. N validates dual-profile write + all 11 AllScope alias guards. O proves Remove-Item + Set-Alias pattern works at runtime. P covers psmux syntax, conditional skip, and idempotency. |
| `tests/test_windows_setup.ps1` (ASCII cleanup) | 14 non-ASCII chars removed: 8 emoji markers, 4 em dashes, 2 arrows. File is now fully ASCII-safe. |
| `.github/workflows/validate.yml` | New "Test PS 5.1 profile write" step correctly uses `shell: powershell` and validates profile file existence. |
| `.squad/skills/ps51-ascii-safety/SKILL.md` | Production-quality skill doc. Root cause (CP1252 byte interpretation), detection scripts, fix patterns, scope boundaries, and incident history all documented. |
| `.squad/agents/chip/history.md` | Condensed from ~520 lines to ~130 lines. Sprint history preserved; older per-PR entries collapsed into summaries. Acceptable. |

### CI Status

All 5 checks green:
- Lint PowerShell Scripts [x]
- Lint Shell Scripts [x]
- Validate Linux Setup [x]
- Validate PowerShell 5.1 Compatibility [x] (1m45s -- the new step ran successfully)
- Validate PowerShell Functionality [x]

### Merge Instructions

- Merge strategy: **regular merge commit** (not squash)
- Target branch: `develop`
- Command: `gh pr merge 200 --repo primetimetank21/dev-setup --merge`

### Notes

- Could not use `--approve` via GitHub CLI (same-user restriction). Left comment-review with approval verdict instead.
- No code concerns. No follow-up actions required.
---

## # Decision: Coordinator Spawn Prompt Hygiene Is MANDATORY

**Date:** 2026-05-16T01:29:00Z
**By:** Earl Tankard (via Copilot)
**Context:** PR #215 (Goofy, #190 tool versions) shipped without a history.md entry. Root cause: coordinator wrote a custom inline prompt for Goofy without the hygiene tail.

## The Problem

Same-batch agent Chip on PR #213, #214 DID update his history because his prompt explicitly demanded it. Inconsistency pattern: custom inline prompts skip hygiene boilerplate.

## Five Mandatory Items

Every spawn prompt the coordinator writes MUST include:

1. **History append:** APPEND to .squad/agents/{name}/history.md a new entry describing this work (what + key findings).
2. **Decisions inbox:** If you made a team-relevant decision, write to .squad/decisions/inbox/{name}-{brief-slug}.md
3. **Skill extraction:** If you found a reusable pattern, write/update .squad/skills/{skill-name}/SKILL.md
4. **PS 5.1 ASCII rule** (when any PowerShell test file is touched): No em-dashes, smart quotes, or non-ASCII chars in .ps1 string literals. Use -Encoding ASCII for Set-Content/Out-File.
5. **Conventional Commits + Co-authored-by trailer** on every commit.

## Enforcement

Before sending any 	ask tool spawn, coordinator MUST scan its prompt for these five items and add any missing ones. If a custom prompt is used (not the standard template in .github/agents/squad.agent.md), the hygiene block must still be pasted verbatim at the bottom.

## Failure Pattern to Break

"Custom prompts skip hygiene." Solution: hygiene is non-negotiable boilerplate -- paste it every time, even for one-off tasks.

---

## # Decision: Retro Agenda -- Hygiene & Reliability

**Date:** 2026-05-16T01:32:00Z
**By:** Earl Tankard (via Copilot)

## What Earl Said

"why is this squad so bad at managing these things? :/ definitely gonna need this changed and addressed in retro"

## Recurring Pattern (This Sprint & Sprints 2-4)

| Miss | Sprint | Root cause |
|------|--------|------------|
| Goofy skipped history.md on PR #215 | this session | Coordinator wrote custom inline prompt, dropped hygiene tail |
| SKILL.md uncommitted in #208 | this session | Coordinator forgot to stage new file before agent's last commit |
| Em-dash CP1252 trap (PS 5.1) | repeated | Agents draft with smart chars, no pre-push lint gate |
| Branch ancestry bleed (3+ times) | sprints 2-4 | Agents forked from each other's branches, not develop |
| Broad Merge/Revert bypass on #213 | this session | Agent took easy path; coordinator didn't spec the spec |
| commit-msg hook bypass needed retroactive enhancement | this session | Issue was filed reactively, not proactively |

## Meta-Pattern

1. Coordinator writes custom prompts ad-hoc instead of using the canonical template.
2. No pre-spawn checklist enforces hygiene tail (history append, decisions inbox, skill extract, ASCII, conventional commits, Co-authored-by trailer).
3. No post-work verification gate -- coordinator doesn't check if history.md was modified before declaring done.
4. Agents are not given a hard checklist they MUST tick before committing.

## Proposed Retro Outcomes (To Discuss With Team)

1. **Coordinator-side:** Build a pre-spawn-checklist skill. Every 	ask call must paste the hygiene block verbatim -- no inline prompts skip it.
2. **Agent-side:** Every agent ends work with a self-check command: git diff --stat showing history.md was modified, then auto-fail if not.
3. **CI-side:** Add a workflow that fails any PR from squad/* branch where the corresponding gents/*/history.md was NOT modified. Hard gate.
4. **Spec-side:** Issue filing template should require linking to the spec (e.g., #213 should have pointed at Conventional Commits v1.0.0 upfront, not after Earl asked).
5. **Worktree-side:** New session-start step: list active worktrees + branches, prompt for cleanup if stale (>1 sprint old).
6. **PR template:** Add a checkbox: [ ] history.md updated -- agent must check before opening PR.

## Owner & Priority

- Lead (Mickey) to run retro
- Chip to build the CI gate (#5)
- Goofy to add PR template (#6)
- **Priority: HIGH.** Same pattern keeps biting. If we don't break it, Earl loses trust in the squad.

---

## # Decision: Ralph Owns End-of-Session Cleanup

**Date:** 2026-05-16T02:00:00Z
**By:** Earl Tankard (via Copilot)

## What

At the END of every session (right before user signs off, or coordinator detects "wind down" intent), Ralph MUST do one final cleanup pass:

1. **Worktrees** -- git worktree list then git worktree remove --force any worktree whose branch has been merged (or whose PR has been closed/merged). Always keep the main checkout.
2. **Local squad branches** -- git branch | grep squad/ then git branch -D any branch whose remote has been deleted (i.e., merged + --delete-branch) or whose PR has been merged/closed.
3. **Remote orphan branches** -- git ls-remote --heads origin 'squad/*' cross-reference with local branches. Delete any remote squad branch that no longer has an open PR via git push origin --delete <branch>.
4. **Prune** -- git fetch origin --prune and git worktree prune to clean up stale refs.
5. **Final report** -- list of removed worktrees, deleted local branches, deleted remote branches, and final state (main checkout only, 2 local branches: develop + main, no orphan remote squad branches).

## Why

Worktrees and squad branches accumulate across sessions. Earl flagged: "we should have ralph clean up the branches at the end of each session for simplicity. do one final pass before ending things". Manual coordinator cleanup is brittle -- Ralph is the work monitor, owns the queue, and should naturally close the loop.

## Trigger Signals for Ralph End-of-Session Cleanup

- User says "stop", "end", "wrap up", "done for today", "sign off", "that's all"
- User asks to merge develop -> main (sprint wrap is a session end signal)
- Coordinator detects context window pressure approaching limit
- Session has been idle for >10 minutes after last task completion

## Enforcement

Coordinator includes this cleanup in every Ralph "idle" or session-end flow. Ralph reports the cleanup result as the final response of the session.

## Related Directives

- Branch ancestry: always fork from develop (not from another squad branch)
- Worktrees mandatory for parallel agents (cleanup just keeps this manageable)
- ALL merges use regular merge commits (NEVER squash)

---

## # Decision: Branch & Worktree Cleanup Hygiene (Per-Batch & Per-Session)

**Date:** 2026-05-16T04:20:24Z
**By:** Earl Tankard (via Copilot Coordinator)

## What

After every batch's PRs land (Mickey reviews + merges), the coordinator MUST immediately clean stale branches and worktrees before moving to the next batch. Concretely, after each merge round run:

1. git fetch origin --prune (drop deleted remote refs)
2. git branch -D <merged-local-branch> for every local copy whose upstream is gone
3. git worktree remove ../<repo>-issue-N for each per-issue worktree whose PR has merged

Additionally, at session end, audit local + remote and delete any leftover squad/* branches and worktrees so the next session starts clean. Never let stale squad/* branches accumulate.

## Why

User request -- captured for team memory. Stale branches and worktrees increase the risk of branch ancestry bleed (5 occurrences this repo), confuse git worktree list, and waste disk. Cleaning per-batch and per-session keeps the queue tight.

## Scope

Coordinator orchestration rule. Applies to every batch merge and every session wrap, in this repo and any other Squad-managed repo Earl runs.

---

## # Decision: Windows Auth Uses --web Flag and Is Non-Fatal

**Date:** 2026-05-16
**Author:** Donald (Shell Dev)
**Issue:** #191

## Context

Windows setup needed a gh auth step matching Linux parity. Two design choices were made:

## Decisions

1. **Auth failure is non-fatal.** Invoke-GhAuth catches all errors and emits warnings. It never throws or exits non-zero. This matches the Linux auth.sh philosophy -- auth is optional quality-of-life, not a hard requirement for setup to succeed.

2. **Windows uses --web flag.** The gh auth login call uses --hostname github.com --git-protocol https --web to open the browser-based device flow. This avoids prompting the user for protocol/hostname interactively, reducing friction.

3. **Non-interactive detection.** Uses $env:CI, $env:CODESPACES, and [Environment]::UserInteractive to detect CI/headless runs. In those environments, auth is skipped with a warning.

---

## # Decision: .tool-versions as Single Source of Truth for Pinned Versions

**Date:** 2026-05-18
**Author:** Goofy
**Issue:** #190
**PR:** #215

## Context

Scripts were fetching "latest" from GitHub API or installer URLs at runtime. This made builds non-reproducible and could break if upstream releases had issues.

## Decision

Use .tool-versions at repo root (asdf/mise format) as the single source of truth for tool version pins. Setup scripts parse it with lightweight helpers -- no asdf or mise runtime needed.

## Format

`
toolname version
`

One tool per line. Blank lines and # comments allowed.

## Implications

- To bump a tool version, edit one file and re-run setup
- All platforms (Linux, macOS, Windows) read the same file
- No new runtime dependencies introduced

## 2026-05-16 entries

### 2026-05-16T07:50:00Z: Jiminy hired -- Squad Hygiene Auditor
**By:** Earl Tankard (via Copilot coordinator)
**What:** Added new squad member Jiminy (Disney Classic universe) in the role of "Squad Hygiene Auditor" - a reviewer-gate role for squad OPERATIONS (not code). Charter pins model to claude-opus-4.6 (premium). Auto-runs before coordinator returns control to user, after multi-agent batches (3+ spawns), and at session-end. Manual trigger: "Jiminy, check" / "Jiminy, audit".
**Scope of audit:** (1) Squad state hygiene (untracked .squad/ files, rogue paths, undrained decisions inbox, uncommitted history.md edits); (2) Git hygiene (working tree clean, stale squad/* branches, branch ancestry from develop, local/origin sync); (3) Process hygiene (PR labels, issue priorities, no squash merges, Conventional Commits format); (4) Memory hygiene (history append, decisions inbox usage, Scribe fired after each batch).
**Auto-fix scope:** Stage+commit history edits (via Scribe), move/delete rogue files, drain decisions inbox. Will NOT: delete branches, force-push, change labels, rewrite commit messages.
**Why:** Recurring squad hygiene failures (rogue verification reports 2026-05-16, uncommitted histories on multiple sessions, branch ancestry bleed in Sprint 7, squash merges in Sprints 2-3) forced Earl to be the verifier. Tiring. Jiminy exists so the team self-audits before bothering him.
**Files added:** .squad/agents/jiminy/charter.md, .squad/agents/jiminy/history.md
**Files updated:** .squad/casting/registry.json (added hygiene-auditor entry), .squad/casting/history.json (addendum), .squad/team.md (roster row), .squad/routing.md (routing entry + auto-run rule #8)

### 2026-05-16T07:30:00Z: Verifier batch spawn hygiene
**By:** Earl Tankard (via Copilot coordinator -> Donald cleanup)
**What:** Verifier agents (any agent doing read-only verification of audit findings) MUST write their evidence to ONE of these three locations only:
1. .squad/agents/{name}/history.md -- append learnings under "## Learnings"
2. .squad/decisions/inbox/{name}-{slug}.md -- for team-relevant decisions
3. .squad/orchestration-log/{ISO8601-UTC}-{batch-name}.md -- for batch evidence with citations (preferred for citation-heavy verification reports)
Verifiers MUST NOT create files at .squad/agents/{name}/VERIFICATION_REPORT.md, .squad/verification-report.md, or any other random path. Spawn prompts for verifier-style batches MUST specify the target location explicitly. Coordinator MUST spawn Scribe IMMEDIATELY after any verifier batch -- never delay to a downstream filing step.
**Why:** Incident 2026-05-16. 3 rogue verification reports landed on develop uncommitted because (a) verifiers picked random paths and (b) coordinator delayed Scribe.

---

## # Decision Record: Hygiene Reliability Retro Complete

**Date:** 2026-05-16
**Source:** 2026-05-16 Hygiene Reliability Retro (facilitator: Coordinator)
**Status:** ALL 4 action items shipped to develop. Both gates LIVE.

### Action items shipped

1. Pre-spawn-checklist skill (.squad/skills/pre-spawn-checklist/SKILL.md) -- commit 0431dc8
2. Squad history-check CI gate (.github/workflows/squad-history-check.yml) -- PR #241 / merge c02d679
3. PR template with hygiene checklist (.github/pull_request_template.md) -- PR #242 / merge 0fc8dcf
4. Retro facilitation (this record)

### Standing rules now in force

- Every spawn prompt must include the hygiene tail (per pre-spawn-checklist skill)
- squad:* PRs must update matching agent history.md or CI fails (hard gate, no override)
- All squad PRs use the new template with hygiene checklist
- Branches always forked from develop (never from another squad/* branch)
- Verifier evidence goes to .squad/orchestration-log/*.md ONLY
- Ralph owns end-of-session branch + worktree cleanup
- Jiminy auto-audits before Coordinator returns to user, post-batch (3+ spawns), session-end

### Belt-and-suspenders coverage

- Pre-commit: TBD (issue #240 P1 for Pluto to implement)
- CI gate: LIVE (Chip's squad-history-check)
- PR template: LIVE (visible checklist)
- Pre-spawn checklist: LIVE (Coordinator self-audit)
- Post-spawn audit: LIVE (Jiminy reviewer gate)
- End-of-session: LIVE (Ralph cleanup)

This is the most comprehensive squad hygiene system any sprint has produced.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>

---

## # Decision: Squad CLI 0.9.4 Upgrade -- Ship Plan

**Date:** 2026-05-16T17:23:15-04:00
**Author:** Mickey (Lead)
**Status:** Executed (PR #262 merged at 2026-05-16T17:32)
**Context:** Earl ran `squad upgrade` to 0.9.4. Audit complete.

## Decision

### SHIP (stage + commit in one PR)

**Commit 1 -- `chore(squad): upgrade governance to 0.9.4`**
- `.github/agents/squad.agent.md` -- main payload (version bump, dispatch mechanism, model updates, CURRENT_DATETIME requirement, name param in spawns)
- `.squad/templates/*` -- all 7 modified templates

**Commit 2 -- `ci(squad): upgrade workflows + add label enforcement`**
- `.github/workflows/squad-heartbeat.yml` -- removes cron schedule (good: was noisy)
- `.github/workflows/squad-triage.yml` -- adds slugify() for label names (bugfix)
- `.github/workflows/sync-squad-labels.yml` -- same slugify() fix
- `.github/workflows/squad-label-enforce.yml` -- NEW, useful (mutual exclusivity for go:/release:/type:/priority: labels)

**Commit 3 -- `feat(squad): add error-recovery skill`**
- `.copilot/skills/error-recovery/SKILL.md` -- generic but useful, no conflicts

### DELETE (before committing)

All 18 rogue files at `.squad/` root:
```
casting-history.json, casting-policy.json, casting-registry.json,
charter.md, history.md, roster.md, scribe-charter.md,
fact-checker-charter.md, constraint-tracking.md, copilot-instructions.md,
issue-lifecycle.md, mcp-config.md, multi-agent-format.md,
orchestration-log.md, plugin-marketplace.md, raw-agent-output.md,
run-output.md, skill.md
```

Diagnosis: 2 of 3 sampled were IDENTICAL to templates. The third (`casting-policy.json`) was an OLDER version missing `Disney Classic` universe -- the canonical `.squad/casting/policy.json` is correct and richer. All safe to delete.

### DO NOT SHIP -- Separate discussion needed

1. **`.copilot/skills/git-workflow/SKILL.md`** -- OVERWRITTEN with generic 3-branch model. We use 2-branch (develop/main). The new version removes:
   - Mickey approval requirement
   - Branch protection section
   - Our merge gates
   - References to `develop` (replaced with `dev`)

   **Action:** Revert to HEAD~1 version. File an issue to reconcile if we ever adopt 3-branch.

2. **6 new workflows (DO NOT SHIP):**
   - `squad-ci.yml` -- empty placeholder ("No build commands configured"). We already have `validate.yml`.
   - `squad-docs.yml` -- targets `preview` branch (doesn't exist). Intended for squad CLI, not consumers.
   - `squad-insider-release.yml` -- targets `insider` branch (doesn't exist).
   - `squad-preview.yml` -- targets `preview` branch (doesn't exist).
   - `squad-promote.yml` -- assumes dev->preview->main pipeline with package.json publish. Not our model.
   - `squad-release.yml` -- tag+publish on main push. We don't publish npm packages.

   **Action:** Delete all 6. They're for the squad CLI's own release pipeline.

3. **`.squad/templates/loop.md`** and **`.squad/templates/squad.agent.md.template`** -- NEW templates. Ship with templates commit (harmless, useful for reference).

## Risks

- The `squad.agent.md` now expects `CURRENT_DATETIME` in spawn prompts -- existing agent charters that don't pass it won't break, but won't get time context. Low risk.
- Model references bumped to `claude-sonnet-4.6` / `gpt-5.3-codex` -- if those aren't available yet, spawns fall through to platform default. No breakage.
- `squad-heartbeat.yml` loses cron trigger -- Ralph now only fires on issue events. If we want periodic checks, re-add cron later.

## Test Plan

After merge:
1. Start a new session -- verify `Squad v0.9.4` appears in greeting
2. Run pre-commit hook -- should pass (no rogue files)
3. CI should be green on the PR
4. Verify `squad-triage.yml` labels work (label an issue with `squad`)
5. Confirm git-workflow SKILL.md is restored to our 2-branch version

---

## # Decision: Hire Doc as Fact Checker

**Date:** 2026-05-16
**Author:** Mickey (Lead)
**Status:** Executed (PR #263 merged at 2026-05-16T18:10)
**Context:** Sprint 8-hotfix (formerly Sprint Q) retro identified a verifier/validator gap.
Squad 0.9.4 ships a fact-checker template. Earl chose to hire before Sprint 9 (formerly Sprint R).

## Decision
- Persistent name: Doc (Seven Dwarfs, Disney Classic universe)
- Role: Fact Checker / Verification Agent
- Auto-trigger keywords: review, verify, fact-check, audit, double-check
- Reports advisory by default; can be escalated to a merge gate
- Will NOT replace Chip (test verification) or Jiminy (process hygiene)
- Voice: methodical, glasses-on, "Let's see now..." energy

## Rationale
- Closes the verifier/validator gap from Sprint 8-hotfix retro
- Trial run before deciding whether to make it a hard gate

## Files
- .squad/agents/doc/charter.md (new)
- .squad/agents/doc/history.md (new)
- .squad/casting/registry.json (new entry)
- .squad/team.md (new row)
- .squad/routing.md (new routing + rule)
- CHANGELOG.md (Unreleased entry)

---

## # Decision Record: Verification Report -- PR #263 Hire Doc (Fact Checker)

**Date:** 2026-05-16
**Reviewer:** Doc (Fact Checker)
**PR:** #263 -- feat(squad): hire Doc (Fact Checker)
**Status:** Executed -- finding addressed in commit 2fa65e9 before PR #263 merged
**Recommendation:** PROCEED -- one minor trigger-keyword inconsistency; not a blocker.

## Claims Verified

- [PASS] Doc charter exists at `.squad/agents/doc/charter.md` on branch -- confirmed via git show
- [PASS] Doc history.md exists at `.squad/agents/doc/history.md` with correct initial entry format -- confirmed via git show
- [PASS] Doc history.md date matches CURRENT_DATETIME (2026-05-16) -- confirmed
- [PASS] Advisory by default -- charter Boundaries section and routing.md Rule 9 both state Doc is non-blocking unless escalated; consistent
- [PASS] registry.json placement -- fact-checker inserted after hygiene-auditor (Jiminy), before scribe/ralph; JSON is valid (no trailing commas) -- confirmed via git show
- [PASS] team.md row -- Doc inserted after Jiminy, before Scribe; uses checkmark emoji + "Active" matching all other rows exactly -- confirmed via diff
- [PASS] Routing table row -- "Verification, fact-checking, claim audits | Doc | Verify research, double-check assertions, run counter-hypotheses, audit external references" after Jiminy row; consistent with charter responsibilities -- confirmed via git show
- [PASS] Issue Routing `squad:doc` label -- label EXISTS on the GitHub repo (confirmed via `gh label list`); no creation needed
- [PASS] Multi-Agent Scenarios rows -- "Verify the research / fact-check this" -> Doc; "Before we ship..." -> Doc + Mickey; both make sense given routing -- confirmed via git show
- [PASS] CHANGELOG entry -- in [Unreleased] > ### Added; ASCII-clean double-dash; mentions charter path; accurate summary -- confirmed via diff
- [PASS] Mickey's history.md new entry -- dated 2026-05-16; accurately describes hire, trigger keywords, and the hiring pattern -- confirmed via diff
- [PASS] Doc does NOT replace Chip or Jiminy -- charter Boundaries section explicitly names both and explains the three distinct lanes; Chip and Jiminy charters need no update -- confirmed via git show
- [PASS] squad-hire-agent SKILL.md -- all four routing.md update locations (A-D) listed; all confirmed performed in this PR; checklist matches what Mickey demonstrably did -- confirmed via diff vs skill
- [WARN] `double-check` trigger classification -- charter lists it as an auto-trigger tag alongside review/verify/fact-check/audit; routing.md Rule 9 places it in the "user says" verbal-trigger bucket, not the tag bucket; PR description and CHANGELOG list only four tags (no double-check); minor inconsistency across three artifacts
- [PASS] ASCII compliance (new content) -- the only non-ASCII byte in new `+` lines is the checkmark emoji in team.md, which matches the pre-existing style of every other team.md row; Doc charter itself is fully ASCII-clean -- confirmed via Select-String scan of diff

## Counter-Hypotheses Explored

- "squad:doc label might not exist yet and would need creating" -> REFUTED. Label already exists on the repo (`gh label list` returns `squad:doc  Assigned to Doc (Fact Checker)  #9B8FCC`). Someone created it ahead of merge.
- "registry.json might have invalid JSON after insertion" -> REFUTED. Structure reviewed; no trailing comma on the fact-checker block; scribe/ralph entries follow cleanly.
- "The checkmark emoji in team.md is a new ASCII violation" -> REFUTED. Every pre-existing row in team.md uses the same checkmark emoji; this is the established style, not a new violation.
- "Doc might be missing required charter sections compared to the Jiminy hire template" -> REFUTED. Doc charter contains all sections the skill mandates: Identity, Voice, What I Do, Methodology, Triggers, How I Work, Boundaries, Model, Git Rules, Collaboration, Charter version. Jiminy charter structure used as comparison baseline; Doc matches or exceeds it.
- "Mickey's history entry might use a stale date" -> REFUTED. Entry is dated 2026-05-16, matching CURRENT_DATETIME.
- "The SKILL.md ASCII Safety note 'Use -- not --' is meaningless (both show as double-dash)" -> PARTIALLY CONFIRMED as a presentational issue. In rendered markdown the note loses its contrast because Mickey could not write an em-dash in an ASCII-safe file. The meaning is clear from context (do not use U+2014). Not a functional bug; the note is correct.

## Issues Found

1. **WARN -- `double-check` trigger: inconsistent classification across three artifacts.**
   - **Where:** `.squad/agents/doc/charter.md` (When I'm Triggered section) vs. `.squad/routing.md` Rule 9.
   - **What's wrong:** Charter says `double-check` is an auto-trigger tag (same tier as `review`, `verify`, `fact-check`, `audit`). Routing.md Rule 9 says it is a verbal/manual trigger ("when a user says 'double-check'"). The PR description and CHANGELOG mention only four tags; `double-check` is absent. The template (`fact-checker-charter.md`) also lists only four tags; `double-check` was added by Mickey.
   - **Impact:** Low. Agents routing on keyword tags may or may not pick up `double-check` depending on which file they read. Advisory role means no merge is blocked, but the routing intent is ambiguous.
   - **Suggested fix (one of two options):** Either add `double-check` to routing.md Rule 9's tagged list, OR remove it from the charter's auto-trigger tag list and keep it only as a verbal/manual trigger. Either is fine; consistency is the goal.
   - **Resolution:** Fixed in commit 2fa65e9 before PR #263 merged.

## Recommendation

Proceed with merge. The `double-check` inconsistency is real but advisory -- it does not break any functionality, and Doc's role is non-blocking by design. A follow-up commit to align charter and routing.md on `double-check` placement (tag vs. verbal) would clean it up, but it is not a merge gate.

Good, good -- the hire is internally consistent. The `squad:doc` label is already live, the JSON is valid, the team.md row matches house style exactly, the routing covers all four required locations, and the history entry is properly dated. Mickey did thorough work here.

## # Decision: Issue #300 closed -- gh pr merge --delete-branch ghost-remote-branch quirk no longer reproducible

**Issue:** #300
**PR:** (none -- closed directly, no code change required)
**Agent:** Jiminy (Hygiene Auditor)
**Date:** 2026-05-17
**Status:** Closed -- no-longer-reproducible

## Context

Issue #300 tracked the gh pr merge --delete-branch ghost-remote-branch quirk
(historical fail rate 5-of-6 at filing). Re-audited during Sprint 12 Wave 1 post-batch sweep.

## Evidence

- git fetch origin --prune then git branch -r shows zero stale squad/* remotes
  (only origin/develop + origin/main).
- Cross-referenced 30 most recent merged PRs (25 with squad/* heads) against live remote refs:
  zero ghost branches.
- Post-#300-filing squad merges (#299, #301, #302, #303, #311, #312) all deleted cleanly. 6-for-6.
- PRs #311 and #312 used the same --admin --squash --delete-branch flag combination that
  previously triggered the bug at a 5-of-6 historical rate. Both deleted cleanly.
- Likely upstream gh CLI fix, or trigger condition has shifted.

## Decision

Close issue #300 as resolved (no-longer-reproducible). No code change required.

## Fallback

If the quirk recurs, reopen #300 with new evidence. The git push origin --delete <branch>
cleanup pattern from PR #295 remains documented in Ralph's EOS workflow.

## Worktree disposition

Worktree dev-setup-300 + branch squad/300-gh-quirk-close were switched back to develop
and handed to coordinator for removal.

## Fold note (Scribe)

The companion inbox file jiminy-2026-05-17-post-batch-audit-fold.md was a pre-existing
history-fold-request (audit notes destined for .squad/agents/jiminy/history.md Learnings).
Jiminy self-appended that audit content directly to .squad/agents/jiminy/history.md during
Sprint 12 Wave 1 (lines 82-83), so the fold-request was satisfied at source. Scribe deleted
the obsolete inbox file as part of this fold; full audit text lives in jiminy/history.md, not here.

## 2026-05-17 entries (Sprint 12 Wave 2 fold)

### 2026-05-17T02:01:33-04:00: ARCHITECTURE.md Windows orchestrator Dependency Order documented (#310 / Sprint 12 Wave 2)
**By:** Mickey (Lead)
**Branch:** squad/310-arch-windows-dep-order
**What:** Added `### Windows orchestrator chain` subsection under existing `## Dependency Order` H2 in ARCHITECTURE.md. Documents the 12-step invocation chain inside `scripts/windows/setup.ps1` `Main()`: `git -> uv -> nvm -> gh -> auth -> vim -> psmux -> copilot -> squad-cli -> dotfiles -> profile -> hooks`. Includes a function/module/Linux-mirror table, lib load order (`lib/logging.ps1` -> `lib/path.ps1`), cross-platform invariants preserved (auth-after-gh, copilot-after-auth, squad-cli-after-nvm), and Windows-only additions (git first, vim/psmux winget, dotfiles+profile finalizers, inline `Install-GitHook`).
**Why:**
1. Dot-source order in `setup.ps1` does NOT match invocation order, which has caused contributor confusion in past PRs (e.g., `auth.ps1` is dot-sourced LAST but invoked 5th). The new section is explicit that `Main()` is the source of truth, not the dot-source block.
2. Linux/Windows parallel install flow visibility was previously asymmetric -- Linux had a documented chain (`zsh -> uv -> nvm -> gh -> auth -> copilot-cli -> squad-cli`) but Windows did not, despite Windows having a richer chain (12 steps vs. Linux's 7) due to platform-specific additions (git not pre-installed, dotfiles/profile finalizers, winget editor/multiplexer installs).
3. The chain has shifted across sprints: PR #195 split a monolithic `setup.ps1` into per-tool modules under `scripts/windows/tools/`, and PR #297 moved `auth.ps1` from the windows root into `tools/`. The History paragraph at the end of the new section records this evolution so future PRs can trace the layout lineage without spelunking.

**Style/format decisions:**
- ASCII arrow chain (`->`) instead of Mermaid: the existing Linux Dep Order is plain ASCII (with U+2192 arrows), and no Mermaid is used anywhere in ARCHITECTURE.md. Brief style pref was "Mermaid preferred IF Linux side has Mermaid, else fall back to ASCII." Fell back to ASCII.
- Used `->` (two ASCII bytes) instead of `->` (U+2192) for new content: brief gotcha called for "ASCII ONLY." The pre-commit hook only enforces ASCII on `*.ps1` files in practice, but the defensive choice for the new section makes the content portable to any consumer (some downstream tooling or AI agents may CP1252-decode). Existing Linux line with `->` left untouched (out of scope).
- Table format chosen over a flat bullet list: 12 steps with three columns (function name, source module, Linux mirror) is dense enough that a table is the more readable form.

**Out of scope but worth a follow-up issue:** File Structure tree at ARCHITECTURE.md:54 still lists `auth.ps1` at the `scripts/windows/` root level. PR #297 moved it into `tools/`. The new Dep Order section explicitly cross-references the move so readers are not misled, but the tree itself is stale. Recommend a separate narrow PR to refresh the windows/ subtree in the File Structure section -- not folded here to keep this PR scope tight.

**Verification:** Read `scripts/windows/setup.ps1` directly (lines 1-77) to confirm invocation order from `Main()`. Did not infer from filenames, dot-source order, or prior documentation. Confirmed `lib/` load order from lines 16-17, tool dot-source order from lines 24-34, and `Main()` call order from lines 48-75.

---

### 2026-05-17: Bash test harness convention -- `set -uo pipefail` + tally counters
**By:** Donald (Shell Dev)
**What:** Documented the bash test harness convention in `CONTRIBUTING.md` (`Test Harness Pattern` section) and authored `.squad/skills/test-harness-pattern/SKILL.md`. Convention: tests in `tests/*.sh` use `set -uo pipefail` (intentionally NOT `-euo`) so individual assertion failures do not abort the suite; PASS/FAIL state is tallied via counters and the script exits non-zero only when `FAIL > 0`. `-euo` is acceptable only when every potentially-failing command is wrapped in `if`/`||` (three current files do this).
**Why:** Convention was non-obvious to contributors -- a well-meaning "fix" to add `-e` to a tally suite would break it silently (first failing assertion aborts before the rest of the tests run; CI sees a partial run). Issue #237 surfaced the need to codify the rule. Source-grounded in seven existing bash test files; mixed `-uo` / `-euo` reality documented honestly rather than rewritten.
**Scope:** Bash tests only. PowerShell tests use a separate `Test-Scenario` harness (`test_windows_setup.ps1`) and are out of scope; would need a separate ticket if a similar codification is wanted there.
**References:** PR (closes #237); CONTRIBUTING.md `Test Harness Pattern` section; `.squad/skills/test-harness-pattern/SKILL.md`.

---

### 2026-05-17: install-guard helper deferred (closes #235)

**By:** Goofy (Cross-Platform Dev), Sprint 12 Wave 2 -- on behalf of Earl Tankard, Jr., Ph.D.

**What:** Confirmed Case B from the dispatch decision flow -- the `install-guard` /
`Install-Guard` helper does NOT exist anywhere in `scripts/lib/`,
`scripts/{linux,windows}/lib/`, or any `scripts/{linux,windows}/setup.{sh,ps1}`
on develop @ 69391b5. Only proposal-level mentions remain in
`.squad/agents/mickey/history.md` (V-8 verification, 2026-05-16) and a
Sprint 11 retro. Issue #235 closed as `not planned`.

**Why:** A premature shared helper would mask the actual diversity in current
"already installed?" checks. The ~12 tool scripts span three distinct shapes:

1. **Simple presence + early exit** (no version pin): `zsh.sh`, `uv.sh`,
   `git.ps1`, `vim.ps1`, `uv.ps1`, `psmux.ps1`. Idiom: `command -v X` /
   `Get-Command X` -> log "already installed" -> exit/return.
2. **Version-pinned check** (regex extract + compare): `gh.sh/ps1`,
   `squad-cli.sh/ps1`, `copilot-cli.sh` / `copilot.ps1`, `nvm.sh/ps1` (Node
   side). Idiom: regex `[0-9]+\.[0-9]+\.[0-9]+` against `--version`, compare
   against value from `Read-ToolVersion.ps1` / `read-tool-version.sh`, return
   early on match.
3. **Composite presence + secondary probe**: `nvm.sh` (`$NVM_DIR/nvm.sh` file
   test), `nvm.ps1` (`Test-Path nvm.exe`), `copilot.ps1` (gh extension list
   regex against `gh-copilot`).

A single helper today would either (a) cover only Pattern 1 and leave the
version-pinned majority untouched, (b) cover Patterns 1+2 and punt Pattern 3,
or (c) over-engineer with conditional knobs. None is a win at this scale.

**Threshold rule (going forward):** revisit when **3+ new tools sharing a
single check shape** are added (e.g., 3+ tools that all do version-pinned
checks against `Read-ToolVersion`). Until then, the inline pattern plus
`Read-ToolVersion.ps1` / `read-tool-version.sh` lookup remains the canonical
idiom, already documented in CONTRIBUTING.md "Tool Version Pin Enforcement".

**Outcome:** No code changes. No PR. Issue #235 closed as `not planned` with
verification comment. Worktree `dev-setup-235` has no commits -- safe to
remove without remote-branch cleanup (no `git push --delete origin
squad/235-defer-install-guard` needed).

---

### 2026-05-17: Worktree-isolation discipline gap (Sprint 12 Wave 2 audit finding)

**By:** Jiminy (Hygiene Auditor) -- on behalf of Earl Tankard, Jr., Ph.D.
**Trigger:** Post-batch audit, 3-agent threshold (Mickey #310/PR #321, Donald #237/PR #320, Goofy #235 Case B).

**What:** During Sprint 12 Wave 2, Mickey (dispatched into worktree `dev-setup-310` for issue #310) wrote his decision drop `mickey-arch-windows-dep-20260517.md` (3432 B) to the MAIN checkout's `.squad/decisions/inbox/` instead of `dev-setup-310/.squad/decisions/inbox/`. Worktree -310's inbox is empty. A second related symptom in the same run: an unrelated stray edit to `ARCHITECTURE.md` (em-dash to `--` normalization, 58 lines) was made on the MAIN checkout and had to be reverted by the coordinator. Two distinct write-to-wrong-CWD events in one agent run.

Mickey's actual PR commit (`fd0401a` on `squad/310-arch-windows-dep-order`) is clean and correct -- ARCH, CHANGELOG, history.md only, no inbox file. So the file-system writes for the PR-bound artifacts went to the right tree, but the decision drop and the abortive ARCH edit both went to the wrong tree.

In the same wave, Donald's parallel spawn (worktree `dev-setup-237`, issue #237) wrote his decision drop CORRECTLY to `dev-setup-237/.squad/decisions/inbox/donald-test-harness-20260517.md`. Same dispatch shape, different outcome. The failure is non-deterministic and likely depends on which tool the agent invokes (PowerShell `Set-Content`/`Add-Content` vs `node` vs `git` resolve paths differently with respect to inherited CWD vs `TEAM_ROOT`).

**Why this matters:** Worktree isolation is the lynchpin of the parallel-agent strategy (codified in `.squad/skills/worktree-isolation/SKILL.md`, Sprint 4 incident, PR #56). When an agent writes to the main checkout instead of its own worktree:
1. The drop bypasses the per-branch decision audit trail (Scribe's fold logic expects drops to travel WITH the PR commit, not as out-of-band edits to main).
2. It creates "phantom" unstaged state on `develop`, which the develop-first rule prohibits.
3. It risks cross-agent collisions if two agents happen to write same-named files to the main checkout simultaneously.
4. It defeats the `.gitattributes merge=union` strategy for append-only files (the merge driver only helps when both sides commit the change on their own branch).

In this case the harm was contained -- coordinator harvested the rogue drop into the main inbox before damage spread, and the stray ARCH edit was reverted. But the PATTERN is the concern, not this instance.

**Proposed remediation (pick one or stack them):**

1. **Pre-spawn CWD pinning (recommended primary).** Coordinator wraps every worktree-bound dispatch with explicit CWD pinning at the prompt-template level:
   ```
   IMPORTANT: Before any file write, run:
     PowerShell:  Set-Location -LiteralPath "$WORKTREE_PATH"
     bash:        cd "$WORKTREE_PATH"
   Verify:
     PowerShell:  (Get-Location).Path  -- must equal $WORKTREE_PATH
     bash:        pwd                   -- must equal $WORKTREE_PATH
   If verification fails, ABORT and report. Do not proceed with any write.
   ```
   This puts the burden on the agent's FIRST tool call (cheap), and surfaces the violation immediately if the environment is misconfigured.

2. **Post-write CWD audit step (recommended secondary, defense-in-depth).** Add a final agent-side step before the response-order summary:
   ```
   Verify all writes landed under $WORKTREE_PATH:
     git -C "$WORKTREE_PATH" status --porcelain  -- should show your changes
     git -C "$MAIN_CHECKOUT" status --porcelain  -- should be UNCHANGED
   If main checkout shows changes you did not intend, abort and report.
   ```
   This catches the failure mode AFTER it happens, before the response-order block, so the coordinator at least learns of it.

3. **Coordinator post-spawn diff check.** Coordinator, after collecting agent results, diffs main checkout against pre-spawn snapshot. Any unexpected file in main -> flag and offer to harvest+revert. This is what the coordinator did manually for Mickey's stray ARCH edit; codify it.

4. **Tool-level fix (longest path).** Wrap PowerShell `Set-Content` / `Add-Content` / `New-Item` in a squad-cli helper that requires `-WorkingDirectory` and refuses ambient CWD. Big lift; defer unless 1+2+3 prove insufficient.

**Recommendation:** Adopt #1 + #2 immediately in the standard dispatch prompt template. #3 is a coordinator-side discipline addition (one-line `git status` comparison before declaring an agent "done"). #4 is overkill for now.

**Out-of-scope follow-ups noted in audit (file separately):**
- Pre-commit hook ASCII-scan (`hooks/pre-commit` Check 2) globs only `*.ps1`. HEAD's `ARCHITECTURE.md` has 134 non-ASCII line hits (em-dashes, box-drawing, U+2192) that escaped the hook. README has 60, CONTRIBUTING has 12, plus widespread `.squad/` and `.copilot/` content. Recommend a separate ticket: either extend Check 2 to `*.md` (after a one-time normalize sweep) OR explicitly document that ASCII enforcement is `.ps1`-only and `.md` is author discretion. The current state is "implicit silent gap" which is the worst of both worlds.

**References:**
- `.squad/skills/worktree-isolation/SKILL.md` (Sprint 4 origin)
- `.squad/agents/mickey/history.md` (Mickey's own note: "pre-commit hook only guards `*.ps1`")
- `hooks/pre-commit` lines 31-66 (Check 2 scope)
- PRs #321 (Mickey) + #320 (Donald) -- the contrast pair that revealed the non-determinism


---

# Sprint 15 Dispatch - 2026-05-17

**By:** Mickey  
**Date:** 2026-05-17T15:20:00-04:00

## Issues Filed

### Issue #356: Sweep legacy non-ASCII chars from .md files
- **Owner:** squad:doc (Doc - mechanical docs sweep)
- **Labels:** squad, squad:doc, priority:p2, type:chore, release:backlog
- **Scope:** Run ascii-sweep.py, hand-fix non-ASCII in fenced blocks, verify pre-commit passes
- **Risk:** Low (purely mechanical text substitution, 60+ files)

### Issue #355: Normalize Sprint letter refs to numbers in CHANGELOG
- **Owner:** squad:scribe (Scribe - CHANGELOG editorial per #343/#344)
- **Labels:** squad, squad:scribe, priority:p2, type:chore, release:backlog (sync-squad-labels added squad:mickey, go:needs-research)
- **Scope:** Replace Sprint R/S/T with Sprint 11/12/13 in [0.9.1]/[0.9.2]/[0.9.3] sections
- **Risk:** Low (prose-only edit to already-shipped entries, append-only rule applies to headers only)

## Wave Plan

**Structure:** Parallel - both issues are independent text edits with no dependencies.  
**Rationale:** Non-blocking edits to different files; no merge conflict risk (only CHANGELOG touched by #355, only .md files touched by #356).

## Decisions

1. **Assign Issue #356 to Doc:** Doc's audit findings in Sprint 14 drove the scope; mechanical sweeps are appropriate for Doc's fact-checking role.
2. **Assign Issue #355 to Scribe:** Scribe owns CHANGELOG editorial per pattern established in #343/#344; retroactive labeling is a prose-only fix within scope.
3. **No compression needed:** history.md at 10275 bytes (under 15360 hard gate).

## Follow-up

- Both issues eligible for Squad routing auto-claim per issue labels.
- No commits or branches needed at this stage (pure issue filing).

---

## 2026-05-17 Sprint 15 Retrospective (Scribe Drop)

**Filed:** 2026-05-17  
**Source:** .squad/decisions/inbox/scribe-sprint-15-retro-2026-05-17.md  
**Topic:** Sprint 15 retrospective completion and skill candidates

### Summary

Sprint 15 retrospective complete and filed to `.squad/retros/2026-05-17-sprint-15-retro.md` (11730 B, 0 non-ASCII bytes). All 8 key lessons captured:

1. Scribe charter scope catch (CHANGELOG reassigned to Mickey)
2. gh squash-merge stray tmp branch quirk
3. Silent success on background spawn detected via filesystem state
4. Doc dual-worktree pattern (first Sprint 15 use)
5. Doc "self-documenting non-ASCII" trap (2nd sprint occurrence)
6. Branch ancestry hook caught stale sprint branch; recovery pattern validated
7. Atomic inbox drain forward-fix applied cleanly
8. Worktree-remove-FIRST held 4-of-4 (lifetime 25-of-25)

### Skill Candidates Flagged for Formalization

- ascii-docs-about-non-ascii (NEW, medium confidence, 2 applications)
- worktree-base-refresh (NEW, low confidence, 1 application)
- worktree-remove-first (confirm HIGH, no change)

### Release Notes

- 0.9.5 shipped; tag on main @ 49545ad
- 6 issues, 6 work PRs + 2 release PRs merged
- Develop at 2dadf58 (post-release)

### Decision

Accept retro as filed. Skill candidates routed to Pluto for drafting (ascii-docs-about-non-ascii, worktree-base-refresh). No action needed on worktree-remove-first (already HIGH confidence).

---

## 2026-05-17 Sprint 16 wrap (decisions fold)

### Sprint 16 EOS Audit Summary

**Conducted by:** Jiminy (Hygiene Auditor)  
**Date:** 2026-05-17T20:08:00-04:00  
**Verdict:** DIRTY (2 blockers resolved post-audit, 3 findings noted)

#### Blockers (resolved)

1. **Inbox drained** -- 4 files merged into decisions.md (this section)
2. **pluto/history.md compressed** -- reduced from 15694 B to under 15360 B hard gate

#### Findings (non-blocking)

1. **No Sprint 16 orchestration log entries** -- Only 1 entry exists (2026-05-17T19-20-00Z-mickey.md), documenting Sprint 15 dispatch. 8 Sprint 16 spawns have zero coverage. Scribe accepted gap.

2. **3 stale remote squad/* branches** -- origin/squad/367-skill-drift-audit, origin/squad/s16-retro, origin/squad/scribe-s16-history-append. Ralph cleanup pending.

3. **Squash-merge policy mismatch** -- Charter specifies "No squash merges on develop or main." Sprint 16 PRs #368, #369, #370, #372, #374, #375, #376 all squash-merged to develop. Only #373 (release merge) was correctly a regular merge. Follow-up: #371 should address this or charter needs update.

#### Audit passes

- Working tree: clean
- develop in sync: HEAD = origin/develop @ aba8332
- Tag 0.9.6: annotated tag 38c0942 -> commit 10d203f (correct)
- PR #373: regular merge (2 parents). Confirmed.
- 128218a on main: documented mistake, recovered via d102a7c forward-merge
- Issue #371: open, labels correct (type:chore, area:meta, squad:scribe, priority:p3)
- Open PRs: 0
- history.md timestamps: all 9 agents updated 2026-05-17
- All Sprint 16 commits on develop match manifest SHAs

#### Agent history.md sizes (HARD GATE 15360 B)

| Agent  | Bytes | Status |
|--------|-------|--------|
| chip   | 12446 | PASS   |
| doc    | 13420 | PASS   |
| donald | 12688 | PASS   |
| goofy  | 10925 | PASS   |
| jiminy | 12494 | PASS   |
| mickey | 11914 | PASS   |
| pluto  | <15360 | PASS (compressed) |
| ralph  | 13147 | PASS   |
| scribe | 13729 | PASS   |

### Sprint 16 Issue Dispatch

**Conducted by:** Mickey (Triage Lead)  
**Issues filed:** 6

1. **#363** -- Scribe: decisions.md archival (decisions.md 60270 B -> 51200 B hard gate)
2. **#362** -- Pluto: ascii-docs-about-non-ascii SKILL.md (prevents self-documenting pitfall)
3. **#364** -- Pluto: worktree-base-refresh SKILL.md (recovery recipe for branch ancestry bleed)
4. **#367** -- Pluto: skill drift watchlist audit (confidence freshness check)
5. **#366** -- Pluto: skill graduation audit (promote low->medium, medium->high per thresholds)
6. **#365** -- Mickey: tag prefix sanity check (verify X.Y.Z bare convention)

**Wave A (parallel):** #363, #362, #364, #365
- #363: Scribe direct-push (develop, --no-verify)
- #362, #364: Pluto skills (disjoint paths, parallel-safe)
- #365: Mickey comment-only (no repo writes)

**Wave B (serialized after Wave A):** #367, then #366
- #367: drift audit, reads-only, writes pluto-skill-drift-2026-05-17.md
- #366: graduation audit, reads #367 findings, writes to SKILL.md

Charter alignment: No conflicts identified. Scribe direct-push pattern matches Sprint 15 workflow.

### Sprint 16 Work Completion

**Issues closed:** 6

1. **#362 (PR #369)** -- ascii-docs-about-non-ascii/SKILL.md -- medium confidence, 2 observations (Sprint 14 #340, Sprint 15 #356/#359)

2. **#363 (direct push 5f07514)** -- decisions.md archival pass -- 1 stale 2025-07-14 entry moved to decisions-archive.md. Hard gate (51200 B) not met mid-sprint; follow-up #371 filed for policy review.

3. **#364 (PR #370)** -- worktree-base-refresh/SKILL.md -- low confidence, 1 observation (Sprint 15 #359)

4. **#365 (comment-close)** -- Tag prefix sanity check -- 14/14 tags conform to bare X.Y.Z convention. No drift.

5. **#366 (comment-close)** -- Skill graduation audit -- 0 candidates eligible. Closed as no-op per #367 findings.

6. **#367 (PR #368)** -- Skill drift watchlist audit -- 30 skills audited, 0 graduation candidates, 27 with zero observed applications, 3 low-confidence under threshold. Report at pluto-skill-drift-2026-05-17.md.

### Forward-Merge Recovery Context

PR #368 (skill drift audit) landed on main by mistake at commit 128218a. Forward-merged back to develop via merge commit d102a7c. main was an ancestor of develop at release time; the develop->main PR #373 brought main forward via regular merge.

### Release SHAs (0.9.6)

- Squash commit (develop, PR #372): 7172ae7f31e6c3a0099313c198558db122186439
- Merge commit (main, PR #373): 10d203fd023077ec3526d8b1bdc17defadd2ace4
- Tag 0.9.6: 38c0942f1959299cfccd084710da90379ff46d59
- GitHub release: https://github.com/primetimetank21/dev-setup/releases/tag/0.9.6

### decisions.md Archival Pass

**Issue:** #363  
**Scope:** decisions.md exceeded hard gate (51200 bytes); archival per 2026-05-10 cutoff rule  
**Cutoff date:** 2026-05-10 (7 days before 2026-05-17)  
**Criterion:** Entries dated 2026-05-09 or earlier

**Entries moved:** 1 (2025-07-14 -- Gitconfig editor literal value + override comment, Issue #184, 1153 bytes)

**File sizes after archival:**

| File | Before | After | Change |
|------|--------|-------|--------|
| decisions.md | 60270 B | 59116 B | -1154 B |
| decisions-archive.md | 121949 B | 123171 B | +1222 B |

**Acceptance criteria:**

- [x] Entry count: 6 + 9 (combined)
- [x] No entries lost in transit
- [ ] decisions.md < 51200 bytes: FAIL (59116 B, 7916 B over gate)
- [x] ASCII-only in additions: 0 non-ASCII bytes
- [x] Header marker updated: "2026-05-04 fold" -> "2026-05-09 second fold"

**Note:** Hard gate not met. Only 1 entry before cutoff date 2026-05-10. Earliest remaining live entry is 2026-05-14 (5 days after cutoff). No entries exist in 2026-05-05 through 2026-05-13 range. Follow-up #371 filed for policy review.

### Decision

Accept all Sprint 16 work as complete. Acknowledge decisions.md gate breach (#371 tracks policy review). Scribe compression of pluto/history.md resolves blocker #2.

---

## 2026-05-17T20:30 Earl directive -- squash-merge policy clarification

**By:** Earl (via Coordinator, Sprint 16 EOS Q&A)
**What:** Squash merges to `develop` ARE the standing policy. Regular merges apply ONLY to `develop -> main` release cuts (and any back-merge recovery). Jiminy's charter line 41 ("No squash merges on develop or main") was outdated -- update to clarify.
**Why:** Sprint 16 squash-merge mismatch surfaced by Jiminy-4 EOS audit. Earl confirmed via choice "Charter is outdated -- squash to develop is what I want."
**Impact:**
- Jiminy charter line 41 needs rewrite
- No retroactive changes to past sprints (no history rewriting)
- This memory should be stored for future sessions

