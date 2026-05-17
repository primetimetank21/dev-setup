### 2026-05-17T06:01:33Z -- Donald: mark .aliases as bash/zsh-only (closes #236)

| Field | Value |
|-------|-------|
| **Agent routed** | Donald (Shell / Dotfiles) |
| **Why chosen** | Issue #236 modifies `config/dotfiles/.aliases` shell semantics -- shell/dotfile lane is Donald's per routing.md. |
| **Mode** | background |
| **Why this mode** | Independent dotfile + docs change; no hard data dependency on other Wave 1 agents. |
| **Files authorized to read** | `config/dotfiles/.aliases`, `README.md`, `CHANGELOG.md`, `.squad/agents/donald/history.md`, `.squad/decisions.md`, issue #236 |
| **File(s) agent must produce** | `config/dotfiles/.aliases` (header annotation: bash/zsh-only), `README.md` (compatibility note), `CHANGELOG.md` (Unreleased > Changed entry), `.squad/agents/donald/history.md` (Sprint 12 PR #313 entry) |
| **Worktree** | `dev-setup-236` on `squad/236-aliases-bash-zsh-only` |
| **PR** | #313 -- docs(donald): mark .aliases as bash/zsh-only (closes #236) |
| **Outcome** | Completed -- PR merged. .aliases now has explicit bash/zsh-only header; README + CHANGELOG updated. ASCII-clean. |
| **Sprint/Wave** | Sprint 12, Wave 1 |
| **Requested by** | Earl Tankard |
