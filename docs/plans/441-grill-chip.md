# Chip's Grill -- Plan for #441
**Date:** 2026-05-27
**Verdict:** Revise

---

## Untested Assumptions

1. **`$TestDrive` is available in the test harness.** Plan Pattern A uses `$TestDrive` in its mock
   scaffold. `$TestDrive` is a Pester-specific variable. The existing `test_windows_setup.ps1`
   uses a CUSTOM `Test-Scenario`/`Write-Skip` harness -- NOT Pester. `$TestDrive` will be `$null`
   at runtime, silently directing writes to the filesystem root or throwing. This is a
   showstopper for Pattern A as written.

2. **`$PROFILE` is assignable in the test host.** The existing Group C tests do
   `$PROFILE = $c2Profile` and `$PROFILE = $c3Profile`. This works in PS 5.1 but THROWS in
   PS 7+: "Cannot overwrite variable PROFILE because it is read-only or constant." Goofy's GG
   tests inherit this harness pattern without acknowledging that it only runs clean on one of
   the two target hosts.

3. **`Invoke-HostQuery` is a real function in production code.** Pattern B requires the
   production implementation to expose `Invoke-HostQuery` as an overridable wrapper. The
   pseudo-code shows it, but the plan never explicitly mandates it as an implementation
   requirement. If the implementer inlines `& $HostExe -NoProfile -Command '$PROFILE'` directly
   inside `Resolve-ProfilePath` without the wrapper, Pattern B tests are untestable.

4. **`Select-Object -Unique` deduplicates Windows paths correctly.** The plan's dedup step uses
   `| Select-Object -Unique`. On Windows, paths are case-insensitive but `Select-Object -Unique`
   is case-sensitive in PowerShell. `C:\Users\foo\OneDrive\Documents\PowerShell\...` and
   `c:\users\foo\onedrive\documents\PowerShell\...` are NOT deduplicated. No test covers this.

5. **Write-Info output is capturable in the test harness.** GG-9 asserts "Write-Info output
   contains the mocked OneDrive path." Write-Info calls Write-Host, which writes to the
   information stream (stream 6), not stdout. Capturing it requires `*>&1` or `6>&1`
   redirection. The existing harness never does this. GG-9 as described cannot pass or fail --
   it will silently not capture anything.

6. **The resolved path fits in 260 characters.** OneDrive tenant paths can be long:
   `C:\Users\firstname.lastname\OneDrive - Contoso Corp Limited\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
   is 143 chars just as a base. Usernames + tenant names in corporate environments frequently
   exceed 260 chars total. On systems without long-path support (`LongPathsEnabled = 0`),
   `New-Item` and `Add-Content` silently fail or throw PathTooLongException. Not in edge cases;
   not tested.

7. **The old hardcoded path and the new resolved path cannot collide in a way that causes double-strip.**
   The cleanup pseudo-code checks `$profilePaths -notcontains $legacy` -- a case-sensitive
   contains check -- before stripping the legacy file. If the paths match except for case, the
   cleanup SKIPS the strip on the file that IS the write target, then the write loop appends a
   NEW block on top of the un-stripped existing block. Double-write. Not tested.

8. **A `pwsh` installed during the same setup run is reachable by `Get-Command`.** If winget
   installs PS 7+ earlier in setup.ps1, the new pwsh.exe is not on PATH in the current process
   until the terminal restarts (a known Windows PATH refresh problem). `Get-Command pwsh` fails,
   fallback triggers, and the block lands at the hardcoded path -- not the OneDrive path. This
   is exactly the bug we are fixing, and it silently regresses on first-run installs. Open
   Question 3 acknowledges this but the test plan has no coverage.

---

## Missing Edge Cases

9. **Partial/corrupt block (BEGIN present, END absent).** If setup was killed mid-write,
   the profile may contain `# BEGIN dev-setup profile` but no `# END dev-setup profile`.
   The strip regex `(?s)\r?\n..BEGIN...*?..END..\r?\n?` does NOT match a partial block
   (lazy `.*?` requires END to be present). The next run appends a new complete block on top
   of the orphaned BEGIN. After two interrupted runs the file has two BEGIN sentinels and one
   END. The idempotency claim breaks.
   Repro: `Write-Output "# BEGIN dev-setup profile`n# partial" | Set-Content $testProfile`,
   then call `Write-PowerShellProfile`. Verify only one BEGIN exists.

10. **Profile file exists but is read-only (Group Policy locked or `attrib +R`).** `Add-Content`
    throws "Access to the path ... is denied." The catch+continue pattern handles it, but no
    test verifies (a) the catch fires, (b) the function continues to the second path rather
    than aborting entirely, and (c) `Write-Err` is emitted, not `Write-Ok`.
    Repro: `Set-ItemProperty $testProfile -Name IsReadOnly -Value $true` before calling the
    function. Assert Write-Ok is NOT in output and the function did not throw.

11. **Profile directory is a symlink/junction to a disconnected network drive.** `Test-Path`
    on a dangling junction returns `$false` on Windows (junction exists, target does not). This
    is different from E8 (UNC path offline) -- here `New-Item -Force` is called because
    `Test-Path` returned false, and `New-Item` on a junction parent may succeed or fail
    depending on driver. Not covered by any edge case entry.
    Repro: Create a directory junction `mklink /J "$env:TEMP\fake_docs" "Z:\nonexistent"`;
    set the resolved path to point through it; call `Write-PowerShellProfile`; verify error
    is caught and reported.

12. **`$PROFILE` host query returns multi-line output (E6) -- "take first non-empty line" is
    not in the pseudo-code.** Goofy lists E6 in the table but the `Resolve-ProfilePath`
    pseudo-code only calls `$resolved.Trim()`. Trim() does NOT take the first line of a
    multi-line string -- it only strips leading/trailing whitespace. A `$PROFILE` that returns
    two lines (e.g., a corporate bootstrap that Write-Hosts a banner before printing the path)
    results in a path containing a newline character, which `New-Item` will reject.
    Repro: Mock `Invoke-HostQuery` to return `"Banner text`nC:\path\to\profile.ps1"`.
    Assert `Resolve-ProfilePath` returns ONLY the path line.

13. **Long profile path > 260 chars on a system without LongPathsEnabled.**
    Repro: Construct a mock `Invoke-HostQuery` response that returns a 270-char path.
    Call `Write-PowerShellProfile`. On a system with
    `HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 0`, assert
    Write-Err is emitted and the function continues to the next path.

14. **ConstrainedLanguage Mode (CLM) blocks `Add-Content` on the profile file.** E11 notes
    "Writing the file may fail if CLM also locks filesystem writes." The plan says "emit
    Write-Warn and proceed" but there is no test that verifies this behavior. The existing
    test suite has no CLM test at all.

15. **Legacy orphan on KFM system where BOTH the legacy path and the resolved path exist.**
    Scenario: User ran setup with old code (block at `$HOME\Documents\PowerShell\...`) then
    also has a real OneDrive Documents profile at the resolved path with unrelated content.
    The cleanup should strip only the dev-setup block from the legacy file, leaving the
    resolved file's existing content untouched. No test verifies this.

---

## Test Plan Gaps

16. **No test for legacy orphan cleanup at all.** Section 6 of the plan describes the cleanup
    algorithm in detail. GG-1 through GG-10 contain ZERO tests that:
    - Create a file at the hardcoded legacy path containing the dev-setup block
    - Set the resolved path to something different
    - Call `Write-PowerShellProfile`
    - Assert the legacy file no longer contains the BEGIN..END block
    - Assert the resolved file contains the BEGIN..END block
    This is the entire value proposition of the backward-compatibility section. It is
    completely untested.

17. **Idempotency tested only twice (2 runs). Three-run test missing.** Group C-3 tests 2 runs.
    The existing comment says "run setup.ps1 twice. Three times." No GG test calls
    `Write-PowerShellProfile` three times in succession and asserts the file size and block
    count are unchanged. The strip+re-inject pattern creates a subtle risk: run 1 strips
    nothing (file empty), injects block; run 2 strips block, injects block; run 3 should
    strip block, inject block. If there is any off-by-one in the strip regex (e.g., it strips
    one too many leading newlines), the file shrinks by one byte each run and three runs proves
    that two runs did not.

18. **No test that the SECOND profile path gets its own independent idempotency guarantee.**
    C-3 only tests one profile path (via `$PROFILE` override). With the new two-path logic,
    we need idempotency verified on EACH resolved path independently AND when both paths are
    active simultaneously.

19. **GG-5 (dedup) does not verify write actually occurred.** GG-5 verifies that
    `$profilePaths` after dedup has length 1. But it does not verify that the function
    WROTE the content to that one file. A bug that deduplicates but then writes nothing
    would pass GG-5.

20. **No test that the function handles `$HOME` being an empty/null string.** If the `HOME`
    environment variable is unset (exotic CI, Docker), the fallback construction
    `[System.IO.Path]::Combine($HOME, 'Documents', ...)` produces a relative path. No test
    covers this; the function would write to a relative path silently.

21. **GG-S1 static assertion is too narrow.** Checking for literal `$HOME, 'Documents'` does
    not catch `"$HOME\Documents"` string interpolation, `$env:USERPROFILE + '\Documents'`,
    or `Join-Path $HOME Documents`. A regex-based check for any of these patterns is needed,
    or the static test provides false confidence.

22. **No test for execution policy `Restricted` blocking the child process query.** Risk R2
    notes this. Plan says "-Command (not -File) should work under Restricted." This claim is
    unverified by any test. It needs a test that simulates `Get-ExecutionPolicy` returning
    Restricted and verifies the child process launch either succeeds or falls back gracefully.

23. **No test that `Set-Content -NoNewline -Encoding ASCII` during strip does not corrupt a
    UTF-8-with-BOM profile.** If the existing profile was saved as UTF-8 BOM, overwriting
    with ASCII via Set-Content strips the BOM but also converts the ENTIRE file to ASCII,
    potentially corrupting any non-ASCII characters in user content. No test covers this
    encoding interaction.

---

## CI Concerns

24. **OneDrive KFM cannot be simulated on GitHub Actions `windows-latest`.** OneDrive client is
    not installed; KFM registry keys are absent; `[Environment]::GetFolderPath('MyDocuments')`
    returns the non-redirected default path. Mocked unit tests (Pattern B) can run, but there
    is no integration gate that exercises the ACTUAL `& powershell -NoProfile -Command '$PROFILE'`
    resolution on a KFM-redirected machine. The fix can ship and silently fail on any KFM
    machine without a CI failure.
    Recommendation: add a manual integration test checklist item that MUST be run on a real
    KFM machine before merge. Document this explicitly in the PR template for issue #441.

25. **Child process spawning (`& powershell -NoProfile ...`) adds 2-6 seconds per run in CI.**
    GitHub Actions runners are slow for process spawning. Each host query spawns a new
    PowerShell process. Two hosts = ~4-10 seconds added to the test run. This is probably
    acceptable for a setup script but should be measured. If tests mock `Invoke-HostQuery`
    correctly, CI tests should NOT spawn real child processes at all -- verify the mock is
    active before the child process call, not after.

26. **PS 5.1 `powershell.exe` is available on `windows-latest` but its behavior differs from
    real user machines.** GitHub Actions runners have `powershell.exe` v5.1 but the Documents
    folder is NOT redirected via OneDrive. Tests that probe `$PROFILE` resolution via the real
    child process will always return the non-KFM path, which passes GG-1 for the wrong reason
    (the mock path happens to equal the fallback). Tests MUST use the mocked `Invoke-HostQuery`
    and NOT rely on the live child process output to verify correctness.

27. **The test file now imports `lib/profile-path.ps1` (new file).** If the lib file does not
    exist yet (Goofy's implementation is incomplete), every test in Group GG that dot-sources
    it will throw at load time, crashing the entire `test_windows_setup.ps1` run and causing
    ALL groups (A through G, previously passing) to report as zero tests run. Guard the import.

---

## Manual Smoke Test I'd Actually Run

Run these steps IN ORDER on a real Windows machine that has OneDrive KFM active. If no KFM
machine is available, simulate it via registry:

```
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" ^
  /v "Personal" /t REG_SZ /d "C:\Users\%USERNAME%\OneDrive\Documents" /f
```

1. **Verify the bug is reproducible before the fix.**
   Open a NEW PowerShell 7 terminal. Run: `$PROFILE` -- note the path (should contain
   `OneDrive`). Open Windows Explorer and verify the path the OLD script would write to
   (`$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) either does
   not exist or does not contain the dev-setup block. Run `gs` or `gpl` -- confirm they
   are NOT defined.

2. **Capture baseline file state.**
   Note whether `$env:USERPROFILE\Documents\PowerShell\...` and the OneDrive path exist
   and their sizes.

3. **Run setup once with the fix.**
   ```
   powershell -ExecutionPolicy Bypass -File setup.ps1
   ```
   Watch for these in the output (required per acceptance criterion):
   - "Resolved powershell profile: C:\Users\...\OneDrive\Documents\WindowsPowerShell\..."
   - "Resolved pwsh profile: C:\Users\...\OneDrive\Documents\PowerShell\..."
   - "Profile written: [OneDrive path] (N bytes)"
   - No "Profile written" line pointing to $HOME\Documents (non-OneDrive)

4. **Verify the correct file was written.**
   `Get-Content (& pwsh -NoProfile -Command '$PROFILE')` -- confirm it contains
   `# BEGIN dev-setup profile` and `# END dev-setup profile` as distinct lines.
   `Get-Content (& powershell -NoProfile -Command '$PROFILE')` -- same check.

5. **Open a NEW terminal (critical -- must be a fresh session to load the profile).**
   Run: `gs`, `gpl`, `ep` -- all must work. Run `Get-Alias gs` -- must resolve to
   `Get-GitStatus`. If any alias is missing, the fix failed.

6. **Run setup a second time (idempotency check).**
   Note the file sizes before the second run. Run setup again. Check file sizes are
   unchanged. Run `Select-String -Path $PROFILE -Pattern "BEGIN dev-setup profile"` --
   must return exactly ONE match.

7. **Run setup a third time.** Same size check. Same single-match check.

8. **Legacy orphan cleanup check (KFM scenario only).**
   Manually create the block at the hardcoded path:
   ```powershell
   $legacy = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
   New-Item -Force -ItemType Directory (Split-Path $legacy) | Out-Null
   Add-Content $legacy "# BEGIN dev-setup profile`n# fake`n# END dev-setup profile"
   ```
   Run setup again. Check that `$legacy` no longer contains the BEGIN marker.
   Check that the OneDrive path still has exactly one BEGIN..END block.

9. **Uninstall check.**
   Run `scripts\windows\uninstall.ps1`. Open a NEW terminal. Run `gs` -- must be
   undefined (or return the system default if one existed before). Check BOTH the OneDrive
   path and the legacy hardcoded path -- neither should contain the dev-setup block.

10. **Re-run setup after uninstall (round-trip idempotency).**
    Run setup again. Open a new terminal. Confirm aliases work. This catches any state the
    uninstall leaves behind that breaks a clean re-install.

---

## If This Goes To Revision

**Revision owner:** Mickey (NOT Goofy -- original author is excluded per team charter)

**Required changes (ordered):**

1. Replace all `$TestDrive` references in Pattern A with an explicit temp directory created
   via `$script:GGTempDir = Join-Path $PSScriptRoot "temp_gg_$(Get-Random)"` and cleaned up
   in a `finally` block. Do NOT assume Pester is available.

2. Fix the `$PROFILE` mutability problem. In PS7+, `$PROFILE` cannot be assigned directly.
   The test harness must stop using `$PROFILE = $path`. Instead, use the `Invoke-HostQuery`
   mock pattern exclusively (Pattern B). Remove Pattern A from the plan entirely or mark it
   PS5.1-only with a runtime version guard.

3. Mandate that `Invoke-HostQuery` is a named, overridable function in the production
   implementation of `Resolve-ProfilePath`. Add this as an explicit implementation
   requirement (not just a test pattern). Without this, the tests cannot mock the child
   process.

4. Fix `Select-Object -Unique` to use case-insensitive dedup on Windows paths:
   `$profilePaths | Sort-Object { $_.ToLower() } -Unique`
   or use a HashSet with `StringComparer.OrdinalIgnoreCase`. Add test GG-5b covering
   paths that differ only in case.

5. Add the multi-line output guard to `Resolve-ProfilePath` pseudo-code. After `Trim()`,
   add: `$resolved = ($resolved -split '\r?\n' | Where-Object { $_ -ne '' } | Select-Object -First 1)`.
   Add test for this (GG-8b: Invoke-HostQuery returns banner + path on two lines).

6. Add legacy orphan cleanup tests. At minimum:
   - GG-11: legacy path exists with dev-setup block, resolved path differs -- after run,
     legacy block is gone, resolved path has the block.
   - GG-12: legacy path and resolved path are the same -- no double-strip.
   - GG-13: legacy path exists with ONLY user content (no sentinel) -- run does not touch it.

7. Add three-run idempotency test (GG-14): call `Write-PowerShellProfile` three times in
   a loop on a temp file; assert block count == 1 and file size is stable after runs 2 and 3.

8. Add read-only file test (GG-15): create temp profile, set IsReadOnly = $true, call
   function, assert Write-Err was emitted (redirect stream 3) and function did not throw.

9. Add partial-block test (GG-16): create temp profile with only the BEGIN marker and no
   END, call function twice, assert exactly one BEGIN and one END exist after both calls.

10. Document OneDrive KFM integration test as a MANUAL GATE in the PR checklist. Add a
    `[MANUAL GATE -- KFM machine required]` section to the PR template for issue #441.
    CI cannot substitute for this.

---

## Final Verdict

The architecture in Goofy's plan is sound -- asking the host for its own `$PROFILE` is the
correct fix and the edge case analysis is thorough. However, the test plan has multiple
showstopper gaps that would let the fix ship with no actual test coverage of its core
value: the legacy orphan cleanup is completely untested, the `$TestDrive` reference
breaks the harness on the existing non-Pester scaffold, and the `$PROFILE` direct
assignment pattern fails silently in PS7+ (the very host this fix targets). A plan with
this many untested paths is not approvable as written.

The revision required is primarily TEST PLAN surgery, not algorithm surgery. Goofy's
algorithm is defensible -- the tests just do not prove it. The case-insensitive dedup bug
and the multi-line Trim() gap are also real code defects that must be corrected before
implementation. Mickey must own the revision to enforce architectural consistency across
the test harness, since the PS7+ `$PROFILE` mutability issue cuts across the entire Group
C pattern and a redesign affects all existing profile tests, not just Group GG.
