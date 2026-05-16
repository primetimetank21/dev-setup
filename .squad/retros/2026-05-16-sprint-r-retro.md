# Sprint R Retro -- 2026-05-16

Sprint R tackled 5 high-priority hygiene and coverage issues from the go:yes backlog.
All 5 PRs merged after Doc's batch fact-check identified and caught 2 real bugs before
merge (autocrlf in #267, pipefail in #269). Follow-up #271 filed for uninstall hooksPath gap.

## What Went Well

- **Parallel worktree isolation worked perfectly.** All 5 agents (Chip, Goofy, Pluto,
  Ralph, Doc) spawned in isolated worktrees with zero checkout conflicts. The SQUAD_WORKTREES=1
  pattern from Sprint 4 proved its worth under real scale.
- **Batch fact-check caught real bugs BEFORE merge.** Doc's systematic verification
  of cross-platform compatibility (shell set -euo pipefail, Windows CI autocrlf behavior)
  identified 2 genuine bugs (#267 X-1 em-dash rejection failure, #269 uninstall.sh glob
  failure). Both required fixes in the PRs before merge. This is a huge multiplier on code
  quality -- 0 post-merge fixes needed.
- **E2E summary job (#265) will catch future regressions.** This addition makes the CI
  output crisp: green/red at a glance instead of scrolling 100 log lines. Platform
  divergence now has a clear signal.
- **Merge strategy and sequencing handled complex conflicts cleanly.** Doc identified
  the Group X collision (both #267 and #268 tried to use "Group X") and CHANGELOG conflicts
  (5 PRs all touching [Unreleased]). Sequential merge + rebase worked.
- **EOS branch cleanup executed with precision.** Ralph deleted 5 stale sprint branches
  (both local and remote) in one pass and documented the final state clearly. Board is clean.

## What Could Be Better

- **Group letter collision in test file.** Chip and Goofy both picked "Group X" for their
  test sections in tests/test_windows_setup.ps1. This collision should have been flagged
  BEFORE branch creation. The fix (rebase #267 to use Group Y) was smooth but preventable.
  ACTION: Coordinator should pre-assign Group letters in spawn prompts to guarantee no collision.
- **Pre-commit Check 5 refused direct develop commits.** Ralph wrote his EOS history entry
  but could not commit it directly (pre-commit hook blocks direct develops). He had to leave
  it modified for Scribe to fold into this drain PR. Doc sidestepped this by opening PR #270.
  ACTION: Clarify in Ralph's charter (and team docs) that develop commits are branch+PR-only,
  and that end-of-sprint rollups go through Scribe's drain process.
- **CHANGELOG.md conflicts are predictable.** All 5 PRs append to [Unreleased]; both #265
  and #268 created a ### Fixed section at the same line, forcing manual rebase and conflict
  resolution. This is mechanically predictable (5 PRs = high conflict likelihood).
  ACTION: Add a "CHANGELOG Conflict Strategy" note to CONTRIBUTING.md: (a) always append
  entries in order of merge, (b) keep unique section headers, (c) if conflict arises,
  union both entries and accept both (CHANGELOG is a log, not a de-dup list).

## Doc's Batch Fact-Check Verdicts

Doc reviewed all 5 PRs and provided detailed cross-platform validation. Key verdicts:

- **PR #265 (E2E summary job):** PASS. Merge criteria met (all 11 CI checks green,
  job dependency chain correct, continue-on-error preserved, failure propagation correct).
- **PR #266 (hooksPath docs):** PASS. Docs accurate and comprehensive. FOLLOW-UP: Uninstall
  scripts do NOT unset core.hooksPath. This leaves a correctness gap: after uninstall,
  hooksPath still points to hooks/ in the repo (now detached). Must be tracked as follow-up
  (#271 filed).
- **PR #267 (hook behavioral coverage):** FAIL (autocrlf bug). X-1 test ("pre-commit rejects
  .ps1 with em-dash") fails on Windows CI due to core.autocrlf active. When test repo is
  created with git init (without disabling autocrlf), git reprocesses staged bytes (LF->CRLF
  conversion). Pre-commit's ASCII check may fail to detect non-ASCII bytes in the post-CRLF form.
  FIX: Add 'git config core.autocrlf false' immediately after 'git init' in New-XTestRepo.
  Also: Group X collision with #268 requires renaming #267's tests to Group Y.
- **PR #268 (winget exit assert):** PASS. All 7 install sites patched, Assert-LastExit
  helper correct, exit code handling compatible with PS 5.1 (no ternaries, no null-conditional).
  All 10 CI checks green.
- **PR #269 (.bak rotation + pipefail):** FAIL (pipefail glob bug). Uninstall.sh uses
  'set -euo pipefail'. New restore_backup() uses 'ls -t ${target}.bak.* 2>/dev/null | head -n 1'.
  When no .bak.* files exist (fresh E2E install, no pre-existing dotfile backup), the glob
  expands to literal string, ls exits non-zero, and pipefail kills the script.
  FIX: Add '|| newest=""' to the assignment to catch ls failure without killing script.
  E2E Linux and macOS both fail at "Run uninstall" step due to this bug.

## Wins and Learnings

- **Wins:**
  - Parallel worktrees = zero contention. All 5 agents shipped at sprint velocity.
  - Doc's first batch fact-check caught 2 real bugs before merge. Pattern works.
    This is a new role for Dev: catch cross-platform pitfalls at scale.
  - E2E summary job reduces CI noise. Failure signal is now clear.
  - Ralph's EOS sweep + Scribe's drain process kept the repo board clean
    (all stale branches deleted, no dangling PRs, develop commit-ready).

- **Learnings:**
  - Windows CI runners have core.autocrlf active. Tests that write git objects with specific
    byte sequences (e.g., em-dash for ASCII validation) must disable autocrlf to prevent git
    reprocessing. This is a pattern Chip (and anyone touching windows CI test repos) should
    carry forward.
  - The 'set -euo pipefail' in uninstall.sh is strict and correct. But it exposes any glob
    that may fail to expand (e.g., 'ls *.bak.*' when no files match). The fix is to add
    '|| fallback' to catch the failure without killing the script. Pluto (and anyone touching
    the uninstall paths) should anticipate this.
  - Batch fact-check as a role: Doc specializes in cross-platform compatibility and shell
    gotchas. Spawning Doc on any multi-platform PR or shell-heavy code change is high-ROI.
    Consider this a standing pattern.

## Action Items / Follow-ups

- **[#271] Uninstall scripts must unset core.hooksPath.** Filed. Add 'git config --unset-all
  core.hooksPath' to both scripts/linux/uninstall.sh and scripts/windows/uninstall.ps1.
  This closes the correctness gap identified in #266 review.
- **[Charter update: Ralph] Clarify develop-commit ban + Scribe drain.** Ralph's history
  entry couldn't be committed directly due to pre-commit Check 5 refusing direct develops.
  Document this workaround in Ralph's charter: EOS history rolls up via Scribe's drain PR,
  not direct commit. This prevents future confusion.
- **[CONTRIBUTING.md] Add "Group letter assignment" SOP.** When spawning multi-agent test
  batches, coordinator assigns Group letters upfront (X, Y, Z, ...) to prevent collision.
  Add to spawn checklist.
- **[CONTRIBUTING.md] Add "CHANGELOG Conflict Strategy" section.** Document the predictable
  conflict pattern and resolution (union entries, accept both lines).
- **[Standing pattern] Spawn Doc on shell-heavy and multi-platform PRs.** The autocrlf and
  pipefail bugs were caught because Doc systematically reviewed both Linux and Windows CI.
  This is high-leverage; add to coordinator's spawn checklist as a recommendation.

## Stats

- **Issues filed:** 1 follow-up (#271 - uninstall hooksPath)
- **PRs shipped:** 5 (#265, #266, #267, #268, #269)
- **Agents active:** Chip (PR #267), Goofy (PR #268), Pluto (PRs #266, #269),
  Doc (batch fact-check), Ralph (EOS cleanup)
- **Test groups added:** Group Y (4 tests in #267 post-rebase), Group X (9 tests in #268)
- **Bugs caught by review:** 2 (autocrlf in #267, pipefail in #269)
- **Bugs post-merge:** 0 (all caught and fixed pre-merge)
- **E2E duration (post-merge):** Linux 39s, macOS 1m3s, Windows 2m34s

## Reflection

Sprint R was a test of scalability under parallel work. Five agents, five PRs, zero worktree
conflicts, and a new batch-check role caught 2 critical bugs before they hit develop.
The Group X collision and CHANGELOG conflicts were friction points that are entirely
preventable with a bit more coordination upfront. But the fact that both were resolved
cleanly (no rollbacks, no post-merge fixes) suggests the process is robust even when
surprises emerge.

The uninstall.sh pipefail bug is a classic shell gotcha (glob that fails to expand in
strict mode). This is the kind of thing that would normally ship, then come back as
a P0 six months later when someone runs uninstall for the first time. Doc's verification
killed that before it could happen.

**Board status:** CLEAN. All 5 sprint branches deleted. develop = 607051a (PR #270 merge).
1 follow-up filed (#271). Ready for Sprint S.
