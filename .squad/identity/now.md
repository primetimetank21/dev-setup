---
updated_at: 2026-05-28T07:45:00-04:00
focus_area: "[TARGET] PR #470 (#468 plan) at v14-amended (commit d0b7852). 3-reviewer regrill split 1A/2R. Decision pending on v15 vs merge-as-is."
active_issues:
  - 468
  - 466
  - 467
pending_prs:
  - 470
  - 471
---

# What's Next (Next Session)

## [TARGET] Decision pending on PR #470 path forward

**Branch:** `squad/468-customizable-install` -- HEAD `d0b7852`
- `d0b7852` (Goofy) -- history.md addendum (post-amend)
- `b5cb3dc` (Goofy) -- v14 plan content (5 quoting fixes: `-Only 'git-hook'`, `-Only 'gh'`, 3x `-Skip 'winget-check'`)
- `140feb4` (Mickey) -- v13 (line 167 fix)
- `8dfb9b4` (Doc) -- v12 (Windows npm-absent matrix syntax fix)
- `f212ef1` (Mickey) -- v11 (2x2 npm-absent matrix)
- `d85993b` (Doc) -- v10 (git-hook path + squad-cli parity)

### v14-amended regrill results (split decision)

| Reviewer | Verdict | Notes |
|----------|---------|-------|
| Duck-4 | REQUEST CHANGES | 4 grammar-spec double-quote lines (188/773/774/784); flagged history.md in commit (NOT a real issue -- squad convention) |
| Jiminy-5 | APPROVE | Labels resolved (`squad:mickey` + `priority:p1` added this session); treats grammar specs as intentional |
| Doc-3 | REQUEST CHANGES | **Real factual error**: v14 changelog cites "v7 changelog" but bare `-Skip winget-check` lived in v9 changelog section. Plus same 4 grammar-spec lines (marked advisory) |

### Blockers for next session to resolve

1. **REAL: v14 changelog factual misattribution** -- Goofy wrote "Lines ~104, ~106 (v7 changelog)" but the bare nits were actually in the v9 changelog section. Doc verified at source. Fix changelog text only.
2. **STYLISTIC: 4 grammar-spec double-quotes** at lines 188/773/774/784 (e.g. `-Only "a,b,c"`). Duck says fix; Doc says advisory; Jiminy + Goofy treat as intentional grammar convention.

### Path options (Earl to pick at session start)

**A.** Amend v14 again: fix changelog text (v7->v9) + normalize the 4 grammar-spec lines to single-quotes, one final regrill, then merge. (Most thorough; another cycle.)

**B.** Amend v14 to fix ONLY the changelog factual error; leave grammar-spec lines as-is (intentional convention claim), regrill, merge. (Middle ground.)

**C.** Merge as-is -- file both as follow-up issues; ship the plan. The changelog is internal metadata, not the substance. (Fastest.)

### Lockout state for v15 (if chosen)

- v14 author: **Goofy** -- locked out as v15 author
- v13 author: Mickey -- eligible for v15
- v12 author: Doc -- eligible for v15 BUT he's the standing required reviewer (Earl directive 2026-05-28). If Doc authors v15, regrill panel needs reconsidered.
- Per-version-prior lockout interpretation has held throughout this session (only the immediate-prior author is locked).
- Natural v15 candidates: **Mickey** (Lead, clean lockout state) or **Pluto** (config engineer, no recent authoring).

### Standing Earl directives (carry forward)

- **Every #468 regrill from v10 onward MUST include Doc** (fact-checker axis).
- **Vertical slicing must remain intact** -- Slices 1/2/3 untouched in all post-v9 patches.
- **Scope discipline** -- surgical fixes only; no "while I'm here" cleanups. Pattern of repeated regrills finding new same-class nits suggests pre-commit author should do a `-Only`/`-Skip`/`--only=`/`--skip=` full-file grep before each author commits.
- **Squash to develop** -- standard merge for PR #470.

## Recently Shipped (this session)

- v10 (`d85993b`) -- Doc: Windows git-hook path + squad-cli parity
- v11 (`f212ef1`) -- Mickey: 2x2 npm-absent matrix + parity clarifier (Earl-authorized deadlock break)
- v12 (`8dfb9b4`) -- Doc: Windows npm-absent example syntax (Duck v11 finding)
- v13 (`140feb4`) -- Mickey: line 167 Windows example syntax (Duck v12 finding)
- v14 (`b5cb3dc` plain, amended in same SHA after force-push from `fe8c3f1`) -- Goofy: 5 PowerShell quoting normalizations (Doc-2 v13 advisory + Goofy self-surfaced amends)
- **PR #470 labels added**: `squad:mickey` + `priority:p1` (resolves Jiminy carry-forward flag)
- Session state persisted (`98b2702`) with donald/doc history compression
- 5 sweep-and-regrill cycles completed; v11/v13 fully approved; v12/v14 found follow-on nits

## Open PRs at session end

- **#470** -- #468 plan, v14-amended pending decision (path A / B / C above)
- **#471** -- #461 research doc by Goofy. APPROVED. Ready to merge.

## After PR #470 merges

1. Slice 1 implementation (per v14 plan): `--list` + `--help` + root entrypoint arg forwarding + mock-tools-dir harness + baseline fixtures.
   - Owners: Goofy (cross-platform) + Donald (bash) + Pluto (registry + config).
   - Chip writes/verifies tests. Doc fact-checks implementation against merged plan.
2. **#466** delta installer + git config wiring (Goofy + Chip).
3. **#467** lazygit installer (Goofy + Chip).
   - Both via `$ToolRegistry` 3-line extension contract from the merged plan.
   - Opt-in: present in `AvailableTools` but absent from `DEFAULT_TOOLS`.

## Process retrospective notes (for Scribe to fold)

- 5 sweep-and-regrill cycles on a single plan revision suggests: authors should run a full `--only=`/`--skip=`/`-Only`/`-Skip` grep before each commit. Same-class nits keep slipping past per-version author sweeps. Add to spawn-prompt hygiene template?
- Rubber-duck (Duck) consistently catches what general-purpose sweeps miss. Consider Duck as the "first reviewer" axis for any plan with code-syntax examples.
- Jiminy + Goofy both reported "context consistency PASS" on v12 sweeps and both missed line 167. The bigger lesson: line-by-line is required; surface scan is insufficient. Jiminy-3/4 self-corrected.
- 6 inbox drops accumulated this session for Scribe to fold: duck-468-v11/v12 (verbal only -- duck cannot write files), jiminy-468-v11/v12/v13/v14, doc-468-v11/v13/v14, goofy-468-v11/v12/v14 (+amend), mickey-468-v13/v14-not-applicable. Spawn Scribe to drain at next session start.

Updated by Coordinator at 2026-05-28T07:45:00-04:00 -- Earl directive: "lets pause here. update now.md so we can pickup next session".
