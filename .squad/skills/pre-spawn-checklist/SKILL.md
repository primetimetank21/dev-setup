# Skill: Pre-Spawn Checklist (Coordinator)

**Confidence:** high (every miss in this skill has produced a real incident; documented below)
**Owner:** Coordinator (self)
**Issue origin:** 2026-05-16 Hygiene Reliability Retro (todo `retro-prespawn-skill`)
**Audience:** Coordinator (and any human acting as coordinator) when writing the prompt for a `task` tool spawn

---

## What

Every time the Coordinator spawns an agent via the `task` tool, the prompt MUST include a **hygiene tail** of mandatory instructions. Without it, agents silently skip history appends, drop rogue files, mis-format commits, leave the inbox un-drained, and create branches off the wrong base. Each of these has been an incident in this repo. This checklist makes the hygiene tail a reflex, not a guess.

## Why

Recurring sprint hygiene failures forced Earl to triple-check every output and eventually hire Jiminy (Squad Hygiene Auditor) so the team self-audits. Jiminy is the safety net; the pre-spawn checklist is the front door. The combination eliminates Earl needing to be the verifier.

### Incidents this skill prevents

| Date | Incident | Root cause |
|------|----------|------------|
| 2026-05-16 | Goofy PR #215 missed `.squad/agents/goofy/history.md` update | Spawn prompt did not require history append |
| 2026-05-16 | 3 rogue verification reports landed on develop (`donald/verification-report-2026-05-04.md`, `goofy/VERIFICATION_REPORT.md`, `.squad/verification-report.md`) | Spawn prompts did not specify allowed output paths; verifiers picked their own |
| 2026-05-16 | Mickey left `issue_body.md` at repo root after `gh issue create -F` | Spawn prompt did not require cleanup of temp body file |
| Sprints 6-7 | Branch ancestry bleed (PRs #114, #116, #118) | Branches forked from another squad branch instead of develop |
| Multiple | PS 5.1 CI parse failures from em dashes in agent-written files | Spawn prompt did not state ASCII-only rule |
| Multiple | Squash-merge regressions on develop to main | Spawn prompts to Mickey did not state "regular merge commits only" |

---

## How: The Hygiene Tail

Append the following block (or its equivalent) to **every** `task` tool spawn prompt. Adjust `{name}` to the assigned agent and include only the items relevant to the work scope.

```
# Hygiene tail (mandatory)

Branch + workflow:
- Branch: `squad/<slug>` forked from develop ONLY (never from another squad/* branch)
- Commit message: Conventional Commits format (the commit-msg hook will reject otherwise)
- Trailer on every commit: `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
- Merge strategy if you merge: REGULAR merge commits only. NEVER squash.

Files you MUST update:
- `.squad/agents/{name}/history.md` -- append a `## Learnings` bullet describing what you did and why

Files you MUST clean up before final commit:
- Any temp file used for `gh issue create -F` / `gh pr create -F` (e.g., `issue_body.md`, `pr_body.md` at repo root). Delete BEFORE the `git add` step.
- Any `.bak`, `.orig`, scratch file in the working tree

Files you MUST NOT create (rogue paths -- Jiminy will flag):
- `.squad/agents/{name}/VERIFICATION_REPORT.md`
- `.squad/agents/{name}/audit-findings.md`
- `.squad/agents/{name}/<random-report>.md`
- `.squad/verification-report.md`
- `.squad/commit-msg-temp.txt`
- `.squad/logs/` (deprecated; use `.squad/log/` -- singular)
- ANY path outside the canonical write list below

Canonical .squad/ write locations (anything else is rogue):
- `agents/{name}/charter.md` | `history.md` | `history-archive.md`
- `decisions.md` | `decisions-archive.md`
- `decisions/inbox/*.md` (gitignored drop-box for Scribe to drain)
- `orchestration-log/*.md` (gitignored local operational log)
- `log/*.md` (singular -- gitignored local session log)
- `skills/{name}/SKILL.md`
- `templates/*.md`
- `casting/*.json`
- `identity/*.md`
- `plugins/*.json`
- `team.md` | `routing.md` | `ceremonies.md` | `config.json`

For verifier-style or audit work, write findings to ONE of:
- `.squad/agents/{name}/history.md` (under `## Learnings`)
- `.squad/decisions/inbox/{name}-{slug}.md` (for decisions Scribe should merge)
- `.squad/orchestration-log/{ISO8601-UTC}-{batch-name}.md` (preferred for citation-heavy reports)

For .ps1 / .yml / test_windows_setup.ps1 files (ASCII rule):
- ASCII only (U+0000 to U+007F). No em dashes, curly quotes, smart apostrophes, arrows, emoji, checkmarks.
- See `.squad/skills/ps51-ascii-safety/SKILL.md` for the CP1252 mechanics and detection scripts.

Decisions inbox usage:
- Standing team decisions go to `.squad/decisions/inbox/{name}-{slug}.md`. Scribe drains.
- Inbox is gitignored (`.gitignore:4`). Do not panic if `git status` shows it untracked.

For PRs (if your work produces one):
- Title: Conventional Commits format
- Labels: `squad:{name}` is REQUIRED so Chip's history-check CI gate validates the right history file
- Plus relevant `area:*` and `type:*` / `priority:*` labels
- Body uses `.github/pull_request_template.md` (with hygiene checklist ticked)

When done, report back:
- Files changed
- PR / issue number + URL (if any)
- Any deviations from this hygiene tail (with reason)
```

---

## How: When to use the SHORT form vs the LONG form

For routine work (Mickey reviewing PRs, Donald fixing a shell script), the LONG form above is the canonical reference. For high-velocity / one-shot spawns (Scribe drain, Ralph cleanup, Mickey file-one-issue), the Coordinator MAY use a SHORT form that names the categories without quoting verbatim:

```
# Hygiene tail (short form)

- Branch from develop, regular merge if you merge, Conventional Commits, Co-authored-by trailer.
- Append `## Learnings` entry to `.squad/agents/{name}/history.md`.
- Clean up any temp file used for `gh issue/pr create -F` before commit.
- Write to canonical .squad/ paths only -- see `.squad/skills/pre-spawn-checklist/SKILL.md` if unsure.
- ASCII only in .ps1 / .yml / tests.
```

The full skill file is the authority. The short form is a token-economy shorthand.

---

## How: Coordinator self-audit BEFORE clicking the spawn

Before invoking `task` tool, the Coordinator runs through this mental checklist:

1. **Have I named the file the agent must append to?** (`.squad/agents/{name}/history.md`)
2. **Have I named the file format for commit message?** (Conventional Commits + Co-authored-by)
3. **Have I named the branch base?** (`develop` only)
4. **Have I named the canonical output locations?** (or pointed to this skill)
5. **Is this a .ps1 / yaml / test_windows_setup.ps1 task?** (if yes, add ASCII rule explicitly)
6. **Is this an issue/PR-creation task that uses `gh ... -F body.md`?** (if yes, add cleanup step)
7. **Will the agent run autonomously without follow-up?** (if yes, require a complete report back with PR/URL/file list)

If any answer is no or "not sure", expand the prompt before spawning.

---

## How: Verification (Jiminy backstop)

Even with this checklist applied, Jiminy runs his 4-lane audit before Coordinator returns control. If Jiminy flags something the checklist should have caught, that incident becomes a NEW row in this skill's "Incidents" table. Treat each Jiminy catch as a checklist gap, not just an agent failure.

---

## Related skills

- `.squad/skills/ps51-ascii-safety/SKILL.md` -- the ASCII rule in detail
- `.squad/skills/worktree-isolation/SKILL.md` -- branch base + worktree hygiene
- `.squad/skills/sourced-lib-pattern/SKILL.md` -- shell lib sourcing convention
- `.squad/skills/path-refresh-windows/SKILL.md` -- Windows PATH after setup
- `.squad/skills/ps51-runtime-file-encoding/SKILL.md` -- when PS 5.1 reads files at runtime

---

## Changelog

- 2026-05-16 -- Initial extraction from the 2026-05-16 hygiene reliability retro. Author: Coordinator.
