---
name: "spawn-prompt-lint"
description: "Six mandatory markers that every coordinator spawn prompt must contain (hygiene tail). Use lint-spawn-prompt.{ps1,sh} to verify presence; use squad-spawn.{ps1,sh} to auto-inject."
domain: "repo-meta, coordinator-tooling"
confidence: "medium"
source: "earned (issue #414, Sprint 19 -- root-cause of #406/#407 fixup pattern: hygiene tail present in template but not injected into spawn prompts)"
---

## Context

Sprint 18 shipped `.squad/templates/spawn-prompt-hygiene.md` (PR #401) as the canonical
6-item hygiene tail. In the same sprint wave, two agents (Pluto PR #402, Donald PR #403)
breached parts of the hygiene tail because the coordinator forgot to embed the template
into their spawn prompts. Fixup PRs #406 and #407 were required.

The root cause is coordinator-side opt-in injection: the template exists but is not
mechanically enforced at spawn time. This skill codifies the 6 mandatory markers that
constitute the hygiene tail, and points to the helper + linter scripts that make
injection automatic (issue #414).

## The 6 Mandatory Markers

These strings MUST appear verbatim in every coordinator spawn prompt. They are the
canonical section headers from `.squad/templates/spawn-prompt-hygiene.md`.

| # | Marker (search string)                        | Covers |
|---|-----------------------------------------------|--------|
| 1 | `CWD-pin -- before every file write`          | Working directory guard before any file write |
| 2 | `base=develop discipline`                     | Every gh pr create must pass --base develop |
| 3 | `ASCII discipline -- after every file write`  | 0 non-ASCII bytes in every committed file |
| 4 | `history.md pre-size-check -- before every append` | Size gate check before history append |
| 5 | `Worktree-remove-FIRST cleanup -- after PR merges` | Safe merge sequence for worktree PRs |
| 6 | `Hygiene tail completion`                     | history.md append + inbox drop at end |

Ref: `.squad/templates/spawn-prompt-hygiene.md` for the full block to copy-paste.

## Recipe: Auto-Inject via squad-spawn

The preferred path. The helper assembles the final prompt by appending the template.

```
# Windows
pwsh -File scripts\squad-spawn.ps1 \
    --body <prompt-skeleton.md> \
    --name <agent> \
    --issue <N> \
    --worktree <path>

# POSIX
bash scripts/squad-spawn.sh \
    --body <prompt-skeleton.md> \
    --name <agent> \
    --issue <N> \
    --worktree <path>
```

Substitutions performed: `{name}` -> agent, `{N}` -> issue number,
`{worktree-path}` -> worktree absolute path. Output goes to stdout; pipe
into the `task` tool prompt parameter.

The scripts are idempotent: if the body already contains all 6 markers,
the template is not appended again.

## Recipe: Lint-Only Verification

Use when you have already assembled a prompt manually and want to confirm
all 6 markers are present before spawning.

```
# Windows
pwsh -File scripts\lint-spawn-prompt.ps1 --file <prompt.md>

# POSIX
bash scripts/lint-spawn-prompt.sh --file <prompt.md>
```

Exit 0 = all 6 markers present (safe to spawn).
Exit 1 = list of missing markers printed to stderr (do not spawn; fix first).

## Coordinator Mandate

Coordinators MUST do one of the following before every agent spawn:

(a) **Use squad-spawn** to assemble the prompt -- hygiene tail is auto-injected.
(b) **Run lint-spawn-prompt** on the manually assembled prompt -- all 6 markers
    confirmed before the `task` tool is invoked.

Both scripts are in `scripts/` and tested in `tests/test_squad_spawn.ps1`,
`tests/test_spawn_prompt_lint.ps1`, and their `.sh` mirrors.

## Anti-Patterns

- Handwriting the hygiene tail from memory -- field experience shows coordinators
  abbreviate or skip items under time pressure. Use the template or helper.
- Embedding only a subset of the 6 markers -- all 6 are mandatory; partial
  compliance reproduces the Sprint 18 failure mode.
- Running lint after spawning -- the linter is a pre-spawn gate, not a post-hoc audit.
  If a running agent lacks items 1-6, you cannot retroactively inject them.
- Trusting "I copy-pasted last sprint's prompt" -- template content can drift
  between sprints. Always regenerate via squad-spawn for the current template.

## Related Skills

- `.squad/templates/spawn-prompt-hygiene.md` -- the canonical 6-item block (source of truth)
- `.squad/skills/gh-pr-base-develop/SKILL.md` -- marker 2 detail
- `.copilot/skills/ascii-docs-about-non-ascii/SKILL.md` -- marker 3 detail
- `.squad/skills/history-md-pre-size-check/SKILL.md` -- marker 4 detail
- `.squad/skills/worktree-remove-first/SKILL.md` -- marker 5 detail
- `.squad/skills/pre-spawn-checklist/SKILL.md` -- broader coordinator spawn hygiene
- `.squad/routing.md` -- Mandatory Hygiene Tail section (references this SKILL)

## References

- Issue #414 -- formalization request (Sprint 19)
- PR #401 -- spawn-prompt-hygiene.md template creation (Sprint 18)
- PRs #406, #407 -- the fixup pattern this skill eliminates
- Sprint 18 retro (`.squad/retros/2026-05-18-sprint-18-retro.md`) -- root cause analysis

**Last reviewed:** 2026-05-18 (Sprint 19, issue #414)
