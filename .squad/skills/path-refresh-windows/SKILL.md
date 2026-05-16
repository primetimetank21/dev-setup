# Skill: PATH Refresh on Windows (Registry Merge)

**Confidence:** high (verified on PS 5.1 and PS 7+; used in nvm.ps1 since #201)
**Owner:** Goofy (Cross-Platform Dev)
**Issue:** #201, #251

---

## What

After a tool installer modifies the Windows PATH (via winget, nvm, or
`SetEnvironmentVariable`), the current PowerShell session does NOT see
the change. `$env:Path` is a snapshot taken when the process started.

To make newly installed binaries discoverable without restarting the
terminal, re-read PATH from the registry:

```powershell
function Refresh-SessionPath {
    # Merge Machine + User registry PATH into the current $env:Path,
    # preserving session-only entries (e.g., GitHub Actions tool-cache
    # injections, profile-set entries, manual session additions).
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')

    $existing = $env:Path
    $combined = @($existing, $machinePath, $userPath) -join ';'
    $env:Path = ($combined -split ';' |
                 Where-Object { $_ -ne '' } |
                 Select-Object -Unique) -join ';'
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

1. **Session entries are now preserved by default.** Pre-merge versions of
   this function (before #251) lost them. The current implementation merges
   registry entries into the existing `$env:Path` with deduplication.

2. **Machine before User.** Windows resolves PATH left-to-right. Putting
   Machine first matches the default shell behavior.

3. **No equivalent on Linux.** On Linux, `nvm` modifies `$PATH` in the
   current shell via `source nvm.sh` -- no registry involved.

---

## Citations

- `scripts/windows/lib/path.ps1` -- `Refresh-SessionPath` function (PR #201, #251)
- `scripts/windows/tools/nvm.ps1` -- calls Refresh-SessionPath (PR #201)
- `scripts/windows/tools/vim.ps1` -- earlier inline PATH refresh (same pattern)

---

## Changelog

- 2026-05-16: changed from replace to merge. Issue #251 (GH Actions tool-cache Node was being wiped).
