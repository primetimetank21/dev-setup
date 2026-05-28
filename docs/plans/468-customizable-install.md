# Plan: #468 Customizable Install (Pick-and-Choose Tools)

**Date:** 2026-05-30
**Author:** Pluto -- v4 (full rewrite); Donald -- v5 (polish pass); Pluto -- v6 (final polish); Jiminy -- v7 (fixture provenance); Pluto -- v8 (coherence reconciliation)
**Issue:** #468
**Status:** Ready for review

---

## v8 Changelog (Pluto -- coherence reconciliation)

1. **v8 (Pluto):** Fixture Provenance includes Windows `winget-check` (lines 535-549), but
   `$DefaultTools` and `$ToolRegistry` omitted it -- making `T_baseline_real_defaults`
   impossible to pass coherently. Reconciled via path (A): added `'winget-check'` as first
   entry in Windows `$DefaultTools` and `$ToolRegistry`, paralleling Linux `prereqs` as
   the prerequisite-check phase. Preserves 2-concept model; AlwaysRun stays dropped.

---

## v7 Changelog (Jiminy -- fixture provenance polish)

1. **v7 (Jiminy):** Fixture Provenance Linux/Windows order corrected to match real `setup.{sh,ps1}` execution including prereqs/dotfiles/git-hook phases absorbed into DefaultTools after AlwaysRun drop.

---

## v6 Changelog (Pluto -- surgical polish on Donald's v5)

1. **`--check` mode write-then-diff bug (Duck blocker):** Restructured
   `regenerate-baseline-fixtures.sh` spec so extraction populates in-memory arrays
   (`${linux_defaults[@]}` / `${win_defaults[@]}`, with PowerShell `$win_defaults`
   explicitly defined) ONLY; `--check` diffs in-memory against committed fixture
   files and never writes. Normal mode is the sole write path.

2. **CI workflow name misalignment (Jiminy blocker):** Slice 4 now correctly targets
   `e2e-install.yml` for e2e jobs and `validate.yml` for validate-{linux,powershell,ps51}.
   Added explicit macOS selective-install e2e coverage (`E2E_only_macos`).

3. **Flag-combo coverage gaps (Jiminy blocker):** Added named Test-Scenario cases for
   bash `--list --skip`, PowerShell `-List -Only` / `-List -Skip`, and both direct-child
   plus root-forwarding paths for `--only` / `--skip`.

4. **Fixture provenance anchor (Jiminy blocker):** Added "Fixture Provenance" subsection
   under Baseline Fixture Mechanism. Explicit current Linux + Windows tool orders committed
   as fixtures BEFORE refactor lands. `regenerate-baseline-fixtures.sh` must NOT be run
   during implementation.

5. **Re-run/flag idempotency (Jiminy blocker):** Added `T_no_selection_persistence` test
   in Slice 3 -- verifies no state persists between flag invocations (bash + pwsh).

6. **Skip-path coverage for git-hook safety (Duck non-blocking):** Added
   `T_git_hook_skip_path_safe` test in Slice 3 -- asserts `--skip=prereqs` (Linux) and
   `-Skip 'git'` (Windows) still allows git-hook to self-guard cleanly.

---

## v5 Changelog (Donald -- polish pass on Pluto's v4)

1. **Baseline harness format mismatch (Donald review):** Stubs now log bare tool names
   (e.g. `echo "prereqs" >> "$RUN_LOG"`) instead of `RAN:prereqs`. This eliminates the
   impossible diff between `RUN_LOG` (prefixed) and `defaults.txt` (bare). Option (a)
   chosen -- simplest, no transform step in tests.

2. **Git-hook safety via flag paths (Duck DK4-bis):** `git-hook.sh` and `Install-GitHook`
   are now self-guarding: early-return exit 0 with skip message when `git` is not on PATH.
   New test `T_git_hook_no_git_safe` in Slice 2 confirms both platforms.

3. **Real-defaults drift test (Duck-2):** Added `T_baseline_real_defaults` (bash + pwsh)
   that extracts real `DEFAULT_TOOLS`/`$DefaultTools` arrays from source via
   `scripts/dev/regenerate-baseline-fixtures.sh` and diffs against committed
   `tests/fixtures/baseline-tools-{linux,windows}.txt`. Runs alongside (not replacing)
   the mock-dispatcher baseline test.

---

## Summary

Add flag-based tool selection to `scripts/linux/setup.sh` and `scripts/windows/setup.ps1`
so users (and CI) can install a subset of tools without modifying the scripts. Default
behavior (no flags) is unchanged -- full install, identical to today.

Flags: `--list`, `--only=a,b`, `--skip=a,b`, `--help` (bash). PowerShell equivalents:
`-List`, `-Only "a,b"`, `-Skip "a,b"`, `-Help`.

---

## Design Decisions

### DD-1: AlwaysRun -- DROPPED

The "AlwaysRun" concept (prerequisites, dotfiles, git-hook always execute regardless
of flags) introduced 4 edge-case blockers:

- Registry overlap: dotfiles in both AvailableTools and AlwaysRun -> ambiguous `--skip`/`--only` behavior
- Mock harness gap: `--tools-dir` didn't cover AlwaysRun phases -> CI pollution from real apt/brew/dotfiles
- Git-hook unsafety: `--only=uv` on fresh Windows -> `Install-GitHook` hard-fails (git absent)
- Cross-platform asymmetry: dotfiles was AlwaysRun on Linux but selectable on Windows

**Resolution:** ALL phases -- prerequisites, dotfiles, git-hook, tool installers -- go through
ONE ordered dispatch pipeline. They are entries in `DEFAULT_TOOLS` (or equivalent ordered list),
subject to the same `--only`/`--skip` semantics as any other tool. This means:

- `--only=uv` installs ONLY uv. No prereqs, no dotfiles, no git-hook.
- `--skip=dotfiles` skips dotfiles. Clear semantics.
- `--list` shows everything including prereqs/dotfiles/git-hook.
- Mock harness (`--tools-dir`) covers the entire pipeline -- no separate seam needed.

**Trade-off:** A user running `--only=nvm` won't get prerequisites auto-installed.
This is intentional and documented. The full default run handles dependency ordering.
A future DAG (out of scope) could add dependency warnings.

### DD-2: Unified Dispatch Seam (`--tools-dir` / `-ToolsDir`)

A single hidden test-only flag overrides where the dispatcher looks for tool scripts.
Since AlwaysRun is gone, this one seam covers the entire pipeline. Mock tests point it
at `tests/fixtures/stub-tools/` and assert against a run-log file.

### DD-3: Baseline Fixture Script (not Makefile)

No Makefile exists in this repo. Adding one for a single target is unjustified overhead.
Instead: `scripts/dev/regenerate-baseline-fixtures.sh` -- a standalone script that extracts
the `DEFAULT_TOOLS` arrays from source and writes fixture files.

### DD-4: PS Root Forwarding -- Sanitized Hashtable

`setup.ps1` (root) declares user-facing params (`Only`, `Skip`, `List`, `Help`) and
builds a sanitized forward-hashtable containing ONLY those params. It does NOT splat
`$PSBoundParameters` (which would include internal params like `ScriptDir`).

```powershell
$forwardParams = @{}
if ($Only) { $forwardParams['Only'] = $Only }
if ($Skip) { $forwardParams['Skip'] = $Skip }
if ($List) { $forwardParams['List'] = $true }
if ($Help) { $forwardParams['Help'] = $true }
& $windowsScript @forwardParams
```

### DD-5: Blank-CSV Validation -- Pre-Split Regex + Post-Split Guard

Bash: check for leading/trailing/consecutive commas BEFORE splitting:

```bash
validate_csv_shape() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "Error: flag requires at least one tool name." >&2; exit 1
  fi
  if [[ "$input" == *,,* || "$input" == ,* || "$input" == *, ]]; then
    echo "Error: empty tool name in list (check commas)." >&2; exit 1
  fi
}
```

PowerShell: post-split loop checking each element for empty string.

---

## Non-Negotiables

1. **Backward compatibility:** `setup.sh` (no args) === current full install. Enforced by baseline-diff test.
2. **Cross-platform parity:** Every flag and its semantics work identically on bash and pwsh.
3. **Existing tool pattern preserved:** Individual tool scripts remain independently runnable.
4. **PS 5.1 compatibility:** All `.ps1` changes must pass `validate-ps51`.
5. **Root entrypoint transparency:** `./setup.sh <flags>` behaves identically to calling the platform script directly.

---

## Shape Decision: Flags-First

**Chosen:** CLI flags (`--only`, `--skip`, `--list`, `--help`)
**Rejected:** Interactive prompt (breaks headless/CI), manifest-only (poor discoverability).

Manifest and prompt are explicitly out of scope -- they can layer on top later.

---

## Tool Classification Model

### Two Concepts

| Concept | Definition | Source of Truth |
|---------|-----------|-----------------|
| **AvailableTools** | Every registered callable step (tools + infra phases). | Linux: filesystem scan of `tools/*.sh`. Windows: `$ToolRegistry.Keys`. |
| **DefaultTools** | The ordered list invoked on a no-flags run. Per-platform. | Hardcoded array constant in the dispatcher. |

`SelectableTools` = `AvailableTools` (anything discoverable is targetable by `--only`/`--skip`).

### Default Order (Linux)

```bash
DEFAULT_TOOLS=(
  "prereqs"
  "zsh"
  "uv"
  "nvm"
  "gh"
  "auth"
  "copilot-cli"
  "squad-cli"
  "dotfiles"
  "git-hook"
)
```

### Default Order (Windows)

```powershell
$DefaultTools = @(
  'winget-check'   # prerequisite gate (parallels Linux 'prereqs')
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
  'git-hook'
)
```

These are the **single source of truth** for no-arg tool behavior. Order preserves
implicit dependency chains.

### Key Invariant

Adding a file to `tools/` (Linux) or a registry entry (Windows) makes it AvailableTools
(selectable via `--only`) but does NOT add it to the default run. Promotion to default
requires appending to the `DEFAULT_TOOLS` constant (deliberate commit).

### Opt-In Example: delta / lazygit (#466, #467)

- `delta.sh` / `delta.ps1` exist -> delta is in AvailableTools
- `delta` NOT in `DEFAULT_TOOLS` -> not invoked on no-flags run
- `--only=delta` works because delta is in AvailableTools
- To promote: append `"delta"` to the `DEFAULT_TOOLS` array

---

## Windows Dispatch: Registry Pattern

**Explicit registry with 3-line extension contract.**

```powershell
$ToolRegistry = [ordered]@{
    'winget-check' = { Test-WingetAvailable }   # prerequisite gate (parallels Linux 'prereqs')
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
    'git-hook'  = { Install-GitHook }
}
```

**3-Line Extension Pattern** (for #466/#467):
```powershell
# 1. Create scripts/windows/tools/delta.ps1 with Install-Delta function
# 2. Dot-source: . "$PSScriptRoot\tools\delta.ps1"
# 3. Registry entry: $ToolRegistry['delta'] = { Install-Delta }
```

**Why not auto-discovery on Windows:** Tool files export arbitrarily-named functions.
No filename->function convention exists. The registry is the explicit bridge.

When `-ToolsDir` is set (test mode), the dispatcher builds a dynamic registry from stubs:
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

---

## Linux Dispatch: Filesystem-Based

On Linux, `AvailableTools` = basenames of `*.sh` files in `$TOOLS_DIR`.
The dispatcher calls `bash "$TOOLS_DIR/${tool_name}.sh"` for each tool in FinalToolSet.

To support `prereqs`, `dotfiles`, and `git-hook` as dispatchable steps, they become
scripts in `tools/`:
- `scripts/linux/tools/prereqs.sh` -- extracted from current `install_prerequisites()`
- `scripts/linux/tools/dotfiles.sh` -- extracted from current inline dotfiles block
- `scripts/linux/tools/git-hook.sh` -- extracted from current inline git-hook block

This keeps the dispatch mechanism uniform: everything is a script in `tools/`.

---

## Root Entrypoint Arg Forwarding

### The Gap (current code)
- `./setup.sh` line 106: `exec bash "$linux_script"` -- does NOT forward `"$@"`
- `./setup.ps1` line 103: `& $windowsScript` -- does NOT forward params

### The Fix

**`./setup.sh`** (root):
```bash
run_linux_setup() {
  # ...existence checks...
  exec bash "$linux_script" "$@"
}
# In main() -- ALL routing branches:
run_linux_setup "$@"
```

**`./setup.ps1`** (root) -- per DD-4:
```powershell
param(
    [string]$Only = '',
    [string]$Skip = '',
    [switch]$List,
    [switch]$Help
)
# ... detection/routing unchanged ...
function Invoke-WindowsSetup {
    param([string]$ScriptDir)
    $windowsScript = Join-Path $ScriptDir 'scripts\windows\setup.ps1'
    # ... existence check ...
    $forwardParams = @{}
    if ($Only) { $forwardParams['Only'] = $Only }
    if ($Skip) { $forwardParams['Skip'] = $Skip }
    if ($List) { $forwardParams['List'] = $true }
    if ($Help) { $forwardParams['Help'] = $true }
    & $windowsScript @forwardParams
}
```

---

## Mock/Stub Test Harness

### Dispatch Seam

Both platforms accept a hidden test-only flag that overrides the tools directory:

**Linux:** `--tools-dir=<path>` (hidden, not in `--help`)
**Windows:** `-ToolsDir <path>` (hidden, not in `-Help`)

### Stub Tool Directory

```
tests/fixtures/stub-tools/
|-- linux/
|   |-- prereqs.sh       # echo "prereqs" >> "$RUN_LOG"
|   |-- alpha.sh         # echo "alpha" >> "$RUN_LOG"
|   |-- bravo.sh         # echo "bravo" >> "$RUN_LOG"
|   |-- charlie.sh       # echo "charlie" >> "$RUN_LOG"
|   |-- dotfiles.sh      # echo "dotfiles" >> "$RUN_LOG"
|   |-- git-hook.sh      # echo "git-hook" >> "$RUN_LOG"
|   |-- uv.sh            # echo "uv" >> "$RUN_LOG" (opt-in/idempotency fixture)
|   `-- delta.sh         # echo "delta" >> "$RUN_LOG" (opt-in)
`-- windows/
    |-- prereqs.ps1      # "prereqs" | Add-Content $env:RUN_LOG
    |-- alpha.ps1        # "alpha" | Add-Content $env:RUN_LOG
    |-- bravo.ps1        # "bravo" | Add-Content $env:RUN_LOG
    |-- charlie.ps1      # "charlie" | Add-Content $env:RUN_LOG
    |-- dotfiles.ps1     # "dotfiles" | Add-Content $env:RUN_LOG
    |-- git-hook.ps1     # "git-hook" | Add-Content $env:RUN_LOG
    |-- uv.ps1           # "uv" | Add-Content $env:RUN_LOG (opt-in/idempotency fixture)
    `-- delta.ps1        # "delta" | Add-Content $env:RUN_LOG (opt-in)
```

> **v5 note (fix #1):** Stubs log bare tool names -- no `RAN:` prefix. This makes
> `RUN_LOG` directly diffable against `defaults.txt` without transformation.

Stub `DEFAULT_TOOLS` for tests (when `--tools-dir` active):
- Linux: `("prereqs" "alpha" "bravo" "charlie" "dotfiles" "git-hook")`
- Windows: `@('prereqs','alpha','bravo','charlie','dotfiles','git-hook')`

When `--tools-dir` is set, the dispatcher also loads `DEFAULT_TOOLS` from a
`defaults.txt` file in the stub dir (one tool name per line). This keeps test
behavior self-contained.

### Run-Log Pattern

```bash
# tests/test_setup_flags.sh
setup_harness() {
  export RUN_LOG="$(mktemp)"
  STUB_DIR="tests/fixtures/stub-tools/linux"
}
teardown_harness() { rm -f "$RUN_LOG"; }
assert_log_equals() {
  local expected="$1"
  diff <(cat "$RUN_LOG") <(echo "$expected") || fail "Run log mismatch"
}
```

```powershell
# tests/test_setup_flags_pwsh.ps1
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

### Hidden Flag Protection

Hidden flags are excluded from `--help`/`-Help` output. Tests assert this negatively:
- `T_help_no_toolsdir: --help output does NOT contain 'tools-dir'`
- `T_help_no_toolsdir_win: -Help output does NOT contain 'ToolsDir'`

---

## Baseline Fixture Mechanism

### Regeneration Script

`scripts/dev/regenerate-baseline-fixtures.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Step 1: Extract defaults into in-memory arrays (NEVER writes files) ---

# Linux: populate bash array ${linux_defaults[@]}.
mapfile -t linux_defaults < <(
  grep -A50 '^DEFAULT_TOOLS=(' "$REPO_ROOT/scripts/linux/setup.sh" \
    | sed -n '/^DEFAULT_TOOLS=(/,/^)/p' \
    | grep '"' \
    | sed 's/.*"\(.*\)".*/\1/'
)

# Windows: populate bash array ${win_defaults[@]} from a PowerShell array named $win_defaults.
mapfile -t win_defaults < <(pwsh -NoProfile -Command "
  \$content = Get-Content '$REPO_ROOT/scripts/windows/setup.ps1' -Raw
  if (\$content -match '(?s)\\\$DefaultTools\s*=\s*@\((.*?)\)') {
    \$win_defaults = @(\$Matches[1].Split([char[]]@([char]13,[char]10,' ')) |
      ForEach-Object { \$_.Trim().Trim(\"'\") } |
      Where-Object { \$_ })
    \$win_defaults
  }
")

# --- Step 2: Branch on mode ---

if [[ "${1:-}" == "--check" ]]; then
  # CHECK MODE: diff in-memory arrays against committed fixtures. Never writes.
  rc=0
  diff "$REPO_ROOT/tests/fixtures/baseline-tools-linux.txt" <(printf '%s\n' "${linux_defaults[@]}") \
    || { echo "DRIFT: Linux DEFAULT_TOOLS changed. Run: scripts/dev/regenerate-baseline-fixtures.sh"; rc=1; }
  diff "$REPO_ROOT/tests/fixtures/baseline-tools-windows.txt" <(printf '%s\n' "${win_defaults[@]}") \
    || { echo "DRIFT: Windows DefaultTools changed. Run: scripts/dev/regenerate-baseline-fixtures.sh"; rc=1; }
  if [[ $rc -ne 0 ]]; then exit 1; fi
  echo "OK: baseline fixtures match source arrays."
  exit 0
fi

# REGENERATE MODE (default / --regenerate): the ONLY path that writes fixture files.
printf '%s\n' "${linux_defaults[@]}" > "$REPO_ROOT/tests/fixtures/baseline-tools-linux.txt"
printf '%s\n' "${win_defaults[@]}" > "$REPO_ROOT/tests/fixtures/baseline-tools-windows.txt"
echo "Fixtures regenerated. Review diff and commit if intentional."
```

### Baseline-Diff Test

```bash
# T_baseline_noarg (stub-based):
setup_harness
bash scripts/linux/setup.sh --tools-dir="$STUB_DIR"
diff "$RUN_LOG" tests/fixtures/stub-tools/linux/defaults.txt
```

The stub `defaults.txt` is the expected run-log output in order. The test proves that
no-arg dispatch matches the declared default order exactly (order + set).

### Real-Defaults Drift Test (v5 fix #3 -- Duck-2)

The mock-dispatcher baseline test above proves the dispatch mechanism works, but does
NOT protect against accidental edits to the real `DEFAULT_TOOLS` / `$DefaultTools` arrays
in production scripts. A separate test closes this gap:

```bash
# T_baseline_real_defaults (bash):
bash scripts/dev/regenerate-baseline-fixtures.sh --check
# --check mode: extract in-memory arrays, diff against committed fixtures, never write
```

```powershell
# T_baseline_real_defaults (pwsh):
& bash scripts/dev/regenerate-baseline-fixtures.sh --check
# Same script works cross-platform (uses pwsh internally for Windows extraction)
```

**`--check` mode** (integrated into the script above -- Step 2):

The `--check` flag causes the script to diff the in-memory bash arrays
`${linux_defaults[@]}` and `${win_defaults[@]}` (the latter populated from a
PowerShell `$win_defaults` array) against the committed fixture files. It **never
writes** to disk. If any diff is detected, it exits non-zero with a remediation
message. This prevents the synthetic-pass bug where writing fixtures before
diffing would always produce a match.

This test catches real-vs-fixture drift (e.g. Windows `profile` or `git` added/removed
from `$DefaultTools` without updating fixtures). It runs IN ADDITION TO the mock-dispatcher
test -- both must pass.

### Fixture Provenance

The committed fixture files (`tests/fixtures/baseline-tools-linux.txt` and
`tests/fixtures/baseline-tools-windows.txt`) are captured from **current behavior BEFORE
the customizable-install refactor lands**. They represent the explicit current default
tool order as verified by reading the pre-change source scripts.

**Current Linux order** (from `scripts/linux/setup.sh` `main` execution):
```
prereqs
zsh
uv
nvm
gh
auth
copilot-cli
squad-cli
dotfiles
git-hook
```

Linux maps to `install_prerequisites` first, then the seven `run_tool` calls, then the dotfiles block, then git-hook config in `main`.

**Current Windows order** (from `scripts/windows/setup.ps1` `Main` execution):
```
winget-check
git
uv
nvm
gh
auth
vim
psmux
copilot
squad-cli
dotfiles
profile
git-hook
```

Windows maps to the `Test-WingetAvailable` gate first, then `Install-*` / `Invoke-*`
function calls through `Install-GitHook` in `Main`. Note: `winget-check` is now a
normal `$DefaultTools` entry (paralleling Linux `prereqs`), so Fixture Provenance,
`$DefaultTools`, and `$ToolRegistry` are coherent and `T_baseline_real_defaults` passes.

> **Implementation note:** `scripts/dev/regenerate-baseline-fixtures.sh` must NOT be run
> as part of implementation. Fixtures are hand-verified from the current pre-change
> `setup.{sh,ps1}` content and committed as-is. Post-refactor, the script extracts from
> the new `DEFAULT_TOOLS` array (which must match these values).

---

## Blank CSV Token Validation

### Bash

```bash
validate_csv_shape() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "Error: flag requires at least one tool name." >&2; exit 1
  fi
  if [[ "$input" == *,,* || "$input" == ,* || "$input" == *, ]]; then
    echo "Error: empty tool name in list (check commas)." >&2; exit 1
  fi
}

split_csv() {
  local input="$1"
  validate_csv_shape "$input"
  IFS=',' read -ra TOOLS <<< "$input"
}
```

### PowerShell

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

```
Input:   flags (--only | --skip | none) + DEFAULT_TOOLS + AvailableTools
Output:  FinalToolSet: string[] (ordered, validated)

Algorithm:
  1. if --list:  print AvailableTools sorted, exit 0
  2. if --help:  print usage, exit 0
  3. if --only AND --skip: exit 1 (mutual exclusion)
  4. if --only:
       validate_csv_shape(input)
       split into names
       validate each name in AvailableTools (reject unknowns)
       FinalToolSet = only_list (user-supplied order)
  5. elif --skip:
       validate_csv_shape(input)
       split into names
       validate each name in AvailableTools (reject unknowns)
       FinalToolSet = DEFAULT_TOOLS minus skip_list (default order preserved)
  6. else:
       FinalToolSet = DEFAULT_TOOLS
  7. Dispatch FinalToolSet sequentially via run_tool()
```

---

## Flag / Grammar Specification

| Flag | Bash | PowerShell | Effect |
|------|------|-----------|--------|
| List | `--list` | `-List` | Print AvailableTools (sorted), exit 0. No install. |
| Only | `--only=a,b,c` | `-Only "a,b,c"` | Install ONLY listed tools. |
| Skip | `--skip=a,b,c` | `-Skip "a,b,c"` | Install DefaultTools EXCEPT listed. |
| Help | `--help` | `-Help` | Print usage, exit 0. |

### Syntax Rules

- Comma-separated, no spaces: `--only=delta,lazygit`
- `--only` and `--skip` are mutually exclusive (exit 1 if both)
- Unknown tool names -> exit 1 with AvailableTools list
- Empty tokens in CSV -> exit 1
- No whitespace trimming -- spaces are literal (fail as unknown)
- `-Only "a,b"` (quoted comma-string) keeps param as `[string]`, split internally

### PowerShell param block (PS 5.1 safe)

```powershell
param(
    [string]$Only = '',
    [string]$Skip = '',
    [switch]$List,
    [switch]$Help,
    [string]$ToolsDir = ''  # Test seam (hidden from -Help)
)
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Unknown tool name in `--only`/`--skip` | Exit 1: `Error: unknown tool(s): foo. Valid: <list>` |
| Both `--only` and `--skip` provided | Exit 1: `Error: --only and --skip are mutually exclusive.` |
| `--only`/`--skip` with empty value | Exit 1: `Error: flag requires at least one tool name.` |
| Empty token in CSV | Exit 1: `Error: empty tool name in list (check commas).` |
| `--list` combined with `--only`/`--skip` | `--list` wins, prints list, exit 0. |
| Unknown CLI argument | Exit 1: `Error: unknown argument: <arg>` |

### Graceful Degradation

Tools are NOT fully independent. Known chains:
- `copilot-cli`/`squad-cli` silently skip if npm absent (nvm not run first)
- `auth` silently skips if `gh` not installed

`--only=copilot-cli` on a fresh machine without nvm = exit 0, tool not functional.
Documented behavior. Future DAG (out of scope) could warn.

### Git-Hook Self-Guard (v5 fix #2 -- DK4-bis)

`git-hook` is a normal selectable tool (AlwaysRun dropped). To prevent failures when
selected without git present (e.g. `--skip=prereqs` on Linux, `-Only git-hook` on
Windows), the git-hook scripts **self-guard** and exit 0 cleanly:

**Linux (`scripts/linux/tools/git-hook.sh`):**
```bash
command -v git >/dev/null 2>&1 || { echo "git not present, skipping hooks"; exit 0; }
```

**Windows (`Install-GitHook` in `scripts/windows/tools/git-hook.ps1`):**
```powershell
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "git not present, skipping hooks"
    return
}
```

This is simpler than flag-combination disallow rules and preserves the 2-concept model.

### UX Caveats (v5 -- non-blocking fixes)

- **`--skip` validates against AvailableTools (not DefaultTools).** Consequently,
  `--skip=delta` is accepted and silently no-ops when delta is opt-in and not in
  DefaultTools. This matches POSIX-ish "skip what isn't there" semantics and is
  intentional -- it avoids breaking scripts that defensively skip tools across platforms.

- **`--skip=prereqs` is a foot-gun.** Later default tools may fail or degrade if their
  dependencies (installed by `prereqs`) are missing. This is documented intentional
  behavior; a future DAG could add warnings.

---

## Vertical Slices

### Slice 1: `--list` + `--help` + Root Forwarding + Mock Harness + Baseline Test

**User-visible behavior unlocked:** User can run `./setup.sh --list` to see available tools,
`./setup.sh --help` for usage, and confirm no-arg behavior hasn't changed.

**Can a user merge and stop?** YES -- discoverability (`--list`) and documentation
(`--help`) available immediately. No install behavior changes.

**Test proving user-visible behavior:** `T_list_output` (user runs `--list`, sees tools).

**Files touched:**
- `setup.sh` (root) -- forward `"$@"` through `run_linux_setup`
- `setup.ps1` (root) -- add `param()` block + sanitized forward hashtable (DD-4)
- `scripts/linux/setup.sh` -- arg parse, `DEFAULT_TOOLS` array, `--tools-dir` seam, extract prereqs/dotfiles/git-hook into `tools/`
- `scripts/linux/tools/prereqs.sh` (new, extracted from `install_prerequisites()`)
- `scripts/linux/tools/dotfiles.sh` (new, extracted from inline dotfiles block)
- `scripts/linux/tools/git-hook.sh` (new, extracted from inline git-hook block)
- `scripts/windows/setup.ps1` -- `param()` block, `$DefaultTools`, `$ToolRegistry` (add `git-hook`), `-ToolsDir` seam
- `tests/test_setup_flags.sh` (new)
- `tests/test_setup_flags_pwsh.ps1` (new)
- `tests/fixtures/stub-tools/linux/*.sh` (new)
- `tests/fixtures/stub-tools/windows/*.ps1` (new)
- `tests/fixtures/stub-tools/linux/defaults.txt` (new)
- `tests/fixtures/stub-tools/windows/defaults.txt` (new)
- `tests/fixtures/baseline-tools-linux.txt` (new)
- `tests/fixtures/baseline-tools-windows.txt` (new)
- `scripts/dev/regenerate-baseline-fixtures.sh` (new)

**Named Test Scenarios:**

```
# tests/test_setup_flags.sh
T_list_output:       --list prints AvailableTools alphabetically, exit 0
T_list_no_install:   --list with --tools-dir produces no RUN_LOG entries
T_help_output:       --help prints usage containing --list, --only, --skip
T_help_exit:         --help exits 0
T_help_no_toolsdir:  --help output does NOT contain 'tools-dir'
T_baseline_noarg:    no-arg with --tools-dir produces run-log matching defaults.txt
T_baseline_real_defaults: regenerate-baseline-fixtures.sh --check exits 0 (real arrays match fixtures)
T_unknown_arg:       --foo exits 1 with error message
T_root_list:         ./setup.sh --list = scripts/linux/setup.sh --list
T_root_help:         ./setup.sh --help exits 0
T_root_only:         ./setup.sh --only=alpha --tools-dir=... installs only alpha (root forwarding)
T_root_skip:         ./setup.sh --skip=bravo --tools-dir=... excludes bravo (root forwarding)
T_list_skip_wins:    --list --skip=bravo prints list only (--list wins), exit 0

# tests/test_setup_flags_pwsh.ps1
T_list_output:       -List prints AvailableTools alphabetically, exit 0
T_list_no_install:   -List with -ToolsDir produces no RUN_LOG entries
T_help_output:       -Help prints usage containing -List, -Only, -Skip
T_help_exit:         -Help exits 0
T_help_no_toolsdir:  -Help output does NOT contain 'ToolsDir'
T_baseline_noarg:    no-arg with -ToolsDir produces run-log matching defaults.txt
T_baseline_real_defaults: regenerate-baseline-fixtures.sh --check exits 0 (real arrays match fixtures)
T_param_ps51:        param() block parses without error under PS 5.1
T_root_list:         .\setup.ps1 -List = scripts\windows\setup.ps1 -List
T_root_help:         .\setup.ps1 -Help exits 0
T_root_only:         .\setup.ps1 -Only 'alpha' -ToolsDir ... installs only alpha (root forwarding)
T_root_skip:         .\setup.ps1 -Skip 'bravo' -ToolsDir ... excludes bravo (root forwarding)
T_list_skip_wins:    -List -Skip 'bravo' prints list only (-List wins), exit 0
```

**Done Criteria:**
- [ ] `--list` / `-List` prints AvailableTools (alpha sorted), exit 0
- [ ] `--help` / `-Help` prints usage, exit 0
- [ ] Hidden flags absent from help output
- [ ] No-arg run invokes exactly DefaultTools in order (baseline-diff via mock harness)
- [ ] Real-defaults drift test passes (`regenerate-baseline-fixtures.sh --check`)
- [ ] Root entrypoints forward flags correctly
- [ ] Mock harness (`--tools-dir` / `-ToolsDir`) functional
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

### Slice 2: `--only` Flag (Selective Install)

**User-visible behavior unlocked:** User can run `./setup.sh --only=gh,uv` to install
only specific tools. This is the primary use case for #468.

**Can a user merge and stop?** YES -- selective install works. `--skip` is just a
convenience inverse.

**Test proving user-visible behavior:** `T_only_single` (user runs `--only=alpha`, only alpha installs).

**Files touched:**
- `scripts/linux/setup.sh` -- `validate_csv_shape`, `split_csv`, selection logic
- `scripts/windows/setup.ps1` -- `Split-ToolList`, `-Only` handling, dispatch filter
- `tests/test_setup_flags.sh` (scenarios appended)
- `tests/test_setup_flags_pwsh.ps1` (scenarios appended)

**Named Test Scenarios:**

```
# Bash
T_only_single:            scripts/linux/setup.sh --only=alpha installs only alpha (direct child path)
T_only_multi:             --only=alpha,bravo installs alpha+bravo in user order
T_only_unknown:           --only=bogus exits 1 with AvailableTools list
T_only_empty:             --only= exits 1
T_only_optin:             --only=delta works (not in DEFAULT_TOOLS)
T_only_blank_trailing:    --only=alpha, exits 1
T_only_blank_consecutive: --only=alpha,,bravo exits 1
T_only_blank_leading:     --only=,alpha exits 1
T_only_space:             --only=' alpha' exits 1 (no trim)
T_git_hook_no_git_safe:   --only=git-hook with git absent -> exit 0 + "skipping" message

# PowerShell
T_only_single:            scripts\windows\setup.ps1 -Only 'alpha' installs only alpha (direct child path)
T_only_multi:             -Only 'alpha,bravo' installs alpha+bravo
T_only_unknown:           -Only 'bogus' exits 1
T_only_empty:             -Only '' exits 1
T_only_optin:             -Only 'delta' works
T_only_blank_trailing:    -Only 'alpha,' exits 1
T_only_blank_consecutive: -Only 'alpha,,bravo' exits 1
T_only_blank_leading:     -Only ',alpha' exits 1
T_only_space:             -Only ' alpha' exits 1
T_only_ps51:              parsing works under PS 5.1
T_git_hook_no_git_safe:   -Only 'git-hook' with git absent -> exit 0 + "skipping" message
```

**Done Criteria:**
- [ ] `--only` / `-Only` installs exactly named tools, nothing else
- [ ] Unknown tool -> exit 1 + AvailableTools list
- [ ] Empty value -> exit 1
- [ ] Blank CSV tokens -> exit 1
- [ ] Spaces not trimmed
- [ ] `git-hook` self-guards when git absent (exit 0 + skip message, both platforms)
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

---

### Slice 3: `--skip` Flag + Mutual Exclusion

**User-visible behavior unlocked:** User can run `./setup.sh --skip=auth` to install
everything except specific tools. Full selection control is now available.

**Can a user merge and stop?** YES -- all flag functionality complete.

**Test proving user-visible behavior:** `T_skip_single` (user runs `--skip=bravo`, bravo excluded).

**Files touched:**
- `scripts/linux/setup.sh` -- skip logic, conflict check
- `scripts/windows/setup.ps1` -- `-Skip` handling, subtract, conflict
- `tests/test_setup_flags.sh` (scenarios appended)
- `tests/test_setup_flags_pwsh.ps1` (scenarios appended)

**Named Test Scenarios:**

```
# Bash
T_skip_single:            scripts/linux/setup.sh --skip=bravo installs all DEFAULT_TOOLS except bravo (direct child path)
T_skip_multi:             --skip=bravo,charlie excludes both
T_skip_unknown:           --skip=bogus exits 1
T_skip_empty:             --skip= exits 1
T_skip_conflict:          --only=alpha --skip=bravo exits 1
T_list_plus_only:         --list --only=alpha prints list only (--list wins)
T_list_plus_skip:         --list --skip=bravo prints list only (--list wins), exit 0
T_skip_blank_trailing:    --skip=bravo, exits 1
T_skip_blank_consecutive: --skip=bravo,,charlie exits 1
T_no_selection_persistence: --only=uv then no-arg -> second run produces full DefaultTools log
T_git_hook_skip_path_safe:  --skip=prereqs with git absent -> exit 0 + git-hook emits skip message

# PowerShell
T_skip_single:            scripts\windows\setup.ps1 -Skip 'bravo' installs all DefaultTools except bravo (direct child path)
T_skip_multi:             -Skip 'bravo,charlie' excludes both
T_skip_unknown:           -Skip 'bogus' exits 1
T_skip_empty:             -Skip '' exits 1
T_skip_conflict:          -Only 'alpha' -Skip 'bravo' exits 1
T_list_plus_only:         -List -Only 'alpha' prints list only (-List wins), exit 0
T_list_plus_skip:         -List -Skip 'bravo' prints list only (-List wins), exit 0
T_skip_blank_trailing:    -Skip 'bravo,' exits 1
T_skip_blank_consecutive: -Skip 'bravo,,charlie' exits 1
T_skip_ps51:              parsing works under PS 5.1
T_no_selection_persistence: -Only 'uv' then no-arg -> second run produces full DefaultTools log
T_git_hook_skip_path_safe:  -Skip 'git' with git absent -> exit 0 + git-hook emits skip message
```

**Done Criteria:**
- [ ] `--skip` / `-Skip` excludes named tools from DefaultTools
- [ ] Mutual exclusion enforced (exit 1)
- [ ] `--list` wins over `--only` and `--skip` (both platforms)
- [ ] Blank CSV tokens -> exit 1
- [ ] No selection state persists between invocations (idempotency, both platforms)
- [ ] Git-hook self-guards under skip-path scenarios (both platforms)
- [ ] All tests pass in `validate-linux`, `validate-powershell`, AND `validate-ps51`

**`T_no_selection_persistence` detail (v6 fix #5):**
```bash
# Bash
setup_harness
bash scripts/linux/setup.sh --only=uv --tools-dir="$STUB_DIR"
assert_log_equals "uv"
: > "$RUN_LOG"
bash scripts/linux/setup.sh --tools-dir="$STUB_DIR"
assert_log_equals "$(cat tests/fixtures/stub-tools/linux/defaults.txt)"
```
```powershell
# PowerShell
Setup-Harness
& scripts\windows\setup.ps1 -Only 'uv' -ToolsDir $StubDir
Assert-LogEquals @('uv')
Clear-Content $script:RunLog
& scripts\windows\setup.ps1 -ToolsDir $StubDir
Assert-LogEquals (Get-Content "tests\fixtures\stub-tools\windows\defaults.txt")
```
This proves flags are pure arguments -- no persisted selection state (file, env var, or
registry) leaks between invocations.

**`T_git_hook_skip_path_safe` detail (v6 fix #6):**

Use the normal stub directory for non-hook tools, but keep the `git-hook` fixture as a
copy of the real self-guard (`command -v git >/dev/null 2>&1` / `Get-Command git
-ErrorAction SilentlyContinue`) so the test stays side-effect-free while proving the
skip/default path reaches the hook guard.

```bash
# Bash: hide git from PATH, run with --skip=prereqs (git-hook still in DefaultTools)
setup_harness
PATH_NO_GIT=$(echo "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(command -v git)")" | tr '\n' ':')
PATH="$PATH_NO_GIT" bash scripts/linux/setup.sh --skip=prereqs --tools-dir="$STUB_DIR" 2>&1 | grep -q "skipping"
# Assert exit 0 (overall run succeeds even though git-hook skipped itself)
```
```powershell
# PowerShell: hide git from PATH, run with -Skip 'git' (git-hook still runs)
Setup-Harness
$origPath = $env:Path
$env:Path = ($env:Path -split ';' | Where-Object { $_ -notlike '*Git*' }) -join ';'
& scripts\windows\setup.ps1 -Skip 'git' -ToolsDir $StubDir 2>&1 | Should -Match "skipping"
$env:Path = $origPath
# Assert exit 0
```

---

### Slice 4: README + e2e Hardening

**User-visible behavior unlocked:** Documentation complete. Users discover the feature
from the README. e2e proves flags work end-to-end on CI runners.

**Can a user merge and stop?** YES -- feature fully documented and e2e-proven.

**Test proving user-visible behavior:** README visible to all users; e2e proves real installs.

**Files touched:**
- `README.md` -- new "Selective Install" section with examples
- `.github/workflows/e2e-install.yml` -- add `--list` and `--only` smoke steps to existing e2e jobs
- `.github/workflows/validate.yml` -- add flag test steps to `validate-linux`, `validate-powershell`, and `validate-ps51`; add `--list` smoke step to existing `validate-macos`

**e2e Scenarios (in `.github/workflows/e2e-install.yml`):**

```
E2E_list_linux:   job e2e-linux ("E2E - Linux"), step "Selective install list smoke (Linux)": ./setup.sh --list exits 0
E2E_only_linux:   job e2e-linux ("E2E - Linux"), step "Selective install only smoke (Linux)": ./setup.sh --only=gh exits 0 and gh available
E2E_list_macos:   job e2e-macos ("E2E - macOS"), step "Selective install list smoke (macOS)": ./setup.sh --list exits 0
E2E_only_macos:   job e2e-macos ("E2E - macOS"), step "Selective install only smoke (macOS)": ./setup.sh --only=gh exits 0 and gh available
E2E_list_win:     job e2e-windows ("E2E - Windows"), step "Selective install list smoke (Windows)": .\setup.ps1 -List exits 0
E2E_only_win:     job e2e-windows ("E2E - Windows"), step "Selective install only smoke (Windows)": .\setup.ps1 -Only "gh" exits 0 and gh available
```

**Validate workflow scenarios (in `.github/workflows/validate.yml`):**

```
validate-linux ("Validate Linux Setup"), step "Run setup flag tests": bash tests/test_setup_flags.sh
validate-macos ("Validate macOS Setup"), step "Selective install list smoke (macOS)": bash setup.sh --list
validate-powershell ("Validate PowerShell Functions"), step "Run setup flag tests (PowerShell)": pwsh tests/test_setup_flags_pwsh.ps1
validate-ps51 ("Validate PowerShell 5.1 Compatibility"), step "Run setup flag tests (PS 5.1)": powershell -ExecutionPolicy Bypass -File tests\test_setup_flags_pwsh.ps1
```

> Verified workflow targets: e2e jobs live in `.github/workflows/e2e-install.yml`
> (`e2e-linux`, `e2e-macos`, `e2e-windows`). Unit/compatibility validation lives in
> `.github/workflows/validate.yml` (`validate-linux`, `validate-macos`,
> `validate-powershell`, `validate-ps51`).

**Done Criteria:**
- [ ] README documents all flags with examples
- [ ] README notes that `--only` does not auto-include prerequisites
- [ ] e2e exercises `--list` + `--only` on all platforms (Linux, macOS, Windows) via root entrypoints
- [ ] macOS selective-install explicitly covered (`E2E_only_macos`)
- [ ] All existing tests still pass (no regression)

---

## Cross-Platform Parity Contract

| Test case | Bash | PS 7+ | PS 5.1 | Slice |
|-----------|:---:|:---:|:---:|:---:|
| `--list` prints AvailableTools sorted | x | x | x | 1 |
| `--help` prints usage | x | x | x | 1 |
| No-arg = baseline fixture (mock harness) | x | x | x | 1 |
| Root entrypoint forwards `--list` | x | x | x | 1 |
| Root entrypoint forwards `--only`/`--skip` | x | x | x | 1 |
| Hidden flag absent from help | x | x | x | 1 |
| `--list` wins over `--skip` | x | x | x | 1 |
| `--only=a,b` installs only a, b | x | x | x | 2 |
| Unknown tool in `--only` -> exit 1 | x | x | x | 2 |
| Empty `--only` -> exit 1 | x | x | x | 2 |
| Blank CSV token -> exit 1 | x | x | x | 2 |
| `--skip=a` excludes a | x | x | x | 3 |
| `--only` + `--skip` conflict -> exit 1 | x | x | x | 3 |
| Unknown tool in `--skip` -> exit 1 | x | x | x | 3 |
| `--list` wins over `--only` | x | x | x | 3 |
| No selection state persists between runs | x | x | x | 3 |
| Git-hook self-guards via skip-path | x | x | x | 3 |

---

## CI Matrix Requirements

All slices require green on:
- `validate-linux` -- bash tests via `bash tests/test_setup_flags.sh`
- `validate-powershell` -- PS 7+ via `pwsh tests/test_setup_flags_pwsh.ps1`
- **`validate-ps51`** -- PS 5.1 via `powershell -File tests\test_setup_flags_pwsh.ps1`

Reference: `.github/workflows/validate.yml` lines 285+.

---

## Slice Ordering and Dependencies

```
Slice 1 (--list + --help + root forwarding + mock harness + baseline)
  `-- Slice 2 (--only + CSV validation)   <- #466/#467 can land here
        `-- Slice 3 (--skip + conflict)
              `-- Slice 4 (README + e2e)
```

#466 (delta) and #467 (lazygit) need Slice 2 merged. They add tool scripts + registry
entries (3-line pattern). NOT added to DefaultTools (opt-in only).

---

## Out of Scope

- Interactive prompt / TUI
- Manifest file
- Tool dependency DAG / auto-prerequisites
- Rewriting existing tool installer scripts
- Uninstall support
- Auto-discovery on Windows
- `--only a b` (space-separated) -- comma-string is canonical
- Making `--only` auto-include prerequisites (explicit opt-out of magic)

---

## Blocker Resolution Map

| Blocker | Resolution |
|---------|-----------|
| D1 (root `$@` forwarding) | Slice 1: `run_linux_setup "$@"` in all routing branches + sanitized PS hashtable (DD-4) |
| D2 (`--tools-dir` doesn't cover AlwaysRun) | DD-1: AlwaysRun dropped -- single `--tools-dir` seam covers everything |
| D3 (blank trailing CSV) | DD-5: pre-split regex + post-split guard, tested in Slice 2 |
| D4 (baseline Makefile incoherent) | DD-3: standalone script under `scripts/dev/`, no Makefile, no `--dry-extract-defaults` |
| DK1 (AlwaysRun/registry overlap) | DD-1: AlwaysRun dropped -- dotfiles is a normal DefaultTool, single classification |
| DK2 (mock harness doesn't cover AlwaysRun) | DD-1: single `--tools-dir` seam covers all phases uniformly |
| DK3 (PS splat collision) | DD-4: sanitized forward-hashtable excludes internal params |
| DK4 (git-hook unsafe when git absent) | DD-1: git-hook is a normal tool -- `--only=uv` never triggers it |
| DK4-bis (git-hook via flag paths) | v5: git-hook self-guards (`command -v git` / `Get-Command git`), `T_git_hook_no_git_safe` |
| DK5 (hidden flags unprotected) | Slice 1: `T_help_no_toolsdir` negative assertions on both platforms |
| Donald-1 (baseline format mismatch) | v5: stubs log bare tool names -- `RUN_LOG` directly diffs against `defaults.txt` |
| Duck-2 (real defaults drift unprotected) | v5: `T_baseline_real_defaults` + `--check` mode in regeneration script |

