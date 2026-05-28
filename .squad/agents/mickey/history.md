# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup -- A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent -- safe to run multiple times

## Core Context

**Sprints 1-7 Summary (2026-04-07 to 2026-05-04):**

Lead architect; established foundational team process, architecture, and Windows/Linux integration across 7 sprints.

- **Sprint 1-4:** OS detection entry points (setup.sh Unix, setup.ps1 Windows); router pattern; full directory structure; 6 core tool scripts; dotfile templates; GitHub Actions workflows
- **Sprint 5:** Issue #54-#57 process items; bin cleanup; `exec 2>&1` stderr/stdout merge; devcontainer CRLF guard; CI=true Copilot CLI bypass
- **Sprint 6:** Windows regression tests (15 tests, Groups A-D); alias consolidation & parity; dual-profile PowerShell (PS 5.1 + PS 7+); alias guards for AllScope conflicts (11 aliases: rm, gc, gl, gcm, gcb, gp, grb, grs, ni, h, ep)
- **Sprint 7:** Git hooks (commit-msg Conventional Commits, pre-push branch protection + shellcheck), branch isolation rule, CI triage, PS 5.1 compatibility fixes
- **Sprint 8 (Gap Audit):** 26-item audit -> 17 issues (#178-#194); Windows setup split into per-tool files under tools/; highest-leverage refactor completed

**Key Patterns Established:**
- `CI=true` for postCreateCommand: when CLI gates on `IsCI()`, set env var rather than PTY wrapping
- Empty catch blocks: use `Write-Verbose` for intentional silence (PSScriptAnalyzer requirement)
- PSVersion-based guards (ONLY safe pattern for PS 5.1 strict mode): `$PSVersionTable.PSVersion.Major -ge 6 -and $IsVariable`
- Strip+re-inject for evolving config blocks (sentinel-based skip breaks incremental updates)
- `--admin` merge workflow for single-user repos (standard, not override)
- Process: Frame issues as problems, not implementations; consult decisions.md before planning
- Retro loop works: action items from sprint N ship in sprint N+1

**Key Files/Decisions:**
- `.squad/decisions.md` -- canonical decisions; decisions/inbox/ for agent-written docs
- CONTRIBUTING.md -- branch isolation rule, direct-push policy, PS 5.x checklist, hook workflow
- .gitattributes -- eol=lf for *.sh; devcontainer CRLF strip guard
- hooks/ -- commit-msg (Conventional Commits), pre-push (branch protection + shellcheck + optional PSScriptAnalyzer advisory)

**Tech Debt Addressed:**
- Branch ancestry bleed (fixed via rule in Sprint 7)
- Stale CI failures on main (em-dash UTF-8 bug, historical artifacts)
- Windows/Linux parity (aliases, setup.ps1 split into tools/)

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- **squad upgrade rogue-file bug (0.9.4):** `squad upgrade` dumps template files at `.squad/` root that should only live in `.squad/templates/`. Compare root files against templates -- if identical or older, delete. The pre-commit hook allow-list catches these, but clean up before committing.
- **git-workflow SKILL.md overwrite risk:** Upgrade overwrites customized skills with the built-in generic version. The 0.9.4 version assumes a 3-branch model (dev/insiders/main) and removes our project-specific rules (merge gates, branch protection, Mickey approval requirement). Always diff after upgrade.
- **New workflows from upgrade may target the squad CLI's own release pipeline** (squad-promote, squad-release, squad-insider-release, squad-preview, squad-docs) -- these assume package.json publishing and branches that don't exist in consumer repos. Delete or don't ship unless the repo actually uses that pipeline.

- `git add --renormalize` updates INDEX only, not working tree
- `script -q /dev/null -c 'command'` for isatty()-gated CLIs (general pattern, deprecated for Copilot CLI)
- Branch protection write via `gh api` blocked by Codespace token scope -- manual UI required
- PR body linkage matters (Closes #X vs #Y)
- Test framework emoji ([x]/[ ]) vs brackets -- pre-existing, flagged for housekeeping
- BOM-encoding gotcha: PS 5.1 `Set-Content -Encoding UTF8` writes UTF-8 WITH BOM. POSIX sh hooks read BOM bytes as line content, breaking regex. Fix: use `-Encoding ASCII` for test temp files (see `.squad/skills/ps51-runtime-file-encoding/SKILL.md`)
- Worktree isolation: batch 3 used separate worktrees per PR. Zero bleed across 3 parallel PRs. CHANGELOG conflicts are expected and trivial to resolve (combine both [Unreleased] entries).
- commit-msg hook rejects merge commit messages (non-conventional format). Use `--no-verify` for merge commits during conflict resolution. This is fine.
- Filed #239 e2e install P0 -- Earl emphasized this is the safety net for what really works on fresh machines. Notes: psmux is the Windows tmux with `tmux` alias; squad CLI is verified with `squad --version`, not the npx path; nightly cron approved.
- 2026-05-16 Hired Doc (Fact Checker) per Earl's request after Sprint 8-hotfix (formerly Sprint Q) retro. Universe: Disney Classic. Auto-triggers on review/verify/fact-check/audit keywords. Closes the verifier/validator gap. Hiring pattern: branch from develop, create .squad/agents/{name}/ dir with charter.md + history.md, update registry.json (after last active non-exempt agent, before scribe), update team.md (same position), update routing.md (table row + issue label + new rule + multi-agent scenarios), update CHANGELOG.md [Unreleased], drop decision to .squad/decisions/inbox/mickey-{slug}.md (gitignored, don't stage). Voice considerations: personalize from character source (Seven Dwarfs Doc = methodical, glasses-on, "Let's see now..." -- kind corrections, not snark). Consider squad-hire-agent skill after 2+ hire patterns confirmed -- pattern is now repeatable (Jiminy was first; Doc is second).
- 2026-05-26 Issue #423: For bash-to-PowerShell parity utilities, keep the bash CLI surface but use native PowerShell JSON handling and a sibling test file when that preserves existing bash coverage. Also strip carriage returns from generated bash driver fixtures so pwsh-on-Linux test runs do not inject CRLF into shim scripts.
- 2026-05-27T02:56:53.258-04:00: #444 domain-aligned PR review model delegates single-domain approvals to Donald, Goofy, Pluto, Chip, and Doc; Mickey keeps governance, architecture, conflicts, and 3+ domain PRs.
- 2026-05-28T02:38:27-04:00: PR #462 (#451) lead review verdict CHANGES REQUESTED. In-scope plan items landed (T_C, T_D, T7, validate-ps51), tests count 6 -> 9, base/head correct, CI ultimately green; merge blocked on scope drift into `.squad/**` (Chip history, identity now, new skill) outside approved test/workflow/plan slice.

---

> Re-trimmed 2026-05-27 per #450 gate. Sprints 1-17 fully archived to history-archive.md; Sprint 19+ retained here.

## Recent Work (pre-Sprint-19 summary)

**Full detail in `history-archive.md`.** Sprints 9-18 moved to archive per hygiene gate. Key learnings: CI=true gate, BOM trap with PowerShell UTF-8, worktree isolation, doc hire pattern, commit-msg merge bypass, squad-upgrade rogue-file bug, git-workflow SKILL overwrite risk, fetch-tags rejection for hermetic tests.

## 2026-05-28 -- Grill Review: Issue #451 Vertical Slice Plan (Round 1)

- **Verdict:** APPROVE-WITH-CHANGES (plan has 2 BLOCKING + 2 MAJOR issues to fix)
- **Key findings:**
  1. **BLOCKING-1 (CI integration):** Plan claims existing CI will run tests but doesn't specify validate.yml line or job. Must add step explicitly.
  2. **BLOCKING-2 (PS 5.1 coverage):** validate-ps51 job does NOT currently run test_sprint_end_labels_pwsh.ps1. Plan must clarify scope: add to validate-ps51 or document why not.
  3. **MAJOR-1 (error-message coupling):** T_C/T_D assertions couple to script error messages. Plan should document this contract in Done Criteria so future maintainers don't accidentally break tests via message rewording.
  4. **MAJOR-2 (T7 scope vagueness):** Plan says "Assert shebang valid" but doesn't specify what that means. Clarify: (a) starts with 0x23 0x21? (b) full shebang check? (c) why needed if asserting no CR?
- **Pattern:** Chip's slice itself is sound (3 test cases, good scope). The blockers are all about CI visibility and test contract clarity -- coordination issues, not technical issues. Recommend Chip revise plan in place (per .squad/skills/grill/SKILL.md Lockout protocol) and resubmit for inline re-grill.

## 2026-05-28 -- Re-Grill Review: Issue #451 Vertical Slice Plan (Round 2)

- **Verdict:** **APPROVE** -- Plan v2 is implementation-ready
- **All 4 findings RESOLVED:**
  1. **F1 (CI integration):** OK RESOLVED. Plan section "CI Integration (v2 addition)" specifies exact YAML step after validate.yml line 369 in validate-ps51 job: `powershell -ExecutionPolicy Bypass -File tests\test_sprint_end_labels_pwsh.ps1`. TODO comment at line 285 marked for removal. Both validate-ps51 and validate-powershell listed as required-green in Done Criteria.
  2. **F2 (PS 5.1 coverage):** OK RESOLVED. Explicit decision to add test to validate-ps51 with justification: test uses only PS 5.1-compatible constructs (lines 47-50). No `$IsWindows` dependency, no ternary/null-coalesce/parallel operators. Identical pattern to existing PS 5.1 test suite.
  3. **F3 (error-message coupling):** OK RESOLVED. T_C asserts exit code only (no message); T_D asserts exit code + substring match on `"release:shipped-"` (mirrors bash peer). **Contract documented** (lines 125-129): coordinated updates required across both test files and script(s). Done Criteria line 174 adds PR description requirement for contract note.
  4. **F4 (T7 shebang vagueness):** OK RESOLVED. Replaced vague "assert shebang valid" with two precise assertions: (1) no 0x0D bytes (CR regression invariant); (2) file starts with bytes 0x23 0x21 (#! header). Rationale documented; code sketch provided (lines 95-109).
- **New concerns:** None. Revision is complete and consistent. Inline doc comment requirement for T7 (lines 90-92) is good practice. Effort estimate unchanged (30 min).
- **Key learning (Grill Round 2 pattern):** Lockout-protocol revisions (grill-then-revise-then-re-grill) work well. Chip's v2 addressed all 4 blockers/majors directly with specificity. No scope creep, no workarounds, no new gaps. When a tester responds to architectural feedback with precision (line numbers, rationale, code sketches), re-grill confirms readiness quickly. Recommended pattern for future complex slices.
## 2026-05-28 -- Grill Review: Issue #451 Plan v3 Verification (Round 3)

- **Verdict:** **APPROVE** -- Plan v3 ready for implementation
- **R2 conditional notes tracking:** All 3 properly recorded in Done Criteria and narrative. (1) Launcher determinism: lines 91-92, 99-101 + deferred to code review per protocol. (2) PR description contract: line 174 Done Criteria. (3) TODO removal: lines 65-66, 172 Done Criteria.
- **Out-of-Scope boundary:** Clean. `$IsWindows` PS 5.1 hazard identified, filed #461, no scope creep. #451 scope tight: T_C, T_D, T7, validate.yml step.
- **New concerns:** None. Revision history (lines 205-229) audit trail complete; no backtracking, no new gaps, no contradictions.
- **Learning (R3 pattern):** Once grill panel issues are resolved in v2 and tracked with precision (line numbers, gates in Done Criteria), R3 verification is fast and confirms implementation readiness. Out-of-Scope sections are stronger scope-boundary tools than they appear.

## Learnings

- 2026-05-28T03:02:58-04:00: PR #462 (#451) re-grill after Goofy revision commits `8870abe` + `93b339f` verdict APPROVED (LEAD). Previous scope-drift blocker cleared: remote diff is strictly limited to `.github/workflows/validate.yml`, `docs/plans/451-pwsh-parity-gaps.md`, and `tests/test_sprint_end_labels_pwsh.ps1`; no `.squad/**`, scripts, src, or other workflow drift remains. T_C/T_D/T7 and validate-ps51 step remain present; CI green; final approval/merge remains Earl-human due reviewer lockout.
- 2026-05-28T03:35:00-04:00: #468 plan v1 (PR #470). **Shape picked: flags-first** (`--list`, `--only`, `--skip`). Rejected interactive prompt (breaks headless), manifest (indirection), full hybrid (unjustified surface area for v1). **Slice breakdown:** S1=`--list` discovery, S2=`--only` selective install, S3=`--skip` exclusion, S4=`--help` + backward-compat regression. #466/#467 land after S2. **Parity obligation:** 7 test cases (list, only, skip, conflict, unknown, no-flags, help) must pass on both bash and pwsh. **Dispatch contract:** Linux uses existing `run_tool()` with filtered list; Windows introduces `$ToolRegistry` hashtable mapping names to scriptblocks.

