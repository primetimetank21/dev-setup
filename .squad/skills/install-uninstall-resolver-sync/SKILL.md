# Skill: Install/Uninstall Resolver Sync

**Confidence:** low (first formal capture; observed in #442)
**Owner:** Mickey (Lead)
**Issue:** #442

---

## What

When an installer script and its corresponding uninstaller both need the same
helper function (e.g. a path resolver), a dependency conflict arises:

- `install.ps1` dot-sources a shared library -> resolver is available
- `uninstall.ps1` must work even if the repo has been deleted post-install ->
  it cannot dot-source the shared library

**Solution:** Inline the resolver in the uninstaller. Accept the duplicate code
as a maintenance surface in exchange for self-containment.

---

## Pattern

### Installer (dot-sourced context)

```powershell
# profile.ps1 -- dots-sources logging.ps1; Write-Info uses Write-Output
# IMPORTANT: functions that return a value via pipeline must NOT call Write-Info.
# Use Write-Host directly to avoid output-stream contamination.

function Resolve-ProfilePath {
    param([string]$HostExe, [string]$FallbackPath)
    if (-not (Get-Command $HostExe -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO]  $HostExe not found - fallback: $FallbackPath"
        return $FallbackPath
    }
    try {
        $raw = Invoke-HostQuery -Exe $HostExe
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN]  $HostExe exited $LASTEXITCODE - fallback: $FallbackPath"
            return $FallbackPath
        }
        $resolved = ($raw.Trim() -split '\r?\n' | Where-Object { $_ } | Select-Object -Last 1).Trim()
        if ([string]::IsNullOrEmpty($resolved)) { return $FallbackPath }
        if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }
        Write-Host "[INFO]  Resolved $HostExe profile: $resolved"
        return $resolved
    } catch {
        Write-Host "[WARN]  Query failed for $HostExe - fallback: $FallbackPath"
        return $FallbackPath
    }
}
```

### Uninstaller (self-contained inline copy)

```powershell
# uninstall.ps1 -- defines its own Write-Info/Write-Warn as Write-Host wrappers.
# The resolver can use Write-Info/Write-Warn here because they do NOT write to the
# success/output stream. This looks like drift from profile.ps1 but is NOT a bug.

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Resolve-ProfilePath {
    param([string]$HostExe, [string]$FallbackPath)
    if (-not (Get-Command $HostExe -ErrorAction SilentlyContinue)) {
        Write-Info "$HostExe not found - fallback: $FallbackPath"
        return $FallbackPath
    }
    try {
        $raw = Invoke-HostQuery -Exe $HostExe
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$HostExe exited $LASTEXITCODE - fallback: $FallbackPath"
            return $FallbackPath
        }
        $resolved = ($raw.Trim() -split '\r?\n' | Where-Object { $_ } | Select-Object -Last 1).Trim()
        if ([string]::IsNullOrEmpty($resolved)) { return $FallbackPath }
        if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }
        Write-Info "Resolved $HostExe profile: $resolved"
        return $resolved
    } catch {
        Write-Warn "Query failed for $HostExe - fallback: $FallbackPath"
        return $FallbackPath
    }
}
```

The two copies are cosmetically different but algorithmically identical.

---

## Rules

1. **Inline in the uninstaller.** Never dot-source from the installed repo in
   `uninstall.ps1` -- the repo may have been deleted.

2. **Document the inline copy.** Add a comment block above the inlined functions:
   ```
   # Resolver functions (inlined for self-containment -- uninstall must work without the repo)
   ```

3. **Keep algorithms in sync.** Cosmetic differences (logging wrapper vs direct
   Write-Host) are acceptable. Algorithm changes (new fallback conditions, path
   validation guards) must be applied to BOTH copies. File a paired issue.

4. **Uninstaller path union is broader.** The uninstaller should target both
   resolved paths AND legacy fallback paths (union, deduped). The installer's
   legacy cleanup loop handles orphan removal; the uninstaller has no "legacy"
   concept -- it cleans everything it can find.

   ```powershell
   # uninstall.ps1 -- include both resolved and fallback in the target set
   $profilePaths = @(
       (Resolve-ProfilePath 'powershell' $ps51Fallback),
       (Resolve-ProfilePath 'pwsh'       $ps7Fallback),
       $ps51Fallback,
       $ps7Fallback
   ) | Sort-Object { $_.ToLower() } -Unique
   ```

5. **Write-Info/Write-Warn form check.** Before flagging uninstall.ps1's
   resolver as "drift" from profile.ps1's Write-Host form, verify whether
   uninstall.ps1 defines its own Write-Info/Write-Warn. If they are Write-Host
   wrappers, the difference is cosmetic and NOT a bug.

---

## Anti-patterns

- **Do NOT dot-source profile.ps1 from uninstall.ps1.** Self-containment is
  the whole point. Dot-sourcing creates a repo-presence dependency.

- **Do NOT call Write-Info/Write-Warn from a value-returning function if
  Write-Info writes to the success stream.** In any context where logging.ps1
  is sourced, Write-Info uses Write-Output and will contaminate captured
  return values. Use Write-Host directly in that context.

- **Do NOT skip the paired-issue requirement.** Algorithm changes to one copy
  that are not applied to the other will silently break install/uninstall parity.

---

## When to Apply

Trigger: any new script pair where both installer and uninstaller need shared
helper logic AND the uninstaller must be self-contained (repo may be deleted).

Examples:
- Profile path resolution (profile.ps1 + uninstall.ps1)
- Any future tool that writes a config block and needs to locate it at removal time

---

## Related Skills

- `.squad/skills/sourced-lib-pattern/SKILL.md` -- dot-source tradeoffs
- `.squad/skills/profile-host-query/SKILL.md` -- the specific resolver this pattern applies to
- `.squad/skills/ps51-ascii-safety/SKILL.md` -- encoding rules for .ps1 writes

---

## References

- Issue: #442
- Plan: `docs/plans/441-profile-path.md` (v5.2, Decision 3)
- PR: #458
