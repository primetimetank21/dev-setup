## Goofy -- Verification Report

### V-1: nvm.ps1 path resolution bug

- **Verdict:** CONFIRMED
- **Citations:** 
  - scripts/windows/tools/nvm.ps1:21-22
  - scripts/lib/Read-ToolVersion.ps1 (actual location)
  - scripts/windows/lib directory listing (only contains logging.ps1)
- **The bug:** Line 21 computes `$libDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'lib'` which resolves to `scripts\windows\lib`. Line 22 then dot-sources `Read-ToolVersion.ps1` from that directory. But `Read-ToolVersion.ps1` actually exists at `scripts\lib\` (shared, cross-platform), not `scripts\windows\lib\`. The nvm.ps1 file runs at `$PSScriptRoot = scripts\windows\tools`, so `Split-Path -Parent` = `scripts\windows`. Joining 'lib' gives `scripts\windows\lib\` — wrong. Actual location is `scripts\lib\` (one level higher in the directory tree).
- **Why CI didn't catch it:** Installers (nvm.ps1, etc.) are not exercised in CI; only their sourcing syntax is validated. Runtime execution would crash with "file not found" when Install-Nvm tries to dot-source the missing file.
- **Nuance the original finding missed:** The pattern is repeatable. dotfiles.ps1 (line 15) uses a similar nested Split-Path approach to traverse UP to repo root, and it works correctly. The difference: dotfiles needs to go UP three levels (scripts → windows → tools → repo), while nvm only needs to go UP one level to the shared scripts/lib. The fix is straightforward: either use `Split-Path -Parent` twice (scripts/windows/tools → scripts/windows → scripts), or change the second join to navigate to the shared lib via the repo root.
- **Recommended phase:** P0
- **Effort estimate:** S
- **Notes:** This is a runtime blocker. If a user runs setup on Windows and happens to trigger Install-Nvm, the function will fail at the dot-source line. The fact that it's not caught in CI is a gap — we should either: (a) mock the .tool-versions file and test installer functions, or (b) at least do a syntax-only parse check that validates dot-source targets exist.

---

### V-7: auth.ps1 misplaced

- **Verdict:** CONFIRMED (structural misalignment)
- **Citations:**
  - scripts/windows/auth.ps1 (exists at root of scripts/windows/)
  - scripts/windows/tools/*.ps1 (all tool scripts follow per-tool file layout)
  - scripts/windows/setup.ps1 (orchestrator calls tool functions)
- **The issue:** `auth.ps1` is placed at `scripts/windows/auth.ps1`, but all other tool installers live under `scripts/windows/tools/`. The file contains `Invoke-GhAuth` function (idempotent check + interactive auth flow), which mirrors the per-tool Install-XYZ function pattern. Looking at the tool scripts (git.ps1, gh.ps1, uv.ps1, vim.ps1, nvm.ps1, etc.), they all follow the same structure: single exported function (Install-*), dot-source logging.ps1, return early if already installed.
- **Why it should be moved:** PR #195 refactored the Windows setup to use a per-tool modular layout. All install functions now live under tools/. The auth.ps1 file follows the same pattern as the tools and should be co-located with them for consistency and discoverability.
- **Nuance the original finding missed:** The file is not actually called `Install-Auth` — it exports `Invoke-GhAuth`. This is mildly inconsistent with the naming convention (gh.ps1 exports Install-GhCli, copilot.ps1 exports Install-CopilotCli). The function name should probably be renamed to Install-GhAuth for consistency, then the file can move to tools/.
- **Caller impact:** scripts/windows/setup.ps1 currently sources from root. Moving auth.ps1 requires updating the setup orchestrator to source from tools/ and any grep of setup.ps1 that looks for `. "$PSScriptRoot\auth.ps1"`.
- **Recommended phase:** P2
- **Effort estimate:** S (move file + rename function + update 2-3 sourcing lines)
- **Notes:** Not a bug — the code works. But it's an architectural inconsistency that violates the per-tool pattern. Low risk to fix since the codebase is young and tests are in place.

---

### V-11: .gitattributes CRLF rules missing

- **Verdict:** CONFIRMED
- **Citations:** .gitattributes (lines 1-19; no *.ps1 rule present)
- **The issue:** .gitattributes defines `* text=auto eol=lf` as the global default and then lists explicit overrides for .sh, .bash, .zsh, .md, .json, .yml, .yaml, .aliases, .vimrc — all set to `eol=lf`. There is NO rule for `*.ps1` files. This means PowerShell scripts will checkout with LF (due to the global `eol=lf` default) on Windows systems that don't have core.eol or core.autocrlf configured globally.
- **Why it matters:** PowerShell on Windows traditionally expects CRLF line endings (the Windows standard). While modern PowerShell 7+ handles both LF and CRLF without complaint, older code or Windows automation tools might expect CRLF. More importantly, git conventions suggest Windows-native files should be CRLF. The global `eol=lf` override is aggressive — it forces POSIX line endings on ALL files unless explicitly excepted.
- **Best practice:** Windows PowerShell scripts should have `*.ps1 text eol=crlf` in .gitattributes. Alternatively, if the repo is intentionally POSIX-ified (all LF, including Windows scripts), the .gitattributes is correct but should document this in README or a comment.
- **Nuance the original finding missed:** Looking at history.md, the repo explicitly enforces ASCII-only and uses Set-StrictMode on all .ps1 files, suggesting the team wants to keep scripts portable and consistent. The use of LF for .ps1 may be intentional (easier to manage in Git, works with PS 7+). If so, it's a design choice, not a bug. But it should be documented.
- **Recommended phase:** P2
- **Effort estimate:** S
- **Notes:** This is not a functional bug today (PS 5.1 and 7+ both handle LF .ps1 files), but it's a deviation from Windows conventions. If the team decides to enforce CRLF for .ps1 files, add one line to .gitattributes. If the team intends LF-only across the board, document it.

---

### V-13: LASTEXITCODE checks missing after winget/npm installs

- **Verdict:** CONFIRMED
- **Citations:**
  - scripts/windows/tools/git.ps1:19 — `winget install ... ` (no check after)
  - scripts/windows/tools/gh.ps1:17 — `winget install ...` (no check after)
  - scripts/windows/tools/vim.ps1:18 — `winget install ...` (no check after)
  - scripts/windows/tools/psmux.ps1:18 — `winget install ...` (no check after)
  - scripts/windows/tools/copilot.ps1:30 — `winget install ...` (no check after)
  - scripts/windows/tools/uv.ps1:17 — `powershell -ExecutionPolicy ... | iex` (no check after)
  - scripts/windows/tools/squad-cli.ps1:25 — `npm install -g ...` (no check after)
- **The issue:** All of these lines invoke external commands (winget, npm, PowerShell download scripts) that can fail silently. None of them check $LASTEXITCODE afterward. If winget returns exit code 1 (install failed), or npm install fails due to network, the script continues as if the install succeeded.
- **Implicit failures (OK patterns):** 
  - git.ps1:14 calls `Get-Command git` right after (will fail if install failed) — OK
  - gh.ps1:12 calls `Get-Command gh` right after — OK
  - vim.ps1:20 calls `Get-ChildItem` to find vim.exe; will fail silently and fall through to "vim installed" message (NOT OK — should check result)
  - nvm.ps1 does NOT check Get-Command after winget — relies on later `nvm list` call; could crash harder at that point
- **The pattern to adopt:**
  ```powershell
  winget install --id Foo.Bar --silent --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) {
      Write-Err "Failed to install Foo.Bar (exit code $LASTEXITCODE)"
      throw "Install-Foo failed"
  }
  ```
- **Why it matters:** Silent failure is dangerous. A user runs setup, sees the OK messages, and the next command tries to use a tool that wasn't actually installed (e.g., nvm not found, node --version fails).
- **Nuance the original finding missed:** Some installers will later fail on Get-Command checks (git, gh) which catch the silent failure downstream, but others (vim, nvm, squad-cli) may not have a sufficient downstream guard and could leave the system in a half-installed state.
- **Recommended phase:** P1
- **Effort estimate:** M (requires careful review + testing to ensure error exits don't mask transient failures; need to decide on strategy: fail hard or skip-with-warn)
- **Notes:** This is a moderate-severity issue. The team should decide: (a) fail-fast on any install error, or (b) warn-and-continue for specific tools. Either way, add explicit LASTEXITCODE checks.

---

### V-15: Encoding policy drift (profile.ps1, uninstall.ps1)

- **Verdict:** CONFIRMED (violates ps51-runtime-file-encoding skill)
- **Citations:**
  - scripts/windows/tools/profile.ps1:28 — `Set-Content $profilePath $raw -NoNewline` (no `-Encoding`)
  - scripts/windows/tools/profile.ps1:294 — `Add-Content -Path $profilePath -Value ""`  (no `-Encoding`)
  - scripts/windows/tools/profile.ps1:296 — `Add-Content -Path $profilePath -Value $profileContent` (no `-Encoding`)
  - scripts/windows/uninstall.ps1:91 — `Set-Content $ProfilePath $cleaned -NoNewline` (no `-Encoding`)
- **The skill requirement:** From `.squad/skills/ps51-runtime-file-encoding/SKILL.md`: When a PowerShell script writes a file at runtime that will be read by a POSIX tool, non-PowerShell consumer, or byte-sensitive reader, you MUST specify `-Encoding ASCII` or use `[System.IO.File]::WriteAllText()`. On PS 5.1, `Set-Content -Encoding UTF8` writes UTF-8 **with BOM** (bytes EF BB BF); PS 7+ writes UTF-8 **without** BOM. The BOM breaks POSIX sh readers and git hooks.
- **What profile.ps1 and uninstall.ps1 write:** PowerShell profile files (.ps1) that will only be read by PowerShell. These are NOT consumed by POSIX tools. So the BOM is harmless.
- **But the skill applies anyway:** The skill says "Write before ... any `Set-Content`, `Add-Content`, or `>` redirection in a `.ps1` file that other-language code will consume." These files only output to PowerShell profiles (PowerShell will read them), so strictly speaking the skill doesn't apply. However, the code violates the blanket pattern: every `Set-Content` / `Add-Content` should have explicit encoding to be safe.
- **Practical impact:** profile.ps1 and uninstall.ps1 will work correctly today on both PS 5.1 and PS 7+, because PowerShell itself handles BOM transparently when reading profiles. But it's a policy violation and bad hygiene.
- **Default behavior:** `Set-Content` without `-Encoding` on PS 5.1 defaults to ASCII (or sometimes system-dependent). On PS 7+ it defaults to UTF-8 no-BOM. This inconsistency is why the skill mandates explicit encoding.
- **The fix:** Add `-Encoding ASCII` to all four calls (since profile content is ASCII text), or use `[System.IO.File]::WriteAllText()` for consistency with the skill's safer choice. The profile content is pure ASCII (no non-ASCII characters needed), so `-Encoding ASCII` is appropriate and portable.
- **Nuance the original finding missed:** The impact is LOW because these files are only consumed by PowerShell (which ignores BOM). But if someone ever extracts profile config to a shell script or data file, the BOM would be present and cause issues.
- **Recommended phase:** P2
- **Effort estimate:** S (add 4 `-Encoding ASCII` flags)
- **Notes:** This is a hygiene issue, not a bug. It's worth fixing to align with the team skill and establish a pattern, but it doesn't cause runtime failure today. When fixed, add a comment referencing the ps51-runtime-file-encoding skill for future reviewers.

---

## Summary

**V-1 (nvm.ps1 path resolution)** is a real runtime bug (P0). The path resolution is broken; Install-Nvm will crash if called. Easy fix: navigate to scripts/lib correctly by using `Split-Path -Parent` twice or absolute path computation.

**V-7 (auth.ps1 placement)** is a structural inconsistency (P2). The code works, but violates the per-tool layout pattern from PR #195. Move to tools/, rename function to Install-GhAuth, update callers.

**V-11 (.gitattributes ps1 rules)** is a missing convention (P2). PowerShell scripts checkout with LF due to global eol=lf default. Windows convention expects CRLF, but the repo may be intentionally POSIX-ified. Document the choice or add `*.ps1 text eol=crlf`.

**V-13 (LASTEXITCODE checks)** is a moderate-severity gap (P1). Seven install commands (winget, npm, etc.) don't check $LASTEXITCODE after execution. Silent failures possible. Add explicit checks.

**V-15 (Encoding policy drift)** is a hygiene violation (P2). profile.ps1 and uninstall.ps1 use Set-Content/Add-Content without explicit `-Encoding`. Works today (PowerShell ignores BOM), but violates the ps51-runtime-file-encoding skill. Fix by adding `-Encoding ASCII`.

**Recommended action priority:** Fix V-1 immediately (bug), then V-13 (error handling), then V-7 and V-15 (refactoring + hygiene).
