# Work Routing

How to decide who handles what for the dev-setup project.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|---------|
| Architecture, design decisions, scope | Mickey | How should the OS detection work? What's the entry point? |
| Bash/Zsh scripts, Linux/macOS installs | Donald | `setup.sh`, tool installs, `.zshrc`, shell aliases |
| PowerShell scripts, Windows installs, OS detection | Goofy | `setup.ps1`, `detect-os.ps1`, winget/scoop installs |
| Dotfiles, tool configs, environment setup | Pluto | `.gitconfig`, `.zshrc` templates, VS Code settings, env vars |
| Tests, CI, edge cases, idempotency | Chip | Validate scripts work, CI workflows, "does it break on re-run?" |
| Code review | Mickey | All PRs reviewed by Mickey before merge |
| Testing & validation | Chip | Write tests, find edge cases, verify fixes |
| Squad hygiene, process audit | Jiminy | Untracked files, uncommitted histories, rogue paths, branch ancestry, label hygiene |
| Verification, fact-checking, claim audits | Doc | Verify research, double-check assertions, run counter-hypotheses, audit external references |
| Session logging | Scribe | Automatic -- never needs routing |
| Work queue monitoring | Ralph | Issue triage, backlog, PR status |

## Multi-Agent Scenarios

| Scenario | Who Gets Spawned |
|----------|-----------------|
| "Build the setup script" | Mickey (architecture, sync) -> Donald + Goofy (parallel, background) |
| "Set up dotfiles" | Pluto (main) + Mickey (review) |
| "Make it work on Windows" | Goofy (script) + Chip (test) |
| "Add a new tool install" | Donald or Goofy (based on OS) + Pluto (if config needed) |
| "Validate the setup" | Chip (all environments) |
| "Team, ..." | Mickey + Donald + Goofy + Pluto in parallel |
| "Verify the research" / "fact-check this" | Doc (verification) |
| "Before we ship..." | Doc + Mickey (verify + review) |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Mickey |
| `squad:mickey` | Architecture, design, review work | Mickey |
| `squad:donald` | Bash/Zsh/Linux scripting work | Donald |
| `squad:goofy` | PowerShell/Windows/cross-platform work | Goofy |
| `squad:pluto` | Dotfiles, configs, environment setup | Pluto |
| `squad:chip` | Testing, CI, validation work | Chip |
| `squad:jiminy` | Squad hygiene audit, process QA | Jiminy |
| `squad:doc` | Fact-checking, verification, audit work | Doc |

## Spawn-Prompt Hygiene

Every coordinator spawn prompt that includes a `gh pr create` step MUST
explicitly instruct the agent to pass `--base develop`. See
`.squad/skills/gh-pr-base-develop/SKILL.md` for the full rule, the verification
step (`gh pr view <N> --json baseRefName`), and the recovery recipe if the wrong
base is used.

Minimum required snippet in every spawn prompt that creates a PR:

```
**gh pr create MUST pass `--base develop` explicitly.**
After creation, verify: gh pr view <N> --json baseRefName --jq .baseRefName
Must equal "develop". If not, close the PR and recreate with --base develop.
```

See also `.squad/skills/pre-spawn-checklist/SKILL.md` for the full background
checklist.

## Mandatory Hygiene Tail

Every coordinator spawn prompt MUST include the **Mandatory Hygiene Tail** block
verbatim. The canonical template lives at:

  `.squad/templates/spawn-prompt-hygiene.md`

Copy-paste the entire block from that file into every spawn prompt. No items may
be omitted. The block covers:

1. CWD-pin verification before every file write
2. base=develop discipline (ref: `.squad/skills/gh-pr-base-develop/SKILL.md`)
3. ASCII discipline per file written (ref: `.copilot/skills/ascii-docs-about-non-ascii/SKILL.md`)
4. history.md pre-size-check before append (ref: `.squad/skills/history-md-pre-size-check/SKILL.md`)
5. Worktree-remove-FIRST cleanup after merge (ref: `.squad/skills/worktree-remove-first/SKILL.md`)
6. Hygiene tail completion (history append, inbox drop, skill formalization check)

Rationale: Sprint 17 retro identified 3 hygiene failures (history.md gate breach,
ASCII em-dash in .gitignore, PR #368 --base=main) all preventable by a mandatory
template. Issue #397.

## Rules

1. **Eager by default** -- spawn all agents who could usefully start work, including anticipatory work.
2. **Scribe always runs** after substantial work, always `mode: "background"`. Never blocks.
3. **Quick facts -> coordinator answers directly.** No agent spawn for "what tools get installed?"
4. **Cross-platform tasks** -- Donald owns bash side, Goofy owns PowerShell side. Both can run in parallel.
5. **"Team, ..." -> fan-out.** Mickey + Donald + Goofy + Pluto in parallel as `mode: "background"`.
6. **Test alongside build.** When Donald or Goofy write a script, spawn Chip to write test cases simultaneously.
7. **Mickey reviews before merge.** All work goes through Mickey for final review.
8. **Jiminy auto-runs** before coordinator returns control to user, after multi-agent batches (3+ spawns), and at session-end. Manual trigger: "Jiminy, check" / "Jiminy, audit". Reports clean state in one line, dirty state with fix-offer.
9. **Doc auto-runs** on tasks tagged `review`, `verify`, `fact-check`, `audit`, or when a user says "fact-check this", "verify this", "double-check". Reports a verification report inline; only blocks merges if explicitly escalated to a gate.
