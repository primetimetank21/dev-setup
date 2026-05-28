# Doc -- Fact Checker

> History log: hires, work completed, learnings.

## 2026-05-16 -- Hired

Hired as the squad's Fact Checker. Addresses the verifier/validator gap Earl flagged in the Sprint 8-hotfix (formerly Sprint Q) retro. First fact-check assignment pending.

## Learnings

---
> **SUMMARIZED 2026-05-28:** Verifications 1-5 (PRs #263, #265-#269, #274-#279, #282, #342) archived to history-archive.md. Patterns: cross-file consistency checks, set -e bash failures, autocrlf CI traps, inter-PR collisions, npm registry version mismatches.

### 2026-05-17 -- Sprint 15 #356 ASCII sweep fact-check + ship

- **Scope:** Sweep 33 tracked .md files for legacy non-ASCII characters (em-dashes, smart quotes, box-drawing) pre-dating the #334 ASCII hook expansion.
- **Files cleaned:** 30 .copilot/skills/*.md + ARCHITECTURE.md + tests/README.md + .github/agents/squad.agent.md. Total: ~1,250 non-ASCII bytes removed.
- **Methodology:** ascii-sweep.py tool + hand-conversion for fenced code blocks (tool preserves fences by design).
- **Fence handling pattern:** Box-drawing (|---|`--) -> ASCII (+--|`--), em-dash (--) -> --, smart quotes -> straight quotes, ellipsis -> ....
- **PR shipped:** #358. Branch: squad/356-md-ascii-sweep off develop @ caf5c64.
- **Verification:** Pre-commit hook passes; `git grep "[^\\x00-\\x7F]"` returns 0 matches on tracked .md files.
- **Learnings:** Worktree setup requires explicit CWD tracking in multi-worktree environments; file I/O via PowerShell [System.IO] can appear to succeed but not persist (use Python pathlib or direct git commands for reliability). UTF-8 byte counting (where multi-byte chars count as N bytes) differs from Unicode character counting -- use Python's `ord(ch) > 127` for accurate non-ASCII detection.
- 2026-05-27 -- Grilled #441 profile-path plan (fact-check lens). Verdict: PROCEED (10 factual claims verified; all PowerShell behaviors + sentinel patterns + profile load order confirmed).

## 2026-05-27 -- Mechanical Trailer Fix: Issue #451

- **Task:** Fix git commit trailers (blank line before Co-authored-by per conventional-commits)
- **Problem:** Commits 461befc + b274cebe had Co-authored-by concatenated to body (Jiminy-R3 DIRTY flagged)
- **Solution:** Rebase with git commit --amend on both commits; insert blank line before trailer
- **Verification:** Both fixed commits parse correctly via git interpret-trailers --parse; old SHAs orphaned; worktree clean
- **Key learning:** Mechanical fixes like trailer format are low-context tasks suitable for delegated review post-implementation. Correct early to maintain clean audit trail.
- 2026-05-28 -- #470 v9 fact-check: REQUEST CHANGES -- wrong Windows git-hook path and false Windows squad-cli npm-absent skip claim.

## 2026-05-28 -- #468 Plan v9 Fact-Check (Mandatory Panel Status Update)

- **Verdict:** REQUEST CHANGES (2 factual errors)
- **Finding 1 (HIGH):** Plan references `scripts/windows/tools/git-hook.ps1` but function actually lives in `scripts/windows/setup.ps1` (different module structure than bash)
- **Finding 2 (HIGH):** Plan claims Windows squad-cli silently skips on npm-absent; actual behavior is exit 1 on npm missing
- **Impact:** No design/process/test reviewer axis found these across v1-v8. Fact-checking immediately caught 2 errors.
- **Earl Directive:** Every future #468 plan re-grill MUST include Doc as mandatory reviewer (join Duck + Jiminy panel)
- **Status:** Doc now mandatory on #468 plan re-grills for v10 onward

## 2026-05-28 -- #468 Plan v12 Authoring (Windows example syntax fix)

- **Role:** Author (v12 patch)
- **Trigger:** Duck v11 verdict -- two Windows npm-absent example bullets used Linux flag syntax (`--only=`) and Linux tool name (`copilot-cli`); Windows uses `-Only 'X'` and registry key `copilot`.
- **Fix:** Lines 793-796 corrected: `-Only 'copilot'` Windows and `-Only 'squad-cli'` Windows. Single-quote style verified against all existing `-Only '...'` usages in plan.
- **Also updated:** Author line (v12 appended), v12 changelog section added above v11.
- **Eligibility:** Doc authored v10 and approved v11 fact-check -- cleanly eligible, no rule relaxation.
- **Commit:** 8dfb9b4 on `squad/468-customizable-install`

## 2026-05-30 -- #468 Plan v13 Fact-Check (Sprint 19)

- **Role:** Fact-checker (v13 authored by Mickey; Doc authored v12)
- **Artifact:** `docs/plans/468-customizable-install.md` @ commit `140feb4`
- **Verdict:** APPROVE
- **v13 fix verified:** Line 179 (was line 167 in v12) -- DD-1 git-hook unsafety bullet corrected from `--only=uv` to `-Only 'uv'`; single-quote convention confirmed correct.
- **Full sweep result:** No new Windows/Linux flag violations introduced. Two pre-existing issues noted: line 815 (`-Only git-hook` unquoted) and line 1108 (`-Only "gh"` double-quoted) -- both from v5, non-blocking.
- **Tool names:** `copilot` (Windows $DefaultTools/registry) and `copilot-cli` (Linux) verified correct throughout.
- **npm-absent 2x2 matrix:** Unchanged from v12; all 4 cells verified against source scripts.
- **Source citations:** All file:line references verified against `squad/468-customizable-install` branch.
- **Self-improvement:** Missed the DD-1 bullet during v12 authoring because it was outside the structured example/table sections I focused on. Future sweeps: explicit pass over ALL inline flag examples in prose sections.
- **Decision drop:** `.squad/decisions/inbox/doc-468-v13-factcheck.md`

## 2026-05-30 -- #468 Plan v14 Fact-Check (Sprint 19)

- **Role:** Fact-checker (v14 authored by Goofy; Doc authored v12, fact-checked v13 -- eligible)
- **Artifact:** `docs/plans/468-customizable-install.md` @ commit `b5cb3dc`
- **Verdict:** REQUEST CHANGES (1 factual error in changelog; content fixes all correct)
- **All 5 fixes verified:** `-Only 'git-hook'` (line 837), `-Only 'gh'` (line 1130), 3x `-Skip 'winget-check'` (lines 110, 112, 866).
- **Changelog error found:** Item 3 attributes the two v9-changelog bare occurrences to "Lines ~104, ~106 (v7 changelog)". Actual v13 locations: lines 88, 90 in the **v9 changelog** section. Lines 104-106 in v13 are the v7 changelog header -- no winget-check content there at all.
- **Required fix:** Line 24-25 of plan -- change "Lines ~104, ~106 (v7 changelog)" to "Lines ~88, ~90 (v9 changelog)".
- **Full sweep result:** 4 pre-existing double-quote violations found at lines 188, 773, 774, 784 (grammar spec / intro text, all from v5 era). Not v14's fault; advisory only. Recommend dedicated v15 cleanup.
- **v13 fix, tool names, npm-absent matrix, source citations:** All verified unchanged and correct.
- **Self-improvement:** v13 sweep missed lines 188, 773, 774, 784 double-quotes. Future sweeps: explicit pass over grammar table AND intro/summary text, not just Windows-example sections.
- **Decision drop:** `.squad/decisions/inbox/doc-468-v14-factcheck.md`

