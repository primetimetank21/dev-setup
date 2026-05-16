## Summary
<!-- One-paragraph description: what is the change and why is it needed? -->


## Changes
<!-- Bullet-point list of files modified, features added, or bugs fixed. -->

-


## Test plan
<!-- How was this change verified? List commands run, CI checks expected, or manual testing steps. -->


## Related
<!-- Link to related issues: "Closes #N", "Refs #N", or "N/A" if no related issues -->


## Hygiene checklist

<!-- Before submitting, verify all items below. Unchecked items may be flagged by Jiminy (hygiene auditor). -->

- [ ] Updated `.squad/agents/{name}/history.md` with a Learnings entry
- [ ] Decisions inbox drained (or noted N/A for this PR)
- [ ] Skill captured for any new pattern (or noted N/A)
- [ ] ASCII-only in all `.ps1` / `test_windows_setup.ps1` / `.yml` files (no em dashes, curly quotes, smart apostrophes — they break PS 5.1 CP1252 parsing)
- [ ] Conventional Commits format on all commits
- [ ] Co-authored-by: Copilot trailer on all commits
- [ ] Branch forked from develop (not from another `squad/*` branch — prevents ancestry bleed)
- [ ] No rogue files outside the canonical `.squad/` paths (`agents/{name}/charter.md|history.md`, `decisions.md`, `decisions/inbox/*.md`, `orchestration-log/*.md`, `log/*.md`, `skills/{name}/SKILL.md`, `templates/*.md`, `casting/*.json`, `identity/*.md`, `plugins/*.json`, `team.md|routing.md|ceremonies.md|config.json`)

<!-- Tip: Jiminy auto-runs before coordinator returns control. Catching hygiene issues before submit saves a round-trip. -->
