---
updated_at: 2026-05-28T05:30:00-04:00
focus_area: "[TARGET] PR #470 (#468 plan) at v10 pending. Doc raised 2 factual blockers on v9. Next session: spawn v10 + final grill panel MUST include Doc."
active_issues:
  - 468
  - 466
  - 467
pending_prs:
  - 470
  - 471
---

# What's Next (Next Session)

## [TARGET] Primary work -- finalize #468 plan, then implement Slice 1

### Step 1 -- Spawn v10 of #468 plan (BLOCKER)

**PR #470** -- `docs/plans/468-customizable-install.md` is at v9 (commit `f4bea92`, by Mickey).
- Duck: APPROVE
- Jiminy: APPROVE
- **Doc: REQUEST CHANGES** -- 2 factual errors all 9 prior rounds missed:
  1. Plan references `scripts/windows/tools/git-hook.ps1` for the Windows git-hook function -- **actual location is `scripts/windows/setup.ps1`** (no separate tools file). Verify and correct every reference.
  2. Plan claims Windows `squad-cli` silently skips on npm-absent -- **actual behavior is `exit 1`**. Linux `squad-cli` is the one that silent-skips. Verify and correct the plan's behavior table / parity claims.

**Lockout state at session end:**
- Locked out as past authors of #468 plan: Mickey (v1, v9), Goofy (v2), Chip (v3), Pluto (v4 + v6 + v8), Donald (v5), Jiminy (v7)
- Doc has NOT authored -- eligible for v10 ownership. He found the bugs; narrow factual edits.
- Alternative: relax lockout for any prior author. Mickey (v9 author) is most natural since v10 is 2 corrections to his v9.

**Recommended dispatch:**
```
Doc, author v10 -- narrow factual fix on v9. Two corrections:
  (1) Replace all references to scripts/windows/tools/git-hook.ps1 with scripts/windows/setup.ps1
      (verify the actual function name in setup.ps1 first)
  (2) Update Windows squad-cli npm-absent behavior claim from "silent skip" to "exit 1"
      (parity table, behavior docs, any Test-Scenario notes)
Preserve all v9 architecture, slicing, concepts, fixture provenance, Invoke-WingetGate spec.
Add v10 changelog with 2 bullets citing Doc's v9 review.
```

### Step 2 -- Final grill panel for v10 (MUST INCLUDE Doc)

**! Earl directive (2026-05-28): every #468 plan re-grill from v10 onward MUST include Doc.**

The fact-checker axis was missing from rounds v1-v8 and only added at v9 -- Doc immediately surfaced 2 real bugs no other reviewer caught. Future regrills need:

- **Duck** (rubber-duck: architecture + blindspot detection)
- **Jiminy** (process/quality auditor: vertical slicing, CI integration, scope discipline)
- **Doc** (fact checker: file paths, function names, line numbers, behavior claims, error message text)

Optional add-ons depending on what's touched in the revision:
- Donald (bash specifics) -- if bash dispatcher or `--list` parsing changes
- Pluto (config/registry) -- if `$ToolRegistry` or `$DefaultTools` changes
- Chip (test/CI) -- if Test-Scenario list or CI matrix changes

### Step 3 -- After v10 approved: merge PR #470 + implement Slice 1

Slice 1 (per v9 plan): `--list` + `--help` + root entrypoint arg forwarding + mock-tools-dir harness + baseline fixtures.
- Implementation owners: Goofy (cross-platform) + Donald (bash) + Pluto (registry + config).
- Chip writes/verifies tests.
- Doc fact-checks final implementation against the merged plan.

### Step 4 -- After Slice 1 lands: #466 + #467 in parallel

**#466** delta installer + git config wiring -- Goofy + Chip. New `scripts/{linux,windows}/tools/delta.{sh,ps1}` + post-install git globals.

**#467** lazygit installer (no config) -- Goofy + Chip. New `scripts/{linux,windows}/tools/lazygit.{sh,ps1}`.

Both land via the `$ToolRegistry` extension contract (3-line pattern) from the v9 plan. Tools are opt-in -- present in `AvailableTools` but absent from `DEFAULT_TOOLS`.

## Recently Shipped (this session)

- **PR #471** (open) -- `docs/research/461-iswindows-detection.md` by Goofy. #461 forward-looking audit; PS 5.1 platform-detection landmines documented.
- **Issue #461** closed (verified fix in commit `31aa228` / PR #462; no remaining unguarded `$IsWindows*` refs in executable paths).
- **PR #470** (draft) -- #468 plan, 9 revisions completed in one session (Mickey -> Goofy -> Chip -> Pluto -> Donald -> Pluto -> Jiminy -> Pluto -> Mickey), pending v10 + final grill.
- **`.squad/skills/`** -- new skills written: `install-plan-grill/`, `ps51-platform-detection-audit/`.

## Open PRs at session end

- **#470** -- #468 plan (v9). Awaiting v10 (Doc-flagged factual fixes).
- **#471** -- #461 research doc. Already-fixed verification. Goofy approve + merge.

## Backlog

- (none beyond #466, #467 -- both blocked on #470 merge)

Updated by Coordinator at 2026-05-28T05:30:00-04:00 -- Earl directive: "document this in now.md that next review should be doc. then wrap session".
