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
