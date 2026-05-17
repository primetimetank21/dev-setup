---
name: "squad-upgrade-hygiene"
description: "Post-upgrade audit checklist for squad CLI upgrades. Catches rogue files, overwritten skills, and irrelevant workflows."
domain: "squad-cli, maintenance"
confidence: "high"
license: MIT
---

# Squad Upgrade Hygiene

After running `squad upgrade`, always audit before committing.

---

## 1. Rogue Files at `.squad/` Root

**Problem:** The upgrade may dump template files directly into `.squad/` root instead of `.squad/templates/`. These are duplicates or older versions of canonical files.

**Detection:**
```bash
git status --short .squad/ | grep "^??" | grep -v "templates/"
```

**Validation:** Compare each rogue file against:
1. `.squad/templates/{same-name}` -- if identical, delete the root copy
2. The canonical subdirectory location (e.g., `.squad/casting/policy.json` vs `.squad/casting-policy.json`) -- if the canonical is newer/richer, delete the root copy

**Fix:** Delete all rogue files before committing. The pre-commit hook's allow-list will reject them anyway.

---

## 2. Overwritten Customized Skills

**Problem:** `squad upgrade` overwrites `.copilot/skills/` with built-in versions, even if customized. It warns but proceeds.

**Detection:**
```bash
git diff --stat -- .copilot/skills/
```

**Validation:** Check if lost content was project-specific (branch names, approval rules, repo-specific commands). If yes, revert.

**Fix:** `git checkout HEAD -- .copilot/skills/{name}/SKILL.md` to restore, then reconcile manually if the new version adds useful content.

---

## 3. Irrelevant New Workflows

**Problem:** Upgrade may add workflows designed for the squad CLI's own release pipeline (npm publish, preview/insiders branches) that don't apply to consumer repos.

**Red flags:**
- Targets branches that don't exist (`preview`, `insider`, `insiders`)
- Contains `npm publish` or package.json version reads
- Has "Project type was not detected" placeholder comments
- Duplicates existing CI (e.g., `squad-ci.yml` vs your own `validate.yml`)

**Fix:** Delete irrelevant workflows. Keep only those that add value to your repo's actual workflow.

---

## 4. Workflow Diffs -- Are They Pure Upstream?

For modified workflows, check `git diff` for:
- Removed project-specific customizations (secrets, custom labels, branch names)
- Added generic logic that conflicts with your setup

If diffs are pure upstream improvements (bugfixes, new features), ship. If they remove customizations, investigate.

---

## Checklist

- [ ] Delete rogue `.squad/` root files
- [ ] Verify `.copilot/skills/` overwrites -- revert if customized
- [ ] Audit new workflows -- delete those targeting non-existent branches
- [ ] Diff modified workflows -- confirm no lost customizations
- [ ] Check `squad.agent.md` for new spawn requirements
- [ ] Run pre-commit hook to validate
- [ ] Commit in logical groups (governance, workflows, skills separately)
