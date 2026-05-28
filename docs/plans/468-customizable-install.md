# Plan: #468 Vertical Slice -- Customizable Install (Pick-and-Choose Tools)

**Date:** 2026-05-28  
**Author:** Mickey (Lead)  
**Issue:** #468  
**Status:** v1 -- Awaiting grill cycle

---

## Summary

Add flag-based tool selection to `scripts/linux/setup.sh` and `scripts/windows/setup.ps1`
so users (and CI) can install a subset of tools without modifying the scripts. Default
behavior (no flags) is unchanged -- full install, identical to today.

---

## Shape Decision: Flags-First (not Hybrid)

**Chosen:** CLI flags (`--only`, `--skip`, `--list`)  
**Rejected:** Interactive prompt (breaks headless/CI), manifest-only (poor discoverability),
full hybrid (unjustified surface area for v1).

**Justification:**
1. CI-friendly -- the primary automation use case is `setup.sh --only=delta,lazygit`.
2. Minimal surface area -- 3 flags vs. prompt TUI + manifest parser + detection logic.
3. Cold-start aware -- no runtime dependency (no `fzf`, `gum`, `dialog`).
4. Manifest can be added as a future slice (slice 5 below) if demand materializes; the flag
   grammar is compatible (manifest generates the same `--only`/`--skip` semantics).
5. Prompt is explicitly OUT -- it can layer on top later as a `--interactive` flag that
   generates `--only=...` internally.

---

## Non-Negotiables

1. **Backward compatibility:** `setup.sh` (no args) === current full install. No behavioral change.
2. **Cross-platform parity:** Every flag and its semantics work identically on bash and pwsh.
3. **Existing tool pattern preserved:** Individual tool scripts remain independently runnable.

---

## Flag / Grammar Specification

### Flags

| Flag | Effect |
|------|--------|
| `--list` | Print available tool names (one per line), exit 0. No install. |
| `--only=a,b,c` | Install ONLY the listed tools (comma-separated). |
| `--skip=a,b,c` | Install all tools EXCEPT the listed ones (comma-separated). |
| `--help` | Print usage synopsis including flag grammar. |

### Syntax rules

- Comma-separated, no spaces: `--only=delta,lazygit`
- Multiple invocations NOT supported (no `--only=a --only=b`). Comma list is canonical.
- Tool names are the filename stems from `scripts/{linux,windows}/tools/`:
  - Linux: `zsh`, `uv`, `nvm`, `gh`, `auth`, `copilot-cli`, `squad-cli`
  - Windows: `git`, `uv`, `nvm`, `gh`, `vim`, `psmux`, `copilot`, `squad-cli`, `dotfiles`, `profile`, `auth`
- `--only` and `--skip` are mutually exclusive (error if both supplied).
- Unknown tool names produce a non-zero exit with a message listing valid names.

### PowerShell equivalents

```powershell
scripts\windows\setup.ps1 -List
scripts\windows\setup.ps1 -Only "delta,lazygit"
scripts\windows\setup.ps1 -Skip "copilot"
```

PowerShell uses `param()` block with `[string]$Only`, `[string]$Skip`, `[switch]$List`.
Comma-separated string is split internally -- same grammar, native parameter style.

---

## Dispatch Contract

### Linux (bash)

```
setup.sh --only=delta,lazygit
  -> parse flags
  -> build tool list: ("delta" "lazygit")
  -> for each tool in list: run_tool "$tool"
      -> bash scripts/linux/tools/${tool}.sh
```

The existing `run_tool()` function (lines 24-41 of `setup.sh`) already handles:
- File-not-found (warns, returns 0)
- Success/failure logging

No change to `run_tool()` itself. The only change is what feeds it -- a filtered list
instead of the hardcoded sequence.

### Windows (PowerShell)

Current pattern dot-sources all tool files then calls `Install-*` functions by name.
The dispatch contract introduces a **registry mapping**:

```powershell
$ToolRegistry = @{
    'git'       = { Install-Git }
    'uv'        = { Install-Uv }
    'nvm'       = { Install-Nvm }
    'gh'        = { Install-GhCli }
    'vim'       = { Install-Vim }
    'psmux'     = { Install-Psmux }
    'copilot'   = { Install-CopilotCli }
    'squad-cli' = { Install-SquadCli }
    'dotfiles'  = { Install-Dotfiles }
    'profile'   = { Write-PowerShellProfile }
    'auth'      = { Invoke-GhAuth }
}
```

Dispatch: iterate `$ToolRegistry.Keys` (or filtered subset), invoke the scriptblock.
All tool files remain dot-sourced unconditionally (loading definitions != executing them).

### Discovery for `--list`

- **Linux:** `ls scripts/linux/tools/*.sh | sed 's/\.sh$//' | sort`
- **Windows:** `$ToolRegistry.Keys | Sort-Object`

This means `--list` output is dynamic -- new tool scripts appear automatically on Linux;
Windows requires a registry entry (acceptable; the registry is the source of truth there).

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Unknown tool name in `--only` or `--skip` | Exit 1, print: `Error: unknown tool(s): foo, bar. Valid tools: ...` |
| Both `--only` and `--skip` provided | Exit 1, print: `Error: --only and --skip are mutually exclusive.` |
| `--only` with empty value | Exit 1, print: `Error: --only requires at least one tool name.` |
| Tool script missing (Linux only) | Existing behavior: `run_tool` warns and continues (exit 0). |

---

## Vertical Slices

### Slice 1: `--list` discovery

**Scope:** Add `--list` flag to both entry points. Print available tool names, exit.

**Files touched:**
- `scripts/linux/setup.sh` (arg parse, early exit)
- `scripts/windows/setup.ps1` (param block, early exit)

**Acceptance criteria:**
- `bash scripts/linux/setup.sh --list` prints tool names, one per line, exit 0
- `pwsh scripts/windows/setup.ps1 -List` prints tool names, one per line, exit 0
- No install activity occurs

**Test plan:**
- `test_setup_list_linux.sh`: assert output matches `ls tools/*.sh` stems
- `test_setup_list_pwsh.ps1`: assert output matches registry keys

---

### Slice 2: `--only` flag (selective install)

**Scope:** Parse `--only=a,b,c`, install only those tools.

**Files touched:**
- `scripts/linux/setup.sh` (arg parse -> build filtered list -> loop)
- `scripts/windows/setup.ps1` (param `-Only`, split, filter registry, invoke)
- `scripts/windows/setup.ps1` (introduce `$ToolRegistry` hashtable)

**Acceptance criteria:**
- `setup.sh --only=uv,nvm` installs only uv and nvm (verify via log output)
- `setup.ps1 -Only "uv,nvm"` installs only uv and nvm
- Unknown tool name exits with error and valid-tool list

**Test plan:**
- Mock tool scripts (create stubs that write marker files)
- Assert only expected markers exist after run
- Assert unknown tool produces exit 1 + correct message

**Dependency note:** #466 (delta) and #467 (lazygit) can land after this slice -- adding
their tool scripts to `scripts/{linux,windows}/tools/` makes them immediately selectable
via `--only=delta` or `--only=lazygit`.

---

### Slice 3: `--skip` flag (exclusion)

**Scope:** Parse `--skip=a,b,c`, install everything except those tools.

**Files touched:**
- `scripts/linux/setup.sh` (arg parse, subtract from full list)
- `scripts/windows/setup.ps1` (param `-Skip`, subtract from registry keys)

**Acceptance criteria:**
- `setup.sh --skip=copilot-cli` installs all tools except copilot-cli
- Mutual exclusion with `--only` enforced (exit 1 if both)
- Unknown tool in `--skip` exits with error

**Test plan:**
- Same mock-stub approach
- Assert excluded tools have NO markers; all others DO
- Assert conflict detection (both flags) returns exit 1

---

### Slice 4: `--help` and backward-compat verification

**Scope:** Add `--help` output, confirm no-arg behavior unchanged.

**Files touched:**
- `scripts/linux/setup.sh` (usage function, `--help` early exit)
- `scripts/windows/setup.ps1` (comment-based help or manual output)
- `README.md` (usage section update)

**Acceptance criteria:**
- `setup.sh --help` prints synopsis including `--list`, `--only`, `--skip`
- No-arg run produces identical behavior to pre-#468 (full install)
- CI regression: existing test suite passes unmodified

**Test plan:**
- Snapshot test: `setup.sh --help` output matches expected string
- Behavioral: no-arg run with stub tools produces all markers (parity with current)

---

### Slice 5 (Future -- OUT OF v1): Manifest file support

**Scope:** Read a `tools.manifest` (plain-text, one tool per line, `!` prefix = skip)
that generates the equivalent of `--only`/`--skip` semantics.

**Status:** Deferred. Will be planned separately if demand materializes after v1 ships.
Not blocking #466/#467.

---

## Cross-Platform Parity Contract

Every user-facing behavior must be tested on both platforms. Chip's test matrix:

| Test case | Linux (bash) | Windows (pwsh) |
|-----------|:---:|:---:|
| `--list` output matches tool inventory | x | x |
| `--only=a,b` installs only a, b | x | x |
| `--skip=a` installs all except a | x | x |
| `--only` + `--skip` conflict -> exit 1 | x | x |
| Unknown tool -> exit 1 + valid list | x | x |
| No flags -> full install (backward compat) | x | x |
| `--help` prints usage | x | x |

Parity tests live in `tests/` directory alongside existing test files.
Naming convention: `test_setup_flags_{linux,pwsh}.{sh,ps1}`.

---

## Out of Scope

- **Interactive prompt / TUI** -- future `--interactive` flag, not v1.
- **Manifest file** -- future slice 5, not v1.
- **PS 5.1 platform detection (#461)** -- separate issue, no overlap.
- **Rewriting tool installer scripts** -- existing pattern preserved as-is.
- **Tool dependency ordering** -- tools are independent; no DAG needed.
- **Uninstall support** -- separate concern (`uninstall.sh`/`uninstall.ps1`).

---

## Slice Ordering and Issue Dependencies

```
Slice 1 (--list)
  |-> Slice 2 (--only)   <--- #466 (delta) + #467 (lazygit) can land here
        |-> Slice 3 (--skip)
              |-> Slice 4 (--help + regression)
```

#466 and #467 need only slice 1+2 merged to land cleanly. They add:
- `scripts/linux/tools/delta.sh` / `scripts/linux/tools/lazygit.sh`
- `scripts/windows/tools/delta.ps1` / `scripts/windows/tools/lazygit.ps1`
- Registry entry in `$ToolRegistry` (Windows)
- NOT added to the default install list initially (opt-in via `--only`)

---

## Done Criteria (v1 = Slices 1-4)

- [ ] `--list`, `--only`, `--skip`, `--help` work on both platforms
- [ ] No-arg behavior unchanged (backward compat gate)
- [ ] Error messages match spec (unknown tool, mutual exclusion, empty value)
- [ ] Parity test suite passes on both `validate-linux` and `validate-powershell` CI jobs
- [ ] README updated with new usage section
- [ ] #466 and #467 can add tools without touching the flag framework

---

## Revision History

| Version | Date | Change |
|---------|------|--------|
| v1 | 2026-05-28 | Initial plan -- flags-first shape, 4 slices |
