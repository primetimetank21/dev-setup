# Session Log

Cumulative log of completed squad sessions.

---

## 2026-04-19 — Windows PowerShell Aliases & PSScriptAnalyzer Hook

**Issues closed:** #138, #147
**PRs merged:** #145 (rejected initial attempt), #146, #148, #149, #150
**Agents:** Mickey (Lead), Donald (Shell Dev), Goofy (Cross-Platform Dev), Chip (Tester)

### Issue #138 — Windows PowerShell aliases not working after setup

**Root cause:** `setup.ps1` wrote only to the first `$PROFILE` path, and
`Set-Alias` calls lacked `-Force -Scope Global`.

**Fix (PR #146, Donald):**
- Dual-path profile injection — writes to both PS 5.1 (`WindowsPowerShell`)
  and PS 7+ (`PowerShell`) profile paths
- `-Force -Scope Global` on all `Set-Alias` calls
- Sentinel strip+re-inject pattern to ensure idempotent profile updates
- Execution-policy diagnostic warning

**PR #145** was the initial attempt but was rejected during review due to test
regressions (K-2, C-1, C-4). Donald's PR #146 resolved all regressions.

**Tests:** Group K added to `tests/test_windows_setup.ps1`; CI 5/5 green.

**Release:** PR #148 (develop → main), 10/10 CI green.

### Issue #147 — PSScriptAnalyzer advisory pre-push hook

**Implementation (PR #149, Goofy + Chip):**
- Added PSScriptAnalyzer advisory section to `hooks/pre-push`
- Output-based module availability check (`'yes'`/`'no'` pattern)
- Warns on violations but never blocks push
- Graceful skip if `pwsh` or PSScriptAnalyzer module absent
- POSIX `/bin/sh` only — no bashisms

**Tests:** Group L (L-1 through L-5) in `tests/test_windows_setup.ps1`.
Key fix during development: PS 5.1 `Join-Path` only accepts 2 positional args;
used nested `Join-Path (Join-Path $root 'hooks') 'pre-push'`.

**CI:** 5/5 green. **Release:** PR #150 (develop → main), 10/10 CI green.

### Key Decisions & Learnings

1. **PS 5.1 `Join-Path` limit:** Only accepts 2 positional args — must nest:
   `Join-Path (Join-Path $root 'a') 'b'`
2. **Output-based checks over exit-code checks:** Exit-code-based
   `pwsh -Command "... exit 1 ..."` checks are ambiguous in pre-push hooks —
   prefer output-based (`'yes'`/`'no'`) checks for module availability
3. **PSScriptAnalyzer hook philosophy:** Warn-only, graceful degradation,
   POSIX sh — never block a push on advisory linting
4. **Dual-path profile injection:** Required for Windows because PS 5.1 and
   PS 7+ use different profile directories

### Sprint Wrap-up

- All stale branches deleted locally and remotely
- Aliases confirmed working by Earl: `ta`, `tt`, `tls`, `tks`, `gpl`, `ggsls`

---

## 2026-04-19 — Issue #151 Documentation Update

**Issue closed:** #151  
**PRs merged:** #152 (docs → develop), #153 (develop → main)  
**Agents:** Goofy (Docs Author), Mickey (Reviewer/Approver)

### Issue #151 — Document PowerShell aliases and pre-push hook workflow

**Documentation scope:**
- README.md: Windows PowerShell aliases section with full table (`ta`, `tt`, `tls`, `tks`, `gpl`, `ggsls`), dual-path profile injection pattern, pre-push hook overview
- CONTRIBUTING.md: Pre-push hook workflow (shellcheck + PSScriptAnalyzer advisory), PSScriptAnalyzer install instructions
- ARCHITECTURE.md: `hooks/` directory entry, PowerShell conventions rows added to OS/Stack matrix, ownership map updated with Goofy as hooks owner

**Acceptance Criteria (All Met):**
1. ✅ Windows PowerShell aliases documented with table and explanation
2. ✅ Dual-path profile injection pattern documented from #138 work
3. ✅ Pre-push hook workflow (shellcheck + advisory) explained from #147 work
4. ✅ All additions follow existing file styles; no content rewritten

**Review & Approval (PR #152):**
- Mickey reviewed all changes and confirmed acceptance criteria met
- Content style consistency verified across all three files
- 5/5 CI checks passing

**Release (PR #153):**
- develop → main merge, 10/10 CI checks passing
- Branch `squad/151-update-docs` deleted locally and remotely post-merge

### Key Learnings

1. **Docs PR scope:** Only add missing documentation. Never rewrite existing sections. Respect heading styles and table formats already in place.
2. **Advisory-only hooks:** When documenting warning-level hooks, clearly label them as such to prevent confusion about push blocking behavior.
3. **Cross-file consistency:** Documentation PRs spanning multiple files require careful attention to voice, tense, and existing formatting conventions in each file.
