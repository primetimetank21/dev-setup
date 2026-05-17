# Skill: PowerShell Exit Code Discipline

**Confidence:** high (confirmed by PR #277 post-mortem)
**Owner:** Mickey (Lead)
**Issue:** #288 (surfaced by #277)

---

## What

PowerShell tracks the exit code of the most recent native command in the
automatic variable `$LASTEXITCODE`. That value **persists across `&` script-call
boundaries** -- when a script ends with a failed-but-expected native command,
the caller (or the GitHub Actions `pwsh` step wrapper) sees the non-zero code
and fails, even though the script logically succeeded.

Every Windows script invoked via `& .\script.ps1` from a workflow `shell: pwsh`
step must end with `$LASTEXITCODE == 0`, or reset it explicitly after any
expected-failure native command.

## Why: the anti-pattern

```powershell
# scripts/windows/uninstall.ps1
& git config --unset-all core.hooksPath 2>&1 | Out-Null
# $LASTEXITCODE == 5 when key was never set -- this is the expected case
# script body ends here
```

Called from a workflow:

```yaml
- shell: pwsh
  run: |
    & .\scripts\windows\uninstall.ps1
```

The GitHub Actions `pwsh` wrapper inspects `$LASTEXITCODE` after the step body
runs. It sees `5` and **fails the step** with no useful diagnostic -- the
script printed `[SKIP] core.hooksPath was not set`, then exited "cleanly", and
yet the step is red.

This is the exact failure mode that bit PR #277. The fix was mechanical:
`$global:LASTEXITCODE = 0` after the call.

### Why `$ErrorActionPreference = 'Stop'` does not save you

Native-command non-zero exits do **not** raise terminating errors in
PowerShell, even under `Set-StrictMode -Version Latest` +
`$ErrorActionPreference = 'Stop'`. `$LASTEXITCODE` is set silently. You must
inspect and reset it manually for any command whose non-zero exit is part of
its contract.

### Why `try/catch` does not save you either

`catch` blocks only fire on terminating PowerShell errors. Native binaries
exiting non-zero produce no terminating error, so the `try` block completes,
the `catch` is skipped, and `$LASTEXITCODE` leaks past the function/script
boundary unchanged.

## The canonical pattern

### 1. Inspect, classify, reset

```powershell
& git config --unset-all core.hooksPath 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "core.hooksPath unset"
} elseif ($LASTEXITCODE -in @(1, 5)) {
    Write-Skip "core.hooksPath was not set (nothing to unset)"
} else {
    Write-Warn "git config --unset-all exited $LASTEXITCODE (unexpected; proceeding)"
}
$global:LASTEXITCODE = 0
```

Three rules:

1. **Inspect immediately.** Read `$LASTEXITCODE` on the next line after the
   native call. Any intervening cmdlet (`Write-Host`, `Out-Null`, etc.) leaves
   it intact -- but readability suffers if the inspection drifts.
2. **Classify the exit codes you expect.** Document them inline. `git
   config --unset-all` returns `5` for "key not present" and `1` for some
   older git builds; treat both as the expected no-op.
3. **Reset `$global:LASTEXITCODE = 0`** after the conditional. Local `$LASTEXITCODE
   = 0` does NOT work -- `$LASTEXITCODE` is an automatic variable in the
   global scope, so a local assignment shadows it without resetting the value
   the parent shell will read.

### 2. Reset at the script's last line if the body might end on a non-zero

When a script's last meaningful native command can fail expectedly (e.g.,
`& git rev-parse --git-dir` guarding "are we in a repo?"), add a trailing
`$global:LASTEXITCODE = 0` immediately before the script's final newline.
That guarantees the `&`-caller and the GH Actions pwsh wrapper see a clean
boundary regardless of which control-flow branch ran.

### 3. Swallow stderr only when the message is noise

```powershell
& git config core.hooksPath 2>$null
```

Use `2>$null` (or `2>&1 | Out-Null`) only when the stderr is a user-facing
distraction (e.g., `fatal: not in a git directory`). Do **not** rely on
stderr redirection to mask exit codes -- the exit code is still set.

## Detection

In code review, flag the following patterns:

1. **Workflow `shell: pwsh` step calling a project script with `&`.**
   ```yaml
   - shell: pwsh
     run: |
       & .\scripts\windows\foo.ps1
   ```
   The called script must end with `$LASTEXITCODE == 0`. Verify the script's
   last native call is either guaranteed-success or followed by an explicit
   reset.

2. **Inside any `.ps1` invoked from such a step**, search for expected-failure
   native commands:
   - `git config --unset` / `git config --unset-all` (exits 5 when key absent)
   - `git config <key>` reading an unset key (exits 1)
   - `git rev-parse` outside a repo (exits 128)
   - `npm uninstall -g <pkg>` for an uninstalled package (exits 1)
   - `winget uninstall <id>` for a missing package (exits non-zero)
   - `gh api <path>` for a 404 resource (exits 1)
   - `gh auth status` for the not-authed case (exits 1)

   Each must be followed (eventually, before script exit) by `$global:LASTEXITCODE = 0`
   on every code path where the non-zero exit was the expected outcome.

3. **Use of `try/catch` to "guard" native commands.** A reviewer comment is
   warranted: `catch` does not fire on native non-zero. The author probably
   wants an `if ($LASTEXITCODE -ne 0)` check + explicit reset.

## Known sites in this repo

Audit performed against `develop` @ `ce53853` for issue #288.

### Script-call boundaries (workflow -> script)

| File:Line | Call | Risk | Mitigation status |
|---|---|---|---|
| `.github/workflows/e2e-install.yml:350` | `& .\setup.ps1` (first run) | Inherits `$LASTEXITCODE` from setup.ps1's last native call | Implicit OK in CI: `actions/checkout@v4` runs before, so `Install-GitHook`'s final native call (`git config core.hooksPath hooks`) exits 0. **No explicit reset.** |
| `.github/workflows/e2e-install.yml:432` | `& .\setup.ps1` (idempotency second run) | Same as above | Same. |
| `.github/workflows/e2e-install.yml:475` | `& .\scripts\windows\uninstall.ps1` | Was leaking `5` from `git config --unset-all` | **Fixed in PR #277** by `$global:LASTEXITCODE = 0` at `uninstall.ps1:125`. |

### Expected-failure native commands inside `scripts/windows/`

| File:Line | Command | Expected non-zero exit | Mitigation status |
|---|---|---|---|
| `scripts/windows/uninstall.ps1:117` | `& git config --unset-all core.hooksPath 2>&1 \| Out-Null` | `5` (key unset) or `1` (older git) | **Mitigated** at line 125: `$global:LASTEXITCODE = 0`. Canonical example for this skill. |
| `scripts/windows/setup.ps1:38` | `& git rev-parse --git-dir 2>$null \| Out-Null` | `128` if not in a git repo | **Mitigated** in PR #292: `$global:LASTEXITCODE = 0` after the if/else block in `Install-GitHook`. |
| `scripts/windows/tools/auth.ps1:28` | `& gh auth status 2>&1 \| Out-String` | `1` when not authenticated | **Mitigated** in PR #292: `$global:LASTEXITCODE = 0` after the try/catch block. |
| `scripts/windows/tools/auth.ps1:36` | `& gh api user --jq '.login' 2>&1 \| Out-String` | `1` on 404 / auth failure | **Mitigated** in PR #292: `$global:LASTEXITCODE = 0` after the try/catch block. |
| `scripts/windows/tools/auth.ps1:73` | `& gh auth status 2>&1 \| Out-String` (post-login verify) | `1` if login failed | **Mitigated** in PR #292: `$global:LASTEXITCODE = 0` after the try/catch block. |
| `scripts/windows/tools/auth.ps1:81` | `& gh api user --jq '.login' 2>&1 \| Out-String` (post-login verify) | `1` on 404 / auth failure | **Mitigated** in PR #292: `$global:LASTEXITCODE = 0` after the try/catch block. |

There are **no** `npm uninstall`, `winget uninstall`, or other listed
expected-failure call sites currently in `scripts/windows/`. If those are
added in the future, they must follow the canonical pattern above.

### Follow-up TODOs (not in scope for #288)

All five sites identified below were hardened in PR #292 (closes #292):

- `scripts/windows/setup.ps1:38` -- `$global:LASTEXITCODE = 0` added after
  `Install-GitHook`'s if/else block. **Done.**
- `scripts/windows/tools/auth.ps1` -- all four `& gh ...` blocks now reset
  `$global:LASTEXITCODE = 0` after the local conditional reads the value.
  **Done.**

## Examples

### From PR #277 -- the bug that triggered this skill

Before (`scripts/windows/uninstall.ps1` pre-fix):

```powershell
# (no unset call -- core.hooksPath was leaking from install)
```

After (`scripts/windows/uninstall.ps1` lines 117-125):

```powershell
& git config --unset-all core.hooksPath 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "core.hooksPath unset (git falls back to per-repo .git/hooks)"
} elseif ($LASTEXITCODE -in @(1, 5)) {
    Write-Skip "core.hooksPath was not set (nothing to unset)"
} else {
    Write-Warn "git config --unset-all exited $LASTEXITCODE (unexpected; proceeding)"
}
$global:LASTEXITCODE = 0
```

The trailing `$global:LASTEXITCODE = 0` is the load-bearing line: without
it, the GH Actions `pwsh` wrapper sees exit `5` from the very common
"hookspath was never set" path and fails the uninstall step.

### Counter-example -- the trap to avoid

```powershell
# WRONG -- local assignment shadows but doesn't reset the global automatic.
& git config --unset-all core.hooksPath 2>$null
$LASTEXITCODE = 0   # creates a local; the global is still 5

# Also WRONG -- catch never fires on native non-zero exit.
try {
    & git config --unset-all core.hooksPath
} catch {
    # this block is dead code for native command failures
}
```

## References

- Issue #288 -- this skill's origin
- PR #277 -- the bug that surfaced the pattern (`fix(uninstall): unset
  core.hooksPath`)
- CONTRIBUTING.md section "PowerShell Exit Code Discipline"
- `.squad/skills/tool-version-pin/SKILL.md` -- structural template
- PowerShell docs: [`$LASTEXITCODE` automatic variable](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables)
- GitHub Actions docs: [`pwsh` shell wrapper exit semantics](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#exit-codes-and-error-action-preference)
