# Decision: Dotfile Install Strategy (issue #11)

**By:** Pluto (Config Engineer)
**Date:** 2026-04-07
**Issue:** #11 — [Config] Dotfile templates

---

## Decisions Made

### 1. Copy templates, don't symlink (for .gitconfig and .npmrc)

**Decision:** `.gitconfig.template` and `.npmrc.template` are **copied** to
`$HOME` rather than symlinked, so users can edit them freely without touching
the repo.

**Why:** These files routinely contain machine-specific values (name, email,
tokens). If symlinked, editing `$HOME/.gitconfig` would corrupt the repo template.

**Trade-off:** Changes to the repo template won't auto-propagate to existing
installs. Acceptable — the install script's idempotency check handles
re-installs safely with backups.

---

### 2. Symlink .editorconfig (not copy)

**Decision:** `.editorconfig` is **symlinked** to `$HOME/.editorconfig`.

**Why:** Editor config is project-agnostic and not machine-specific. Symlinking
means updates to the canonical template in the repo propagate to all projects
automatically.

---

### 3. Placeholder substitution via sed, not envsubst

**Decision:** Use `sed -i` to substitute `YOUR_NAME` / `YOUR_EMAIL` placeholders
rather than `envsubst` or a templating engine.

**Why:** `envsubst` is not available on all platforms (notably macOS without
Homebrew). `sed` is universally available. The substitution is simple enough
that a regex approach is readable and safe.

---

### 4. .gitconfig backup on overwrite (not skip)

**Decision:** When `$HOME/.gitconfig` already exists and differs from the
template, **back it up** (`.bak`) and overwrite it — rather than skipping.

**Why:** In Codespaces/Dev Containers, an existing `.gitconfig` may have been
auto-generated with wrong defaults. The template is the source of truth; the
backup preserves the user's previous state for recovery.

---

### 5. No .zshrc in this issue

**Decision:** This issue creates no `.zshrc` template.

**Why:** Issue #8 (shell aliases/shortcuts) owns `.zshrc`. Mixing concerns
would create a merge conflict risk and blur ownership.
