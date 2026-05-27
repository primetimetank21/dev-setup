# Grill Report: #441 -- profile.ps1 writes to wrong path on OneDrive/KFM systems

**Griller:** Donald (Implementation Lead -- authored v3; uniquely owns gap context)
**Plan reviewed:** docs/plans/441-profile-path.md (v4, author: Jiminy)
**Date:** 2026-05-27
**Session:** 441-grill-v4
**Verdict:** REVISE

---

## Verdict

REVISE. No single finding is a full ship-blocker, but P1's patch introduced a concrete
encoding bug (HIGH) that would silently corrupt legacy profile encoding on PS5.1 if
shipped as written. One MEDIUM finding (TestDrive contradiction with D2) forces the
implementer to guess. Two other MEDIUMs need notes to close. Algorithm is otherwise sound
and P1-P7 regression patches land correctly.

---

## Regression Check (P1-P7)

| # | Griller | v3 Finding | v4 Status |
|---|---------|-----------|-----------|
| P1 | Pluto | foreach body empty stub | RESOLVED -- inline strip regex + Set-Content + Write-Info filled in |
| P2 | Pluto | function boundary ambiguous | RESOLVED -- Write-PowerShellProfile wrapper explicit with comment explaining dot-source safety |
| P3 | Chip | GG-7 $LASTEXITCODE mock broken (function-local assignment) | RESOLVED -- `& $env:ComSpec /c "exit 1"` inside mock sets $LASTEXITCODE globally via native-command semantics; Doc-grill verified this pattern directly |
| P4 | Chip | C-2/C-3 skip unspecified + $PROFILE assignment outside Test-Scenario | RESOLVED -- `skip` replaced with if/Write-Host/return; `$PROFILE = $path` moved inside Test-Scenario body per v3-D4 |
| P5 | Chip | Mock isolation scope model undocumented | RESOLVED (with note) -- "child scope" model stated, redefinition before each test specified; no code skeleton but mechanism is unambiguous given confirmed Test-Scenario implementation (`& $Test`) |
| P6 | Chip | GG-4 both-hosts-same-path ambiguous | RESOLVED -- both mock calls explicitly return same $oneDrivePath; dedup to 1 entry stated; both legacy paths explicitly called orphaned |
| P7 | Doc | $PROFILE "read-only" characterization inaccurate | RESOLVED -- updated to "conceptually (not technically) read-only per MS Learn" |

Note on P3 verification: `& $env:ComSpec /c "exit 1"` inside a PS function DOES set
`$global:LASTEXITCODE = 1`. PowerShell's $LASTEXITCODE is set at global scope by any
native-command invocation, regardless of the calling function's local scope. Doc confirmed
this with `cmd.exe /c "exit 7" 2>$null` -> $LASTEXITCODE = 7 (not reset by redirection).
The GG-7 mock mechanism is correct. P3 is fully resolved.

---

## New Findings

### [HIGH] F-1: Missing `-Encoding ASCII` in orphan-strip Set-Content (P1 introduced)

**Citation:** Section 4, foreach body, line: `Set-Content $legacy $stripped.TrimEnd() -NoNewline`

**Reference:** production profile.ps1 line 28: `Set-Content $profilePath $raw -NoNewline -Encoding ASCII`

The P1 patch fills the empty stub with:
```powershell
Set-Content $legacy $stripped.TrimEnd() -NoNewline
```

Production line 28 uses `-Encoding ASCII` for all profile writes. The orphan-strip code
omits it. Default encoding for Set-Content:
- PS 5.1: UTF-16 LE with BOM
- PS 7+:  UTF-8 without BOM

Legacy orphan files were written by the old production code using ASCII. Rewriting without
`-Encoding ASCII` silently re-encodes the file. On PS5.1 this produces UTF-16 LE output
(PS5.1 can load UTF-16 LE profiles, so it does not break loading), but it:
1. Is inconsistent with the encoding contract established by production code
2. Is inconsistent with production line 28 -- an implementer sees two Set-Content calls
   in the same function with different encoding behavior, which signals an undocumented
   split that will generate future confusion
3. Could interact unexpectedly with downstream tooling that probes the profile as ASCII

This is a net-new production bug introduced by Jiminy's P1 fix. The fix is one word:
add `-Encoding ASCII` to the orphan-strip Set-Content call.

---

### [MEDIUM] F-2: "TestDrive" in GG-4 row contradicts Section 3 Decision 2

**Citation:** Section 5, GG-4 row (Input column): "BOTH `$ps51Fallback` AND `$ps7Fallback`
files exist in TestDrive seeded with BEGIN marker"

**Reference:** Section 3, Decision 2: "Use the existing Test-Scenario harness with the
`Invoke-HostQuery` mock pattern. `$PROFILE` is read-only in PS 7+ and `$TestDrive` is
Pester-specific. Adding Pester is scope creep."

"TestDrive" unambiguously refers to Pester's `TestDrive:` PSDrive. Section 3 D2
explicitly rejects Pester and cites `$TestDrive` as Pester-specific. The GG-4 row then
references the same term in a test input description.

An implementer reading the plan literally must choose one of:
  (a) Use Pester TestDrive -- contradicts D2
  (b) Treat "TestDrive" as loose shorthand for "test temporary real-path" -- requires a guess
  (c) Be confused and pause for clarification

The intended interpretation is almost certainly (b): seed $ps51Fallback and $ps7Fallback
as real temporary paths (probably under $env:TEMP or a test subdir), create the files
there, run the function, assert the files are stripped. But the plan must say that instead
of "TestDrive." One sentence in the GG-4 input column closes this.

---

### [MEDIUM] F-3: $LASTEXITCODE stale contamination from GG-7 into success-path tests

**Citation:** Section 5, GG-7 row; Section 5, GG-1 through GG-6 mocks (implied)

GG-7's mock calls `& $env:ComSpec /c "exit 1"`, which sets `$global:LASTEXITCODE = 1`.
Success-path mocks (GG-1 through GG-6) return paths via a function body that does NOT
call any native command. PowerShell does not reset $LASTEXITCODE to 0 between function
calls or test runs. If GG-7 runs before any success-path test, $LASTEXITCODE = 1 persists
into that test. Production code checks `if ($LASTEXITCODE -ne 0)` immediately after
`Invoke-HostQuery` returns -- a stale 1 causes the fallback branch to fire and the test
fails for the wrong reason.

The plan specifies test redefinition-before-each-test for mock isolation, but says nothing
about $LASTEXITCODE state between tests. Two viable fixes:

  (a) Success-path mocks call `& $env:ComSpec /c "exit 0"` before returning, resetting
      $LASTEXITCODE to 0 explicitly. Portable and self-contained.
  (b) Plan states GG-7 must run last and documents the ordering requirement explicitly.

Neither is currently stated. As written, a test runner that executes GG-7 first (e.g.,
running only GG-7 during development, then full suite) leaves subsequent success tests
contaminated.

---

### [MEDIUM] F-4: Orphan-strip regex diverges from production regex without rationale

**Citation:** Section 4, strip regex:
`(?s)$([regex]::Escape($beginMarker)).+?$([regex]::Escape($endMarker))\r?\n?`

**Reference:** production profile.ps1 line 27:
`(?s)\r?\n$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?`

Two differences introduced without explanation:

1. Production has `\r?\n` PREFIX before the BEGIN marker (strips the preceding newline
   together with the block). Plan's orphan-strip regex omits this prefix. Effect: when
   block is in the MIDDLE of a file, plan's regex leaves an extra blank line that production
   does not. `TrimEnd()` compensates only when the block is at the END of the file.

2. Production uses `.*?` (zero-or-more); plan uses `.+?` (one-or-more). Edge case: a
   BEGIN marker immediately followed by END marker (empty block) is handled by production
   but not by the plan's regex. Trivial in practice but is a divergence.

Note: the plan's regex is actually SUPERIOR for one edge case (block at START of file)
because the production regex requires `\r?\n` before BEGIN and would fail to match when
BEGIN is on line 1. However, introducing a different regex for the same conceptual
operation (stripping a BEGIN..END block) without documenting the divergence is a
maintainability trap. The implementer reading both the plan and production code will see
two regex patterns and not know which is authoritative.

The plan should either adopt the production regex (with a note that TrimEnd() handles the
trailing newline) or document why the new regex differs.

---

### [LOW] F-5: $beginMarker, $endMarker, $ps51Fallback, $ps7Fallback undefined in Section 4 snippet

**Citation:** Section 4, `Write-PowerShellProfile` function body

The Section 4 pseudocode references `$beginMarker`, `$endMarker`, `$ps51Fallback`, and
`$ps7Fallback` without defining them in the snippet. A comment says
"# Write to each resolved path (existing strip+re-inject logic)" -- indicating Section 4
is a PARTIAL view of the function and definitions exist elsewhere in production. An
experienced implementer will infer these from production lines 12-19. However, for an
implementer treating the plan as a self-contained spec, the undefined variables create
ambiguity about exact values. A one-line comment citing "production lines 12-19 for
variable definitions" would close this cleanly.

---

## Implementation-Readiness Verdict

A competent engineer can implement the core algorithm from v4; P1-P7 patches are
substantively correct and the function boundary is now unambiguous. However, following
the plan LITERALLY produces two concrete bugs: (1) the orphan-strip Set-Content silently
changes file encoding on PS5.1 (F-1, HIGH, one-word fix), and (2) success-path GG tests
contaminated by GG-7's $LASTEXITCODE if run out of order (F-3, MEDIUM). The TestDrive
contradiction (F-2) forces an implementer guess. Three of four issues are trivial to
resolve with targeted wording changes; F-4 requires a sentence of rationale. Overall:
NOT ready to hand to an implementer today without the F-1 encoding fix at minimum.

---

## Required Fixes for v5

1. **F-1 [HIGH].** Section 4 orphan-strip Set-Content: add `-Encoding ASCII` to match
   production line 28. One word.

2. **F-2 [MEDIUM].** Section 5 GG-4 Input column: replace "TestDrive" with an explicit
   description of the real-path seeding mechanism (e.g., "$ps51Fallback and $ps7Fallback
   set to real temp-directory paths; files created before calling Write-PowerShellProfile").

3. **F-3 [MEDIUM].** Section 5 header or GG-7 row: add one of -- (a) success-path mocks
   call `& $env:ComSpec /c "exit 0"` to reset $LASTEXITCODE before returning, or (b) an
   explicit note that GG-7 must run after GG-1 through GG-6 and state why.

4. **F-4 [MEDIUM].** Section 4 strip regex: add a comment or footnote explaining the
   intentional divergence from production line 27 (dropped `\r?\n` prefix, `.+?` vs `.*?`),
   or adopt the production regex and note that `TrimEnd()` handles the trailing blank.

5. **F-5 [LOW].** Section 4: add a comment directing the implementer to production lines
   12-19 for `$beginMarker`, `$endMarker`, `$ps51Fallback`, `$ps7Fallback` definitions.

---

## What v4 Got Right

- **P1 loop body**: Pluto's BLOCKING finding is filled. The regex is functional and the
  `$isOrphan` condition is correct (`.Count -eq 0` is exact and readable).
- **P2 function boundary**: Comment explaining dot-source safety is clear and directly
  addresses Pluto's ambiguity concern. Zero chance of misreading the scope now.
- **P3 GG-7 mock mechanism**: `& $env:ComSpec /c "exit 1"` is the right answer to Chip's
  NF-1. Not a global assignment hack; uses native-command semantics, which is
  self-documenting.
- **P4 C-2/C-3 guard**: Moving `$PROFILE = $path` INSIDE the Test-Scenario body is
  the correct fix -- Chip called out that the assignment was outside and the guard inside
  was therefore ineffective. Jiminy caught this precisely.
- **P6 GG-4 dual-path spec**: Both mock calls returning same $oneDrivePath is now
  explicitly stated, ending the (a) vs (b) ambiguity Chip raised.
- **P7 $PROFILE wording**: Doc's correction accepted cleanly. "Conceptually not
  technically" is accurate and closes the false claim without disturbing the guard logic.
- **Test-Scenario scope model**: Plan correctly identifies `& $Test` child-scope model
  (confirmed in tests/test_windows_setup.ps1 lines 37-53). "Mocks in enclosing scope are
  visible inside" is accurate for `& $block` execution.

---

**Grilled by:** Donald (Implementation Lead)
**Date:** 2026-05-27
**Session:** 441-grill-v4
