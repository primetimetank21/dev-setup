# SKILL: PS 5.1 Platform Detection Audit

**Skill ID:** `ps51-platform-detection-audit`  
**Owner:** Goofy  
**Extracted from:** Issue #461 research (2026-05-28)

---

## When to use this skill

Run this audit any time you:
- Add a new `.ps1` file that might branch on OS/platform
- Refactor existing platform detection
- Review a PR that touches `$IsWindows`, `$IsLinux`, `$IsMacOS`, `$IsCoreCLR`
- Respond to a CI failure in `validate-ps51`

---

## Step 1: Grep for all PS-7-only automatic variables

```powershell
# From repo root
rg '\$IsWindows|\$IsLinux|\$IsMacOS|\$IsCoreCLR' --glob '*.ps1' -n
```

Or with PowerShell native:
```powershell
Get-ChildItem -Recurse -Filter '*.ps1' |
    Select-String -Pattern '\$(IsWindows|IsLinux|IsMacOS|IsCoreCLR)'
```

---

## Step 2: Classify each occurrence

For each match, determine:

| Classification | Pattern | Safe? |
|---|---|---|
| Comment / string literal | `# $IsWindows is...` | OK Not executable |
| PSVersion short-circuit | `$PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows` | OK |
| Test-Path guard | `(Test-Path Variable:IsWindows) -and $IsWindows` | OK |
| Regex over file content | `-match '\$IsWindows'` (reading a string) | OK |
| **Bare reference** | `if (-not $IsWindows)`, `if ($IsWindows)` | NO BUG |

---

## Step 3: Verify no bare references remain

A bare reference is any occurrence of `$IsWindows` (etc.) where:
- It is not inside a comment
- It is not behind a `$PSVersionTable.PSVersion.Major -ge 6` short-circuit
- It is not behind a `Test-Path Variable:IsWindows` guard

---

## Step 4: Pick the right replacement

### For POSIX-branch guards (chmod, exec bits, path separator):

```powershell
# PRIMARY -- .NET BCL, PS 5.1 + PS 7+ safe, enum type-safe
$isPosix = [System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT
if ($isPosix) {
    & chmod +x $targetPath 2>$null | Out-Null
}
```

### For production OS detection (three-way: win/linux/mac):

```powershell
# Keep the PSVersion short-circuit pattern used in setup.ps1
$isWin = ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) -or `
          ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')
$isLin = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$isMac = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
```

### Acceptable alternates (not preferred):

```powershell
# Clean but string-based; missing key on PS 5.1 returns $null safely
$isPosix = $PSVersionTable.Platform -eq 'Unix'

# Regex; works but fragile to OS string format changes
$isPosix = $PSVersionTable.OS -match 'Linux|Darwin'
```

---

## Step 5: Check for StrictMode amplification

Under `Set-StrictMode -Version Latest`, bare references to undefined variables **throw** rather than returning `$null`. Any script that sets StrictMode at module/script scope should be audited carefully. The guards above are safe under StrictMode.

---

## Step 6: CI verification path

- `validate-ps51` in `validate.yml` runs `shell: powershell` (Windows PowerShell 5.1) steps on `windows-latest`
- Run `powershell -ExecutionPolicy Bypass -File tests\test_windows_setup.ps1` locally to verify E-5 test still passes
- E-5 test checks `scripts/windows/setup.ps1` specifically -- also check any new files manually

---

## Known safe patterns (do not change)

| File | Pattern | Notes |
|---|---|---|
| `setup.ps1:32-35` | PSVersion short-circuit | Canonical production pattern |
| `tests/test_windows_setup.ps1:167` | `(Test-Path Variable:IsLinux) -and $IsLinux` | Test fixture guard |
| `tests/test_windows_setup.ps1:179` | `((Test-Path Variable:IsWindows) -and $IsWindows) -or ($env:OS -eq 'Windows_NT')` | Compound fallback guard |
| `tests/test_sprint_end_labels_pwsh.ps1:323` | `[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT` | Post-#462 fix |
