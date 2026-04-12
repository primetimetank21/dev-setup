# Session Log: Install Script Fixes (Issues #68–#69)

**Date:** 2026-04-12T02:46:55Z  
**Duration:** ~1 hour  
**Participants:** Mickey (Lead), Donald (Shell Dev)  
**Outcome:** ✅ Both issues fixed, PRs merged to `develop`

---

## Context

Windows users continued experiencing failures during Devcontainer setup despite prior `.gitattributes` fix (PR #66). Investigation revealed two independent, fixable bugs:

1. **Issue #68:** stdout/stderr interleaving in piped contexts (diagnostic noise)
2. **Issue #69:** CRLF persistence in working trees from pre-PR#66 clones (bash runtime errors)

---

## Work Summary

### Phase 1: Issue Creation (Mickey)
- Created GitHub issues #68 and #69 with clear problem statements and proposed solutions
- Documented rationale for two-issue split (separation of concerns, independent review)
- Assigned both to Donald for implementation
- Decision record: `.squad/decisions/inbox/mickey-install-issues.md`

### Phase 2: Implementation (Donald)
- **PR #70:** Fixed issue #68 by adding `exec 2>&1` to root scripts
  - Files touched: `setup.sh`, `scripts/linux/setup.sh`
  - Impact: stderr merged into stdout; all subsequent child processes inherit merged FDs
  - CI: 4/4 green

- **PR #71:** Fixed issue #69 by adding CRLF strip in Devcontainer `onCreateCommand`
  - File touched: `.devcontainer/devcontainer.json`
  - Impact: working tree CRLF files stripped before setup runs (no-op on LF systems)
  - CI: 4/4 green

- Decision record: `.squad/decisions/inbox/donald-68-69-fixes.md`

### Phase 3: Review & Merge (Mickey)
- Reviewed both PRs; approved both
- Verified CI (4/4 green on each)
- Merged via `gh pr merge --squash --delete-branch --admin`
- Branches cleaned up: `squad/68-fix-output-ordering`, `squad/69-devcontainer-crlf-guard`

---

## Outcomes

✅ Issue #68 resolved — stdout/stderr ordering fixed  
✅ Issue #69 resolved — CRLF guard applied  
✅ Both PRs merged to `develop`  
✅ CI green on all checks  
✅ Decision records captured in inbox for Scribe merge  
✅ Clean git history (squash merges)

---

## Key Decisions

1. **Two separate issues:** Logging order (orthogonal to line-ending). Faster independent review + merge.
2. **`exec 2>&1` in root scripts only:** Child processes inherit merged FDs; redundant in tool scripts.
3. **`onCreateCommand` before `postCreateCommand`:** CRLF strip must run before setup.sh is invoked.
4. **`sed -i 's/\r//'`:** POSIX-portable alternative to dos2unix; no-op on LF systems.

---

## Next Steps

- Scribe: Merge decision records from inbox into decisions.md
- Scribe: Update Mickey and Donald history.md with team context
- Scribe: Commit and push `.squad/` changes
- Team: Close issues #68 and #69 (will auto-close when PRs merge if linked in PR bodies)
