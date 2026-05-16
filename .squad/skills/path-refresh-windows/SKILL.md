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

2. **winget returns before the installer finishes.** For installers like
   `CoreyButler.NVMforWindows` that wrap a setup.exe, `winget install --silent`
   can return BEFORE the inner installer has written files or updated the
   registry. Calling `Refresh-SessionPath` immediately after may find nothing.
   The installer can take 100+ seconds in CI (observed ~100s on GH Actions
   windows-latest), so the default timeout is 180s.

   **Fix:** `Wait-ForNvmInstall` in `scripts/windows/lib/path.ps1` polls with
   a two-pronged strategy: (1) `Refresh-SessionPath` + `Get-Command nvm` as
   the primary signal (catches the registry update regardless of install path),
   and (2) direct path probing of 7 candidate directories as a fallback (catches
   cases where the registry update is delayed).

3. **Machine before User.** Windows resolves PATH left-to-right. Putting
   Machine first matches the default shell behavior.

4. **No equivalent on Linux.** On Linux, `nvm` modifies `$PATH` in the
   current shell via `source nvm.sh` -- no registry involved.

---

## Citations

- `scripts/windows/lib/path.ps1` -- `Refresh-SessionPath` function (PR #201, #251)
- `scripts/windows/lib/path.ps1` -- `Wait-ForNvmInstall` polling helper (PR #257, #251)
- `scripts/windows/tools/nvm.ps1` -- calls Refresh-SessionPath + Wait-ForNvmInstall (PR #201, #257)
- `scripts/windows/tools/vim.ps1` -- earlier inline PATH refresh (same pattern)

---

## Changelog

- 2026-05-16: changed from replace to merge. Issue #251 (GH Actions tool-cache Node was being wiped).
- 2026-05-18: added Wait-ForNvmInstall polling helper. winget returns before nvm-setup.exe finishes; polling 5 candidate paths with 90s timeout. Issue #251, PR #257.
- 2026-05-18: v6 -- bumped timeout to 180s (installer took ~100s in CI); poll loop now uses Refresh-SessionPath + Get-Command as primary signal, expanded candidate paths (7 dirs) as fallback; diagnostic dump on timeout. Issue #251, PR #257.
