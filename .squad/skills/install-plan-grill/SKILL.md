---
name: "install-plan-grill"
description: "Checklist for grilling a plan that adds CLI flags or install-selection logic to setup.sh / setup.ps1."
domain: "testing, cross-platform, CI"
confidence: "medium"
source: "earned (issue #468 grill, 2026-05-28 -- first formal application; pattern synthesized from #441 grill precedent)"
---

## What This Skill Covers

Use this skill when grilling any plan that:
- Adds new CLI flags to `setup.sh` or `setup.ps1`
- Adds selective install / filter logic (--only, --skip, manifest, prompt)
- Introduces a new dispatch contract (registry, function map, filtered list)

This is Chip's angle: test coverage, parity, CI matrix, idempotency, negative paths.

---

## Grill Checklist

### 1. Parity test contract

- [ ] Each slice's acceptance criteria has a **named test file** for bash AND pwsh.
- [ ] Each file has **named test cases** (exact `Test-Scenario` string or bash function name) -- not prose.
- [ ] The parity matrix rows map 1:1 to named test cases.
- [ ] No slice says "Chip writes tests" without specifying what those tests are called.

**Anti-pattern:** Naming the test FILE in Slice 1 but only giving prose for Slices 2-4. Prose does not produce contractual CI coverage.

### 2. Backward-compat gate

- [ ] An explicit "no-arg run" test case is named.
- [ ] The baseline is defined: what markers / log lines / exit code constitute "unchanged behavior"?
- [ ] A mechanism exists to capture or commit the baseline before the PR lands.
- [ ] This test runs BEFORE any slice-2+ code lands (Slice 1 or standalone).

**Red flag:** "No-arg run produces all markers" without defining the markers list.

### 3. Negative path coverage

Demand named test cases for each of these:
- [ ] Unknown tool name in `--only` or `--skip` -> exit 1 + valid-tool list
- [ ] `--only` + `--skip` both supplied -> exit 1 + mutual-exclusion message
- [ ] `--only=` (empty value) -> exit 1
- [ ] `--skip=` (empty value) -> exit 1 (often missed; must match `--only` validation)
- [ ] Repeated/duplicate flag (`--only=a --only=b` if grammar forbids it) -> defined behavior
- [ ] `--list` + `--only` combo -> defined behavior (list wins, or error)

### 4. CI matrix

- [ ] `validate-ps51` is explicitly named in Done Criteria if any `.ps1` file is changed.
- [ ] `test_setup_flags_pwsh.ps1` (or equivalent) runs under `shell: powershell` in validate-ps51, NOT only under `pwsh`.
- [ ] The PS 5.1 step runs the test FILE directly via `powershell -File`, not `pwsh`.
- [ ] Any new `param()` block or hashtable literal is syntax-checked under PS 5.1.

**Historical landmine:** `param()` blocks and hashtable `@{}` literals with new syntax have silently broken PS 5.1 in prior sprints.

### 5. Idempotency

The plan must list explicit invariants for "run twice with `--only=X`":
- [ ] Exit code 0 on both runs
- [ ] No duplicate PATH entries
- [ ] Marker file / sentinel count unchanged
- [ ] No error output on second run

"Existing `run_tool()` handles it" is NOT a test specification.

### 6. Slice independence

- [ ] Slice 1's tests can pass before Slice 2 code exists (no shared stubs that don't exist yet).
- [ ] If test files are shared across slices, the plan specifies how incomplete slices are skipped without causing false-fails.
- [ ] No fixture file is created in Slice 2 that Slice 1's tests depend on.

### 7. Test naming convention

In this repo:
- Bash test files: `test_{topic}.sh` (NO platform suffix)
- PowerShell parity files: `test_{topic}_pwsh.ps1` (`_pwsh` suffix)
- Example correct pair: `test_squad_spawn.sh` + `test_squad_spawn_pwsh.ps1` (if parity needed)

**Reject:** `test_setup_flags_linux.sh` -- `_linux` suffix is not an established convention.
**Accept:** `test_setup_flags.sh` + `test_setup_flags_pwsh.ps1`

### 8. e2e coverage

- [ ] `e2e-install.yml` is mentioned (or explicitly deferred with justification).
- [ ] At minimum, `--list` (or equivalent discovery flag) is added as a smoke step in all three e2e jobs.
- [ ] If e2e is deferred, the plan says "e2e deferred to slice N -- rationale: ..." (not silent).

---

## Dispatch-Contract Specific Checks

When a plan introduces a registry/hashtable dispatch (e.g., `$ToolRegistry`):

- [ ] Key ordering: is iteration order intentionally non-deterministic? If tool order matters, require `Sort-Object` or explicit ordering rationale.
- [ ] Dynamic discovery: if `--list` is dynamic on Linux (`ls tools/*.sh`) but static on Windows (`$ToolRegistry.Keys`), new tools added to Linux fs are NOT automatically visible on Windows. Plan must acknowledge and document the sync requirement.

---

## Scoring

| Finding | Severity |
|---------|----------|
| Named test case missing for any slice | BLOCKING |
| PS 5.1 not in CI matrix for `.ps1` changes | BLOCKING |
| Backward-compat baseline undefined | BLOCKING |
| e2e not mentioned | BLOCKING |
| Filename conflict (slice vs parity table) | BLOCKING |
| Idempotency invariants absent | MEDIUM |
| Test naming convention broken | MEDIUM |
| Dispatch ordering unacknowledged | MEDIUM |
| Edge case in error table missing | LOW |
| Undefined flag combo behavior | LOW |

Three or more BLOCKINGs -> REVISE verdict.
Any BLOCKING without a clear fix path -> escalate to Mickey before assigning revision.

---

## Related Skills

- `.squad/skills/grill/SKILL.md` -- general grill ceremony rules (lockout, parallel spawn, output format)
- `.squad/skills/parity-audit/SKILL.md` -- test file inventory and runner coverage audit
- `.squad/skills/ps51-ascii-safety/SKILL.md` -- encoding trap for .ps1 test files
- `.squad/skills/test-harness-pattern/SKILL.md` -- Test-Scenario pattern and skip conventions

---

---

## Donald's Bash-Specific Addendum

These checks are in addition to Chip's test/parity angle above. Apply when the plan touches bash installers.

### D-1. Default list: order and source

- [ ] Is the default (no-flags) list hardcoded or filesystem-scanned?
  - Filesystem scan = alphabetical order. Alphabetical breaks implicit tool ordering (nvm before npm-tools; gh before auth).
  - Hardcoded array = safe, preserves existing execution order.
- [ ] Does the plan explicitly name the default list mechanism (not leave it to implementer)?

### D-2. `--list` command correctness

- [ ] Does the list command produce bare tool names or full paths?
  - `ls tools/*.sh | sed 's/\.sh$//'` strips extension but NOT path prefix. Produces `tools/auth` not `auth`.
  - Correct: `for f in "${TOOLS_DIR}"/*.sh; do basename "$f" .sh; done`
- [ ] Does the test assertion reference the correct extraction pattern?

### D-3. Opt-in vs default gate mechanism

- [ ] If new tools are "opt-in only," is the gate named?
  - Filesystem scan = no gate (adding the file auto-includes in default).
  - Hardcoded default array = effective gate -- plan must say so.

### D-4. Silent degradation chains

- [ ] Does the plan acknowledge tools that silently degrade (not fail) when prerequisites are absent?
  - `--only=npm-tool` on a fresh machine without nvm = exit 0, tool not installed.
  - "No DAG needed" is wrong if tools have graceful-degrade guards. Document the chains.

### D-5. Arg-parsing mechanism under `set -e`

- [ ] Is the parsing mechanism specified? (case-based loop, NOT getopts)
  - `getopts` does not support `--long-opts`; returns 1 at end of args (kills under `set -euo pipefail`).
- [ ] IFS-split guard: `IFS=',' read -ra tools <<< "${arg#--only=}"` can return 1 on empty string -- need `|| true`.

### D-6. Backward-compat: no-flags order

- [ ] On a fresh machine, does no-flags run install tools in the same order as before?
- [ ] Is auth always after gh? Are npm-dependent tools always after nvm?

---

## Changelog

- 2026-05-28 -- Initial creation. Author: Chip (Tester). Issue #468 grill (PR #470).
  Confidence: medium (first direct application; pattern synthesized from #441 grill precedent + history.md learnings).
  No Donald drop found in inbox at time of writing; first-author is Chip.
- 2026-05-28 -- Donald (Shell Dev) appended bash-specific checks (D-1 through D-6) based on #468 grill findings.
