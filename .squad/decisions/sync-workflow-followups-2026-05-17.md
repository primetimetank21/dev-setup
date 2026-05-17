# Decision: sync-squad-labels.yml Follow-up Fixes

**Date:** 2026-05-17
**Issue:** #350 (closes)
**PR:** squad/350-sync-workflow-followups
**Sprint:** 14 Wave 3 (pulled from Sprint 15 candidates per Earl's call)
**Surfaces from:** #347 Phase 6 workflow audit

---

## Context

Three mechanical gaps in `.github/workflows/sync-squad-labels.yml` were
identified during the #347 Phase 6 audit and filed as #350. The workflow
was not managing three label groups that exist in the repo:
`priority:p3`, and the `platform:*` set created in PR #349. Additionally,
dead code left over from an abandoned @copilot integration path was
cluttering the script.

---

## Fix 1: Add `priority:p3` to PRIORITY_LABELS (line ~93)

`priority:p3` has existed in the repo since Sprint 12 W1 (#254) but was
never added to the workflow's `PRIORITY_LABELS` array. Without this entry,
the workflow cannot re-create the label if it is ever deleted, and will not
sync description or color changes.

**Entry added:**
```js
{ name: 'priority:p3', color: 'D4E5F7', description: 'Backlog / icebox' }
```

### Color choice rationale

Two options were presented in the issue:
- `0E8A16` (green) -- same as `go:yes` (Ready to implement)
- `D4E5F7` (light blue) -- same as `release:backlog` (Not yet targeted)

**Chosen: `D4E5F7`**

Rationale: "Backlog / icebox" is semantically equivalent to
`release:backlog` -- both signal "not yet targeted / deferred". Using the
same cool-tone light blue (`D4E5F7`) groups them visually and avoids
conflating `priority:p3` with `go:yes`, which carries a "ready" signal.
Green (`0E8A16`) connotes readiness; light blue connotes deferral. The
choice is self-documenting.

Note: The existing repo label had color `0075CA` and description
"Enhancement -- nice to have". The workflow will update it to `D4E5F7` /
"Backlog / icebox" on next sync run per the `updateLabel` path.

---

## Fix 2: Add PLATFORM_LABELS array + push (lines ~96-100, ~122)

Three `platform:*` labels were created in PR #349 (`platform:linux`,
`platform:macos`, `platform:windows`, all color `0052CC`). The workflow
had no `PLATFORM_LABELS` array, so these labels were unmanaged -- they
could not be re-created or synced if deleted.

**Array added after PRIORITY_LABELS:**
```js
const PLATFORM_LABELS = [
  { name: 'platform:linux',   color: '0052CC', description: 'Linux-specific' },
  { name: 'platform:macos',   color: '0052CC', description: 'macOS-specific' },
  { name: 'platform:windows', color: '0052CC', description: 'Windows-specific' }
];
```

**Push added with the other static label groups:**
```js
labels.push(...PLATFORM_LABELS);
```

Color `0052CC` matches the labels created in PR #349 (confirmed via
`gh label list --search "platform:"`).

---

## Fix 3: Remove dead `hasCopilot` code (Option A)

Three code blocks were removed:

1. **`const hasCopilot` check** (was line 62-63):
   ```js
   // Check if @copilot is on the team
   const hasCopilot = content.includes('...robot emoji... Coding Agent');
   ```

2. **`COPILOT_COLOR` const** (was line 68):
   ```js
   const COPILOT_COLOR = '10b981';
   ```

3. **`if (hasCopilot)` conditional push** (was lines 114-121):
   ```js
   if (hasCopilot) {
     labels.push({
       name: 'squad:copilot',
       color: COPILOT_COLOR,
       description: 'Assigned to @copilot (Coding Agent) for autonomous work'
     });
   }
   ```

**Rationale for Option A (remove, not integrate):**

Earl did not specify @copilot integration plans for #350. Option A was the
explicit fallback in the issue body. The `content.includes()` check searched
for a robot emoji string that never matched any actual `team.md` content
(no team.md has ever included that exact emoji + text combination). The
code was dead from birth. Removing it eliminates 4 bytes of non-ASCII
(the robot emoji U+1F916 UTF-8 encoding) as a side benefit.

If @copilot integration is later desired, a new issue should be filed to
design the team.md marker format and workflow behavior explicitly.

---

## Pre-existing non-ASCII em-dashes in workflow YAML

The workflow YAML contains 5 em-dashes on lines 31, 80, 86, 106, 132
(15 non-ASCII bytes total in UTF-8). These are **deliberately left in
place** and are out of scope for this PR.

The pre-commit ASCII Check 2 (`grep -nP '[^\x00-\x7f]'`) does NOT scan
`.yml` files -- its scope is `.ps1`, `.sh`, and `.md` only. Therefore
these em-dashes do not violate any enforced policy. This was documented in
the #347 decision drop and confirmed again here.

**Post-Fix 3 workflow YAML non-ASCII byte count: 15**
(was 19 before Fix 3; delta is exactly 4 bytes -- the U+1F916 UTF-8
four-byte sequence that was removed with the dead code)

---

## References

- Closes #350
- Surfaces from #347 Phase 6 audit (Sprint 14 W2)
- Sprint 14 Wave 3 attribution (pulled from Sprint 15 candidates)
- PR #349: platform:* labels created (Pluto, Sprint 14 W2)
- Sprint 12 W1 precedent: #254 / PR #315 (same gap for priority:p3 first noted)
- `.squad/skills/label-hygiene/SKILL.md`: audit-before-delete SOP
