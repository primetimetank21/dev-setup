# Squad Team

> dev-setup — Replicable setup scripts for Dev Containers and Codespaces

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Mickey | Lead | `.squad/agents/mickey/charter.md` | ✅ Active |
| Donald | Shell Dev | `.squad/agents/donald/charter.md` | ✅ Active |
| Goofy | Cross-Platform Dev | `.squad/agents/goofy/charter.md` | ✅ Active |
| Pluto | Config Engineer | `.squad/agents/pluto/charter.md` | ✅ Active |
| Chip | Tester | `.squad/agents/chip/charter.md` | ✅ Active |
| Scribe | Session Logger | `.squad/agents/scribe/charter.md` | ✅ Active |
| Ralph | Work Monitor | `.squad/agents/ralph/charter.md` | ✅ Active |

## Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup
- **Universe:** Disney Classic
- **Created:** 2026-04-07
- **Goal:** Cross-platform setup scripts for Dev Containers / Codespaces — auto-detect OS and install preferred tools, configs, and shortcuts

## Stack

- **Languages:** Bash, Zsh, PowerShell
- **Targets:** Linux, macOS, Windows, Dev Containers, GitHub Codespaces
- **Tools to install:** zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user-defined shortcuts
- **Approach:** Idempotent scripts, dotfile templates, OS detection routing
