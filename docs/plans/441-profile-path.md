# Fix Plan: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Author:** Goofy (Cross-Platform Developer)
**Date:** 2026-05-27
**Issue:** https://github.com/primetimetank21/dev-setup/issues/441
**Branch:** squad/441-profile-path-fix
**Status:** Draft -- pending grilling by Mickey (architecture), Chip (testing), Doc (fact-checking)

---

## 1. Problem Statement

`scripts/windows/tools/profile.ps1` builds profile paths by concatenating `$HOME`,
`Documents`, and either `WindowsPowerShell` or `PowerShell` using
`[System.IO.Path]::Combine`. On systems where Windows Known Folder Move (KFM)
redirects Documents to OneDrive, or where a user or policy has relocated `$PROFILE`
to a custom path, the path PowerShell actually sources on startup does NOT match
the hardcoded construction. The dev-setup block is written to a file that is never
dot-sourced, so aliases (`pn`, `cdg`, `ep`, `gpl`, etc.) silently fail to appear in
new terminals. The user-visible symptom is: setup reports success but aliases are
absent; the user must diagnose by inspecting `$PROFILE` and comparing it to what
the script actually wrote.

---

## 2. Root Cause Analysis

### The broken assumption

The current code builds paths like:

    [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1')
    [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell',        'Microsoft.PowerShell_profile.ps1')

This assumes `$HOME\Documents` is the Documents folder. That assumption fails in
the following Windows scenarios:

### Scenario A -- OneDrive Known Folder Move (KFM) sync policy

When a user enables "Back up my Documents folder" in OneDrive settings, or when
an organization deploys KFM via Intune/GPO, Windows silently redirects the
Documents special folder to:

    C:\Users\<user>\OneDrive\Documents\   (personal)
    C:\Users\<user>\OneDrive - Contoso\Documents\   (business tenant)

`$HOME` stays `C:\Users\<user>`, but `[Environment]::GetFolderPath('MyDocuments')`
returns the OneDrive path. PowerShell resolves `$PROFILE` against the redirected
Documents folder, not `$HOME\Documents`. The hardcoded path
`$HOME\Documents\...` points to a directory that may not even exist.

### Scenario B -- Shell folder redirect via registry or folder redirect policy

Group Policy / MDM can redirect the `{My Documents}` CSIDL via registry key
`HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`.
The redirect target can be any UNC path or local path that differs from
`$HOME\Documents`.

### Scenario C -- User manually moved Documents or used `mklink`

A user may have moved their Documents folder to `D:\Documents` using the
"Location" tab in the Documents Properties dialog, or created a symlink/junction.
`$HOME\Documents` may be a junction pointing elsewhere, or may not exist at all.

### Scenario D -- $HOME overridden

If the `HOME` environment variable is set explicitly (some corporate images,
Docker, or WSL-adjacent setups set this), `$HOME` may differ from
`[Environment]::GetFolderPath('UserProfile')`. PowerShell itself uses the
special folder API when constructing `$PROFILE`, not the `HOME` env var.

### Scenario E -- Custom $PROFILE location set at PS startup

A user or administrator can override `$PROFILE` at shell startup by calling:

    $PROFILE = 'D:\my-profiles\Microsoft.PowerShell_profile.ps1'

Or a corporate PS profile bootstrap script may redirect `$PROFILE` before
user profile loading. In this case, asking the host at runtime is the only
correct strategy.

### Why $PROFILE is the truth

PowerShell sets `$PROFILE` using `[Environment]::GetFolderPath('MyDocuments')`
(PS 5.1) or the equivalent SHGetKnownFolderPath for `{Personal}` KNOWNFOLDERID
(PS 7+). Both honor the OS folder redirect, OneDrive KFM, and shell folder
registry overrides. Constructing from `$HOME` bypasses all of this.

The correct approach is: ask each PowerShell host what its `$PROFILE` is, and
write there.

---

## 3. Proposed Approach

### Algorithm

For each host that is installed (PS 5.1 `powershell.exe`, PS 7+ `pwsh.exe`):

1. Detect whether the host binary exists on PATH.
2. Ask the host to report its own `$PROFILE` value via `-NoProfile -Command`.
3. Use the reported path as the write target.
4. Fall back to the hardcoded construction ONLY if the host binary is absent
   (meaning the profile for that host will never load anyway -- write is a no-op
   in that case, but we preserve the fallback so the behavior is unchanged for
   fresh installs where the host just hasn't been used yet).

### Pseudo-code

    function Resolve-ProfilePath {
        param(
            [string]$HostExe,         # 'powershell' or 'pwsh'
            [string]$FallbackPath     # hardcoded path as before
        )

        $hostCmd = Get-Command $HostExe -ErrorAction SilentlyContinue
        if (-not $hostCmd) {
            Write-Info "$HostExe not found -- using fallback path: $FallbackPath"
            return $FallbackPath
        }

        try {
            # Ask the host for its CurrentUser CurrentHost profile path.
            # -NoProfile: don't let any existing profile interfere.
            # -NonInteractive: no prompts.
            $resolved = & $HostExe -NoProfile -NonInteractive -Command '$PROFILE' 2>$null
            $resolved = $resolved.Trim()

            if ([string]::IsNullOrEmpty($resolved)) {
                Write-Warn "$HostExe returned empty PROFILE -- falling back to: $FallbackPath"
                return $FallbackPath
            }

            Write-Info "Resolved $HostExe profile: $resolved"
            return $resolved

        } catch {
            Write-Warn "Could not query $HostExe for PROFILE ($_) -- falling back to: $FallbackPath"
            return $FallbackPath
        }
    }

    $ps51Fallback = [System.IO.Path]::Combine(
        $HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'
    )
    $ps7Fallback  = [System.IO.Path]::Combine(
        $HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1'
    )

    $profilePaths = @(
        Resolve-ProfilePath -HostExe 'powershell' -FallbackPath $ps51Fallback,
        Resolve-ProfilePath -HostExe 'pwsh'       -FallbackPath $ps7Fallback
    )

    # Deduplicate in case both hosts resolve to the same file
    # (rare but possible if a user has configured a shared profile location)
    $profilePaths = $profilePaths | Select-Object -Unique

    # ... existing strip+re-inject logic unchanged below ...

### Key decisions in the algorithm

- Use `$PROFILE` (CurrentUser CurrentHost), not `$PROFILE.CurrentUserAllHosts`.
  The issue title and user report concern host-specific profiles; AllHosts is a
  separate file that runs for ALL hosts and carries different semantics.
  CurrentHost is the right target for host-specific aliases.

- Deduplicate. Two hosts resolving to the same physical file must not cause a
  double-write (the strip+re-inject is idempotent, but duplicate entries would
  still be added in the current append loop).

- Preserve fallback. If a host is absent, the fallback path is used. This
  matches existing behavior for systems that haven't installed PS 7+ yet.

- Diagnostic log lines must show the RESOLVED path, not the constructed one.
  This is required by issue #441 acceptance criterion 4.

---

## 4. Edge Cases

The following configurations must be handled correctly (or explicitly documented
as out-of-scope with a warning emitted):

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| E1 | OneDrive KFM -- personal OneDrive | Resolve-ProfilePath returns OneDrive path; write there |
| E2 | OneDrive KFM -- business tenant path with spaces | Path with spaces must be quoted; PowerShell handles this natively |
| E3 | Only PS 5.1 installed (no pwsh) | Fallback used for PS 7+ path (write is benign no-op if dir absent) |
| E4 | Only PS 7+ installed (no powershell.exe) | Fallback used for PS 5.1 path; emit Write-Info noting host absent |
| E5 | Neither host on PATH (exotic env) | Both fallbacks used; warn loudly |
| E6 | $PROFILE query returns multi-line output | Trim() + take first non-empty line; guard against garbage output |
| E7 | $PROFILE is a UNC path (network-mapped Documents) | Use path as-is; New-Item -Force handles UNC dirs if accessible |
| E8 | $PROFILE dir is inaccessible (permissions, offline drive) | Catch block + Write-Err + continue (existing pattern) |
| E9 | Both hosts resolve to identical path | Deduplicate before write loop |
| E10 | $HOME overridden via env var | Fallback still uses $HOME env var (consistent with existing behavior); resolved path comes from host query, bypassing $HOME entirely |
| E11 | ConstrainedLanguage mode (CLM) | `& pwsh -NoProfile -Command '$PROFILE'` launches a NEW process outside CLM; resolution works. Writing the file may fail if CLM also locks filesystem writes -- emit Write-Warn and proceed |
| E12 | System-level $PROFILE redirect (corporate bootstrap) | Host query captures the final resolved value post-redirect; correct |
| E13 | PS 7 installed but not on PATH (e.g., installed via winget to non-PATH location) | Get-Command fails; emit info about pwsh not found on PATH; fallback used |
| E14 | $PROFILE returns a path with a trailing newline or CRLF | Trim() + TrimEnd([char]0x0D, [char]0x0A) handles this |
| E15 | Headless / non-interactive context (CI, Dev Container) | -NoProfile -NonInteractive flags prevent prompts; process launch still works |
| E16 | Documents folder is a symlink/junction to another drive | Test-Path and New-Item resolve symlinks transparently on Windows |
| E17 | Profile path contains non-ASCII characters (Unicode username) | Do NOT enforce ASCII on the resolved PATH itself; ASCII guard applies only to file CONTENT written inside the block |
| E18 | Execution policy = Restricted or AllSigned | Launching child process with -NoProfile -NonInteractive still works (no script file executed, inline command only); profile WRITE still works; load failure is a separate warning (existing behavior) |
| E19 | setup.ps1 run from a UNC path (\\server\share\...) | $PSScriptRoot is UNC; Resolve-ProfilePath does not depend on $PSScriptRoot |
| E20 | WSL interop calling setup.ps1 | powershell.exe / pwsh.exe exist as Windows binaries; host query works |

---

## 5. Test Plan

### Unit tests (Pester, tests/test_windows_setup.ps1 -- new Group)

Tests will be added as a new Group (proposed: Group GG, appended after existing
highest group).

#### Test infrastructure: mocking $PROFILE

`$PROFILE` is an automatic variable set by the PowerShell engine. To mock it in
tests, use one of two patterns:

**Pattern A -- Override in child scope before calling the function:**

    # In the test harness (before dot-sourcing profile.ps1 or calling the SUT):
    function global:Resolve-ProfilePath {
        param([string]$HostExe, [string]$FallbackPath)
        # Return a temp path under $TestDrive
        if ($HostExe -eq 'powershell') { return "$TestDrive\ps51\Microsoft.PowerShell_profile.ps1" }
        if ($HostExe -eq 'pwsh')       { return "$TestDrive\ps7\Microsoft.PowerShell_profile.ps1" }
        return $FallbackPath
    }

**Pattern B -- Mock the child process launch:**

If `Resolve-ProfilePath` is tested in isolation, mock `Get-Command` to return
a fake command object and mock the `& $HostExe` invocation via a wrapper
function `Invoke-HostQuery` that can be overridden:

    # Wrapper in production code:
    function Invoke-HostQuery { param([string]$Exe) & $Exe -NoProfile -NonInteractive -Command '$PROFILE' }

    # In tests:
    function global:Invoke-HostQuery { param([string]$Exe)
        if ($Exe -eq 'powershell') { return 'C:\Users\TestUser\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' }
        if ($Exe -eq 'pwsh')       { return 'C:\Users\TestUser\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' }
    }

Pattern B is preferred because it avoids spawning real child processes in tests
and allows injecting arbitrary paths without touching the filesystem.

#### Test cases (Group GG)

| ID    | Name | What it proves |
|-------|------|----------------|
| GG-1  | Resolved path used when host returns valid path | Write goes to the mocked OneDrive path, not $HOME\Documents\... |
| GG-2  | Fallback used when host binary absent | Get-Command returns $null; fallback path used |
| GG-3  | Fallback used when host returns empty string | Invoke-HostQuery returns ''; fallback path used |
| GG-4  | Fallback used when host invocation throws | Invoke-HostQuery throws; catch branch taken; fallback used |
| GG-5  | Deduplication -- two hosts same path | $profilePaths after dedup has length 1 |
| GG-6  | Only PS 7+ present -- PS 5.1 fallback emitted as Write-Info | Verify Write-Info called with 'not found' substring |
| GG-7  | Profile content written to resolved path | After calling Write-PowerShellProfile with mocked resolver, file exists at mocked path and contains BEGIN sentinel |
| GG-8  | Trailing CRLF in host output trimmed | Invoke-HostQuery returns "path\r\n"; resolved value equals "path" |
| GG-9  | Diagnostic log shows resolved path, not constructed path | Write-Info output contains the mocked OneDrive path |
| GG-10 | Both host-resolved paths get the dev-setup block | Both mocked paths contain BEGIN..END block after Write-PowerShellProfile |

#### Static assertion tests

Add one static test (Group GG-S1) verifying that `profile.ps1` does NOT contain
the literal string `$HOME, 'Documents'` outside of the fallback variable
assignment. This prevents regression to the hardcoded construction.

---

## 6. Backward Compatibility

### Systems with the block already at the WRONG location

If setup.ps1 was run on a KFM system before this fix, the dev-setup block now
exists at:

    $HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1   (PS 5.1)
    $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1           (PS 7+)

After the fix, `Write-PowerShellProfile` will write to the CORRECT (resolved)
path. The old file at the hardcoded path is orphaned.

### Cleanup strategy

On install (not uninstall), `Write-PowerShellProfile` should:

1. Resolve the correct path (new behavior).
2. Also probe the OLD hardcoded paths.
3. If the old hardcoded path exists AND contains the dev-setup sentinel, strip
   the block from that file (using the existing strip regex).
4. Emit a Write-Info noting the cleanup.

This is safe and idempotent: if the old path and the new path are the same
(stock Windows, no KFM), the strip happens on the same file before re-injection,
which is already the existing behavior.

Pseudo-code for cleanup pass in `Write-PowerShellProfile`:

    # Cleanup: remove block from old hardcoded paths if they differ from resolved
    $legacyPaths = @(
        [System.IO.Path]::Combine($HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'),
        [System.IO.Path]::Combine($HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1')
    )

    foreach ($legacy in $legacyPaths) {
        if ($profilePaths -notcontains $legacy) {
            # This path is NOT one we are about to write to -- clean up stale block
            if ((Test-Path $legacy) -and (Select-String -Path $legacy -Pattern $beginMarker -Quiet)) {
                Write-Info "Removing stale dev-setup block from legacy path: $legacy"
                # ... strip regex, same as in Remove-DevSetupProfileBlock ...
            }
        }
    }

---

## 7. Uninstall Mirror

`scripts/windows/uninstall.ps1` has the same hardcoded path construction at
lines 107-110. It must be updated to use the same resolution logic.

### Changes required in uninstall.ps1

1. Extract `Resolve-ProfilePath` (or a simplified equivalent) into a shared
   helper. Two options:

   **Option A -- Duplicate the resolver inline in uninstall.ps1.**
   Pros: uninstall.ps1 is standalone (no dot-source chain); simpler.
   Cons: logic duplication.

   **Option B -- Extract to `scripts/windows/lib/profile-path.ps1` and
   dot-source from both profile.ps1 and uninstall.ps1.**
   Pros: single source of truth.
   Cons: uninstall.ps1 gains a dependency on lib/; must verify lib path is
   accessible at uninstall time.

   Recommendation: Option B. The lib/ directory is already a dependency
   (logging.ps1 pattern is established). A `profile-path.ps1` lib is the
   right home for `Resolve-ProfilePath`.

2. Update the `$profilePaths` array (lines 107-110) to call
   `Resolve-ProfilePath` for each host, same as the install side.

3. Add the legacy-cleanup behavior: when uninstalling, also probe the hardcoded
   fallback paths for a stale block and remove it. This handles the case where
   a user installed with the old code and is now uninstalling with the new code.

4. Emit diagnostic lines showing the resolved path being targeted.

### Proposed uninstall path resolution

    # Resolve actual profile paths for removal
    $ps51Fallback = [System.IO.Path]::Combine(
        $HOME, 'Documents', 'WindowsPowerShell', 'Microsoft.PowerShell_profile.ps1'
    )
    $ps7Fallback  = [System.IO.Path]::Combine(
        $HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1'
    )

    $resolvedPaths = @(
        Resolve-ProfilePath -HostExe 'powershell' -FallbackPath $ps51Fallback,
        Resolve-ProfilePath -HostExe 'pwsh'       -FallbackPath $ps7Fallback
    ) | Select-Object -Unique

    # Also probe legacy hardcoded paths in case install was done with old code
    $allTargets = ($resolvedPaths + $legacyFallbacks) | Select-Object -Unique

    foreach ($p in $allTargets) {
        Remove-DevSetupProfileBlock -ProfilePath $p
    }

---

## 8. Files Touched

| File | Change | Reason |
|------|--------|--------|
| `scripts/windows/tools/profile.ps1` | Add `Resolve-ProfilePath` call; replace hardcoded `$profilePaths` construction; add legacy-cleanup pass; update diagnostic log lines | Core bug fix |
| `scripts/windows/uninstall.ps1` | Replace hardcoded `$profilePaths` construction; add legacy-cleanup probe; dot-source or inline `Resolve-ProfilePath` | Mirror uninstall fix (issue #441 acceptance criterion) |
| `scripts/windows/lib/profile-path.ps1` | NEW FILE -- `Resolve-ProfilePath` helper function | Shared resolver to avoid duplication; follows existing lib/ pattern |
| `tests/test_windows_setup.ps1` | Add Group GG (10 behavior tests + 1 static test) | Acceptance criterion: test added under tests/ that mocks $PROFILE |

No changes needed to:
- `scripts/windows/setup.ps1` (orchestrator -- calls `Write-PowerShellProfile`, no path logic)
- `scripts/windows/lib/logging.ps1` (no changes to logging contract)
- Root `setup.ps1` (OS detection layer, unaffected)

---

## 9. Open Questions / Known Unknowns

1. **`$PROFILE` vs `$PROFILE.CurrentUserCurrentHost` vs `$PROFILE.CurrentUserAllHosts`:**
   The issue proposes using `$PROFILE.CurrentUserAllHosts`. This plan recommends
   `$PROFILE` (= CurrentUserCurrentHost). The correct choice depends on whether
   dev-setup aliases should load for ALL hosts (ISE, VSCode, custom hosts) or
   only the default terminal host. Decision needed from Mickey/Earl before
   implementation.

2. **PS 7 installed but not on PATH:**
   `Get-Command pwsh` fails if `pwsh` was installed by winget to a location
   not in the current PATH. We may need to probe known install paths (e.g.,
   `C:\Program Files\PowerShell\7\pwsh.exe`) as a secondary check. The
   threshold for this complexity is unknown.

3. **Race condition on first install of PS 7:**
   If `Install-Nvm` or another installer causes a new PS 7 install during the
   same setup run, PATH may not be updated until terminal restart. `pwsh` may
   not be found on PATH even though it was just installed. Is this a real
   scenario in our install order? Setup.ps1 installs pwsh via winget in
   `Install-*` functions before `Write-PowerShellProfile` -- need to confirm
   the PATH refresh (Issue #251 pattern) happens before profile write.

4. **UNC path behavior with `New-Item -Force`:**
   `New-Item -ItemType Directory -Path \\server\share\... -Force` behavior
   on disconnected network drives is not fully tested. Should we add an
   explicit connectivity check for UNC paths before attempting to create
   the directory?

5. **CLM (ConstrainedLanguage mode) -- child process launch:**
   Does `& powershell -NoProfile -Command '$PROFILE'` succeed under CLM
   imposed on the PARENT process? Likely yes (new process, new language mode),
   but not verified in our test environment.

6. **Uninstall.ps1 dot-source dependency:**
   If we extract `Resolve-ProfilePath` to `lib/profile-path.ps1`, uninstall.ps1
   must dot-source from a known relative path. Currently uninstall.ps1 does NOT
   dot-source any lib files (it redefines Write-Ok etc. inline). This would be
   the first lib dependency. Is that acceptable? Alternative is to inline the
   resolver in uninstall.ps1.

7. **Test harness compatibility:**
   Our current test pattern calls `Write-PowerShellProfile` after dot-sourcing
   profile.ps1 inside a `Test-Scenario` / `Invoke-Expression` block. Mocking
   `Invoke-HostQuery` as a global function must be done BEFORE the dot-source.
   Verify this works with the existing Group scaffold before finalizing the
   test design.

---

## 10. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | Child process launch (`& pwsh -NoProfile ...`) is slow -- adds 1-3 seconds per host to setup run time | Medium | Low | Acceptable tradeoff; one-time setup cost |
| R2 | `& powershell -NoProfile -Command '$PROFILE'` inherits caller's execution policy; if Restricted, child may fail to launch | Low | Medium | Test with Restricted policy; -Command (not -File) should work even under Restricted |
| R3 | Legacy cleanup on install removes a user's custom content if they manually placed content between the same sentinel lines as another tool | Very low | High | The sentinel is unique to dev-setup; collision is only possible if another tool uses the exact same BEGIN/END markers |
| R4 | Deduplication collapses two genuinely different profile paths to one if they resolve to the same string but differ in case | Low | Low | Use case-insensitive compare for dedup on Windows paths |
| R5 | Introducing `lib/profile-path.ps1` breaks uninstall.ps1 if the lib path is wrong at uninstall time (user may have moved dev-setup repo) | Medium | Medium | Inline the resolver in uninstall.ps1 (Option A fallback) if lib dependency is rejected |
| R6 | PS 7 preview or daily-build variants install as `pwsh-preview` not `pwsh` -- resolver misses them | Low | Low | Out of scope; document as known limitation |
| R7 | Fix resolves correctly at install time but a KFM policy is applied AFTER install; block is now at the right OneDrive path but a future uninstall runs on a machine where KFM has since been removed -- hardcoded fallback plus legacy probe should cover this | Low | Medium | The all-targets union in uninstall covers both resolved + fallback; this risk is mitigated by design |
| R8 | ASCII guard -- the resolved $PROFILE path itself may contain non-ASCII chars (Unicode username) -- if we log it via Write-Info and Write-Info uses ASCII encoding, the path may be mangled in the log | Low | Low | Write-Info uses Write-Host which handles Unicode; the ASCII guard applies only to file CONTENT, not log output |
