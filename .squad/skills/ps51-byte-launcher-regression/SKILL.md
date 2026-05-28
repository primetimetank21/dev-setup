---
name: "ps51-byte-launcher-regression"
description: "Use byte-level ReadAllBytes assertions for PS 5.1-safe launcher regression tests: assert no CR bytes and assert shebang bytes directly."
domain: "testing, windows-compatibility"
confidence: "medium"
source: "earned (issue #451 / PR #462 sprint-end labels parity)"
---

## Pattern

When a PowerShell test writes a POSIX launcher from a here-string, validate the file as bytes, not text:

```powershell
$bytes = [System.IO.File]::ReadAllBytes($launcherPath)
if ($bytes -contains 0x0D) { throw 'launcher contains CR bytes (0x0D)' }
if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x23 -or $bytes[1] -ne 0x21) {
    throw 'launcher missing shebang bytes 0x23 0x21 (#!)'
}
```

## Why

`Get-Content` can normalize or reinterpret line endings. `[System.IO.File]::ReadAllBytes()` works in PS 5.1 and verifies the exact bytes that bash will execute.

## Related harness notes

- Keep `.ps1` test files ASCII-only.
- If a test shim is an external `.ps1` script whose output must be captured by the script under test, use `Write-Output`, not `Write-Host` or `[Console]::Out.WriteLine()`.
- For PS 5.1-compatible platform checks, prefer `[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT` over `$IsWindows`.
