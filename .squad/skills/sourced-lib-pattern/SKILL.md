# Skill: Sourced Library Pattern (Cross-Platform)

**Confidence:** high (used in #186 for logging; applicable to any shared lib)
**Owner:** Goofy (Cross-Platform Dev)
**Issue:** #186

---

## What

When extracting shared functions into a sourced library file, the path
resolution differs between shell and PowerShell, and between production
and test contexts.

## Path Resolution

### Shell (Bash)

Production (from any script):
```sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"
```

- `${BASH_SOURCE[0]}` is the path of the file being sourced, not the caller.
- `dirname` + relative path resolves correctly regardless of `$PWD`.
- The `SC1091` directive suppresses shellcheck's "file not found" warning for
  dynamic paths.

### PowerShell

Production (from setup.ps1, same directory as lib/):
```powershell
. "$PSScriptRoot\lib\logging.ps1"
```

Production (from tools/*.ps1, one directory below lib/):
```powershell
. "$PSScriptRoot\..\lib\logging.ps1"
```

### Test Context (PowerShell)

When tests load scripts via `Invoke-Expression (Get-Content $path -Raw)`,
`$PSScriptRoot` resolves to the **test** directory, not the script directory.

**Fix:** Pre-load the lib in the test harness, then strip the dot-source line:
```powershell
# Pre-load shared lib
. (Join-Path $RepoRoot 'scripts\windows\lib\logging.ps1')

# Strip dot-source from tool content before Invoke-Expression
$content = Get-Content $toolPath -Raw
$exec = $content -replace '\.\s+"?\$PSScriptRoot[^"]*logging\.ps1"?', '# loaded by test harness'
Invoke-Expression $exec
```

## When to Apply

- Extracting any shared functions into a `lib/` directory
- Adding new lib files alongside existing ones (e.g., `lib/paths.sh`)
- Writing tests that load scripts via `Invoke-Expression`

## References

- `scripts/linux/lib/log.sh` -- shell logging lib
- `scripts/windows/lib/logging.ps1` -- PowerShell logging lib
- `tests/test_windows_setup.ps1` -- test harness pre-load pattern
