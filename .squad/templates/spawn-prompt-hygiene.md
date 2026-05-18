# Mandatory Hygiene Tail -- Canonical Spawn-Prompt Template

Copy the block below verbatim into every coordinator spawn prompt.
Adjust `{name}` to the assigned agent, `{N}` to the issue number, and
`{worktree-path}` to the pre-created worktree path.

Source: `.squad/templates/spawn-prompt-hygiene.md` (issue #397)

---

## Mandatory Hygiene Tail (copy-paste into every spawn prompt)

```
### Hygiene Tail -- MANDATORY (do not omit any item)

**1. CWD-pin -- before every file write**
Run and PASS before touching any file:
  $EXPECTED = '{worktree-path}'
  Set-Location -LiteralPath $EXPECTED
  if ($pwd.Path -ne $EXPECTED) { throw "CWD drift: at $($pwd.Path), expected $EXPECTED" }

**2. base=develop discipline**
Ref: .squad/skills/gh-pr-base-develop/SKILL.md
- Every `gh pr create` MUST pass `--base develop` explicitly.
- After creation, verify:
    gh pr view <N> --json baseRefName --jq .baseRefName
  Output MUST equal "develop". If not, close and recreate with --base develop.

**3. ASCII discipline -- after every file write**
Ref: .copilot/skills/ascii-docs-about-non-ascii/SKILL.md
- 0 non-ASCII bytes (> 0x7F) in every committed file.
- Verify each file after writing:
    python -c "from pathlib import Path; print(sum(1 for b in Path('<file>').read_bytes() if b > 127))"
  Output MUST be 0.

**4. history.md pre-size-check -- before every append**
Ref: .squad/skills/history-md-pre-size-check/SKILL.md
- Before appending to .squad/agents/{name}/history.md, check:
    (Get-Item .squad/agents/{name}/history.md).Length
- If size > 14336 B (90% of 15360 B hard gate), shorten entry or compress first.

**5. Worktree-remove-FIRST cleanup -- after PR merges**
Ref: .squad/skills/worktree-remove-first/SKILL.md
From the MAIN checkout (not the worktree), run in this order:
  1. Harvest: inspect .squad/decisions/inbox/* and any unpushed history.md appends.
  2. git worktree remove ..\dev-setup-{N} --force
  3. git branch -D squad/{N}-{slug} 2>$null
  4. gh pr merge {PR} --admin --squash --delete-branch

**6. Hygiene tail completion**
When all work is done:
- Append 1-2 line entry to .squad/agents/{name}/history.md (under current sprint section).
- If a standing decision was made, drop to .squad/decisions/inbox/{name}-{timestamp}-{slug}.md.
- If a pattern was applied 2nd+ time and no SKILL exists, file a formalization issue.
```

---

## Notes for coordinators

- This block is the canonical template. Do NOT abbreviate or skip items.
- For the full background checklist see: `.squad/skills/pre-spawn-checklist/SKILL.md`
- `history-md-pre-size-check` SKILL path: `.squad/skills/history-md-pre-size-check/SKILL.md`
  (formalized in issue #398 -- will exist by merge time; the path is canonical regardless)
- Rationale: Sprint 17 retro documented 3 hygiene failures all preventable by this template.
  See `.squad/retros/2026-05-18-sprint-17-retro.md` "What surprised us" section.
