# Skill: Profile Host-Query Resolution

**Confidence:** high (implemented and tested in #442)
**Owner:** Pluto (Config Engineer)
**Issue:** #442

---

## What

When writing content to a PowerShell profile, do NOT assume the profile path is
`$HOME\Documents\PowerShell\...`. On OneDrive KFM (Known Folder Move) machines,
`$PROFILE` resolves to `OneDrive\Documents\...` instead. Hardcoding the path
causes the profile block to be written to the wrong file; aliases silently fail.

The correct approach is to spawn the target host executable as a subprocess and
query its live `$PROFILE` value at runtime.

---

## Pattern

### Invoke-HostQuery

```powershell
function Invoke-HostQuery {
    param([string]$Exe)
    & $Exe -NoProfile -NonInteractive -Command '$PROFILE'
}
```

- Spawns `$Exe` (e.g., `powershell` or `pwsh`) as a subprocess
- Passes `-NoProfile` so no existing profile modifies the output
- Returns the subprocess stdout (which includes the profile path)
- LASTEXITCODE is set to the subprocess exit code

### Resolve-ProfilePath

```powershell
function Resolve-ProfilePath {
    param([string]$Exe, [string]$Fallback)
    $lines = Invoke-HostQuery -Exe $Exe
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN]  $Exe query failed (exit $LASTEXITCODE) -- using fallback: $Fallback"
        return $Fallback
    }
    $resolved = ($lines | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1)
    if (-not $resolved) {
        Write-Host "[WARN]  $Exe returned empty output -- using fallback: $Fallback"
        return $Fallback
    }
    Write-Host "[INFO]  Resolved $Exe profile: $resolved"
    return $resolved
}
```

**Key decisions:**
- Use `Write-Host` (not `Write-Info`/`Write-Output`) inside this function.
  `Write-Info` uses `Write-Output`, which contaminates the return stream.
  Callers that capture the return value would receive both the path AND the
  log lines. `Write-Host` writes to stream 6 (host display only).
- Extract the LAST non-empty line from subprocess output. Some shells print
  warnings or telemetry before the path; last-line extraction handles this.
- Fall back to the hardcoded path on any failure (exe not found, non-zero exit,
  empty output). This preserves behavior on systems without the target host.

---

## Calling pattern (Write-PowerShellProfile)

```powershell
function Write-PowerShellProfile {
    param(
        [string]$Ps51Fallback = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
        [string]$Ps7Fallback  = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    )
    $local:ps51Path = Resolve-ProfilePath -Exe 'powershell' -Fallback $Ps51Fallback
    $local:ps7Path  = Resolve-ProfilePath -Exe 'pwsh'       -Fallback $Ps7Fallback
    $local:profilePaths = @($local:ps51Path, $local:ps7Path) |
        Sort-Object { $_.ToLower() } -Unique
    # ... write loop ...
}
```

**Why optional params?** Production callers use `Write-PowerShellProfile` with
no args (resolved paths at runtime). Test callers inject temp paths via
`-Ps51Fallback`/`-Ps7Fallback` to avoid writing to the real `$PROFILE`.
This is the v5.2-D1 test-injection seam.

---

## Test mocking pattern

In the test file, redefine `Invoke-HostQuery` in script scope before calling
`Write-PowerShellProfile`:

```powershell
$global:LASTEXITCODE = 0
function Invoke-HostQuery { param([string]$Exe) return $mockPath }
Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7
```

Then reset after each test. This avoids spawning real subprocesses in tests
and makes the resolved path deterministic.

---

## Anti-patterns

- **Do NOT hardcode `$HOME\Documents\...`** as the profile path in any new code.
  Always use `Resolve-ProfilePath` or pass the path as a parameter.
- **Do NOT call `Write-Info`/`Write-Warn` inside `Resolve-ProfilePath`** or any
  other value-returning helper. Use `Write-Host` instead.
- **Do NOT assume `Sort-Object -Unique` returns an array.** When dedup collapses
  to 1 item it returns a scalar string. Use `@($profilePaths)[0]` and
  `@($profilePaths).Count` in diagnostics to force array semantics.
- **Do NOT start idempotency test files as empty.** The strip regex
  `(?s)\r?\n# BEGIN...# END\r?\n?` requires a preceding newline before the
  BEGIN marker. Seed idempotency test files with pre-existing content.

---

## Related Skills

- `.squad/skills/ps51-ascii-safety/SKILL.md` -- ASCII-only requirement for .ps1 files
- `.squad/skills/pwsh-lastexitcode/SKILL.md` -- LASTEXITCODE reset patterns
- `.squad/skills/sourced-lib-pattern/SKILL.md` -- dot-source vs inline function tradeoffs

---

## References

- Issue: #442
- Plan: `docs/plans/441-profile-path.md` (v5.2)
- PR: squad/442-profile-path-impl
