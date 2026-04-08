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

## Agent Timeout Policy

Agents are spawned via the `task` tool with `mode: "background"`. There is no built-in timeout parameter — the coordinator enforces wall-clock limits by tracking elapsed time and acting when an agent exceeds its budget.

### Timeout Tiers

| Task Type | Examples | Wall-Clock Limit |
|-----------|----------|-----------------|
| **Quick** | Single-file lookup, read + report, simple Q&A | 5 min |
| **Standard** | Implement one feature, write tests, update one config area | 10 min |
| **Complex** | Multi-file refactor, cross-cutting feature, multi-agent fan-out | 20 min |

When task type is unspecified, default to **Standard (10 min)**.

### What the Coordinator Does When an Agent Times Out

1. **First timeout:** Cancel the stalled agent. Log the failure in the orchestration log (agent name, elapsed time, last known state). Retry once with a decomposed or leaner prompt — break the task into smaller pieces, reduce scope, or change the approach.
2. **Second timeout (same task):** Cancel. Do **not** retry again. Escalate to the user with: `"⚠️ {AgentName} stalled twice on #{issue} — manual intervention needed."` Log and stop.
3. **No silent retries** — every timeout must be visible in the orchestration log and reported to the user.

### Interaction with Ralph

Ralph monitors running agents. When an agent's elapsed time exceeds its tier limit, Ralph flags it to the coordinator immediately. The coordinator then cancels and applies the retry/escalate logic above. Ralph does not kill agents directly — it flags; the coordinator acts.

### Rationale

Sprint 4 incident: Chip (issue #43) ran 45+ tool calls over 6+ minutes without useful output. Ralph had to take over manually. A documented timeout policy prevents this class of runaway agent and gives the coordinator clear recovery steps.

## Stack

- **Languages:** Bash, Zsh, PowerShell
- **Targets:** Linux, macOS, Windows, Dev Containers, GitHub Codespaces
- **Tools to install:** zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user-defined shortcuts
- **Approach:** Idempotent scripts, dotfile templates, OS detection routing
