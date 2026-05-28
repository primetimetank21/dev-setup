# Research Report: #461 -- $IsWindows PS 5.1 Defensiveness

**Date:** 2026-05-28  
**Author:** Goofy (Cross-Platform Dev)  
**Issue:** [#461](https://github.com/primetimetank21/dev-setup/issues/461) -- Replace `$IsWindows` check with explicit POSIX platform detection  
**Branch:** `squad/461-research-iswindows`  
**Status:** Research-only. Implementation deferred to follow-up PR.

---

## 1. Claim Verification

### The original bug

In commit `550821a` (the `feat(scripts): add sprint-end-labels.ps1 PowerShell parity (#438)` commit that introduced `tests/test_sprint_end_labels_pwsh.ps1`), the `New-TestEnv` fixture contained:

```powershell
if (-not $IsWindows) {
    & chmod +x $launcherPath 2>$null | Out-Null
}
```

### Why this is a bug on PS 5.1

`$IsWindows` is a PS 7+ (PowerShell Core 6.0+) automatic variable. On Windows PowerShell 5.1 it does not exist in the session state.

| Condition | Value | Resulting branch |
|---|---|---|
| PS 5.1: `$IsWindows` is undefined | `$null` | `-not $null` = `$true` -> **chmod executes** |
| PS 7+ Windows | `$true` | `-not $true` = `$false` -> chmod skipped (correct) |
| PS 7+ Linux/macOS | `$false` | `-not $false` = `$true` -> chmod executes (correct) |

On PS 5.1, the chmod branch fires on every run. Since PS 5.1 is Windows-only, `chmod` does not exist as a native command; the call fails silently (suppressed by `2>$null | Out-Null`). This is operationally harmless but is fragile, misleading, and technically incorrect.

### Set-StrictMode amplifier

Under `Set-StrictMode -Version Latest`, accessing an undefined variable raises a hard terminating error -- not just a silent `$null`. The test file sets `$ErrorActionPreference = 'Stop'` globally, which means any unguarded `$IsWindows` reference would throw on PS 5.1 if StrictMode were in force at that scope. The fixture does not itself set StrictMode, but the risk surface is real for any future caller that does.

### Local PS 5.1 repro

The `validate-ps51` CI job (`validate.yml` lines 285-372) runs `shell: powershell` steps on `windows-latest`, which invokes Windows PowerShell 5.1. The specific step at line 369-372 runs `test_sprint_end_labels_pwsh.ps1` under PS 5.1:

```yaml
- name: Run sprint-end labels tests (PS 5.1)
  shell: powershell
  run: |
    powershell -ExecutionPolicy Bypass -File tests\test_sprint_end_labels_pwsh.ps1
```

This confirms a repro path existed. Local repro: `powershell -ExecutionPolicy Bypass -File tests\test_sprint_end_labels_pwsh.ps1` from any Windows PS 5.1 session.

---

## 2. Blast Radius Audit

### Complete `$IsWindows` / `$IsLinux` / `$IsMacOS` / `$IsCoreCLR` inventory

Searched the entire repo with: `grep -rn '\$IsWindows|\$IsLinux|\$IsMacOS|\$IsCoreCLR' --include='*.ps1'`

| File | Line | Variable | Pattern | Safe? | Notes |
|---|---|---|---|---|---|
| `setup.ps1` | 27 | `$IsWindows` | Comment only | OK | Documentation text, not executable |
| `setup.ps1` | 32 | `$IsWindows` | `$PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows` | OK | PSVersion short-circuit guard |
| `setup.ps1` | 34 | `$IsLinux` | `$PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux` | OK | PSVersion short-circuit guard |
| `setup.ps1` | 35 | `$IsMacOS` | `$PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS` | OK | PSVersion short-circuit guard |
| `tests/test_windows_setup.ps1` | 11 | `$IsLinux/$IsMacOS/$IsWindows` | Comment/heading text | OK | Not executable code |
| `tests/test_windows_setup.ps1` | 132 | `$IsLinux` | Comment | OK | Not executable code |
| `tests/test_windows_setup.ps1` | 163-164 | `$IsLinux` | Comment | OK | Not executable code |
| `tests/test_windows_setup.ps1` | 167 | `$IsLinux` | `(Test-Path Variable:IsLinux) -and $IsLinux` | OK | Test-Path guard |
| `tests/test_windows_setup.ps1` | 175 | `$IsWindows` | Comment | OK | Not executable code |
| `tests/test_windows_setup.ps1` | 179 | `$IsWindows` | `((Test-Path Variable:IsWindows) -and $IsWindows) -or ($env:OS -eq 'Windows_NT')` | OK | Compound guard with $env:OS fallback |
| `tests/test_windows_setup.ps1` | 393-411 | `$IsLinux/$IsMacOS/$IsWindows` | E-5 test -- reads file content as strings, uses `-match` on text | OK | Regex over file content, not variable access |
| `tests/test_sprint_end_labels_pwsh.ps1` | ~320 (commit `550821a`) | `$IsWindows` | Bare `if (-not $IsWindows)` | NO **BUG** (was) |

### Status of the original bug

**The bug was silently fixed in PR #462 (commit `31aa228`).** The current HEAD of `tests/test_sprint_end_labels_pwsh.ps1` at the affected location now reads:

```powershell
$isWindowsRuntime = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
if (-not $isWindowsRuntime) {
    & chmod +x $launcherPath 2>$null | Out-Null
}
```

The fix was applied during the T7 (launcher byte-check) work in PR #462, which required touching the same `New-TestEnv` function. The replacement uses `[System.Environment]::OSVersion.Platform` -- an approach already evaluated as correct (see Section 3 below).

### `$IsCoreCLR` verdict

`$IsCoreCLR` does not appear anywhere in the repo. No action needed.

### Summary

- **1 real bug found** (the original `if (-not $IsWindows)`) -- **already fixed in PR #462**
- **0 remaining unguarded PS-7-only auto-var references** in any executable code path
- `setup.ps1` uses the canonical PSVersion short-circuit guard, which is correct and should not be changed
- `tests/test_windows_setup.ps1` uses `Test-Path Variable:` guards -- correct

---

## 3. Detection Alternatives Evaluation

### Candidates

#### A. `$PSVersionTable.Platform -eq 'Unix'`

| PS version / runtime | `$PSVersionTable.Platform` | Result of `-eq 'Unix'` |
|---|---|---|
| PS 5.1 Windows | key absent -> `$null` | `$false` OK |
| PS 7+ Windows | `'Win32NT'` | `$false` OK |
| PS 7+ Linux (bare metal) | `'Unix'` | `$true` OK |
| PS 7+ macOS | `'Unix'` | `$true` OK |
| PS 7+ in WSL | `'Unix'` | `$true` OK |
| PS 7+ in Dev Container (Linux) | `'Unix'` | `$true` OK |
| Git Bash (not pwsh) | n/a | n/a |

**PS 5.1 safety:** `$PSVersionTable` is `System.Management.Automation.PSVersionHashTable`; missing keys return `$null` without error, including under `Set-StrictMode -Version Latest` (PSVersionHashTable is special-cased). Confirmed safe.  
**Edge case:** If `$PSVersionTable` itself is cleared by an adversarial host, this fails. Ignored for normal use.

#### B. `$PSVersionTable.OS -match 'Linux|Darwin'`

| PS version / runtime | `$PSVersionTable.OS` | Result |
|---|---|---|
| PS 5.1 Windows | absent -> `$null` | `$null -match ...` = `$false` OK |
| PS 7+ Windows | `'Microsoft Windows ...'` | `$false` OK |
| PS 7+ Linux | `'Linux ...'` | `$true` OK |
| PS 7+ macOS | `'Darwin ...'` | `$true` OK |
| WSL | `'Linux ...'` | `$true` OK |

**Note:** String content of `.OS` can vary across OS versions; regex matching is resilient but adds a fragility dependency on string format. Also, `$null -match 'pattern'` returns `$false` in PowerShell (not an error), so PS 5.1 is safe.

#### C. `[System.Environment]::OSVersion.Platform`

| PS version / runtime | `OSVersion.Platform` enum value | Notes |
|---|---|---|
| PS 5.1 Windows | `Win32NT` (2) | Correct |
| PS 7+ Windows | `Win32NT` (2) | Correct |
| PS 7+ Linux | `Unix` (4) | Correct |
| PS 7+ macOS | `Unix` (4) | Correct |
| WSL (pwsh) | `Unix` (4) | Correct -- chmod is needed here |
| Dev Container (Linux) | `Unix` (4) | Correct |
| Git Bash | n/a (not pwsh) | |

**PS 5.1 safety:** `[System.Environment]::OSVersion` is a .NET BCL type present since .NET 2.0, fully available in Windows PowerShell 5.1. No version guard needed. Enum comparison is type-safe and immune to string format drift.  
**Recommendation:** This is the strongest option for POSIX-branch guards. **Already adopted by PR #462.** OK

#### D. `$env:OS -eq 'Windows_NT'`

| PS version / runtime | `$env:OS` | Result |
|---|---|---|
| PS 5.1 Windows | `'Windows_NT'` | `$true` OK |
| PS 7+ Windows | `'Windows_NT'` | `$true` OK |
| PS 7+ Linux (bare) | empty/unset | `$false` OK |
| PS 7+ macOS | empty/unset | `$false` OK |
| WSL | unset by default | `$false` OK |
| CI container (ubuntu) | unset | `$false` OK |

**Caveat:** `$env:OS` is user-writable. In theory, `$env:OS = 'Windows_NT'` inside a script or parent shell could spoof this on Linux. Unlikely in practice but worth noting. Best used as a fallback, not a sole check.

### Summary table

| Approach | PS 5.1 | PS 7+ Win | PS 7+ Linux/Mac | WSL | Type-safe | Recommended |
|---|---|---|---|---|---|---|
| Bare `-not $IsWindows` | NO BUG | OK | OK | OK | -- | No |
| `$PSVersionTable.Platform -eq 'Unix'` | OK | OK | OK | OK | String | Yes (alt) |
| `$PSVersionTable.OS -match 'Linux\|Darwin'` | OK | OK | OK | OK | String regex | Acceptable |
| `[System.Environment]::OSVersion.Platform` | OK | OK | OK | OK | Enum | **Primary** |
| `$env:OS -eq 'Windows_NT'` | OK | OK | OK | OK | String | Fallback only |
| PSVersion short-circuit (`-ge 6 -and $IsX`) | OK | OK | OK | OK | Bool | Production only |

---

## 4. Backward-Compatibility Check

### Test suite impact

Running the existing pwsh test suite against the current HEAD (fix already applied):

- `validate-ps51` -> runs `test_sprint_end_labels_pwsh.ps1` under PS 5.1. With the fix (`OSVersion.Platform`), `$isWindowsRuntime = $true` on Windows, so the chmod branch is correctly skipped. **No regression.** Previously: chmod ran silently and failed silently -- now it correctly does not run. Behavioral change is correct, not a regression.
- `validate-powershell` -> runs `test_sprint_end_labels.ps1` (bash-parity test). Unaffected; different file.
- `tests/test_windows_setup.ps1` E-5 test -> checks `scripts/windows/setup.ps1` for unguarded auto-vars. The test file itself (`test_sprint_end_labels_pwsh.ps1`) is not in scope of E-5. No impact.
- `setup.ps1` PSVersion guards -> unchanged. All tests that verify these patterns remain green.

**Risk: zero.** The fix replaces a silently-buggy call with a correct guard. No currently-green test depends on the broken behavior.

### Future risk: `$PSVersionTable.Platform` under StrictMode

`$PSVersionTable` hashtable key access is safe under StrictMode in PS 5.1 (missing key -> `$null`, not an error). However, if any future code uses `$PSVersionTable.Platform` in a script block where StrictMode is set more aggressively by a test harness, and that code does not anticipate `$null`, there could be downstream `$null` comparison surprises. Mitigation: always compare with `-eq 'Unix'` or `-ne 'Win32NT'` rather than treating the value as a boolean.

---

## 5. Scope Boundary: #461 vs #466 / #467 / #468

| Issue | Domain | Overlap with #461 |
|---|---|---|
| #461 | Platform detection defensiveness (test fixture + production guards) | N/A (this issue) |
| #466 | delta installer (`scripts/{linux,windows}/tools/delta.{sh,ps1}`) | None -- new files, no $IsWindows |
| #467 | lazygit installer (`scripts/{linux,windows}/tools/lazygit.{sh,ps1}`) | None -- new files, no $IsWindows |
| #468 | Install-flag framework (pick-and-choose, bash+pwsh parity) | None -- flag parsing, not platform detection |

**Conclusion:** #461 is strictly independent of #466, #467, and #468. It should land as a standalone PR and does not need to block or wait for any of those issues. It also does not need to be a prerequisite for them (none of the new tool installers use bare `$IsWindows` patterns).

---

## Recommended Fix

> **For the implementer (not Goofy in this pass):** lift this section directly.

### 1. In `tests/test_sprint_end_labels_pwsh.ps1` -- `New-TestEnv` function

**Status: Already fixed in PR #462 (commit `31aa228`).** No action needed for this specific occurrence.

Current code (correct):
```powershell
$isWindowsRuntime = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
if (-not $isWindowsRuntime) {
    & chmod +x $launcherPath 2>$null | Out-Null
}
```

### 2. In `setup.ps1` -- `Get-Platform` function

**Status: Already correct.** Existing PSVersion short-circuit guards are the canonical PS 5.1-safe pattern. **Do not change.**

```powershell
$isWin = ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) -or `
          ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')
$isLin = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$isMac = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS
```

### 3. Canonical pattern for any new code

For any new PowerShell code that needs POSIX-branch detection, use **Option C** as primary:

```powershell
# Preferred: .NET BCL enum, PS 5.1 + PS 7+ compatible, no string fragility
$isPosix = [System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT
if ($isPosix) {
    & chmod +x $targetPath 2>$null | Out-Null
}
```

For production OS detection functions (like `Get-Platform`) that need to differentiate Linux vs macOS vs Windows, keep the PSVersion short-circuit pattern.

### 4. Acceptance criteria for close of #461

- [ ] Zero bare `$IsWindows` / `$IsLinux` / `$IsMacOS` references without a guard in any executable `.ps1` file
- [ ] `validate-ps51` CI step remains green
- [ ] ASCII-only (no new non-ASCII bytes introduced)
- [ ] E-5 test (`test_windows_setup.ps1`) continues to pass

### 5. Can #461 be closed now?

The only concrete bug (bare `if (-not $IsWindows)` in `New-TestEnv`) was already remediated in PR #462. All other occurrences are correctly guarded. The implementer should:

1. Verify the PR #462 fix is present in the current `develop` HEAD (confirmed: it is).
2. Optionally add a comment in `test_sprint_end_labels_pwsh.ps1` near the OSVersion check noting why it uses `.Platform` instead of `$IsWindows`.
3. Close #461 with a reference to the fix commit (`31aa228`) and this research report.

---

*Report authored 2026-05-28 by Goofy on branch `squad/461-research-iswindows`.*
