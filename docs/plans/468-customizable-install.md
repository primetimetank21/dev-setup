# Plan: #468 Vertical Slice -- Customizable Install (Pick-and-Choose Tools)

**Date:** 2026-05-28  
**Author:** Goofy (Cross-Platform Dev) -- v2 revision  
**Original author:** Mickey (Lead) -- v1  
**Issue:** #468  
**Status:** v2 -- Addresses grill findings (Duck, Donald, Chip)

---

## Summary

Add flag-based tool selection to `scripts/linux/setup.sh` and `scripts/windows/setup.ps1`
so users (and CI) can install a subset of tools without modifying the scripts. Default
behavior (no flags) is unchanged -- full install, identical to today.

v2 introduces three core concepts (**AvailableTools**, **DefaultTools**, **SelectableTools**),
an explicit default-order encoding, a baseline-fixture contract, and named test scenarios
for every slice.

---

## Shape Decision: Flags-First (not Hybrid)

**Chosen:** CLI flags (`--only`, `--skip`, `--list`)  
**Rejected:** Interactive prompt (breaks headless/CI), manifest-only (poor discoverability),
full hybrid (unjustified surface area for v1).

**Justification:**
1. CI-friendly -- the primary automation use case is `setup.sh --only=delta,lazygit`.
2. Minimal surface area -- 3 flags vs. prompt TUI + manifest parser + detection logic.
3. Cold-start aware -- no runtime dependency (no `fzf`, `gum`, `dialog`).
4. Manifest can be added as a future slice if demand materializes; the flag
   grammar is compatible (manifest generates the same `--only`/`--skip` semantics).
5. Prompt is explicitly OUT -- it can layer on top later as a `--interactive` flag that
   generates `--only=...` internally.

---

## Non-Negotiables

1. **Backward compatibility:** `setup.sh` (no args) === current full install. No behavioral change.
   Enforced by baseline fixture (see Slice 0).
2. **Cross-platform parity:** Every flag and its semantics work identically on bash and pwsh.
3. **Existing tool pattern preserved:** Individual tool scripts remain independently runnable.
4. **PS 5.1 compatibility:** All `.ps1` changes must pass `validate-ps51` (line 285, `validate.yml`).

---

## Tool Classification Model

> **Addresses:** Duck finding #1 (three concepts), Donald finding #3 (opt-in gate).

### Three Concepts

| Concept | Definition | Source of Truth |
|---------|-----------|-----------------|
| **AvailableTools** | Every callable installer in `scripts/{platform}/tools/`. | Filesystem scan (`basename` without extension). |
| **DefaultTools** | The ordered list invoked on a no-flags run. Per-platform. | Hardcoded array constant in the dispatcher (see below). |
| **SelectableTools** | What `--only`/`--skip` can target. | Union of DefaultTools + any AvailableTools file that exists. Equals AvailableTools. |

### Key Invariant

**Adding a file to `tools/` makes it selectable via `--only` but does NOT add it to
the default run.** The only way to add a tool to the default run is to append it to
the `DEFAULT_TOOLS` constant. This is the opt-in gate for delta/lazygit.

### Opt-In Example: delta / lazygit (#466, #467)

After those PRs land:
- `delta.sh` / `delta.ps1` exist in `tools/` -> delta is in **AvailableTools**
- `delta` is NOT in `DEFAULT_TOOLS` -> not invoked on no-flags run
- `--only=delta` works because delta is in **SelectableTools** (= AvailableTools)
- To promote delta to default: append `"delta"` to the `DEFAULT_TOOLS` array (deliberate commit)

---

## Default Order Encoding

> **Addresses:** Donald finding #2 (order must be explicit, not filesystem-derived).

### Linux (bash) -- `scripts/linux/setup.sh`

```bash
# Canonical execution order. Append-only. Do NOT reorder without verifying dependencies.
DEFAULT_TOOLS=(
  "zsh"
  "uv"
  "nvm"
  "gh"
  "auth"
  "copilot-cli"
  "squad-cli"
)
```

### Windows (PowerShell) -- `scripts/windows/setup.ps1`

```powershell
# Canonical execution order. Append-only. Do NOT reorder without verifying dependencies.
$DefaultTools = @(
  'git'
  'uv'
  'nvm'
  'gh'
  'auth'
  'vim'
  'psmux'
  'copilot'
  'squad-cli'
  'dotfiles'
  'profile'
)
```

These arrays are the **single source of truth** for no-arg behavior. Order preserves
implicit dependency chains (nvm before copilot-cli; gh before auth).

---

## Windows Dispatch: Registry Pattern (Explicit)

> **Addresses:** Duck finding #3 ($ToolRegistry coupling resolved).

**Pick: (a) -- explicit registry with documented 3-line extension pattern.**

The `$ToolRegistry` is an `[ordered]@{}` hashtable mapping tool name -> scriptblock.
It exists solely as a name-to-function dispatch table. **Iteration order comes from
`$DefaultTools`, NOT from `$ToolRegistry.Keys`.**

```powershell
$ToolRegistry = [ordered]@{
    'git'       = { Install-Git }
    'uv'        = { Install-Uv }
    'nvm'       = { Install-Nvm }
    'gh'        = { Install-GhCli }
    'auth'      = { Invoke-GhAuth }
    'vim'       = { Install-Vim }
    'psmux'     = { Install-Psmux }
    'copilot'   = { Install-CopilotCli }
    'squad-cli' = { Install-SquadCli }
    'dotfiles'  = { Install-Dotfiles }
    'profile'   = { Write-PowerShellProfile }
}
```

### 3-Line Extension Pattern (for #466/#467)

To add a new opt-in tool (e.g., delta):

```powershell
# 1. Create scripts/windows/tools/delta.ps1 with Install-Delta function
# 2. Dot-source it in setup.ps1:
. "$PSScriptRoot\tools\delta.ps1"
# 3. Add registry entry:
$ToolRegistry['delta'] = { Install-Delta }
# (Do NOT add to $DefaultTools unless promoting to default)
```

### Why NOT auto-discovery on Windows

Windows tool files export arbitrarily named functions (Install-Git, Invoke-GhAuth,
Write-PowerShellProfile). There is no naming convention that maps filename -> function.
The registry is the explicit bridge. Auto-discovery would require a naming convention
refactor (out of scope).

---

## Internal Selection Model

> **Addresses:** finding #11 (future-proof selection abstraction).

After flag parsing, both platforms produce a **FinalToolSet**: an ordered array of tool
names to execute. The model:

```
Input:   flags (--only | --skip | none) + DEFAULT_TOOLS + AvailableTools
Output:  FinalToolSet: string[] (ordered, validated, deduplicated)

Algorithm:
  if --only:
    validate each name in AvailableTools
    FinalToolSet = only_list (preserve user-supplied order)
  elif --skip:
    validate each name in AvailableTools
    FinalToolSet = DEFAULT_TOOLS minus skip_list (preserve default order)
  else:
    FinalToolSet = DEFAULT_TOOLS
```

A future manifest or prompt UI targets this same model: produce a `FinalToolSet` array,
hand it to the dispatcher. No CLI grammar emulation needed.

---

## Flag / Grammar Specification

### Flags

| Flag | Effect |
|------|--------|
| `--list` | Print AvailableTools (one per line, alphabetical), exit 0. No install. |
| `--only=a,b,c` | Install ONLY the listed tools (comma-separated). |
| `--skip=a,b,c` | Install all DefaultTools EXCEPT the listed ones (comma-separated). |
| `--help` | Print usage synopsis including flag grammar. |

### Syntax Rules

- Comma-separated, no spaces: `--only=delta,lazygit`
- Multiple invocations NOT supported (no `--only=a --only=b`). Comma list is canonical.
- Tool names are filename stems from `scripts/{platform}/tools/` (sans extension).
- `--only` and `--skip` are mutually exclusive (error if both supplied).
- Unknown tool names produce exit 1 with a message listing valid names (= AvailableTools).

### PowerShell Grammar

> **Addresses:** finding #10 (parity grammar pick + justification).

```powershell
scripts\windows\setup.ps1 -List
scripts\windows\setup.ps1 -Only "delta,lazygit"
scripts\windows\setup.ps1 -Skip "copilot"
scripts\windows\setup.ps1 -Help
```

**Pick: quoted comma-string (`-Only "a,b"`).**

**Justification:**
- `-Only a,b` (unquoted) in PowerShell becomes a `[string[]]` array, which changes the
  `param()` type signature and complicates validation (user can pass `-Only a -Only b`).
- `--only=a,b` (double-dash) is not idiomatic PowerShell and requires manual parsing
  (breaks tab-completion, comment-based help, `Get-Help`).
- Quoted comma-string keeps the param as `[string]`, split internally with
  `$Only.Split(',')`, parity with bash `IFS=',' read -ra`.

**Param block (PS 5.1 safe):**
```powershell
param(
    [string]$Only = '',
    [string]$Skip = '',
    [switch]$List,
    [switch]$Help
)
```

No advanced features (no `[ValidateSet]`, no `[Parameter()]` with PS 7+ attributes).
Plain types only. Tested under `shell: powershell` in `validate-ps51`.

---

## Discovery for `--list`

> **Addresses:** Donald finding #1 (sed bug), Duck finding #1 (AvailableTools definition).

### Linux (bash)

```bash
list_available_tools() {
  local f
  for f in "${TOOLS_DIR}"/*.sh; do
    [[ -f "$f" ]] || continue
    basename "$f" .sh
  done | sort
}
```

**Exclusions:** Only files matching `*.sh` glob in `tools/`. Directories, README,
.gitignore, helper libs (lib/) are outside `tools/` and never matched.

### Windows (PowerShell)

```powershell
function Get-AvailableTools {
    $ToolRegistry.Keys | Sort-Object
}
```

The registry IS the source of truth on Windows. Any file in `tools/` without a registry
entry is not discoverable (intentional -- see extension pattern above).

---

## Bash Arg-Parsing Mechanism

> **Addresses:** Donald finding #5 (getopts unsafe under set -e).

```bash
# Case-based loop. No getopts (incompatible with --long-opts + set -e).
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)   FLAG_LIST=1; shift ;;
      --help)   FLAG_HELP=1; shift ;;
      --only=*) FLAG_ONLY="${1#--only=}"; shift ;;
      --skip=*) FLAG_SKIP="${1#--skip=}"; shift ;;
      *)        echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done
}

# IFS split with empty guard
split_csv() {
  local input="$1"
  [[ -z "$input" ]] && { echo "Error: flag requires at least one tool name." >&2; exit 1; }
  IFS=',' read -ra TOOLS <<< "$input" || true
}
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Unknown tool name in `--only` or `--skip` | Exit 1: `Error: unknown tool(s): foo, bar. Valid: <AvailableTools>` |
| Both `--only` and `--skip` provided | Exit 1: `Error: --only and --skip are mutually exclusive.` |
| `--only` with empty value (`--only=`) | Exit 1: `Error: --only requires at least one tool name.` |
| `--skip` with empty value (`--skip=`) | Exit 1: `Error: --skip requires at least one tool name.` |
| `--list` combined with `--only`/`--skip` | `--list` wins, prints list, exit 0 (no install). |
| Tool script missing (Linux only) | Existing behavior: `run_tool` warns and continues (exit 0). |

### Graceful Degradation (not independence)

> **Addresses:** Donald finding #4 (silent degradation acknowledgment).

Tools are NOT fully independent. Known degradation chains:
- `copilot-cli` / `squad-cli` silently skip if npm absent (nvm not run first)
- `auth` silently skips if `gh` not installed

`--only=copilot-cli` on a fresh machine without nvm = exit 0, tool not functional.
This is documented behavior, not a bug. A future DAG (out of scope) could warn.

---

## Vertical Slices

### Slice 0: Capture Baseline Fixtures

> **Addresses:** Duck finding #2 (baseline contract), Chip finding B-4.

**Scope:** Before ANY flag code lands, capture the current tool invocation order as
committed fixture files. These become the regression contract.

**Runnable command (bash):**
```bash
# From repo root:
echo "zsh
uv
nvm
gh
auth
copilot-cli
squad-cli" > tests/fixtures/baseline-tools-linux.txt
```

**Runnable command (pwsh):**
```powershell
# From repo root:
@('git','uv','nvm','gh','auth','vim','psmux','copilot','squad-cli','dotfiles','profile') |
    Set-Content tests/fixtures/baseline-tools-windows.txt -Encoding ascii
```

**Files created:**
- `tests/fixtures/baseline-tools-linux.txt`
- `tests/fixtures/baseline-tools-windows.txt`

**Done Criteria:**
- [ ] Fixtures committed to `develop` before Slice 1 merges
- [ ] Each fixture exactly matches the current `run_tool` / `Install-*` call sequence
- [ ] `validate-ps51` step passes (no .ps1 changes in this slice, but confirm no regression)

---

### Slice 1: `--list`, `--help`, and Baseline Diff

> **Addresses:** Chip finding B-5 (--help in Slice 1), finding #9 (baseline test early).

**Scope:** Add `--list` and `--help` flags. Add baseline-diff test. No `--only`/`--skip` yet.

**Files touched:**
- `scripts/linux/setup.sh` (arg parse, `DEFAULT_TOOLS` array, `list_available_tools()`, help text)
- `scripts/windows/setup.ps1` (`param()` block, `$DefaultTools`, `$ToolRegistry`, `Get-AvailableTools`, help)
- `tests/test_setup_flags.sh` (new)
- `tests/test_setup_flags_pwsh.ps1` (new)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh
Test-Scenario "T_list_output: --list prints all AvailableTools alphabetically, exit 0"
Test-Scenario "T_list_no_install: --list produces no install side-effects"
Test-Scenario "T_help_output: --help prints usage containing --list, --only, --skip"
Test-Scenario "T_help_exit: --help exits 0 with no install"
Test-Scenario "T_baseline_noarg: no-arg run produces tool list matching baseline-tools-linux.txt"
Test-Scenario "T_unknown_arg: unknown --foo exits 1"

# tests/test_setup_flags_pwsh.ps1
Test-Scenario "T_list_output: -List prints all AvailableTools alphabetically, exit 0"
Test-Scenario "T_list_no_install: -List produces no install side-effects"
Test-Scenario "T_help_output: -Help prints usage containing -List, -Only, -Skip"
Test-Scenario "T_help_exit: -Help exits 0 with no install"
Test-Scenario "T_baseline_noarg: no-arg run produces tool list matching baseline-tools-windows.txt"
Test-Scenario "T_param_ps51: param() block parses without error under PS 5.1"
```

**Done Criteria:**
- [ ] `--list` / `-List` prints AvailableTools (alpha sorted), exit 0
- [ ] `--help` / `-Help` prints usage, exit 0
- [ ] No-arg run invokes exactly the tools in baseline fixture (order + set)
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`
- [ ] `validate-ps51` runs `powershell -File tests\test_setup_flags_pwsh.ps1`
- [ ] e2e-install.yml: `--list` added as smoke step in linux, macos, windows jobs

---

### Slice 2: `--only` Flag (Selective Install)

**Scope:** Parse `--only=a,b,c`, install only those tools.

**Files touched:**
- `scripts/linux/setup.sh` (flag parse, `split_csv`, selection logic)
- `scripts/windows/setup.ps1` (`-Only` param handling, split, filter, dispatch)
- `tests/test_setup_flags.sh` (new scenarios appended)
- `tests/test_setup_flags_pwsh.ps1` (new scenarios appended)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh (added in Slice 2)
Test-Scenario "T_only_single: --only=uv installs only uv and nothing else"
Test-Scenario "T_only_multi: --only=uv,nvm installs uv and nvm only, in user-specified order"
Test-Scenario "T_only_unknown: --only=bogus exits 1 with valid-tool list"
Test-Scenario "T_only_empty: --only= (empty) exits 1"
Test-Scenario "T_only_optin: --only=delta works if delta.sh exists but is not in DefaultTools"
Test-Scenario "T_only_idempotent: --only=uv run twice -> exit 0 both, no duplicate markers"

# tests/test_setup_flags_pwsh.ps1 (added in Slice 2)
Test-Scenario "T_only_single: -Only 'uv' installs only uv"
Test-Scenario "T_only_multi: -Only 'uv,nvm' installs uv and nvm only"
Test-Scenario "T_only_unknown: -Only 'bogus' exits 1 with valid-tool list"
Test-Scenario "T_only_empty: -Only '' exits 1"
Test-Scenario "T_only_optin: -Only 'delta' works if delta.ps1 + registry entry exist"
Test-Scenario "T_only_idempotent: -Only 'uv' run twice -> exit 0, no duplicate markers"
Test-Scenario "T_only_ps51: -Only parsing works under PS 5.1 (shell: powershell)"
```

**Done Criteria:**
- [ ] `--only` / `-Only` installs exactly the named tools, nothing else
- [ ] Unknown tool -> exit 1 + AvailableTools list
- [ ] Empty value -> exit 1
- [ ] Idempotency: run twice -> exit 0, no duplicates
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

### Slice 3: `--skip` Flag (Exclusion) + Conflict Detection

**Scope:** Parse `--skip=a,b,c`, install DefaultTools minus those. Enforce mutual exclusion.

**Files touched:**
- `scripts/linux/setup.sh` (skip logic, conflict check)
- `scripts/windows/setup.ps1` (`-Skip` param, subtract, conflict check)
- `tests/test_setup_flags.sh` (new scenarios appended)
- `tests/test_setup_flags_pwsh.ps1` (new scenarios appended)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh (added in Slice 3)
Test-Scenario "T_skip_single: --skip=auth installs all DefaultTools except auth"
Test-Scenario "T_skip_multi: --skip=auth,copilot-cli installs all except auth and copilot-cli"
Test-Scenario "T_skip_unknown: --skip=bogus exits 1 with valid-tool list"
Test-Scenario "T_skip_empty: --skip= (empty) exits 1"
Test-Scenario "T_skip_conflict: --only=uv --skip=nvm exits 1 with mutual-exclusion message"
Test-Scenario "T_skip_idempotent: --skip=auth run twice -> exit 0 both"
Test-Scenario "T_list_plus_only: --list --only=uv prints list only (--list wins)"

# tests/test_setup_flags_pwsh.ps1 (added in Slice 3)
Test-Scenario "T_skip_single: -Skip 'auth' installs all DefaultTools except auth"
Test-Scenario "T_skip_multi: -Skip 'auth,copilot' installs all except auth and copilot"
Test-Scenario "T_skip_unknown: -Skip 'bogus' exits 1 with valid-tool list"
Test-Scenario "T_skip_empty: -Skip '' exits 1"
Test-Scenario "T_skip_conflict: -Only 'uv' -Skip 'nvm' exits 1 with mutual-exclusion message"
Test-Scenario "T_skip_idempotent: -Skip 'auth' run twice -> exit 0"
Test-Scenario "T_skip_ps51: -Skip parsing works under PS 5.1"
```

**Done Criteria:**
- [ ] `--skip` / `-Skip` excludes named tools from DefaultTools
- [ ] Mutual exclusion enforced (exit 1 if both `--only` and `--skip`)
- [ ] Unknown tool -> exit 1
- [ ] Empty value -> exit 1
- [ ] `--list` + other flags -> list wins
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

### Slice 4: README Polish + e2e Hardening

**Scope:** Update README usage section. Expand e2e coverage.

**Files touched:**
- `README.md` (new "Selective Install" usage section)
- `.github/workflows/e2e-install.yml` (add `--only` smoke in all 3 platform jobs)

**Named Test Scenarios:**

```
# e2e (in workflow, not test file)
E2E_list_smoke: setup.sh --list exits 0 (linux + macos)
E2E_list_smoke_win: setup.ps1 -List exits 0 (windows)
E2E_only_smoke: setup.sh --only=gh exits 0 (linux)
E2E_only_smoke_win: setup.ps1 -Only "gh" exits 0 (windows)
```

**Done Criteria:**
- [ ] README documents `--list`, `--only`, `--skip`, `--help` with examples
- [ ] e2e-install.yml exercises `--list` + `--only` on all platforms
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

## PowerShell Grammar Parity Tests

> **Addresses:** finding #10 (parity test cases for pwsh grammar edge cases).

These scenarios are embedded in the Slice 2/3 test files above. Explicit edge cases:

| Input | Expected | Slice |
|-------|----------|-------|
| `-Only "uv,nvm"` (quoted, comma) | Installs uv + nvm | 2 |
| `-Only "uv"` (quoted, single) | Installs uv only | 2 |
| `-Only ""` (quoted empty) | Exit 1, error message | 2 |
| `-Only "bogus"` (unknown) | Exit 1, valid-tool list | 2 |
| `-Skip "auth"` (quoted) | All minus auth | 3 |
| `-Only "uv" -Skip "nvm"` (conflict) | Exit 1, mutual-exclusion | 3 |

---

## Cross-Platform Parity Contract

Test files: `tests/test_setup_flags.sh` + `tests/test_setup_flags_pwsh.ps1`

| Test case | Bash | PS 7+ | PS 5.1 | Slice |
|-----------|:---:|:---:|:---:|:---:|
| `--list` prints AvailableTools alphabetically | x | x | x | 1 |
| `--help` prints usage | x | x | x | 1 |
| No-arg = baseline fixture | x | x | x | 1 |
| `--only=a,b` installs only a, b | x | x | x | 2 |
| Unknown tool in `--only` -> exit 1 | x | x | x | 2 |
| Empty `--only` -> exit 1 | x | x | x | 2 |
| `--skip=a` excludes a | x | x | x | 3 |
| `--only` + `--skip` conflict -> exit 1 | x | x | x | 3 |
| Unknown tool in `--skip` -> exit 1 | x | x | x | 3 |
| Empty `--skip` -> exit 1 | x | x | x | 3 |

---

## CI Matrix Requirements

All slices require green on:
- `validate-linux` (bash tests via `bash tests/test_setup_flags.sh`)
- `validate-powershell` (PS 7+ via `pwsh tests/test_setup_flags_pwsh.ps1`)
- **`validate-ps51`** (PS 5.1 via `powershell -File tests\test_setup_flags_pwsh.ps1`)
  - Reference: `.github/workflows/validate.yml` line 285+
  - Gates: `param()` block syntax, `$ToolRegistry` hashtable, `Split()` calls, all flag logic

---

## Out of Scope

- **Interactive prompt / TUI** -- future `--interactive` flag, not v1.
- **Manifest file** -- future slice, not v1.
- **PS 5.1 platform detection (#461)** -- separate issue, closed.
- **Rewriting tool installer scripts** -- existing pattern preserved as-is.
- **Tool dependency DAG** -- graceful degradation documented above; enforcement deferred.
- **Uninstall support** -- separate concern.
- **Auto-discovery on Windows** -- registry pattern chosen over convention-based discovery.
- **`--only a b` (space-separated)** -- comma-string is canonical (see grammar justification).

---

## Slice Ordering and Issue Dependencies

```
Slice 0 (baseline fixture) -- prerequisite, no code changes
  |-> Slice 1 (--list + --help + baseline test)
        |-> Slice 2 (--only)   <--- #466 (delta) + #467 (lazygit) can land here
              |-> Slice 3 (--skip + conflict detection)
                    |-> Slice 4 (README + e2e hardening)
```

#466 and #467 need Slice 2 merged to land cleanly. They add:
- `scripts/linux/tools/delta.sh` / `scripts/linux/tools/lazygit.sh`
- `scripts/windows/tools/delta.ps1` / `scripts/windows/tools/lazygit.ps1`
- Dot-source + `$ToolRegistry['delta'] = { Install-Delta }` (3-line pattern)
- **NOT** added to `$DefaultTools` / `DEFAULT_TOOLS` (opt-in only)

---

## Done Criteria (v1 = Slices 0-4)

- [ ] Baseline fixtures committed and matching current behavior
- [ ] `--list`, `--only`, `--skip`, `--help` work on both platforms
- [ ] No-arg behavior unchanged (baseline-diff test green)
- [ ] Error messages match spec (unknown tool, mutual exclusion, empty value)
- [ ] All named Test-Scenario cases pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`
- [ ] `validate-ps51` runs flag test file under `shell: powershell` (PS 5.1)
- [ ] README updated with new usage section
- [ ] e2e-install.yml exercises `--list` + `--only` on all 3 platforms
- [ ] #466 and #467 can add tools via 3-line extension pattern without touching flag logic

---

## Revision History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| v1 | 2026-05-28 | Mickey | Initial plan -- flags-first shape, 4 slices |
| v2 | 2026-05-28 | Goofy | Address all grill findings (Duck/Donald/Chip). See below. |

### v2 Changes (Grill Findings Addressed)

**Duck findings:**
1. Three-concept model (AvailableTools/DefaultTools/SelectableTools) with invariant: adding file != adding to default. -> "Tool Classification Model" section.
2. Baseline contract: fixture files + baseline-diff test in Slice 0/1 replace assertion-only backward-compat. -> Slice 0 + T_baseline_noarg test.
3. $ToolRegistry coupling resolved: explicit registry with documented 3-line extension pattern. Iteration uses $DefaultTools order, not .Keys. -> "Windows Dispatch" section.

**Donald findings:**
4. `--list` sed bug fixed: `basename "$f" .sh` in a for-loop, exclusions documented. -> "Discovery for --list" section.
5. Default order encoded as hardcoded array constant (DEFAULT_TOOLS / $DefaultTools). Not filesystem-derived. -> "Default Order Encoding" section.
6. Opt-in mechanism: present in AvailableTools, absent from DefaultTools. Gate is the array constant. -> "Tool Classification Model" section.

**Chip findings:**
7. PS 5.1 added to every slice's Done Criteria. `validate-ps51` line 285 referenced. -> Each slice + "CI Matrix Requirements" section.
8. Every slice has named `Test-Scenario` cases matching repo convention. -> Slice 1-4 test scenario blocks.
9. `--help` and baseline-diff moved to Slice 1 (not Slice 4). Slice 4 keeps README. -> Slice restructure.

**Additional (grill synthesis):**
10. PowerShell grammar: `-Only "a,b"` (quoted comma-string) picked and justified. Parity edge-case table added. -> "PowerShell Grammar" section.
11. Internal selection model (FinalToolSet) specified for future manifest/prompt targeting. -> "Internal Selection Model" section.
12. Out-of-scope expanded with items surfaced by v2 analysis. -> "Out of Scope" section.
