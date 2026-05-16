# Skill: PATH Refresh on Windows (Registry Read)

**Confidence:** high (verified on PS 5.1 and PS 7+; used in nvm.ps1 since #201)
**Owner:** Goofy (Cross-Platform Dev)
**Issue:** #201

---

## What

After a tool installer modifies the Windows PATH (via winget, nvm, or
`SetEnvironmentVariable`), the current PowerShell session does NOT see
the change. `$env:Path` is a snapshot taken when the process started.

To make newly installed binaries discoverable without restarting the
terminal, re-read PATH from the registry:

```powershell
function Refresh-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path    = "$machinePath;$userPath"
}
```

---

## When to use

- After `winget install` of any tool that adds itself to PATH
- After `nvm use <version>` (nvm-windows writes the active Node dir to user PATH)
- After any `[System.Environment]::SetEnvironmentVariable('PATH', ..., 'User')` call
- Any time the setup chain needs a just-installed binary in the same session

---

## Gotchas

1. **Session-only entries are lost.** If earlier code added something to
   `$env:Path` without writing to the registry, `Refresh-SessionPath` will
   drop it. Call it only when you know all important PATH entries are
   persisted in the registry.

2. **Machine before User.** Windows resolves PATH left-to-right. Putting
   Machine first matches the default shell behavior.

3. **No equivalent on Linux.** On Linux, `nvm` modifies `$PATH` in the
   current shell via `source nvm.sh` -- no registry involved.

---

## Citations

- `scripts/windows/tools/nvm.ps1` -- `Refresh-SessionPath` function (PR #201)
- `scripts/windows/tools/vim.ps1` -- earlier inline PATH refresh (same pattern)
