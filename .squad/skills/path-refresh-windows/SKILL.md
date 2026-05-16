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

## Portable nvm-windows (preferred)

For nvm-windows, use the portable `nvm-noinstall.zip` approach rather than
`winget install CoreyButler.NVMforWindows`. The winget installer wraps
nvm-setup.exe which detaches and runs asynchronously -- CI observed install
times of 24s, 100s, and >180s depending on runner load. winget returns
"success" before the installer finishes, causing PATH/registry races.

The portable approach downloads the zip from GitHub releases, extracts to
`%USERPROFILE%\nvm`, writes `settings.txt`, and sets NVM_HOME/NVM_SYMLINK
at User scope. Deterministic and instantaneous.

See `scripts/windows/tools/nvm.ps1`: `Install-NvmPortable` + `Set-NvmEnvironment`.

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

2. **winget returns before the installer finishes.** For installers like
   `CoreyButler.NVMforWindows` that wrap a setup.exe, `winget install --silent`
   can return BEFORE the inner installer has written files or updated the
   registry. This is why nvm-windows uses the portable zip approach instead
   (no installer, no race).

3. **Machine before User.** Windows resolves PATH left-to-right. Putting
   Machine first matches the default shell behavior.

4. **No equivalent on Linux.** On Linux, `nvm` modifies `$PATH` in the
   current shell via `source nvm.sh` -- no registry involved.

---

## Citations

- `scripts/windows/lib/path.ps1` -- `Refresh-SessionPath` function (PR #201, #251)
- `scripts/windows/tools/nvm.ps1` -- `Install-NvmPortable` + `Set-NvmEnvironment` (PR #257, #251)
- `scripts/windows/tools/vim.ps1` -- earlier inline PATH refresh (same pattern)

---

## Changelog

- 2026-05-16: changed from replace to merge. Issue #251 (GH Actions tool-cache Node was being wiped).
- 2026-05-18: added Wait-ForNvmInstall polling helper. winget returns before nvm-setup.exe finishes; polling 5 candidate paths with 90s timeout. Issue #251, PR #257.
- 2026-05-18: v6 -- bumped timeout to 180s (installer took ~100s in CI); poll loop now uses Refresh-SessionPath + Get-Command as primary signal, expanded candidate paths (7 dirs) as fallback; diagnostic dump on timeout. Issue #251, PR #257.
- 2026-05-18: v8 -- replaced winget+Wait-ForNvmInstall with portable nvm-noinstall.zip download (Install-NvmPortable + Set-NvmEnvironment). Deterministic, no installer race. Issue #251, PR #257.
