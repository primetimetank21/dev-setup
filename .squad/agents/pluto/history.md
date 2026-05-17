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

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. CP1252 encoding trap + fix patterns.
! **LABEL HYGIENE:** `.squad/skills/label-hygiene/SKILL.md` -- audit-before-delete SOP. Always grep `.github/workflows/sync-squad-labels.yml` for the label name; if the workflow defines it, remove the definition or the label will auto-recreate on next push to `.squad/team.md`.

> Pre-Sprint-13 entries compressed 2026-05-17 (#319) and again 2026-05-17 (#347) per `.squad/skills/history-compression/SKILL.md`. Skill pointers + recurring-incident refs preserved verbatim.

## Pre-Sprint-13 work log (compressed)

- **2026-04-07 -- #10/#11/#8/#108** Dev Container + Codespace post-create, dotfile templates (`.gitconfig`, `.npmrc`, `.editorconfig`), shell alias first cut, PowerShell alias parity first cut (PR #115).
- **2026-04-08 -- #56 (worktree isolation)** `SQUAD_WORKTREES=1` env var; coordinator creates worktrees at `{repo-parent}/{repo-name}-{issue-number}`. Default-on in devcontainer.json. Full pattern in `.squad/skills/worktree-isolation/SKILL.md` + CONTRIBUTING "Parallel Agent Work". PR #58.
- **2026-04-12 -- #64** Managed-block append to `.zshrc`/`.bashrc` with sentinel markers `# --- dev-setup managed block ---`.
- **Sprint 6 / #108 f-up** PowerShell aliases completion; AllScope alias guards.
- **2026-04-XX -- #184 (gitconfig templates)** Git reads `.gitconfig` values as literal strings -- shell expansion `${EDITOR:-vim}` is NOT expanded. Rule: any tool-config template NOT processed by a shell at apply time must use literal values + override comment.
- **2026-05-16 audit** Configs/dotfiles/hooks lens; 9 findings; top 3: .ps1 CRLF in .gitattributes, `[[ ]]` POSIX compat in .aliases, PSScriptAnalyzer advisory mode in pre-push.
- **2026-05-16 -- Jiminy joins** Hygiene Auditor (process QA, not code review). See `.squad/agents/jiminy/charter.md`.
- **2026-05-18 -- #188 (PR #203)** Created CHANGELOG.md (Keep a Changelog format); backfilled 7 sprints from git log + `.squad/log/`.
- **2025-07-14 -- #192** Tmux auto-attach opt-in via `TMUX_AUTOSTART=1` guard; POSIX `[ "${VAR:-}" = "1" ]` pattern.
- **2026-05-16 -- #227** Timestamped `.bak.YYYYMMDD-HHMMSS` backups (both platforms); newest-wins restore; legacy `.bak` fallback preserved.
- **2026-05-16 -- Sprint 10 / #271** Uninstall `core.hooksPath` scope mismatch: install used `--global`, uninstall used `--local`. Fix: scope parity (both `--global`).
- **2026-05-16 -- Sprint 9 / PR #266 + #269** README + CONTRIBUTING hooksPath model; `.bak` rotation + pipefail fix in uninstall.sh (was masking pipeline failures).
- **2026-05-17 -- PR #275 (#231)** `*.ps1 text eol=crlf` in `.gitattributes` -- PS 5.1 strict-mode parser sensitive to LF in some script forms. Symmetric with `*.sh text eol=lf`.
- **2026-05-21 -- #249 (protected branch guard)** Added Check 5 to pre-commit: `git rev-parse --abbrev-ref HEAD` + case match on develop/main/master -> exit 1. Renumbered shellcheck to Check 6. 5 new test cases.
- **2026-05-21 -- #240 (pre-commit hygiene checks)** Checks ordered fastest-first; all HARD FAIL. `grep -nP '[^\x00-\x7f]'` for ASCII detection (requires GNU grep + PCRE, ships with git-bash). Do NOT set `LC_ALL=C` with `-P` on git-bash (breaks). Scans staged content via `git show ":$file"`.
- **2026-05-17 -- #233 (PSSA advisory docs)** 14-line comment block in `hooks/pre-push` above PSSA section explaining advisory-only intent (availability gap, subjective rules, scope). CONTRIBUTING "Why is PSSA advisory" subsection. Load-bearing `|| true` documented so future readers do not "fix" it away.
- **Sprint 12 W1 -- #254 (PR #315) legacy priority label cleanup (PRECEDENT for #347)** Deleted `priority: high/medium/low` (spaced legacy labels) after audit confirmed 0 open issues used them. Found `sync-squad-labels.yml` `PRIORITY_LABELS` missing `priority:p3` (label exists in repo but workflow will not re-sync if deleted). Captured pattern in `.squad/skills/label-hygiene/SKILL.md`. Same gap re-confirmed in #347.

---

## Sprint 14 W2 -- Issue #347: Label taxonomy cleanup (45 -> 32 labels)

**Branch:** `squad/347-label-cleanup`
**PR:** (pending push)
**Status:** Migration complete; all 7 phases passed.

### What I did

Slimmed the repo label taxonomy from 45 to 32 labels via Earl's mandated
triple-verification protocol. 13 deletions (8 GitHub-default duplicates,
4 stale release version labels, 1 lonely `status:in-progress`), 3 renames
(`area:linux/macos/windows` -> `platform:linux/macos/windows`).

Pre-flight gated on Wave 1 + 1.5 closure (#340, #341, #342, #343 all CLOSED).
Then per the run-book:

- **Phase 1 (pre-snapshot)** Captured `gh label list` (45 labels), per-label
  issue counts for all 16 touched labels (bug=28, documentation=9,
  enhancement=42, status:in-progress=16, area:linux=1, area:macos=1,
  area:windows=3, all 5 GH-default zero-count drops + 4 zero-count releases).
- **Phase 2 (plan)** Built `tmp-label-migration-plan.json` with PRE/AFTER +
  per-issue ops triplets. 84 unique affected issues. Validated plan: every
  remove-of-a-replace-bucket label paired with the correct add; no
  forbidden label in any `expected_after`.
- **Phase 3 (create new first)** `gh label create platform:linux/macos/windows`
  with color `0052CC`. Verified via name-filter (the `--search` flag is a
  fuzzy match -- it also matched `squad:goofy`; switched to in-script
  `Where-Object { $_ -like 'platform:*' }` to compare cleanly).
- **Phase 4 (migrate)** Per-issue PRE/OP/POST loop with hard-halt on POST
  failure. 84/84 PASS, 0 PRE-mismatch skips, 0 POST halts. All ops applied
  via a single `gh issue edit --remove-label X,Y --add-label A,B` call so
  the swap is one API round-trip per issue.
- **Phase 5 (delete with 0-count gate)** For each of the 16 deprecated
  labels, re-verified `gh issue list --label X --state all` returned 0
  before calling `gh label delete --yes`. All 16 deleted.
- **Phase 6 (workflow + docs audit)** Updated `sync-squad-labels.yml`:
  removed `release:v0.4.0`/`v0.5.0`/`v0.6.0`/`v1.0.0` from RELEASE_LABELS
  (kept `release:backlog`); removed the entire SIGNAL_LABELS block
  (`bug`, `feedback`) and the corresponding `labels.push(...SIGNAL_LABELS)`.
  Confirmed all other workflow + doc "matches" were plain-English uses, not
  label references. ASCII gate (`hooks/pre-commit` Check 2) does NOT scan
  `.yml`, so the file's pre-existing em-dashes + emoji marker on line 63
  ship as-is and are documented in the decision drop.
- **Phase 7 (post-snapshot + drop)** 32 labels post, all 16 deletes
  confirmed absent, all 3 platform:* present. Decision drop at
  `.squad/decisions/label-taxonomy-2026-05-17.md` captures counts, lists,
  protocol evidence, and out-of-scope follow-ups.

### Key learnings

- **`gh label list --search "platform:"` is a FUZZY match, not a prefix
  filter.** It matched `squad:goofy` (because of the `g` and `o` overlap?
  -- the search algorithm is undocumented but clearly not literal). Always
  validate with explicit name filtering (`Where-Object { $_ -like 'X:*' }`)
  when computing diffs against an expected set. Same lesson re-learned each
  time `gh search` is used.
- **`gh issue edit` accepts comma-separated lists in `--remove-label`/
  `--add-label` for atomic multi-op.** Single API round-trip per issue
  beats remove-then-add (which races against label-change automations).
  84 issues x 1 call = 84 calls, not 168.
- **Triple-verification protocol pays for itself.** With 84 issues x 3
  checks = 252 gh-view calls, the run took ~3 minutes. 0 PRE mismatches
  and 0 POST failures means the migration plan was correct end-to-end, but
  if any single issue had drifted (e.g., triage automation re-labelled
  mid-run), the PRE-skip + POST-halt would have caught it without
  corrupting state.
- **0-count gate before each `gh label delete` is non-negotiable.**
  Without it, deleting a label silently strips it from any issue that still
  carries it -- irreversible. Phase 5 re-verified count even though Phase 4
  had just migrated everything, because Phase 4 + Phase 5 are separated by
  Phase 6 work that could theoretically re-add a label.
- **Re-confirmed the Sprint 12 W1 (#254) out-of-scope finding:**
  `sync-squad-labels.yml` `PRIORITY_LABELS` is still missing `priority:p3`.
  Same applies now for the new `platform:*` -- the workflow defines what
  gets auto-synced from team.md, not what exists in the repo. Documented in
  the #347 decision drop under out-of-scope follow-ups; no new issue filed.
- **ASCII mandate scope is `.ps1/.md/.sh` per the pre-commit hook, not
  `.yml`.** Saved a scope-expansion trap on `sync-squad-labels.yml` which
  has pre-existing em-dashes. The mandate applies to the files the hook
  enforces; documented this in the decision drop so the next config
  engineer knows.

**PR:** (pending push -- worktree branch `squad/347-label-cleanup`).

---

## Sprint 14 W3 -- Issue #350: sync-squad-labels.yml follow-up fixes

**Branch:** `squad/350-sync-workflow-followups`
**Issue:** #350
**Status:** Complete.

### What I did

Three mechanical gaps in `sync-squad-labels.yml` surfaced by the #347
Phase 6 audit, filed as #350 and pulled into Sprint 14 W3.

- **Fix 1 (priority:p3):** Added `priority:p3` to `PRIORITY_LABELS`.
  Color chosen: `D4E5F7` (light blue, same as `release:backlog`), NOT
  `0E8A16` (green / go:yes). Rationale: backlog/icebox is a deferral
  signal, not a readiness signal; light blue groups it with
  `release:backlog` visually.

- **Fix 2 (PLATFORM_LABELS):** Added `PLATFORM_LABELS` const array for
  `platform:linux/macos/windows` (color `0052CC`, matching PR #349) and
  the corresponding `labels.push(...PLATFORM_LABELS)` call.

- **Fix 3 (hasCopilot removal -- Option A):** Removed `COPILOT_COLOR`
  const, `hasCopilot` content-includes check (which searched for a robot
  emoji marker that never existed in any real team.md), and the
  `if (hasCopilot)` conditional push. Dead code from birth; Option A per
  issue body (Earl specified no @copilot integration plans).

Side-benefit of Fix 3: U+1F916 four-byte sequence removed from YAML.
Workflow non-ASCII count dropped from 19 to 15 (5 pre-existing em-dashes
at 3 bytes each remain; those are out of scope -- hook does not scan
`.yml`).

Decision drop: `.squad/decisions/sync-workflow-followups-2026-05-17.md`