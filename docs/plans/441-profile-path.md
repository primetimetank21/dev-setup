---
issue: 441
title: "Profile path fix on OneDrive/KFM systems"
status: implemented
created: 2026-05-27
updated: 2026-06-13
---

# Plan: #441 -- Profile path fix on OneDrive/KFM systems

## 1. Problem

`profile.ps1` hardcodes `$HOME\Documents\...` as the profile path. On OneDrive KFM systems, PowerShell's actual `$PROFILE` resolves to `OneDrive\Documents\...`. The dev-setup block is written to a file that is never sourced; aliases silently fail to appear in new terminals.

---

## 2. Decision: Scope

**IN (this PR):**
1. Query each host for its `$PROFILE` and write there
2. Fallback to hardcoded path when host absent
3. Case-insensitive deduplication for Windows paths
4. Legacy cleanup of orphaned blocks at old hardcoded paths
5. Test coverage proving the fix via mocked `Invoke-HostQuery`

**OUT (file as follow-up if reported):**
- CLM, UNC paths, long paths > 260 chars, Unicode usernames, partial/corrupt blocks -- file issue if reported
- `pwsh` not on PATH after same-session install -- existing #251 pattern applies
- PS preview/daily-build variants (`pwsh-preview`) -- known limitation

---

## 3. Decisions Made

**1. `$PROFILE` (CurrentUserCurrentHost) vs `$PROFILE.CurrentUserAllHosts`**

Decision: Use `$PROFILE` (CurrentUserCurrentHost). Host-specific aliases belong in host-specific profiles. VSCode terminal runs pwsh.exe directly and is covered by CurrentHost. Earl ratified 2026-05-27.

**2. Test harness: Pester vs existing `Test-Scenario`**

Decision: Use the existing `Test-Scenario` harness with the `Invoke-HostQuery` mock pattern. `$PROFILE` is read-only in PS 7+ and `$TestDrive` is Pester-specific. Adding Pester is scope creep.

**3. Uninstall lib dependency**

Decision: Inline the resolver in `uninstall.ps1` (Option A). `uninstall.ps1` must work even if the user deletes the repo after install. Resolver is ~30 lines inlined -- acceptable for self-containment.

**4. `Invoke-HostQuery` wrapper**

Decision: Mandate `Invoke-HostQuery` in production code. Testability requires a seam. Mock must be defined AFTER dot-sourcing `profile.ps1` or the dot-source overwrites it.

**v3-D1. GG-6 direction -- Select-Object -Last 1 with -NoLogo**

Decision: Change to `-Last 1`; add `-NoLogo`. Verified: `powershell -NoProfile -NonInteractive -Command '$PROFILE'` emits path-only (no banner). `-NoLogo` explicit suppression; `-Last 1` defense-in-depth for edge-case preamble. GG-6 assertion upgraded to `$result -eq $expectedMockPath`.

**v3-D2. $LASTEXITCODE check**

Decision: Check `$LASTEXITCODE -ne 0` after `Invoke-HostQuery`. `& $Exe` exits non-zero without throwing; `try/catch` does not fire. Fallback now logs the exit code explicitly. GG-7 added.

**v3-D3. GG-4 expands to dual-orphan test**

Decision: GG-4 seeds BOTH legacy paths simultaneously and asserts BOTH stripped. One-path test cannot catch a loop-break bug after the first match.

**v3-D4. C-2/C-3 guarded in PS7+**

Decision: Guard C-2 and C-3 with proper skip. The `$PROFILE` automatic variable is conceptually read-only in PowerShell (per Microsoft Learn); assigning to it is unsupported and may cause issues in test contexts. Full refactor deferred; behavior these tests cover is superseded by this PR. Concrete mechanism: move the `$PROFILE = $path` assignment INSIDE the Test-Scenario body (it was erroneously outside as setup code), then open with `if ($PSVersionTable.PSVersion.Major -ge 7) { Write-Warning '[SKIPPED] C-2: PS7+ -- $PROFILE conceptually read-only; covered by GG tests'; return }`. This ensures the assignment never fires on PS7+ and the skip reason is logged.

**v3-D5. Sort-Object dedup -- confirmed correct, no change**

Decision: `Sort-Object { $_.ToLower() } -Unique` is confirmed correct: `-Unique` keys on the script block output; equal `.ToLower()` values are deduplicated. GG-3 confirms empirically. No algorithm change.

**v5.2-D1. `Write-PowerShellProfile` parameter contract**

Decision: `Write-PowerShellProfile` accepts optional `-Ps51Fallback`/`-Ps7Fallback` parameters. Defaults equal production lines 17-18. Production: call with no arguments (defaults apply; zero callsite changes). Tests: pass explicit temp-dir paths to redirect all disk writes away from real `$HOME` profile files. `$beginMarker`/`$endMarker` require no test override and remain `$local:` constants inside the function.

---

## 4. Algorithm

```powershell
# In profile.ps1 (and inlined in uninstall.ps1):

function Invoke-HostQuery {
    param([string]$Exe)
    & $Exe -NoProfile -NonInteractive -NoLogo -Command '$PROFILE' 2>$null
}

function Resolve-ProfilePath {
    param([string]$HostExe, [string]$FallbackPath)

    if (-not (Get-Command $HostExe -EA SilentlyContinue)) {
        Write-Info "$HostExe not found -- fallback: $FallbackPath"
        return $FallbackPath
    }
    try {
        $raw = Invoke-HostQuery -Exe $HostExe
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$HostExe exited $LASTEXITCODE -- fallback: $FallbackPath"
            return $FallbackPath
        }
        $resolved = ($raw.Trim() -split '\r?\n' | Where-Object { $_ } | Select-Object -Last 1).Trim()
        if ([string]::IsNullOrEmpty($resolved)) { return $FallbackPath }
        if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }
        Write-Info "Resolved $HostExe profile: $resolved"
        return $resolved
    } catch {
        Write-Warn "Query failed for $HostExe -- fallback: $FallbackPath"
        return $FallbackPath
    }
}

function Write-PowerShellProfile {
    param(
        # v5.2-JN-1: optional params allow test override; defaults mirror production lines 17-18
        [string]$Ps51Fallback = [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'),
        [string]$Ps7Fallback  = [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
    )
    # ALL path-resolution and write logic lives inside this function.
    # Dot-sourcing profile.ps1 only defines the three functions above; it does NOT
    # execute resolution or writes. Tests define mock Invoke-HostQuery AFTER
    # dot-sourcing and BEFORE calling Write-PowerShellProfile.
    $local:beginMarker = '# BEGIN dev-setup profile'  # v5.1-F5: mirrors production line 12
    $local:endMarker   = '# END dev-setup profile'    # v5.1-F5: mirrors production line 13

    $profilePaths = @(
        (Resolve-ProfilePath 'powershell' $Ps51Fallback),
        (Resolve-ProfilePath 'pwsh' $Ps7Fallback)
    ) | Sort-Object { $_.ToLower() } -Unique

    $legacyPaths = @($Ps51Fallback, $Ps7Fallback)
    foreach ($legacy in $legacyPaths) {
        $isOrphan = ($profilePaths | Where-Object { $_.ToLower() -eq $legacy.ToLower() }).Count -eq 0
        if ($isOrphan -and (Test-Path $legacy) -and
            (Select-String -Path $legacy -Pattern $beginMarker -Quiet)) {
            $content = Get-Content $legacy -Raw
            $stripped = $content -replace "(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?", ''  # v5.1-F4: matches production line 27
            Set-Content $legacy $stripped.TrimEnd() -NoNewline -Encoding ASCII  # v5-H1: matches production line 28
            Write-Info "Stripped orphaned block from legacy path: $legacy"
        }
    }

    # Write to each resolved path (existing strip+re-inject logic)
}
```

---

## 5. Test Plan

Tests added to `test_windows_setup.ps1` as Group GG. Dot-source `profile.ps1` once at the top of the GG group to define functions; redefine mock `Invoke-HostQuery` in file scope immediately before each Test-Scenario call (not a `BeforeEach` block -- Test-Scenario has none) so no mock state leaks. Before each redefinition, reset `$global:LASTEXITCODE = 0` so GG-7's native-command exit-1 does not contaminate subsequent success-path tests (v5-H2). GG tests that write to disk (GG-1, GG-4, GG-5) create a unique temp dir via `Join-Path $env:TEMP "gg-test-441-$(New-Guid)"` and pass temp paths to `Write-PowerShellProfile` via `-Ps51Fallback`/`-Ps7Fallback` parameters; clean up in a `finally` block (v5.2-JN-1). `Test-Scenario` runs its block in a child scope -- mocks defined in the enclosing (file) scope are visible inside but are reset between tests by explicit redefinition.

| ID | Name | Input | Expected | Assertion |
|----|------|-------|----------|-----------|
| GG-1 | Resolved path used | Mock returns OneDrive path; call `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` (temp paths, not real `$HOME`) | Block at OneDrive path | `Test-Path $mockPath` and contains BEGIN marker |
| GG-2 | Fallback when host absent | Absent exe name (`'powershell-notexist'`) | Fallback path used | `$result -eq $FallbackPath` |
| GG-3 | Case-insensitive dedup | Mock returns same path different case | One path in array | `$profilePaths.Count -eq 1` |
| GG-4 | Legacy cleanup -- dual orphan | Both `Invoke-HostQuery` mock calls return the SAME `$oneDrivePath`; dedup produces 1 entry in `$profilePaths`; call `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` where both are `Join-Path $env:TEMP "gg-test-441-$(New-Guid)"` temp paths (not real `$HOME`), both seeded with BEGIN marker (v5.2-JN-1) | Both legacy files stripped; OneDrive file has BEGIN marker | Neither legacy file has BEGIN marker; OneDrive file has BEGIN marker |
| GG-5 | Idempotency (3 runs) | `Write-PowerShellProfile -Ps51Fallback $tempPath51 -Ps7Fallback $tempPath7` 3x same temp file | One block | `(Select-String ... -AllMatches).Matches.Count -eq 1` |
| GG-6 | Multi-line output (defense) | Mock returns `"banner`n$mockPath"` | Path extracted | `$result -eq $mockPath` (exact-equals) |
| GG-7 | Non-zero exit fallback | `$HostExe = 'powershell'` (guaranteed present on Windows; `'pwsh'` is unsuitable -- not-installed early-exit would mask the mock invocation and produce a false green on PS5.1-only runners (v5-H4)); mock calls `& $env:ComSpec /c "exit 1"` then returns empty string; native-command sets `$LASTEXITCODE = 1` at global scope | Fallback returned; warning logged | `$result -eq $FallbackPath` |

---

## 6. Migration

**Single strategy:** On install, `Write-PowerShellProfile`:
1. Resolves correct paths from hosts
2. Probes legacy hardcoded paths
3. If legacy differs from resolved AND contains sentinel: strips the block
4. Writes block to resolved paths

Uninstall: same logic -- probe both resolved and legacy paths, strip all that contain the sentinel.

---

## 7. Acceptance Criteria

Per issue #441:
- [ ] Aliases load on OneDrive/KFM systems after fresh install
- [ ] Aliases load after re-running setup on a system with old orphaned block
- [ ] Uninstall removes block from all locations (resolved + legacy)
- [ ] Diagnostic log shows resolved path, not hardcoded path
- [ ] Test added under `tests/` that mocks `$PROFILE` resolution
- [ ] C-2 and C-3 guarded against PS7+ `$PROFILE` assignment error (skip with logged reason)

---

## 8. Known Limitations (Post-Ship)

| Scenario | What we tell the user |
|----------|----------------------|
| CLM blocks child process | "Run setup from an unrestricted shell" |
| UNC path inaccessible | "Ensure network drive is connected" |
| Path > 260 chars | "Enable LongPathsEnabled registry key" |
| `pwsh-preview` not detected | "Install stable pwsh or add aliases manually" |
| Block written to wrong path before fix | "Re-run setup; legacy cleanup handles this"