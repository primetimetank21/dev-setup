# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Pluto (Config Engineer -- architecture/algorithm correctness angle)
**Plan reviewed:** docs/plans/441-profile-path.md (v3, author: Donald)
**Date:** 2026-05-27
**Verdict:** REVISE

**Author locked out:** Goofy (v1), Mickey (v2), Donald (v3)
**Eligible next reviser (if REVISE):** Chip

---

## Angle: Architecture & Algorithm Correctness

---

### Findings

**1. Drive-letter regex `'^[A-Za-z]:\\'` -- correct and scope-consistent (no hole)**

plan:Section 4, line 98: `if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }`

The regex is correct:
- Accepts both uppercase and lowercase drive letters. [Environment]::GetFolderPath returns
  uppercase on standard Windows, but lowercase is legal on case-insensitive NTFS. The
  inclusive range is the right defensive posture.
- Rejects UNC paths (`\\server\share\...`). UNC is explicitly OUT per Section 2. Rejecting
  a UNC-returning host and falling back to the hardcoded path is consistent with the scope
  decision. No contradiction.
- Rejects error message strings, PSReadLine artifacts, partial stack traces, and other
  garbage that could slip through `Select-Object -Last 1`.

Minor gap (non-blocking): individual split-result lines are NOT trimmed before the regex
check. `$raw.Trim()` strips the outer blob; `Where-Object { $_ }` drops empty lines; but
each surviving line may still carry a trailing space or trailing `\r` if the host emits
unexpected whitespace. The regex `'^[A-Za-z]:\\'` checks the PREFIX only -- it passes a
path like `C:\Users\Earl\..._profile.ps1 ` (trailing space). Downstream `Split-Path` and
`New-Item` accept such strings on most PS versions, but strict-mode + symlinked directories
can misbehave. A one-liner `$resolved = $resolved.Trim()` after `Select-Object -Last 1`
would close this gap.

Verdict on item: not blocking; suggest add-trim as implementation note.

---

**2. `-NoLogo` on powershell.exe 5.1 and pwsh.exe -- valid, non-issue**

plan:Section 3 v3-D1, Section 4 Invoke-HostQuery: `& $Exe -NoProfile -NonInteractive -NoLogo -Command '$PROFILE' 2>$null`

`-NoLogo` has been a documented parameter of `powershell.exe` since Windows PowerShell 2.0
(suppresses the copyright banner). It is equally valid on `pwsh.exe` (PS 7+). No version
caveat applies.

If `-NoLogo` were unsupported on a given binary (hypothetical), `powershell.exe` would
write the "Unknown parameter" message to stderr and exit non-zero. `2>$null` suppresses
the stderr noise; the non-zero `$LASTEXITCODE` -- now checked in v3 -- triggers the warning
and fallback. Defense-in-depth is intact even for the hypothetical.

Verdict on item: clean. No hole.

---

**3. `$LASTEXITCODE` after `Invoke-HostQuery` with `2>$null` -- no interference, check is correct**

plan:Section 4 Resolve-ProfilePath: `$raw = Invoke-HostQuery -Exe $HostExe` then `if ($LASTEXITCODE -ne 0)`

`$LASTEXITCODE` is set by the exit code of the child process at the moment it exits. Stream
redirection (`2>$null`) suppresses output bytes -- it has no effect on the exit-code
integer. The check is valid.

`Invoke-HostQuery` is a PS function, not an external command. Calling it does NOT reset
`$LASTEXITCODE`. Inside the function, `& $Exe ...` is the only statement, so `$LASTEXITCODE`
after the function returns equals the exit code of that one external call. The variable is
global-scoped in PS and is not reset by function return. The pattern is correct.

One implementation note: if a previous external command in the same script left a non-zero
`$LASTEXITCODE` and `Get-Command $HostExe` somehow throws BEFORE `Invoke-HostQuery` is
reached, the stale `$LASTEXITCODE` could theoretically be read. But the guard is `if (-not
(Get-Command $HostExe -EA SilentlyContinue))`, which is a PS cmdlet -- it does not touch
`$LASTEXITCODE`. And the check fires only AFTER `Invoke-HostQuery` returns, not before. So
no stale-value leak path exists in the algorithm as written.

Verdict on item: clean. No hole.

---

**4. `try/catch` + `$LASTEXITCODE` ordering under `$ErrorActionPreference = 'Stop'` -- correct**

plan:Section 4 Resolve-ProfilePath, production profile.ps1 line 7: `$ErrorActionPreference = 'Stop'`

Under `$ErrorActionPreference = 'Stop'`, PS cmdlet non-terminating errors become
terminating (caught by `catch`). External process calls via `& $Exe` are NOT subject to
this promotion -- they set `$LASTEXITCODE` and return silently regardless of exit code.
The two error-handling paths are orthogonal:

- `catch` fires only for PS-native exceptions (e.g., `CommandNotFoundException` if `& $Exe`
  somehow resolves to a nonexistent command after the `Get-Command` gate, or if
  `Write-Info`/`Write-Warn` throw due to a logging failure).
- `$LASTEXITCODE -ne 0` fires only for successful-launch-but-failed-exit of the external
  process.

The plan question "does try/catch catch it before $LASTEXITCODE fires?" applies only if
the external process itself throws in the PARENT scope -- which `& $Exe` cannot do (it
either launches the process, or fails to launch and throws `CommandNotFoundException`,
which is a PS exception handled by `catch`). If `$PROFILE` inside the CHILD process is
somehow inaccessible, the child exits (possibly non-zero) and the parent's `$LASTEXITCODE`
check handles it. The catch block is never involved in child-process-level errors.

Verdict on item: clean. Algorithm ordering is correct and complete.

---

**5. Legacy cleanup loop body is an empty stub -- BLOCKING**

plan:Section 4, lines 113-118:

```
foreach ($legacy in $legacyPaths) {
    $isLegacy = -not ($profilePaths | Where-Object { $_.ToLower() -eq $legacy.ToLower() })
    if ($isLegacy -and (Test-Path $legacy) -and (Select-String -Path $legacy -Pattern $beginMarker -Quiet)) {
        # Strip block from orphaned legacy file
    }
}
```

The loop body is a single comment. No stripping code exists. The plan does not name a
function to call, does not inline the regex, and does not reference the strip logic from
production `uninstall.ps1` (`Remove-DevSetupProfileBlock`). The comment reads as a
placeholder that was never filled in.

This is a plan-internal contradiction:
- Section 5 GG-4 asserts "Both legacy paths stripped" and checks that neither legacy file
  has the BEGIN marker after the run.
- Section 4 contains no stripping code. GG-4 would fail against the algorithm as written.

The fix is one of three options:
  (A) Inline the strip regex (same pattern as profile.ps1 lines 26-29 or uninstall.ps1
      lines 93-94) directly in the loop body.
  (B) Extract a shared `Remove-ProfileBlock` helper, call it here and in uninstall.ps1.
  (C) Import or dot-source the strip function -- but this conflicts with the self-contained
      goal stated in D3.

Option A is consistent with the self-containment rationale and keeps the cognitive footprint
local. But the plan must state which option is chosen and show the implementation, not a
comment. A stub comment is not an algorithm.

Note: `Remove-DevSetupProfileBlock` in uninstall.ps1 does the right thing but lives only
in that file. profile.ps1 (production) has inline strip logic at lines 23-29 but only for
the "already-written" path, not for orphaned-legacy stripping. The v3 plan adds a new
stripping context that currently has no implementation.

Verdict on item: BLOCKING. GG-4 directly contradicts Section 4.

---

**6. Ambiguity: is the Section 4 algorithm top-level or inside Write-PowerShellProfile? -- BLOCKING**

plan:Section 4 comment: `# In profile.ps1 (and inlined in uninstall.ps1):`
plan:Section 5 header: "Invoke-HostQuery mock defined AFTER dot-sourcing profile.ps1."

Section 4 shows `$profilePaths = @(Resolve-ProfilePath ...) | Sort-Object ...` and the
foreach legacy loop as bare top-level statements -- not wrapped in a function. If this code
is actually placed at the top level of profile.ps1 (outside any function), it executes the
moment the script is dot-sourced. The test mock-after-dot-source pattern in Section 5 then
breaks:

1. Test dot-sources profile.ps1.
2. Top-level code runs immediately -- calls `Resolve-ProfilePath` -> calls `Invoke-HostQuery`
   (the real one, not the mock, because mock isn't defined yet).
3. Test defines mock `Invoke-HostQuery`. Too late -- the resolution already ran.

GG-1 through GG-7 all depend on the mock intercepting calls to `Invoke-HostQuery`. If the
algorithm runs at dot-source time, every GG test silently tests the wrong thing (real host
queries, not mocked ones), and failures appear only on machines missing the hosts.

The current production profile.ps1 wraps all logic inside `Write-PowerShellProfile`. The
v3 plan must explicitly state that the algorithm remains inside that function (or an
equivalent named function). The Section 4 pseudocode block is ambiguous on this point --
it omits the enclosing function boundary.

Section 5 note ("Mock must be defined AFTER dot-sourcing profile.ps1 or the dot-source
overwrites it") is correct for the function-scoped case but says nothing to prevent a
future implementer from reading Section 4 literally and placing the code at top level.

The plan must add a function-boundary wrapper in Section 4, making the scope explicit:

```powershell
function Write-PowerShellProfile {
    # ... Invoke-HostQuery and Resolve-ProfilePath defined here, or at file scope above
    $profilePaths = @(
        (Resolve-ProfilePath 'powershell' $ps51Fallback),
        (Resolve-ProfilePath 'pwsh' $ps7Fallback)
    ) | Sort-Object { $_.ToLower() } -Unique
    ...
}
```

Without this clarification, Section 4 and Section 5 are potentially inconsistent depending
on where the implementer places the code.

Verdict on item: BLOCKING. Scoping ambiguity invalidates the test design in Section 5.

---

**7. GG-2 "absent exe name" -- correct approach, minor fragility (non-blocking)**

plan:Section 5 GG-2: input `'powershell-notexist'`

`Get-Command 'powershell-notexist' -EA SilentlyContinue` returns nothing (no match on any
reasonable dev machine). The exe-not-found guard fires and the fallback is returned.

This tests the right thing: that the guard logic works without needing to shadow
`Get-Command` (which would be a risky built-in mock). The approach is cleaner than v2.

The only fragility: if some future PATH entry installs a binary literally named
`powershell-notexist.exe`, the test fails for the wrong reason. Using a GUID-based name
(`powershell-absent-{hex}`) is mathematically guaranteed absent. This is a low-probability
concern on any real dev machine; not a blocking hole. Consider as an implementation note.

Verdict on item: non-blocking. Acceptable for practical purposes.

---

**8. D3 re-evaluation gap: Option B analysis was requested but not performed -- non-blocking process concern**

Donald's revision instructions (441-grill-donald.md, If Revision Needed section):
> "Section 3 Decision 3: restate the line-count estimate (~31 lines, not ~15)"
> "re-evaluate Option B (lib file) at the corrected line count"

v3 D3: "Resolver is ~30 lines inlined -- acceptable for self-containment."

v3 restated the count (31->30, roughly) but skipped the Option B analysis Donald requested.
The phrase "acceptable for self-containment" is a restatement of the original conclusion
from v1/v2, not a freshly-performed comparison.

Additionally, the ~30 line claim is still low. Counting Section 4 as written:
- `Invoke-HostQuery` function: ~5 lines (header + param + body + closing brace)
- `Resolve-ProfilePath` function: ~22 lines (header, param block, Get-Command guard, try
  block with 4 exit paths, catch block, closing brace)
- `$profilePaths = @(...) | Sort-Object`: ~4 lines
- `$legacyPaths = @(...)`: 1 line
- `foreach ($legacy in $legacyPaths) { ... }`: ~7 lines (with the currently-empty body)
Total: ~39 lines BEFORE the actual strip logic in the loop body (Finding 5).

At 40+ lines in uninstall.ps1, the Option B question is material. The plan should document
the Option B evaluation, even if the conclusion remains Option A.

Verdict on item: non-blocking for this re-grill, but the missing analysis is a process gap
that weakens confidence in D3. If Finding 5 is fixed by adding inline strip logic, the
line count grows further and Option B deserves a real answer.

---

**9. Dedup + legacy cleanup interaction for shared-path scenario -- handled correctly**

plan:Section 4 algorithm, Section 3 v3-D5

Scenario: both hosts resolve to the same OneDrive path (dedup leaves one entry in
`$profilePaths`). Legacy cleanup iterates `$legacyPaths = @($ps51Fallback, $ps7Fallback)`.
For each: `$isLegacy = -not ($profilePaths | Where-Object { $_.ToLower() -eq $legacy.ToLower() })`.

Since both `$ps51Fallback` (`$HOME\Documents\WindowsPowerShell\...`) and `$ps7Fallback`
(`$HOME\Documents\PowerShell\...`) are different from the OneDrive-resolved path, both
evaluate `$isLegacy = true`. If both legacy files exist with the BEGIN marker, both get
stripped. The single resolved OneDrive path receives the block write. This is correct.

Practical note: PS5.1 `$PROFILE` always contains `WindowsPowerShell` in the subdir and
PS7 `$PROFILE` always contains `PowerShell`. Their values cannot be identical under
standard PS behavior. The shared-path dedup scenario is only possible with non-standard
profile configuration. The algorithm handles it correctly regardless; no special case needed.

Verdict on item: clean. No hole.

---

**10. Power-of-9 decisions cargo-cult check -- one weak entry (D3)**

D1 (Select-Object -Last 1 + -NoLogo): directly addresses Donald's Finding 1. Rationale
is concrete ("banner appears before path on stdout; -Last 1 selects path"). Not cargo-cult.

D2 ($LASTEXITCODE check): directly addresses Donald's Finding 2. Rationale is correct PS
semantics. Not cargo-cult.

D3 (inline ~30 lines): the re-evaluation step was skipped (see Finding 8). The conclusion
is the same as v1/v2 restated with a corrected number, not freshly derived. Weak.

D4 (GG-4 dual-orphan expansion): concrete rationale ("one-path test cannot detect a
loop-break bug after the first match"). Not cargo-cult.

D5 (Sort-Object -Unique confirmed): explicitly states mechanism ("keys on script block
output; equal .ToLower() values deduplicated") and points to GG-3 as empirical confirmation.
Not cargo-cult.

Only D3 reads as "we restated the prior conclusion with the corrected number." All other
decisions show real reasoning. D3 is a process gap (see Finding 8), not an algorithm error.

---

### What v3 Got Right

- **GG-6 contradiction fixed:** changing to `Select-Object -Last 1` correctly resolves
  Donald's Finding 1. A banner prefix no longer produces the wrong line.
- **$LASTEXITCODE guard added:** v3-D2 adds the check Donald required, closes the silent-
  fallback-on-broken-PS5.1 hole. GG-7 provides the corresponding test coverage.
- **Regex path validation added:** `'^[A-Za-z]:\\'` guard prevents garbage strings from
  reaching `Split-Path`/`New-Item`. Consistent with Section 2 UNC OUT decision.
- **Single-quoting on `'$PROFILE'`:** correct in both PS5.1 and PS7. Parent shell does not
  expand the variable; child shell evaluates it. This was correct in prior versions and
  remains correct.
- **D3 line-count honesty:** accepting ~30 lines (even if slightly low) over v2's "~15 lines"
  is a direct improvement. The inline-for-self-containment rationale is sound.
- **D4 dual-orphan test (GG-4):** expanding to seed both legacy paths simultaneously is the
  right test design. Catches loop-break-after-first-match bugs that a one-path test misses.

---

### Verdict

REVISE. Two findings are blocking.

**Finding 5** is a plan-internal contradiction of the same severity as Donald's Finding 1
against v2: GG-4 asserts both legacy paths are stripped, but Section 4 contains no
stripping code -- only a comment placeholder. An implementer reading the plan cannot
determine what to write in the loop body. Any implementation that fills the stub will be
unreviewed.

**Finding 6** is an architecture ambiguity that threatens the entire test design: if
Section 4's top-level-looking code is placed at file scope in profile.ps1, dot-source
runs it before any test mock is defined, and every GG test silently calls the real host
query instead of the mock. The plan must show the function-boundary wrapper in Section 4
to make the scope unambiguous.

Findings 1 (minor trim gap), 7 (GG-2 fragility), 8 (D3 analysis gap) are non-blocking and
may be handled as implementation notes during the revision pass.

---

## If Revision Needed

**Revision owner:** Chip
**Sections requiring change:**
- Section 4 algorithm: add explicit function-boundary wrapper (e.g., inside
  `Write-PowerShellProfile`) so top-level vs. function scope is unambiguous
- Section 4 algorithm: fill the empty loop body -- name the strip function or show the
  inline strip code; do not leave a comment as implementation
- Section 3 D3: document the Option B (lib file) comparison at ~40 lines; accept or
  reject with reasoning, not just a number change
- Section 5 GG-4: confirm the assertion still holds once the loop body is filled (it
  should; the assertion is correct, the code is not)
**Re-grill required after revision:** Yes -- Section 4 is substantively changed.
Scope to Section 4 algorithm and Section 5 GG-4; other sections are stable.
