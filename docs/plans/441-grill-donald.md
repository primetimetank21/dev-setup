# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Donald (Shell Developer -- shell/algorithm correctness angle)
**Plan reviewed:** docs/plans/441-profile-path.md (v2, author: Mickey)
**Date:** 2026-05-27
**Verdict:** REVISE

**Author locked out:** Mickey (v2 author), Goofy (v1 author)
**Eligible next reviser (if REVISE):** Pluto -- dominant holes are PS 5.1 behavior, Windows
path validation, and algorithm correctness; all squarely in Pluto's Config Engineer lane.

---

## Angle: Shell / Algorithm Correctness

---

### Findings

**1. GG-6 cannot pass -- internal contradiction between Section 4 and Section 5**

Section 4 algorithm (plan lines ~84-85):

```
$resolved = (Invoke-HostQuery -Exe $HostExe).Trim()
$resolved = ($resolved -split '\r?\n' | Where-Object { $_ } | Select-Object -First 1)
```

Section 5, GG-6:

| GG-6 | Multi-line output | Mock returns "banner\npath" | Only path extracted | Return value contains no newline |

`Select-Object -First 1` returns the FIRST non-empty line. When the mock returns
`"banner\npath"`, the first line is `"banner"`, not the path. The algorithm would
return the wrong line. GG-6's "Only path extracted" assertion would FAIL against the
code in Section 4.

The plan acknowledges that banner output may exist but provides no filtering logic to
distinguish a banner line from a path line. The algorithm implicitly relies on the child
process emitting ONLY the path -- but GG-6 explicitly tests the contrary case with no
corresponding algorithm change to handle it. Section 4 and Section 5 cannot both be
correct as written.

**Fix required:** Either (a) change the algorithm to take the LAST non-empty line
(profile paths come after any banner on stdout), or (b) add a path-shape validation
(e.g., line matches `^[A-Za-z]:\\`) to find the real path in multi-line output, and
update GG-6 accordingly.

---

**2. `$LASTEXITCODE` unchecked -- silent fallback on broken PS 5.1 install**

Section 4 `Resolve-ProfilePath` uses a `try/catch` to detect failures:

```
try {
    $resolved = (Invoke-HostQuery -Exe $HostExe).Trim()
    ...
} catch {
    Write-Warn "Query failed for $HostExe -- fallback: $FallbackPath"
    return $FallbackPath
}
```

In PowerShell, `& $Exe ...` (calling an external executable) does NOT throw on a
non-zero exit code. It sets `$LASTEXITCODE` and returns. If `powershell.exe -Command
'$PROFILE'` exits non-zero (e.g., execution policy blocks the `-Command` invocation,
or the PS 5.1 install is partially corrupt), the try block continues executing with
empty/null stdout. The `if ([string]::IsNullOrEmpty($resolved))` check silently returns
`$FallbackPath` with NO warning to the user -- the catch never fires.

This is the exact silent failure pattern my charter prohibits: a broken PS 5.1 install
falls back to the old hardcoded path with no diagnostic, and the issue appears fixed
to the user (old aliases load from hardcoded path) while the real path is never written.

`$LASTEXITCODE` must be checked immediately after `& $Exe -Command '$PROFILE'`:

```powershell
$raw = & $Exe -NoProfile -NonInteractive -Command '$PROFILE' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "$Exe exited $LASTEXITCODE -- fallback: $FallbackPath"
    return $FallbackPath
}
```

---

**3. No path-shape validation on resolved output**

After `Select-Object -First 1`, the returned string is accepted as a profile path
without any validation. The plan does not check whether the string:
- starts with a drive letter (`C:\`, `D:\`, etc.)
- contains the expected profile filename (`Microsoft.PowerShell_profile.ps1`)
- is a plausible Windows filesystem path at all

If the child process emits any unexpected content on stdout (error message, partial
stack trace, PSReadLine prompt artifact, BOM), that string is passed to
`Split-Path $resolved` and subsequently to `New-Item -ItemType Directory`. On a badly
formed string, `Split-Path` may return `$null` or an empty string, and
`New-Item -ItemType Directory -Path ""` under `Set-StrictMode -Version Latest` will
throw -- but the error message will point at `New-Item`, not at the broken query.

A one-liner guard:
```powershell
if ($resolved -notmatch '^[A-Za-z]:\\') { return $FallbackPath }
```
would catch the majority of garbage values and give a meaningful fallback.

---

**4. Trim-then-split order is defensible only if no stdout precedes the path**

The `.Trim()` is applied to the ENTIRE multi-line output BEFORE splitting. This means:
- Leading/trailing whitespace/newlines on the full blob are stripped.
- But if ANY non-empty content appears on a line BEFORE the path value, `.Trim()` does
  NOT help -- that content survives the split and `Select-Object -First 1` takes it.

As noted in Finding 1, GG-6 tests exactly this case. The order is not the bug; the
missing path-shape filter is. However the comment "(handles PS5.1 banner output)"
in the plan (or the GG-6 row title "Multi-line output") implies the plan's author
believed this order would handle the banner case. It does not.

This is not a standalone REVISE trigger -- it is covered by Finding 1 -- but the
reviewer should be aware the Trim-then-split ordering provides no protection against
a leading banner line.

---

**5. `~15 lines` estimate for inlining is off by roughly 2x**

Section 3, Decision 3:
> "The resolver is ~15 lines -- inlining is acceptable."

Counting Section 4's two functions as written:
- `Invoke-HostQuery`: 4 lines
- `Resolve-ProfilePath`: ~18 lines (param block, guard, try/catch with 3 branches)
- `$profilePaths` construction + Sort-Object: 4 lines
- `$legacyPaths` + foreach loop stub: 5 lines

Total: ~31 lines before the `$ps51Fallback`/`$ps7Fallback` variable definitions are
added. The "~15 lines" claim is roughly half the actual count. At 30+ lines, the
inlining decision is less clear-cut. If Findings 2 and 3 above add `$LASTEXITCODE`
checks and path-shape guards, the count grows further toward 40 lines.

The decision in Section 3 should re-evaluate Option B (lib file) at the corrected
line count, or accept the higher inline count explicitly.

---

**6. `Sort-Object { $_.ToLower() } -Unique` -- works, but lacks citation**

`Sort-Object -Unique` with a script block compares adjacent sorted items by their
expression output, not by the original object. Two paths differing only by case will
have identical `.ToLower()` values and will be deduplicated correctly. This does work
in both PS 5.1 and PS 7.

However, the plan asserts this behavior without a PS documentation reference or a
note that GG-3 is intended to confirm it empirically. Since the PowerShell docs for
`Sort-Object -Unique` with script blocks are sparse and the behavior can surprise
contributors, a brief inline comment or a note pointing to GG-3 as the confirmation
test would be appropriate. This is a minor documentation gap, not a blocking hole.

---

**7. `Invoke-HostQuery` quoting -- CORRECT (no hole)**

```
& $Exe -NoProfile -NonInteractive -Command '$PROFILE' 2>$null
```

Single-quoted `'$PROFILE'` in the parent shell passes the literal string `$PROFILE`
to the child. The child PS process evaluates it and emits the profile path. This is
correct for both `powershell.exe` (5.1) and `pwsh.exe` (7+). Double-quoted
`"$PROFILE"` would expand in the PARENT shell (producing the PARENT'S profile path)
before the child sees it -- so the single-quoting here is intentional and correct.

---

**8. `Get-Command $HostExe` -- PATH-order concern is low risk**

`Get-Command 'powershell'` resolves the first `powershell.exe` on PATH. On most
Windows systems this is the only PS 5.1 binary and the path concern is theoretical.
The check is used only to gate whether to attempt the query; the same PATH ordering
that `Get-Command` uses is also used by `& $Exe`. So the two calls are consistent.
Not a blocking hole.

---

### What v2 Got Right

v2 improves substantially over v1:

- **Testability seam via `Invoke-HostQuery`:** mandating a wrapper function that tests
  can mock is the correct architecture. v1 had no seam and was untestable.

- **Case-insensitive dedup:** v1 had no dedup at all. The `Sort-Object { $_.ToLower() }
  -Unique` approach is correct (Finding 6 above confirms it works).

- **Legacy cleanup design:** probing legacy paths and stripping orphaned blocks is the
  right migration strategy. The isLegacy check using `.ToLower()` comparison is correct.

- **Fallback pattern:** `$ps51Fallback` / `$ps7Fallback` as explicit named variables
  rather than inline literals is cleaner than v1.

- **Scope discipline:** OUT items in Section 2 are well-chosen. CLM, UNC, LongPaths,
  and Unicode usernames are correctly deferred with a "file issue if reported" policy.

- **`2>$null` on the child call:** redirecting stderr from the query child prevents
  PS 5.1 startup warnings from polluting the captured output. Correct.

- **Decision 4 (uninstall lib dependency):** correct diagnosis. `uninstall.ps1` must
  be self-contained. Option A (inline) is the right answer; the line count estimate
  is wrong, but the decision itself is sound.

---

### Verdict

REVISE. Two findings are blocking:

**Finding 1** is a plan-internal contradiction: GG-6 asserts behavior that the
Section 4 algorithm cannot deliver. A griller cannot approve a plan where a named
test is structurally guaranteed to fail against the named algorithm. This must be
resolved before implementation.

**Finding 2** is a shell correctness issue: unguarded `$LASTEXITCODE` on an external
process call is an anti-pattern in any shell script. It creates a silent failure path
on broken PS 5.1 installs -- the exact scenario the fix is designed to serve.

Finding 3 (no path validation) and Finding 5 (line count) are secondary but should
be addressed in the same revision pass to avoid a second REVISE cycle.

Findings 4, 6, 7, 8 are non-blocking and may be handled as implementation notes.

---

## If Revision Needed

**Revision owner:** Pluto
**Sections requiring change:**
- Section 4 algorithm: fix `Select-Object -First 1` vs. GG-6 contradiction
  (add path-shape filter OR change to last-non-empty-line selection)
- Section 4 algorithm: add `$LASTEXITCODE` check after `& $Exe` call
- Section 4 algorithm: add path-shape guard before accepting resolved string
- Section 3 Decision 3: restate the line-count estimate (~31 lines, not ~15)
**Re-grill required after revision:** Yes -- Section 4 is substantively changed.
Scope the re-grill to Section 4 and Section 5 (GG tests); other sections are stable.
