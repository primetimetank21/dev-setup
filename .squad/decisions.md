# Squad Decisions

## Active Decisions

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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
