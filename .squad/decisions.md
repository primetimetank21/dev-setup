# Squad Decisions

## Active Decisions

## [Sprint 4] Enable Branch Protection on `develop`

**Date:** 2026-04-07
**Decision:** Enable GitHub branch protection on `develop` requiring 1 approving review + passing CI before merge.
**Rationale:** Ralph bypassed the Mickey approval gate in Sprint 2 and Sprint 3. Branch protection enforces this at the GitHub level.
**Owner:** Mickey
**Note:** GitHub API returned 403 (token lacks branch protection write scope); rules must be enabled manually in repo Settings → Branches.

### 2026-04-07T03:20:54Z: User directive
**By:** Earl Tankard, Jr., Ph.D. (via Copilot)
**What:** Always commit and push at the end of every session — Scribe must `git push` after the final commit, not just `git commit`.
**Why:** User request — captured for team memory

### 2026-04-07: 14 GitHub issues created
**Scope:** primetimetank21/dev-setup
**Created by:** Mickey (Lead)
**Detail:** 
- 14 issues covering architecture, tool installs (zsh, uv, nvm, gh, copilot-cli), config (dotfiles, shortcuts, devcontainer), auth, testing, CI
- Issue breakdown: 1 architecture, 7 tool installs/auth, 3 config, 2 testing/CI
- All issues labeled with `squad` + `squad:{member}` labels
- Squad labels created: squad, squad:mickey, squad:donald, squad:goofy, squad:pluto, squad:chip
**Owner distribution:** Mickey (1), Donald (7), Goofy (1), Pluto (3), Chip (2)

### 2026-04-07: Architecture — Entry Point and File Structure
**By:** Mickey (Lead)
**Issue:** #3

**Entry Points:** Two root-level entry points — `setup.sh` (Unix: Linux, macOS, WSL) and `setup.ps1` (Windows). OS detection uses `uname -s` + `/proc/version` on Unix; `$IsWindows` builtin on PowerShell.

**File Structure:**
```
dev-setup/
├── setup.sh              # Unix entry point (router only)
├── setup.ps1             # Windows entry point (router only)
├── scripts/linux/        # Core Linux/macOS installer + per-tool scripts
├── scripts/windows/      # Core Windows installer
├── config/dotfiles/      # Dotfile templates
└── .github/workflows/    # CI
```

**Key decisions:**
- WSL is always routed as Linux — grepped via `/proc/version` for "microsoft"
- Entry points are thin routers only — no tool installation at root level
- Tool scripts run via `bash <script>` (not `source`) to keep each isolated in its own subshell
- No package-manager abstraction layer — apt/brew per tool script, winget for Windows

### 2026-04-07: Dotfile Install Strategy
**By:** Pluto (Config Engineer)
**Issue:** #11

**Key decisions:**
- `.gitconfig.template` and `.npmrc.template` are **copied** (not symlinked) — machine-specific, user-editable
- `.editorconfig` is **symlinked** — project-agnostic, propagates updates automatically
- Placeholder substitution via `sed -i` (not `envsubst`) — `envsubst` absent on macOS without Homebrew
- On existing `.gitconfig`: **back up** (`.bak`) and overwrite — Codespaces may have stale auto-generated config
- No `.zshrc` in this issue — owned by issue #8 to avoid merge conflicts

## [2026-04-07] Process Violation — Sprint 3 PRs merged without Mickey review

PRs #33, #34, #35, #36 were merged to `develop` by Ralph's sub-agents without mandatory Mickey approval.

**Root cause:** Ralph's agent loop merged PRs via `gh pr merge` without waiting for a review approval.

**Corrective action:** Ralph's task templates must require `gh pr review --approve` from Mickey before calling `gh pr merge`. Branch protection rules should be enabled on `develop` to enforce required reviews.

## [2026-04-07] Decision: `develop → main` promotion requires Mickey's explicit green light

**By:** Mickey (Lead) — Sprint 3 retro
**What:** `develop` may only be promoted to `main` after Mickey gives explicit verbal (or written) approval. No agent, no automation, and no squad member may trigger the merge without that sign-off.
**Why:** Sprint 3 demonstrated that unreviewed code reaching `develop` contained P1 bugs. Without Mickey's retroactive review and hold on promotion, both bugs would have shipped to `main`. The review gate is the last line of defense.

## [2026-04-07] Decision: Codespace initialization must set git identity before any commits

**By:** Earl Tankard, Jr., Ph.D. (via retro) — Sprint 3
**What:** Every Codespace startup must run `git config user.name` and `git config user.email` with the owner's actual identity before any commit is made. The devcontainer must inject these values from environment variables at init time.
**Why:** The `.gitconfig.template` placeholders (`YOUR_NAME`, `YOUR_EMAIL`) were never substituted in the Codespace, resulting in 35 commits attributed to placeholder values across the entire project history. Fixing it required `git filter-repo` history rewrite — an expensive, error-prone, and disruptive operation.

## [2026-04-07] Decision: `uv` is the ONLY Python package manager — `pip` is banned

**By:** Earl Tankard, Jr., Ph.D. (owner preference) — Sprint 3
**What:** All Python tool installation in this repo must use `uv` (e.g., `uv tool install <package>`). `pip` is explicitly banned. This applies to devcontainer setup, documentation, scripts, and any ad-hoc commands run during squad work.
**Why:** `uv` is the owner's documented preference, established in the architecture decisions from Sprint 1. Using `pip install git-filter-repo` in Sprint 3 was a direct violation of a standing directive.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
