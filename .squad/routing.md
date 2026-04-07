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
| Session logging | Scribe | Automatic — never needs routing |
| Work queue monitoring | Ralph | Issue triage, backlog, PR status |

## Multi-Agent Scenarios

| Scenario | Who Gets Spawned |
|----------|-----------------|
| "Build the setup script" | Mickey (architecture, sync) → Donald + Goofy (parallel, background) |
| "Set up dotfiles" | Pluto (main) + Mickey (review) |
| "Make it work on Windows" | Goofy (script) + Chip (test) |
| "Add a new tool install" | Donald or Goofy (based on OS) + Pluto (if config needed) |
| "Validate the setup" | Chip (all environments) |
| "Team, ..." | Mickey + Donald + Goofy + Pluto in parallel |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Mickey |
| `squad:mickey` | Architecture, design, review work | Mickey |
| `squad:donald` | Bash/Zsh/Linux scripting work | Donald |
| `squad:goofy` | PowerShell/Windows/cross-platform work | Goofy |
| `squad:pluto` | Dotfiles, configs, environment setup | Pluto |
| `squad:chip` | Testing, CI, validation work | Chip |

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory work.
2. **Scribe always runs** after substantial work, always `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** No agent spawn for "what tools get installed?"
4. **Cross-platform tasks** — Donald owns bash side, Goofy owns PowerShell side. Both can run in parallel.
5. **"Team, ..." → fan-out.** Mickey + Donald + Goofy + Pluto in parallel as `mode: "background"`.
6. **Test alongside build.** When Donald or Goofy write a script, spawn Chip to write test cases simultaneously.
7. **Mickey reviews before merge.** All work goes through Mickey for final review.
