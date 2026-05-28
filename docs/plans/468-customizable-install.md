# Plan: #468 Vertical Slice -- Customizable Install (Pick-and-Choose Tools)

**Date:** 2026-05-29  
**Author:** Chip (Test/QA) -- v3 revision  
**Previous authors:** Mickey (Lead) -- v1, Goofy (Cross-Platform Dev) -- v2  
**Issue:** #468  
**Status:** v3 -- Addresses v2 re-grill findings (Duck, Chip, Donald)

---

## Summary

Add flag-based tool selection to `scripts/linux/setup.sh` and `scripts/windows/setup.ps1`
so users (and CI) can install a subset of tools without modifying the scripts. Default
behavior (no flags) is unchanged -- full install, identical to today.

v3 introduces four core concepts (**AlwaysRun**, **AvailableTools**, **DefaultTools**,
**SelectableTools**), root entrypoint arg forwarding, a mock/stub test harness with
explicit dispatch seam, regenerable baseline fixtures, and blank-CSV-token validation.

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
5. **Root entrypoint transparency:** `./setup.sh <flags>` and `.\setup.ps1 <flags>` must behave
   identically to calling the platform script directly with the same flags.

---

## Root Entrypoint Arg Forwarding

> **Addresses:** Duck v2 re-grill finding #1 (root entrypoints do not forward args).

### The Gap (verified empirically)

- `./setup.sh` line 106: `exec bash "$linux_script"` -- does NOT forward `"$@"`.
- `./setup.ps1` line 103: `& $windowsScript` -- does NOT forward `$args` or explicit params.

Users/CI calling `./setup.sh --only=gh` would silently ignore the flag.

### The Fix

**`./setup.sh`** (root):
```bash
# In run_linux_setup():
exec bash "$linux_script" "$@"
```
The `main "$@"` at line 109 already passes args to `main()`; `run_linux_setup` must
relay them. Change `run_linux_setup()` signature to accept `"$@"` and pass through.

**`./setup.ps1`** (root):
```powershell
# In Invoke-WindowsSetup:
param(
    [string]$Only = '',
    [string]$Skip = '',
    [switch]$List,
    [switch]$Help
)
# ...
& $windowsScript @PSBoundParameters
```
Use `$PSBoundParameters` splatting (PS 5.1 safe) to forward all declared params.
The root script declares the same `param()` block as the inner script.

### Files Touched (Slice 1)

- `setup.sh` (root) -- forward `"$@"` through `run_linux_setup`
- `setup.ps1` (root) -- add `param()` block + splat to inner script

### e2e Tests for Root Forwarding (Slice 1)

```
Test-Scenario "T_root_list_linux: ./setup.sh --list exits 0 with same output as scripts/linux/setup.sh --list"
Test-Scenario "T_root_list_win: .\setup.ps1 -List exits 0 with same output as scripts\windows\setup.ps1 -List"
Test-Scenario "T_root_help_linux: ./setup.sh --help exits 0"
Test-Scenario "T_root_help_win: .\setup.ps1 -Help exits 0"
```

---

## Tool Classification Model

> **Addresses:** Duck v1 finding (three concepts), Donald finding #3 (opt-in gate),
> Duck v2 re-grill finding #2 (AlwaysRun classification).

### Four Concepts

| Concept | Definition | Source of Truth |
|---------|-----------|-----------------|
| **AlwaysRun** | Non-tool phases that execute regardless of `--only`/`--skip`. Infrastructure that tools depend on. | Hardcoded in dispatcher, outside the FinalToolSet loop. |
| **AvailableTools** | Every registered callable installer. | Linux: filesystem scan of `tools/*.sh` (basename sans extension). Windows: `$ToolRegistry.Keys` (registered callable installers backed by dot-sourced files). |
| **DefaultTools** | The ordered list of tools invoked on a no-flags run. Per-platform. | Hardcoded array constant in the dispatcher. |
| **SelectableTools** | What `--only`/`--skip` can target. | Equals AvailableTools. |

### AlwaysRun Phase Audit

> Empirically verified against current `scripts/linux/setup.sh` (lines 55-101) and
> `scripts/windows/setup.ps1` (lines 19-46, 48-77).

| Phase | Linux | Windows | Rationale |
|-------|:-----:|:-------:|-----------|
| Prerequisites (apt/brew) | Y AlwaysRun | -- (winget handles per-tool) | System packages needed by all tools |
| Winget availability check | -- | Y AlwaysRun | Hard gate; exit 1 if absent |
| Dotfiles | Y AlwaysRun | **Reclassified -> AlwaysRun** | See reconciliation below |
| Git-hook config | Y AlwaysRun | Y AlwaysRun | Repo integrity; not a "tool" |
| Profile (PS) | -- | DefaultTools (selectable) | PS-specific; users may skip |

### Cross-Platform Reconciliation: Dotfiles

**Current state:**
- Linux: dotfiles applied unconditionally after all tools (line 92-96, outside `run_tool` loop)
- Windows: `Install-Dotfiles` is in `$DefaultTools` (selectable, skippable)

**v3 decision: Make dotfiles AlwaysRun on BOTH platforms.**

**Rationale:** Dotfiles configure the shell environment that tools depend on (aliases,
PATH fragments, prompt). Skipping dotfiles via `--skip=dotfiles` creates an inconsistent
machine state where tools are installed but their shell integration is missing. Dotfiles
are infrastructure, not a tool.

**Implementation:** Remove `'dotfiles'` from Windows `$DefaultTools` array; call
`Install-Dotfiles` unconditionally after the FinalToolSet dispatch loop (matching Linux
behavior). `--only=delta` still applies dotfiles. `--list` does NOT show dotfiles
(it is not a selectable tool).

### Behavior Under `--only` / `--skip`

| Flag used | AlwaysRun phases | FinalToolSet (tools) |
|-----------|:----------------:|:--------------------:|
| (none) | All run | All DefaultTools |
| `--only=delta` | All run | Only delta |
| `--skip=auth` | All run | DefaultTools minus auth |
| `--list` | None (info-only) | None (no install) |

**Explicit answer:** `--only=delta` DOES run prerequisites, dotfiles, and git-hook config.
It does NOT run other tools. This is safe and expected -- AlwaysRun is infrastructure.

### Key Invariant

**Adding a file to `tools/` (Linux) or a registry entry (Windows) makes it selectable
via `--only` but does NOT add it to the default run.** The only way to add a tool to
the default run is to append it to the `DEFAULT_TOOLS` / `$DefaultTools` constant.
This is the opt-in gate for delta/lazygit.

### Opt-In Example: delta / lazygit (#466, #467)

After those PRs land:
- `delta.sh` / `delta.ps1` exist in `tools/` + registry entry -> delta is in **AvailableTools**
- `delta` is NOT in `DEFAULT_TOOLS` -> not invoked on no-flags run
- `--only=delta` works because delta is in **SelectableTools** (= AvailableTools)
- AlwaysRun phases still execute (prerequisites, dotfiles, hooks)
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
# NOTE: 'dotfiles' removed from v2 -- reclassified as AlwaysRun (see Tool Classification Model).
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
  'profile'
)
```

These arrays are the **single source of truth** for no-arg tool behavior. Order preserves
implicit dependency chains (nvm before copilot-cli; gh before auth).

---

## Windows Dispatch: Registry Pattern (Explicit)

> **Addresses:** Duck v1 finding #3 ($ToolRegistry coupling), Duck v2 re-grill finding #3
> (single source-of-truth consistency).

**Pick: (a) -- explicit registry with documented 3-line extension pattern.**

### AvailableTools Definition (Unified)

| Platform | AvailableTools = | Mechanism |
|----------|-----------------|-----------|
| Linux | Callable installer files in `tools/` dir | `basename *.sh` in `$TOOLS_DIR` |
| Windows | Registered callable installers | `$ToolRegistry.Keys` (each backed by a dot-sourced file) |

**Invariant (both platforms):** AvailableTools = the set of names the dispatcher can
resolve to a runnable action. On Linux, file existence IS the registration. On Windows,
the registry entry IS the registration (because filenames don't map 1:1 to function names).

**"Adding a file makes it selectable" -- clarification:** On Linux, literally true (file =
registration). On Windows, adding a file alone is NOT sufficient; the 3-line pattern
(dot-source + registry entry) is required. The invariant is: **"completing the platform's
registration makes a tool selectable."**

### The Registry

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

Note: `'dotfiles'` remains in the registry (it is callable via `--only=dotfiles` for
debugging) but is removed from `$DefaultTools` because it is AlwaysRun.

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

## Mock/Stub Test Harness

> **Addresses:** Chip v2 re-grill finding #4 (mock/live boundary unspecified).

### Problem

T_only_*, T_skip_*, T_baseline_* assertions cannot run real installers in CI. Opt-in
tools (delta, lazygit) may not even have real installer scripts merged yet. Tests must
verify the dispatcher selects and orders correctly without executing real `apt-get`,
`winget`, `brew`, etc.

### Solution: Dispatch Seam via `--tools-dir` / `-ToolsDir`

Both platforms accept a hidden test-only flag that overrides the tools directory:

**Linux (bash):**
```bash
# Hidden flag (not in --help; test-only seam):
--tools-dir=*) TOOLS_DIR="${1#--tools-dir=}"; shift ;;
```

**Windows (PowerShell):**
```powershell
# Hidden param (not in -Help output; test-only seam):
param(
    [string]$Only = '',
    [string]$Skip = '',
    [switch]$List,
    [switch]$Help,
    [string]$ToolsDir = ''  # Test seam: override tools directory
)
if ($ToolsDir) { $script:ToolsDir = $ToolsDir }
```

### Stub Tool Directory Structure

```
tests/fixtures/stub-tools/
|-- linux/
|   |-- alpha.sh        # echo "INSTALLED:alpha" >> "$RUN_LOG"
|   |-- bravo.sh        # echo "INSTALLED:bravo" >> "$RUN_LOG"
|   |-- charlie.sh      # echo "INSTALLED:charlie" >> "$RUN_LOG"
|   `-- delta.sh        # echo "INSTALLED:delta" >> "$RUN_LOG" (opt-in)
`-- windows/
    |-- alpha.ps1       # "INSTALLED:alpha" | Add-Content $env:RUN_LOG
    |-- bravo.ps1       # "INSTALLED:bravo" | Add-Content $env:RUN_LOG
    |-- charlie.ps1     # "INSTALLED:charlie" | Add-Content $env:RUN_LOG
    `-- delta.ps1       # "INSTALLED:delta" | Add-Content $env:RUN_LOG (opt-in)
```

Each stub writes a marker line to `$RUN_LOG` (env var set by the test harness before
invocation). Stubs are ~1 line each; no real installs, no network, no sudo.

### Run-Log Harness Pattern

```bash
# tests/test_setup_flags.sh -- harness example
setup_harness() {
  export RUN_LOG="$(mktemp)"
  STUB_DIR="tests/fixtures/stub-tools/linux"
}

teardown_harness() {
  rm -f "$RUN_LOG"
}

assert_log_equals() {
  local expected="$1"
  diff <(cat "$RUN_LOG") <(printf '%s\n' $expected) || fail "Run log mismatch"
}
```

```powershell
# tests/test_setup_flags_pwsh.ps1 -- harness example
function Setup-Harness {
    $script:RunLog = [System.IO.Path]::GetTempFileName()
    $env:RUN_LOG = $script:RunLog
    $script:StubDir = "tests\fixtures\stub-tools\windows"
}

function Teardown-Harness {
    Remove-Item $script:RunLog -ErrorAction SilentlyContinue
}

function Assert-LogEquals {
    param([string[]]$Expected)
    $actual = Get-Content $script:RunLog
    if (Compare-Object $actual $Expected) { throw "Run log mismatch" }
}
```

### How Tests Use the Seam

```bash
# T_only_single example:
setup_harness
bash scripts/linux/setup.sh --tools-dir="$STUB_DIR" --only=alpha
assert_log_equals "INSTALLED:alpha"
teardown_harness
```

```powershell
# T_only_single example:
Setup-Harness
& scripts\windows\setup.ps1 -ToolsDir $script:StubDir -Only "alpha"
Assert-LogEquals @("INSTALLED:alpha")
Teardown-Harness
```

### Why `--tools-dir` Over Alternatives

| Alternative | Rejection reason |
|-------------|-----------------|
| Env var (`SETUP_TOOLS_DIR`) | Leaks into child processes; harder to reason about in CI matrix |
| Function override / monkey-patch | Not portable between bash/pwsh; fragile |
| Symlink swap | Race conditions in parallel CI; cleanup burden |
| `--tools-dir` CLI flag | Explicit, self-documenting, no global state, same shape both platforms |

### Windows Registry Override

When `$ToolsDir` is set, the dispatcher builds a dynamic registry from the stub dir:

```powershell
if ($ToolsDir) {
    $ToolRegistry = [ordered]@{}
    foreach ($f in Get-ChildItem "$ToolsDir\*.ps1") {
        $name = $f.BaseName
        $path = $f.FullName
        $ToolRegistry[$name] = [scriptblock]::Create("& '$path'")
    }
}
```

This means stub tests use auto-discovery (file = registration), which is fine because
stubs follow a 1:1 filename-to-action convention by design. Production code retains
the explicit registry.

---

## Baseline Fixture Regeneration

> **Addresses:** Chip v2 re-grill finding #5 (regeneration mechanism + proof of order+set).

### Regeneration Command

```bash
# From repo root -- regenerates BOTH platform fixtures from source-of-truth arrays:
make baseline-fixtures
```

**Makefile target:**
```makefile
.PHONY: baseline-fixtures
baseline-fixtures:
	@echo "Regenerating baseline fixtures from DEFAULT_TOOLS arrays..."
	@bash -c 'source scripts/linux/setup.sh --dry-extract-defaults && \
	  printf "%s\n" "$${DEFAULT_TOOLS[@]}" > tests/fixtures/baseline-tools-linux.txt'
	@pwsh -Command '& { \
	  . scripts/windows/setup.ps1 -DryExtractDefaults; \
	  $$DefaultTools | Set-Content tests/fixtures/baseline-tools-windows.txt -Encoding ascii }'
	@echo "Done. Review diff and commit if intentional."
```

The `--dry-extract-defaults` / `-DryExtractDefaults` flag is a test-only seam that
prints the `DEFAULT_TOOLS` array and exits without running any installs. It sources
the dispatcher just far enough to read the constant.

### Baseline-Diff Test Mechanics

The T_baseline_noarg tests prove **both order AND exact set** using the mock harness:

```bash
# T_baseline_noarg (linux):
setup_harness
bash scripts/linux/setup.sh --tools-dir="$STUB_DIR"
# RUN_LOG now has "INSTALLED:alpha\nINSTALLED:bravo\nINSTALLED:charlie" (matching stub DEFAULT_TOOLS)
diff "$RUN_LOG" tests/fixtures/baseline-tools-linux.txt
# Diff compares line-by-line: order matters, extra/missing lines fail
```

For the real baseline fixture (not stubs), the fixture file content matches the
`DEFAULT_TOOLS` array exactly. The test proves:
- **Exact set:** any added/removed tool fails the diff
- **Order:** any reordering fails the diff
- **No real installers run:** mock harness ensures CI safety

### When to Regenerate

Regenerate fixtures when:
- A tool is added to or removed from `DEFAULT_TOOLS` / `$DefaultTools`
- Tool order changes (should be rare; requires dependency verification)

CI will fail the baseline-diff test if fixtures are stale, forcing a deliberate update.

---

## Blank CSV Token Validation

> **Addresses:** Donald v2 re-grill comment (non-blocking, included for completeness).

### Problem

Bash `IFS=',' read -ra` on `"uv,"` produces `("uv" "")` -- a trailing empty element.
PowerShell `"uv,".Split(',')` produces `@("uv", "")` -- same. Without validation,
empty tokens may silently pass or cause confusing "unknown tool: ''" errors.

### Expected Behavior: Reject with Specific Error

| Input | Behavior |
|-------|----------|
| `--only=uv,` | Exit 1: `Error: empty tool name in list (trailing comma). Valid: <AvailableTools>` |
| `--only=uv,,nvm` | Exit 1: `Error: empty tool name in list (consecutive commas). Valid: <AvailableTools>` |
| `--only= uv` | Exit 1: `Error: unknown tool(s): ' uv'. Valid: <AvailableTools>` (no trim; space is literal) |
| `--only=,uv` | Exit 1: `Error: empty tool name in list (leading comma). Valid: <AvailableTools>` |

**Design decision:** No trimming. Tool names are literal filename stems. Leading/trailing
spaces are not stripped -- they produce "unknown tool" errors naturally. Empty tokens
(from commas) are caught by an explicit post-split validation loop.

### Implementation (bash):
```bash
split_csv() {
  local input="$1"
  [[ -z "$input" ]] && { echo "Error: flag requires at least one tool name." >&2; exit 1; }
  IFS=',' read -ra TOOLS <<< "$input" || true
  for t in "${TOOLS[@]}"; do
    [[ -z "$t" ]] && { echo "Error: empty tool name in list (check commas)." >&2; exit 1; }
  done
}
```

### Implementation (pwsh):
```powershell
function Split-ToolList {
    param([string]$Input)
    if ([string]::IsNullOrEmpty($Input)) {
        Write-Err "Flag requires at least one tool name."; exit 1
    }
    $tools = $Input.Split(',')
    foreach ($t in $tools) {
        if ([string]::IsNullOrEmpty($t)) {
            Write-Err "Empty tool name in list (check commas)."; exit 1
        }
    }
    return $tools
}
```

---

## Internal Selection Model

> **Addresses:** finding #11 (future-proof selection abstraction).

After flag parsing, both platforms produce a **FinalToolSet**: an ordered array of tool
names to execute. The model:

```
Input:   flags (--only | --skip | none) + DEFAULT_TOOLS + AvailableTools
Output:  FinalToolSet: string[] (ordered, validated, deduplicated)

Algorithm:
  1. AlwaysRun phases execute unconditionally (outside this model)
  2. if --only:
       validate each name in AvailableTools (reject unknowns)
       validate no empty tokens (reject malformed CSV)
       FinalToolSet = only_list (preserve user-supplied order)
  3. elif --skip:
       validate each name in AvailableTools (reject unknowns)
       validate no empty tokens (reject malformed CSV)
       FinalToolSet = DEFAULT_TOOLS minus skip_list (preserve default order)
  4. else:
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
| `--only=a,b,c` | Install ONLY the listed tools (comma-separated). AlwaysRun still executes. |
| `--skip=a,b,c` | Install all DefaultTools EXCEPT the listed ones. AlwaysRun still executes. |
| `--help` | Print usage synopsis including flag grammar. |

### Syntax Rules

- Comma-separated, no spaces: `--only=delta,lazygit`
- Multiple invocations NOT supported (no `--only=a --only=b`). Comma list is canonical.
- Tool names are filename stems from `scripts/{platform}/tools/` (sans extension).
- `--only` and `--skip` are mutually exclusive (error if both supplied).
- Unknown tool names produce exit 1 with a message listing valid names (= AvailableTools).
- Empty tokens in CSV (trailing/leading/consecutive commas) produce exit 1.
- No whitespace trimming -- spaces in tool names are literal (and will fail as unknown).

### PowerShell Grammar

> **Addresses:** finding #10 (parity grammar pick + justification).

```powershell
.\setup.ps1 -List
.\setup.ps1 -Only "delta,lazygit"
.\setup.ps1 -Skip "copilot"
.\setup.ps1 -Help
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
    [switch]$Help,
    [string]$ToolsDir = ''  # Test seam (hidden from -Help)
)
```

No advanced features (no `[ValidateSet]`, no `[Parameter()]` with PS 7+ attributes).
Plain types only. Tested under `shell: powershell` in `validate-ps51`.

---

## Discovery for `--list`

> **Addresses:** Donald v1 finding #1 (sed bug), Duck finding #1 (AvailableTools definition).

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

The registry IS the source of truth on Windows (registered callable installers).
Any file in `tools/` without a registry entry is not discoverable (intentional --
completing the platform's registration is required).

---

## Bash Arg-Parsing Mechanism

> **Addresses:** Donald finding #5 (getopts unsafe under set -e).

```bash
# Case-based loop. No getopts (incompatible with --long-opts + set -e).
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)        FLAG_LIST=1; shift ;;
      --help)        FLAG_HELP=1; shift ;;
      --only=*)      FLAG_ONLY="${1#--only=}"; shift ;;
      --skip=*)      FLAG_SKIP="${1#--skip=}"; shift ;;
      --tools-dir=*) TOOLS_DIR="${1#--tools-dir=}"; shift ;;  # Test seam
      *)             echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done
}

# IFS split with empty-token guard
split_csv() {
  local input="$1"
  [[ -z "$input" ]] && { echo "Error: flag requires at least one tool name." >&2; exit 1; }
  IFS=',' read -ra TOOLS <<< "$input" || true
  for t in "${TOOLS[@]}"; do
    [[ -z "$t" ]] && { echo "Error: empty tool name in list (check commas)." >&2; exit 1; }
  done
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
| Empty token in CSV (`--only=uv,`) | Exit 1: `Error: empty tool name in list (check commas).` |
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

**Regeneration command:** `make baseline-fixtures` (see "Baseline Fixture Regeneration" section).

**Initial capture (manual, since `--dry-extract-defaults` doesn't exist yet):**

```bash
# From repo root:
printf '%s\n' zsh uv nvm gh auth copilot-cli squad-cli > tests/fixtures/baseline-tools-linux.txt
```

```powershell
# From repo root:
@('git','uv','nvm','gh','auth','vim','psmux','copilot','squad-cli','profile') |
    Set-Content tests/fixtures/baseline-tools-windows.txt -Encoding ascii
```

Note: `dotfiles` excluded from Windows fixture -- it is AlwaysRun, not a DefaultTool.

**Files created:**
- `tests/fixtures/baseline-tools-linux.txt`
- `tests/fixtures/baseline-tools-windows.txt`
- `Makefile` (add `baseline-fixtures` target)

**Done Criteria:**
- [ ] Fixtures committed to `develop` before Slice 1 merges
- [ ] Each fixture exactly matches the `DEFAULT_TOOLS` / `$DefaultTools` array
- [ ] `make baseline-fixtures` documented and functional
- [ ] `validate-ps51` step passes (no .ps1 changes in this slice, but confirm no regression)

---

### Slice 1: `--list`, `--help`, Root Forwarding, and Baseline Diff

> **Addresses:** Chip finding B-5 (--help in Slice 1), finding #9 (baseline test early),
> Duck v2 re-grill finding #1 (root entrypoint forwarding).

**Scope:** Add `--list` and `--help` flags. Add baseline-diff test. Forward args from
root entrypoints. Introduce mock harness. No `--only`/`--skip` yet.

**Files touched:**
- `setup.sh` (root) -- forward `"$@"` through `run_linux_setup`
- `setup.ps1` (root) -- add `param()` block + `@PSBoundParameters` splat
- `scripts/linux/setup.sh` (arg parse, `DEFAULT_TOOLS` array, `list_available_tools()`, help text, `--tools-dir` seam, AlwaysRun phase extraction)
- `scripts/windows/setup.ps1` (`param()` block, `$DefaultTools`, `$ToolRegistry`, `Get-AvailableTools`, help, `-ToolsDir` seam, AlwaysRun extraction)
- `tests/test_setup_flags.sh` (new)
- `tests/test_setup_flags_pwsh.ps1` (new)
- `tests/fixtures/stub-tools/linux/{alpha,bravo,charlie,delta}.sh` (new)
- `tests/fixtures/stub-tools/windows/{alpha,bravo,charlie,delta}.ps1` (new)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh
Test-Scenario "T_list_output: --list prints all AvailableTools alphabetically, exit 0"
Test-Scenario "T_list_no_install: --list produces no install side-effects"
Test-Scenario "T_help_output: --help prints usage containing --list, --only, --skip"
Test-Scenario "T_help_exit: --help exits 0 with no install"
Test-Scenario "T_baseline_noarg: no-arg run with stub tools produces markers matching baseline fixture (order+set)"
Test-Scenario "T_unknown_arg: unknown --foo exits 1"
Test-Scenario "T_root_list_linux: ./setup.sh --list exits 0 with same output as scripts/linux/setup.sh --list"
Test-Scenario "T_root_help_linux: ./setup.sh --help exits 0"

# tests/test_setup_flags_pwsh.ps1
Test-Scenario "T_list_output: -List prints all AvailableTools alphabetically, exit 0"
Test-Scenario "T_list_no_install: -List produces no install side-effects"
Test-Scenario "T_help_output: -Help prints usage containing -List, -Only, -Skip"
Test-Scenario "T_help_exit: -Help exits 0 with no install"
Test-Scenario "T_baseline_noarg: no-arg run with stub tools produces markers matching baseline fixture (order+set)"
Test-Scenario "T_param_ps51: param() block parses without error under PS 5.1"
Test-Scenario "T_root_list_win: .\setup.ps1 -List exits 0 with same output as scripts\windows\setup.ps1 -List"
Test-Scenario "T_root_help_win: .\setup.ps1 -Help exits 0"
```

**Done Criteria:**
- [ ] `--list` / `-List` prints AvailableTools (alpha sorted), exit 0
- [ ] `--help` / `-Help` prints usage, exit 0
- [ ] No-arg run invokes exactly the tools in baseline fixture (order + set), via mock harness
- [ ] Root `./setup.sh --list` and `.\setup.ps1 -List` produce identical output to platform scripts
- [ ] Mock harness (`--tools-dir` / `-ToolsDir`) functional; stub tools write to `$RUN_LOG`
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`
- [ ] `validate-ps51` runs `powershell -File tests\test_setup_flags_pwsh.ps1`
- [ ] e2e-install.yml: `--list` added as smoke step in linux, macos, windows jobs

---

### Slice 2: `--only` Flag (Selective Install)

**Scope:** Parse `--only=a,b,c`, install only those tools. AlwaysRun phases still execute.

**Files touched:**
- `scripts/linux/setup.sh` (flag parse, `split_csv`, selection logic)
- `scripts/windows/setup.ps1` (`-Only` param handling, split, filter, dispatch)
- `tests/test_setup_flags.sh` (new scenarios appended)
- `tests/test_setup_flags_pwsh.ps1` (new scenarios appended)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh (added in Slice 2)
Test-Scenario "T_only_single: --only=alpha installs only alpha (stub log = INSTALLED:alpha)"
Test-Scenario "T_only_multi: --only=alpha,bravo installs alpha+bravo only, in user-specified order"
Test-Scenario "T_only_unknown: --only=bogus exits 1 with valid-tool list"
Test-Scenario "T_only_empty: --only= (empty) exits 1"
Test-Scenario "T_only_optin: --only=delta works (delta.sh exists but not in DEFAULT_TOOLS)"
Test-Scenario "T_only_idempotent: --only=alpha run twice -> exit 0 both, single marker line"
Test-Scenario "T_only_blank_trailing: --only=alpha, exits 1 (trailing comma = empty token)"
Test-Scenario "T_only_blank_consecutive: --only=alpha,,bravo exits 1 (consecutive commas)"
Test-Scenario "T_only_blank_leading: --only=,alpha exits 1 (leading comma)"
Test-Scenario "T_only_space: --only=' alpha' exits 1 (space = unknown tool, no trim)"

# tests/test_setup_flags_pwsh.ps1 (added in Slice 2)
Test-Scenario "T_only_single: -Only 'alpha' installs only alpha"
Test-Scenario "T_only_multi: -Only 'alpha,bravo' installs alpha+bravo only"
Test-Scenario "T_only_unknown: -Only 'bogus' exits 1 with valid-tool list"
Test-Scenario "T_only_empty: -Only '' exits 1"
Test-Scenario "T_only_optin: -Only 'delta' works (delta.ps1 + registry exist, not in DefaultTools)"
Test-Scenario "T_only_idempotent: -Only 'alpha' run twice -> exit 0, single marker"
Test-Scenario "T_only_blank_trailing: -Only 'alpha,' exits 1 (trailing comma)"
Test-Scenario "T_only_blank_consecutive: -Only 'alpha,,bravo' exits 1 (consecutive commas)"
Test-Scenario "T_only_blank_leading: -Only ',alpha' exits 1 (leading comma)"
Test-Scenario "T_only_space: -Only ' alpha' exits 1 (space = unknown, no trim)"
Test-Scenario "T_only_ps51: -Only parsing works under PS 5.1 (shell: powershell)"
```

**Done Criteria:**
- [ ] `--only` / `-Only` installs exactly the named tools, nothing else (plus AlwaysRun)
- [ ] Unknown tool -> exit 1 + AvailableTools list
- [ ] Empty value -> exit 1
- [ ] Blank CSV tokens (trailing/leading/consecutive commas) -> exit 1
- [ ] Spaces not trimmed (literal match against AvailableTools)
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
Test-Scenario "T_skip_single: --skip=bravo installs all DEFAULT_TOOLS except bravo"
Test-Scenario "T_skip_multi: --skip=bravo,charlie installs all except bravo and charlie"
Test-Scenario "T_skip_unknown: --skip=bogus exits 1 with valid-tool list"
Test-Scenario "T_skip_empty: --skip= (empty) exits 1"
Test-Scenario "T_skip_conflict: --only=alpha --skip=bravo exits 1 with mutual-exclusion message"
Test-Scenario "T_skip_idempotent: --skip=bravo run twice -> exit 0 both"
Test-Scenario "T_list_plus_only: --list --only=alpha prints list only (--list wins)"
Test-Scenario "T_skip_blank_trailing: --skip=bravo, exits 1 (trailing comma)"
Test-Scenario "T_skip_blank_consecutive: --skip=bravo,,charlie exits 1 (consecutive commas)"

# tests/test_setup_flags_pwsh.ps1 (added in Slice 3)
Test-Scenario "T_skip_single: -Skip 'bravo' installs all DefaultTools except bravo"
Test-Scenario "T_skip_multi: -Skip 'bravo,charlie' installs all except bravo and charlie"
Test-Scenario "T_skip_unknown: -Skip 'bogus' exits 1 with valid-tool list"
Test-Scenario "T_skip_empty: -Skip '' exits 1"
Test-Scenario "T_skip_conflict: -Only 'alpha' -Skip 'bravo' exits 1 with mutual-exclusion message"
Test-Scenario "T_skip_idempotent: -Skip 'bravo' run twice -> exit 0"
Test-Scenario "T_skip_blank_trailing: -Skip 'bravo,' exits 1 (trailing comma)"
Test-Scenario "T_skip_blank_consecutive: -Skip 'bravo,,charlie' exits 1 (consecutive commas)"
Test-Scenario "T_skip_ps51: -Skip parsing works under PS 5.1"
```

**Done Criteria:**
- [ ] `--skip` / `-Skip` excludes named tools from DefaultTools
- [ ] Mutual exclusion enforced (exit 1 if both `--only` and `--skip`)
- [ ] Unknown tool -> exit 1
- [ ] Empty value -> exit 1
- [ ] Blank CSV tokens -> exit 1 (same validation as `--only`)
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
E2E_list_smoke: ./setup.sh --list exits 0 (linux + macos) [root entrypoint]
E2E_list_smoke_win: .\setup.ps1 -List exits 0 (windows) [root entrypoint]
E2E_only_smoke: ./setup.sh --only=gh exits 0 (linux) [root entrypoint]
E2E_only_smoke_win: .\setup.ps1 -Only "gh" exits 0 (windows) [root entrypoint]
```

**Done Criteria:**
- [ ] README documents `--list`, `--only`, `--skip`, `--help` with examples
- [ ] README notes AlwaysRun behavior ("prerequisites and dotfiles always run")
- [ ] e2e-install.yml exercises `--list` + `--only` on all platforms via ROOT entrypoints
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

## PowerShell Grammar Parity Tests

> **Addresses:** finding #10 (parity test cases for pwsh grammar edge cases).

These scenarios are embedded in the Slice 2/3 test files above. Explicit edge cases:

| Input | Expected | Slice |
|-------|----------|-------|
| `-Only "alpha,bravo"` (quoted, comma) | Installs alpha + bravo | 2 |
| `-Only "alpha"` (quoted, single) | Installs alpha only | 2 |
| `-Only ""` (quoted empty) | Exit 1, error message | 2 |
| `-Only "bogus"` (unknown) | Exit 1, valid-tool list | 2 |
| `-Only "alpha,"` (trailing comma) | Exit 1, empty token | 2 |
| `-Only "alpha,,bravo"` (consecutive) | Exit 1, empty token | 2 |
| `-Only " alpha"` (leading space) | Exit 1, unknown tool | 2 |
| `-Skip "bravo"` (quoted) | All minus bravo | 3 |
| `-Only "alpha" -Skip "bravo"` (conflict) | Exit 1, mutual-exclusion | 3 |

---

## Cross-Platform Parity Contract

Test files: `tests/test_setup_flags.sh` + `tests/test_setup_flags_pwsh.ps1`

| Test case | Bash | PS 7+ | PS 5.1 | Slice |
|-----------|:---:|:---:|:---:|:---:|
| `--list` prints AvailableTools alphabetically | x | x | x | 1 |
| `--help` prints usage | x | x | x | 1 |
| No-arg = baseline fixture (via mock harness) | x | x | x | 1 |
| Root entrypoint forwards `--list` | x | x | x | 1 |
| `--only=a,b` installs only a, b | x | x | x | 2 |
| Unknown tool in `--only` -> exit 1 | x | x | x | 2 |
| Empty `--only` -> exit 1 | x | x | x | 2 |
| Blank CSV token -> exit 1 | x | x | x | 2 |
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
- **AlwaysRun phase customization** -- these phases are not user-toggleable in v1.

---

## Slice Ordering and Issue Dependencies

```
Slice 0 (baseline fixture + Makefile target) -- prerequisite, no flag code
  |-> Slice 1 (--list + --help + root forwarding + mock harness + baseline test)
        |-> Slice 2 (--only + blank-CSV validation)   <--- #466 (delta) + #467 (lazygit) can land here
              |-> Slice 3 (--skip + conflict detection)
                    |-> Slice 4 (README + e2e hardening)
```

#466 and #467 need Slice 2 merged to land cleanly. They add:
- `scripts/linux/tools/delta.sh` / `scripts/linux/tools/lazygit.sh`
- `scripts/windows/tools/delta.ps1` / `scripts/windows/tools/lazygit.ps1`
- Dot-source + `$ToolRegistry['delta'] = { Install-Delta }` (3-line pattern)
- **NOT** added to `$DefaultTools` / `DEFAULT_TOOLS` (opt-in only)
- `--only=delta` exercises them through AlwaysRun + tool dispatch

---

## Done Criteria (v1 = Slices 0-4)

- [ ] Baseline fixtures committed and matching current behavior
- [ ] `make baseline-fixtures` regeneration command functional
- [ ] `--list`, `--only`, `--skip`, `--help` work on both platforms
- [ ] Root entrypoints (`./setup.sh`, `.\setup.ps1`) forward all flags correctly
- [ ] No-arg behavior unchanged (baseline-diff test green via mock harness)
- [ ] AlwaysRun phases execute under `--only`/`--skip` (prerequisites, dotfiles, hooks)
- [ ] Error messages match spec (unknown tool, mutual exclusion, empty value, blank CSV token)
- [ ] All named Test-Scenario cases pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`
- [ ] `validate-ps51` runs flag test file under `shell: powershell` (PS 5.1)
- [ ] Mock harness (`--tools-dir` / `-ToolsDir`) enables CI-safe assertion of tool selection
- [ ] README updated with new usage section (including AlwaysRun note)
- [ ] e2e-install.yml exercises `--list` + `--only` on all 3 platforms via root entrypoints
- [ ] #466 and #467 can add tools via 3-line extension pattern without touching flag logic

---

## Revision History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| v1 | 2026-05-28 | Mickey | Initial plan -- flags-first shape, 4 slices |
| v2 | 2026-05-28 | Goofy | Address all grill findings (Duck/Donald/Chip). See below. |
| v3 | 2026-05-29 | Chip | Address v2 re-grill findings (Duck/Chip/Donald). See below. |

### v3 Changes (v2 Re-Grill Findings Addressed)

**Duck v2 re-grill findings:**
1. Root entrypoint arg forwarding: `setup.sh` and `setup.ps1` added to Slice 1 files-touched; forward `"$@"` and `@PSBoundParameters`; dedicated root-forwarding tests added. -> "Root Entrypoint Arg Forwarding" section.
2. AlwaysRun classification: 4th concept added (AlwaysRun). Audit of both platform scripts identifies prerequisites, dotfiles, git-hook config. Dotfiles reclassified from DefaultTools to AlwaysRun on Windows for cross-platform consistency. Explicit table shows behavior under `--only`/`--skip`. -> "Tool Classification Model" section.
3. Windows AvailableTools single source-of-truth: table now says "registered callable installers" (not "filesystem scan") for Windows. Invariant clarified per-platform: Linux file=registration, Windows registry-entry=registration. "Adding a file makes it selectable" wording removed for Windows. -> "Windows Dispatch" section.

**Chip v2 re-grill findings:**
4. Mock/stub test harness: `--tools-dir` / `-ToolsDir` CLI seam defined. Stub tool directory with marker-file pattern. Run-log harness for both bash and pwsh. Justification table for seam choice. Windows dynamic registry from stubs. -> "Mock/Stub Test Harness" section.
5. Baseline fixture regeneration: `make baseline-fixtures` command with Makefile target. `--dry-extract-defaults` seam for array extraction. Baseline-diff test mechanics prove both order and exact set via mock harness. -> "Baseline Fixture Regeneration" section.

**Donald v2 re-grill comment (non-blocking, included):**
6. Blank CSV token validation: explicit tests for `--only=uv,`, `--only=uv,,nvm`, `--only= uv`. Decision: reject empty tokens (exit 1), no whitespace trimming. Implementation shown for both platforms. Test scenarios added to Slices 2 and 3. -> "Blank CSV Token Validation" section.

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
