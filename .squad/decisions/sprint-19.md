# Sprint 19 Decisions

(Archived from .squad/decisions.md at Sprint 19 Wave 1 completion -- Issues #414-#417.)
(Original content: Sprint 19 Wave 1 dispatch and design decisions, 2026-05-17 to 2026-05-18.)

---

# Sprint 19 Candidate Research -- Synthesis

**Author:** Coordinator
**Date:** 2026-05-17
**Requested by:** Earl ("have the team research these issues and verify if they are 'real' or 'valuable' enough to take on")

## Context

Post-Sprint 18 (0.9.8 shipped), Earl asked for a Sprint 19 candidate menu. Coordinator surfaced 7 options (A-G) and dispatched 5 parallel `explore` research agents (haiku) to verify each candidate against the codebase before committing scope.

## Research Dispatch

| Agent | Candidate(s) | Verdict | Effort |
|---|---|---|---|
| mickey-research-a | A: auto-inject hygiene tail | real+valuable | M |
| donald-research-bc | B: CHANGELOG fold script | real+valuable | M |
| donald-research-bc | C: inbox auto-drain workflow | real-LOW-value (HOLD) | S |
| goofy-research-dg | D: pre-commit history.md size gate | real+valuable | S |
| goofy-research-dg | G: cross-platform parity audit | real+valuable | M |
| chip-research-e | E: live-validation script inventory | NOT-real (scope exhausted) | -- |
| pluto-research-f | F: worktree pre-creation SKILL | real-LOW-value (no new SKILL needed) | trivial |

## Verdict Details

### A -- Auto-inject hygiene tail (GREENLIGHT)

Root-cause fix for S18's meta-failure: PR #401 shipped the template, but PRs #402/#403 in the same wave breached it because coordinator forgot to embed. Required fixup PRs #406/#407. Recommended hybrid: CLI helper (`scripts/squad-spawn.{ps1,sh}`) + linter (`scripts/lint-spawn-prompt.{ps1,sh}`) + optional CI gate.

### B -- CHANGELOG fold script (GREENLIGHT)

3-sprint recurring gap (0.9.5/0.9.6/0.9.7 all required manual addition of 5+ missing entries). The SKILL recipe is fully formalized at `.copilot/skills/changelog-fold-completeness/SKILL.md` and ready to codify. Pattern matches `scripts/sprint-end-labels.sh` complexity tier.

### C -- Inbox auto-drain workflow (HOLD)

Scribe already drains the inbox reliably each session (proven in S18 retro -- Scribe drained 4 files this sprint). The 16-orphan problem was pre-S17 historical (Earl's Option-2 dump in PR #412 cleaned it up), not a recurring failure. A per-merge workflow would race Scribe with no clear benefit. **Decision: drop. Revisit if a recurring drain failure surfaces.**

### D -- Pre-commit history.md size gate (GREENLIGHT)

`hooks/pre-commit` Check 2 already enforces ASCII (line 47-50, platform-aware via git-bash hex grep). The 15360 B size gate is NOT yet there -- straightforward addition. Cheapest high-leverage item. PR #412 (size breach) + PR #413 (self-correction) prove the discipline-only model fails.

### E -- Live-validation script inventory (DROP)

Chip's inventory came back clean: 12 scripts total, **0 test-only**. All are live-validated via `e2e-install.yml` on ubuntu/macos/windows runners, or are pure stateless utilities (trivial). Earl's hypothesis (latent test-only bugs) did not pan out. Scope exhausted -- no follow-up needed.

### F -- Worktree pre-creation SKILL (DOWNGRADED to F-lite)

Pattern is ALREADY documented in `.squad/skills/worktree-isolation/SKILL.md` (lines 37-44), `.squad/templates/issue-lifecycle.md` (lines 134-138), and `.squad/templates/spawn-prompt-hygiene.md` (line 5). A new SKILL would create dual sources of truth. **Decision: trivial 2-3 line clarification to `.squad/routing.md` ONLY -- no new SKILL file.**

### G -- Cross-platform parity audit (DEFER to Sprint 20)

Real gaps confirmed: 3 bash-only scripts + 7 PS1-only scripts, plus tests not running in `validate.yml`. Worth a sprint, but lower urgency than A/B/D for S19. Carry to S20 candidate pool.

## Sprint 19 Final Shape

**Filed issues:**
- #414 -- A: Auto-inject hygiene tail (squad:mickey, priority:p1, effort M)
- #415 -- B: CHANGELOG fold automation script (squad:donald, priority:p1, effort M)
- #416 -- D: Pre-commit history.md size gate (squad:goofy, priority:p1, effort S)
- #417 -- F-lite: Document worktree pre-creation in routing.md (squad:pluto, priority:p2, effort trivial)

**Total scope:** 2 M + 1 S + 1 trivial = single wave, parallel-safe via 4 pre-created worktrees (per worktree-isolation SKILL).

## Carry Forward

- **Sprint 20 candidates:** G (parity audit) as primary; revisit C and E if conditions change.
- **Research method validated:** Pre-sprint `explore` agent dispatch (haiku, parallel) is an effective tool for verifying candidate menu before committing scope. Surfaced 2 drops (C, E) and 1 downgrade (F -> F-lite) we would have spent effort on otherwise. **Recommend formalizing as a SKILL after one more application** (medium confidence after 2 uses).

## References

- Sprint 18 retro: `.squad/retros/2026-05-18-sprint-18-retro.md`
- Decisions: `.squad/decisions/sprint-18.md`
- Hygiene template: `.squad/templates/spawn-prompt-hygiene.md`
- CHANGELOG SKILL: `.copilot/skills/changelog-fold-completeness/SKILL.md`
- Pre-commit hook: `hooks/pre-commit`
- Worktree isolation: `.squad/skills/worktree-isolation/SKILL.md`

---

# Decision: changelog-fold.sh design choices (Sprint 19, Issue #415)

**Author:** Donald (Shell Developer)
**Date:** 2026-05-18
**Sprint:** 19
**Issue:** #415

## 1. Dry-run as default mode

`--dry-run` is the default; `--apply` must be passed explicitly to modify CHANGELOG.md.

**Rationale:** The fold is destructive (in-place file edit). A footgun-safe default prevents
accidental writes during probing. This mirrors the `sprint-end-labels.sh` convention.

## 2. Categorization heuristic: labels > title prefix > Changed + WARN

Priority: (1) `type:feature/bug/chore/docs` labels, (2) conventional-commit title prefix
(`feat:`, `fix:`, `chore:`, etc.), (3) fall-through to `Changed` with a stderr WARN.

**Rationale:** Labels are authoritative but not always present. Title prefixes cover the common
case. Changed-as-fallback ensures every item is categorized; the WARN surfaces gaps for follow-up.

## 3. Idempotency strategy: grep version header before any gh calls

The script checks `grep -q "\[${RELEASE_VERSION}\]" "$CHANGELOG_PATH"` at entry and exits 1
immediately if the version is already present.

**Rationale:** Avoids unnecessary gh API calls on re-runs. Exit 1 (not 0) forces the caller to
notice the no-op; CI can gate on this to catch accidental double-runs.

## 4. jq via stdin rather than --argjson for large datasets

Combined PR + issue arrays are pre-merged via `jq -s 'add | ...'` and piped to subsequent jq
calls via stdin, rather than passed as `--argjson` arguments.

**Rationale:** Discovered in live validation: Scoop jq shim hit "Argument list too long" with
104 PRs + 51 issues. Piping via stdin avoids OS argument-length limits entirely.

## 5. Test stub uses LF-only line endings

`New-TestEnv` writes stub `gh` scripts with `[System.IO.File]::WriteAllText` and
`($lines -join "`n")` to force LF-only endings.

**Rationale:** PowerShell `@"..."@` here-strings write CRLF on Windows. A bash stub with CRLF
has shebang `#!/usr/bin/env bash\r`, which fails with "bad interpreter". LF-only is mandatory
for any file that bash will execute.

---

# Decision: pre-commit history.md size gate (issue #416)

**Date:** 2026-05-18
**Author:** Goofy (Sprint 19)
**PR:** #419

## Threshold choice rationale

- Hard limit: 15360 B (15 KB) -- matches the existing agent-discipline SKILL and
  the three prior incidents (Sprints 15-17) that established this number.
- Warn threshold: 14336 B (90% of hard limit) -- leaves ~1 KB headroom so
  measurement error in the agent-discipline step does not cause surprise rejections.
  Established in SKILL.md during Sprint 18 (#398); this PR carries it forward.

## Warn vs hard limit semantics

- WARN (exit 0): file is approaching the gate but still safe to commit. Agent should
  compress before the NEXT append, not necessarily now. Output goes to stderr so it
  does not corrupt tooling that parses stdout for commit info.
- ERROR (exit 1): file already over the gate. Hard block; agent must compress before
  the commit can land. Compression recipe is linked inline in the error message.

## Cross-platform notes

- Implemented in POSIX sh (same shell as all other checks in hooks/pre-commit).
- Uses git show :"$staged_file" | wc -c | tr -d ' ' -- the tr strips leading
  whitespace emitted by BSD wc on macOS; GNU wc on Linux/Git Bash emits no space
  but the strip is harmless.
- || true after grep prevents set-e failure when no history.md is staged (same
  pattern used in Check 2 ASCII gate, proven on Windows Git Bash).
- Tested on Windows Git Bash (Git for Windows 2.x) -- T7a/T7b/T7c all PASS.

## Placement as Check 7

Inserted between Check 5 (protected branch refuse) and Check 6 (shellcheck).
Check 6 has an early exit 0 when shellcheck is absent; placing Check 7 before it
ensures the size gate always runs regardless of shellcheck availability.

---

# Decision: squad-spawn CLI shape (Issue #414, Sprint 19)

**Date:** 2026-05-18
**Author:** Mickey (Lead)
**PR:** #420 (squad/414-hygiene-helper -> develop)

## Decision

Used manual $args parsing (no param() block) for squad-spawn.ps1 and
lint-spawn-prompt.ps1 to support --double-dash CLI flags consistent with the
bash companion scripts. PowerShell's param() binder maps -single-dash by default;
double-dash flags require manual parsing in -File invocation mode.

Idempotency implemented by checking all 6 markers present in body before appending
the template. This prevents double-injection when coordinators run squad-spawn on
a prompt that was already assembled (e.g., a re-spawn after edits).

Marker detection uses exact substring match (.IndexOf) rather than regex to avoid
wildcard/escape issues with the marker strings (which contain parens and dots).

Confidence: medium -- 1 observation; pattern may need revision once CI gate
(Phase 3, out of scope here) is implemented and the full marker set is battle-tested.

---

# Decision: Per-Runner Exclusions for Orphan Tests (Issue #424)

**Date:** 2026-05-18  
**Author:** Chip  
**Issue:** #424  
**PR:** #426  

## Context

Wired 10 orphan tests from `tests/` into `.github/workflows/validate.yml`. Not all tests are suitable for all runners.

## Decisions

### macOS Exclusions

Skipped 3 .sh tests on validate-macos job:
- `test_nvm_bootstrap.sh` - refs `scripts/linux/tools/nvm.sh`, `scripts/linux/tools/squad-cli.sh`, `scripts/linux/tools/copilot-cli.sh`
- `test_shared_logging.sh` - refs `scripts/linux/lib/log.sh` (Linux-specific logging library)
- `test_precommit_hygiene.sh` - refs `hooks/pre-commit` (Linux-specific hook behavior)

### Linux Inclusions

Promoted `test_tool_versions.sh` from macOS-only to Linux (it's platform-agnostic, tests `.tool-versions` parsing via `scripts/lib/read-tool-version.sh`).

### Windows Inclusions

All 4 orphan .ps1 tests were wired and verified locally:
- `test_changelog_fold.ps1` - 5/5 passed
- `test_squad_spawn.ps1` - 5/5 passed
- `test_spawn_prompt_lint.ps1` - 5/5 passed
- `test_sprint_end_labels.ps1` - 7/7 passed

### Non-Runnable Tests

All `test_*.sh` and `test_*.ps1` files in `tests/` were confirmed as standalone entry-points (not sourced libraries). No files were excluded for being non-runnable.

## Rationale

- Linux-specific path references make macOS runs fail or produce false negatives
- Platform-agnostic tests (idempotency, spawn tooling, tool version parsing) run on all applicable runners
- Git hooks config (`git config core.hooksPath hooks`) was added before `test_precommit_hygiene.sh` on Linux (matches existing pattern for Windows git hooks tests)

## Follow-up

None required. All orphan tests are now wired or explicitly excluded with documented reason.
