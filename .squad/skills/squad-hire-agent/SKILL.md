# Skill: squad-hire-agent

> Repeatable checklist for hiring a new named agent into the squad.
> Extracted from: Jiminy hire (2026-05-16) + Doc hire (2026-05-16). Two instances = pattern confirmed.

## When to Use

Use this skill when Earl or the Coordinator authorizes hiring a new squad agent with a persistent character name.

## Step-by-Step

### 1. Branch
```powershell
git checkout develop && git pull --ff-only
git checkout -b squad/hire-{slug}
```

### 2. Create agent directory + files
```
.squad/agents/{name-lowercase}/charter.md
.squad/agents/{name-lowercase}/history.md
```

**Charter must include:**
- Identity block (Name, Role, Universe, Style)
- Voice section (character-specific -- pull from source material)
- What I Do
- Methodology / Scope (role-specific)
- Triggers
- How I Work
- Boundaries (what the agent does NOT do; who it does NOT replace)
- Model section (preferred tier + rationale)
- Git Rules (branch from develop, never commit direct)
- Collaboration section (inbox path, cooperating agents)
- Charter version line

**History initial content:**
```markdown
# {Name} -- {Role}

> History log: hires, work completed, learnings.

## {YYYY-MM-DD} -- Hired

Hired as the squad's {Role}. {One sentence context.} First assignment pending.

## Learnings

(none yet)
```

### 3. Update .squad/casting/registry.json
- Insert after last active non-exempt agent (currently after hygiene-auditor)
- Before scribe and ralph (exempt, always last)
- Validate JSON: no trailing commas

```json
"{role-slug}": {
  "persistent_name": "{Name}",
  "universe": "Disney Classic",
  "created_at": "{ISO8601}",
  "legacy_named": false,
  "status": "active"
}
```

### 4. Update .squad/team.md
- Insert in Members table after last active non-exempt agent, before Scribe
- Match checkmark style exactly (currently: checkmark emoji Active)

```
| {Name} | {Role} | `.squad/agents/{name}/charter.md` | checkmark Active |
```

### 5. Update .squad/routing.md (four locations)
A. **Routing Table** -- add row after Jiminy row
B. **Issue Routing** -- add `squad:{name-lowercase}` label row
C. **Rules** -- add new numbered rule for auto-trigger behavior (increment from last rule)
D. **Multi-Agent Scenarios** -- add relevant scenario rows

### 6. Update CHANGELOG.md [Unreleased] > ### Added
One-liner: who joined, what they do, trigger keywords, charter path. ASCII-only.

### 7. Drop decision to inbox
Path: `.squad/decisions/inbox/mickey-hire-{slug}.md`
Note: inbox is gitignored -- do NOT stage.

### 8. Append to mickey history.md
Under Learnings: date, name, role, universe, trigger keywords, one-line summary.

### 9. Consider skill extraction
After 2+ hires confirm the pattern, draft `.squad/skills/squad-hire-agent/SKILL.md`.
(Pattern confirmed at Doc hire -- this skill is the result.)

### 10. Stage, commit, push, PR
```powershell
git add .squad/agents/{name}/ .squad/casting/registry.json .squad/team.md .squad/routing.md .squad/agents/mickey/history.md CHANGELOG.md
git diff --cached --stat
# write commit-msg.tmp and pr-body.tmp (ASCII-only)
git commit -F commit-msg.tmp
git push -u origin squad/hire-{slug}
gh pr create --base develop --head squad/hire-{slug} --title "feat(squad): hire {Name} ({Role})" --body-file pr-body.tmp
```

## Voice Personalization Tips

Pull from the character's source material. Key questions:
- What is their defining personality trait?
- How do they deliver bad news -- with snark, with kindness, with bluntness?
- What's their signature phrase or energy?
- How do they interact with the team -- leader, follower, independent?

Examples:
- Jiminy Cricket: conscience-driven, earnest, "always let your conscience be your guide"
- Doc (Seven Dwarfs): methodical, glasses-on inspector, "Let's see now...", kind corrections

## Files Touched (every hire)

| File | Change |
|------|--------|
| `.squad/agents/{name}/charter.md` | new |
| `.squad/agents/{name}/history.md` | new |
| `.squad/casting/registry.json` | new entry |
| `.squad/team.md` | new row |
| `.squad/routing.md` | routing row + issue label + rule + scenarios |
| `.squad/agents/mickey/history.md` | append learning |
| `CHANGELOG.md` | Unreleased entry |
| `.squad/decisions/inbox/mickey-hire-{slug}.md` | new (gitignored) |

## ASCII Safety

Commit body, PR body, and CHANGELOG entries: ASCII-only. No em-dashes (U+2014), no smart quotes, no fancy bullets. Use `--` not `--`. Markdown emoji in .md files is fine (hook only checks .ps1).
