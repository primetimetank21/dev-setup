# Pluto Archive -- Historical Context

> Append-only per Source of Truth Hierarchy. Entries preserve pre-Sprint 14 work + Sprint 14 detailed breakdowns archived 2026-05-17.

---

## Sprint 14 W2 (archived 2026-05-17) -- Issue #347: Label taxonomy cleanup (45 -> 32 labels)

**Branch:** squad/347-label-cleanup  
**PR:** (pending push)  
**Status:** Migration complete; all 7 phases passed.

### What I did

Slimmed the repo label taxonomy from 45 to 32 labels via Earl's mandated triple-verification protocol. 13 deletions (8 GitHub-default duplicates, 4 stale release version labels, 1 lonely status:in-progress), 3 renames (area:linux/macos/windows -> platform:linux/macos/windows).

Pre-flight gated on Wave 1 + 1.5 closure (#340, #341, #342, #343 all CLOSED). Then per the run-book:

- **Phase 1 (pre-snapshot)** Captured gh label list (45 labels), per-label issue counts for all 16 touched labels (bug=28, documentation=9, enhancement=42, status:in-progress=16, area:linux=1, area:macos=1, area:windows=3, all 5 GH-default zero-count drops + 4 zero-count releases).
- **Phase 2 (plan)** Built tmp-label-migration-plan.json with PRE/AFTER + per-issue ops triplets. 84 unique affected issues. Validated plan: every remove-of-a-replace-bucket label paired with the correct add; no forbidden label in any expected_after.
- **Phase 3 (create new first)** gh label create platform:linux/macos/windows with color 0052CC. Verified via name-filter (the --search flag is a fuzzy match -- it also matched squad:goofy; switched to in-script Where-Object { $_ -like 'platform:*' } to compare cleanly).
- **Phase 4 (migrate)** Per-issue PRE/OP/POST loop with hard-halt on POST failure. 84/84 PASS, 0 PRE-mismatch skips, 0 POST halts. All ops applied via a single gh issue edit --remove-label X,Y --add-label A,B call so the swap is one API round-trip per issue.
- **Phase 5 (delete with 0-count gate)** For each of the 16 deprecated labels, re-verified gh issue list --label X --state all returned 0 before calling gh label delete --yes. All 16 deleted.
- **Phase 6 (workflow + docs audit)** Updated sync-squad-labels.yml: removed release:v0.4.0/v0.5.0/v0.6.0/v1.0.0 from RELEASE_LABELS (kept release:backlog); removed the entire SIGNAL_LABELS block (bug, feedback) and the corresponding labels.push(...SIGNAL_LABELS).
- **Phase 7 (post-snapshot + drop)** 32 labels post, all 16 deletes confirmed absent, all 3 platform:* present.

### Key learnings

- gh label list --search "platform:" is a FUZZY match, not a prefix filter.
- gh issue edit accepts comma-separated lists in --remove-label/--add-label for atomic multi-op.
- Triple-verification protocol (252 gh-view calls, ~3 minutes) caught 0 PRE mismatches and 0 POST failures.
- 0-count gate before each gh label delete is non-negotiable.
- sync-squad-labels.yml PRIORITY_LABELS still missing priority:p3 (label exists in repo but workflow will not re-sync if deleted).
- ASCII mandate scope is .ps1/.md/.sh per the pre-commit hook, not .yml.

---

## Sprint 14 W3 (archived 2026-05-17) -- Issue #350: sync-squad-labels.yml follow-up fixes

**Branch:** squad/350-sync-workflow-followups  
**Issue:** #350  
**Status:** Complete.

### What I did

Three mechanical gaps in sync-squad-labels.yml surfaced by the #347 Phase 6 audit, filed as #350 and pulled into Sprint 14 W3.

- **Fix 1 (priority:p3):** Added priority:p3 to PRIORITY_LABELS. Color chosen: D4E5F7 (light blue, same as release:backlog), NOT 0E8A16 (green / go:yes). Rationale: backlog/icebox is a deferral signal, not a readiness signal; light blue groups it with release:backlog visually.

- **Fix 2 (PLATFORM_LABELS):** Added PLATFORM_LABELS const array for platform:linux/macos/windows (color 0052CC, matching PR #349) and the corresponding labels.push(...PLATFORM_LABELS) call.

- **Fix 3 (hasCopilot removal -- Option A):** Removed COPILOT_COLOR const, hasCopilot content-includes check (which searched for a robot emoji marker that never existed in any real team.md), and the if (hasCopilot) conditional push. Dead code from birth; Option A per issue body (Earl specified no @copilot integration plans).

Side-benefit of Fix 3: U+1F916 four-byte sequence removed from YAML. Workflow non-ASCII count dropped from 19 to 15 (5 pre-existing em-dashes at 3 bytes each remain; those are out of scope -- hook does not scan .yml).

---

## Sprint 15 -- Issue #364: worktree-base-refresh SKILL.md

**Branch:** squad/364-worktree-base-refresh-skill  
**Issue:** #364  
**Status:** Complete.

### What I did

Drafted and landed .copilot/skills/worktree-base-refresh/SKILL.md -- the first formal writeup of the stale-sprint-branch recovery pattern that surfaced in Sprint 15 PR #359.

The skill documents:
- Why the pre-commit branch-ancestry hook (Check 1) fires when a sprint branch is cut from an old develop tip and develop has since advanced.
- Why git reset --soft is unsafe (leaves INDEX pinned to divergent base, spurious mass-staging result).
- The 3-phase recovery recipe: backup staged files to scripts/_tmp_recovery_<slug>/, git reset --hard origin/develop, restore + commit + cleanup.
- Three acceptance checks before pushing (status clean, diff clean, ancestry verified via git merge-base --is-ancestor origin/develop HEAD).
- Anti-patterns and when to use git rebase instead.

Confidence set to low (1 application: Sprint 15 #359, recovery commit d3229c8). Will graduate to medium on second observation.

### Key learnings

- git reset --soft on a diverged branch produces a mass-staging trap. The INDEX is still set relative to the old base tip, so every file develop changed appears as a staged modification. With 30+ changed files this is effectively un-reviewable and risks committing a silent reversion.
- git reset --hard origin/develop + copy-back is the safe path when the branch has no unique commits.
- git merge-base --is-ancestor origin/develop HEAD is the canonical post-recovery verification -- exits 0 means ancestry is correct and the hook will pass.

