## Why

Complements Jiminy (Squad Hygiene Auditor, hired 2026-05-16). Jiminy provides judgment-call audits via the Coordinator; this hook provides deterministic, client-side enforcement at commit time. Belt-and-suspenders coverage.

Catches recurring failure modes BEFORE they hit the repo:

- PS 5.1 CP1252 issue: em dashes / smart quotes in `*.ps1` files break string literals at byte 0x94
- Rogue file paths under `.squad/` that violate the Source of Truth Hierarchy
- Branch ancestry bleed (`squad/*` branches forked from other squad branches instead of `develop`)

## Scope

Extend `hooks/pre-commit` to add 4 new checks:

### 1. ASCII-only check on staged `**/*.ps1` files

- Scan staged PowerShell files for non-ASCII bytes (> 0x7F)
- Hard fail with filename + line number if found
- Rationale: PS 5.1 misreads CP1252 bytes (e.g., 0x94 = U+2014 em dash UTF-8 tail) as string terminators, silently breaking parsing
- Implementation hint: `LC_ALL=C grep -nP '[^\x00-\x7F]' "$file"` per staged `.ps1`

### 2. Rogue path check under `.squad/`

For each staged NEW file under `.squad/`, verify path matches one of the legal locations per the Source of Truth Hierarchy:

- `.squad/agents/{name}/charter.md` | `history.md` | `history-archive.md`
- `.squad/decisions.md` | `.squad/decisions-archive.md`
- `.squad/decisions/inbox/*.md` (gitignored drop-box)
- `.squad/orchestration-log/*.md`
- `.squad/log/*.md`
- `.squad/skills/{name}/SKILL.md`
- `.squad/templates/*.md`
- `.squad/casting/*.json`
- `.squad/identity/*.md`
- `.squad/plugins/*.json`
- `.squad/team.md` | `routing.md` | `ceremonies.md` | `config.json`

If a staged path doesn't match the allowlist, **hard fail** with a message pointing to the Source of Truth Hierarchy and suggesting the correct location (orchestration-log for batch evidence, decisions/inbox for decisions, history.md for learnings).

### 3. Staged inbox file check (defensive)

- `.squad/decisions/inbox/` is gitignored, so staged files there should never happen
- If somehow staged, warn loudly — indicates gitignore was bypassed or misconfigured

### 4. Branch ancestry check (for `squad/*` branches only)

- If current branch matches `squad/*`, verify `git merge-base --is-ancestor develop HEAD` returns true
- If `develop` is NOT an ancestor, the branch was forked from somewhere else (likely another squad branch)
- Hard fail: "Branch ancestry bleed detected. `squad/*` branches must be forked from `develop`, not from other squad branches. Either rebase onto develop or recreate the branch from develop."
- This catches the recurring failure mode from Sprint 7 at commit time, not PR time

## Cross-platform considerations

- Hook MUST work in bash (Linux/macOS) AND git-bash on Windows
- ASCII check: `LC_ALL=C grep -nP '[^\x00-\x7F]'` is portable
- Path allowlist: bash glob matching or a simple case statement
- Branch ancestry: `git merge-base --is-ancestor` is portable

## Out of scope

- PSScriptAnalyzer (already in pre-push as advisory per CONTRIBUTING.md)
- Conventional Commits (commit-msg hook already owns this)
- Server-side enforcement (would need pre-receive hook on GitHub — different mechanism, separate epic)

## Acceptance

- [ ] `hooks/pre-commit` extended with 4 new checks
- [ ] Each check has a clear, actionable error message
- [ ] Tests added under `tests/` covering fail and pass cases for each check
- [ ] Cross-platform smoke test: hook runs cleanly in WSL/git-bash on Windows
- [ ] CHANGELOG entry under `[Unreleased]`
- [ ] No new dependencies (POSIX shell only, like existing hooks)

## Related

- #239 (E2E install P0) — complementary safety net at install time
- 2026-05-16 audit batch + Jiminy hire (motivation)
- `.squad/decisions.md` — spawn-hygiene-mandatory + verifier-batch-hygiene directives
