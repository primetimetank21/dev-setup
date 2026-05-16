# Skill: PS 5.1 ASCII Safety

**Confidence:** high (confirmed twice in same session; root cause is well-understood)
**Owner:** Chip (Tester)
**Issue:** #197

---

## What

All `.ps1` files -- setup scripts, tool scripts, and test scripts -- must contain only ASCII characters (U+0000-U+007F). This applies to every byte in the file: string literals, comments, Write-Host output tags, and variable names. No exceptions. If a character is not on a US keyboard, it does not belong in a `.ps1` file in this repo.

## Why

PowerShell 5.1 reads `.ps1` files using the system's default encoding, which on English Windows is CP1252 (Windows-1252). It does **not** auto-detect UTF-8, even if the file is saved as UTF-8 without a BOM.

When a `.ps1` file contains non-ASCII characters saved as UTF-8:

1. The UTF-8 multibyte sequence is read as raw bytes under CP1252.
2. CP1252 maps individual bytes to its own character set, often interpreting them as punctuation or control characters.
3. Certain byte values happen to be quotation marks in CP1252, which **terminate string literals mid-parse**.

**Concrete example -- the em dash (U+2014):**

- UTF-8 encoding: bytes `E2 80 94`
- CP1252 reads byte `0x94` as the RIGHT DOUBLE QUOTATION MARK (`"`)
- PowerShell 5.1 sees an unexpected `"` inside a string literal
- Result: `ParseException: TerminatorExpectedAtEndOfString`

The CI job **Validate PowerShell 5.1 Compatibility** runs scripts and test files under `shell: powershell` (PS 5.1). Any non-ASCII character in those files risks a parse failure in CI, even if it works perfectly under PS 7+ (which defaults to UTF-8).

### Incidents

| Incident | File | Characters | Fix |
|----------|------|------------|-----|
| Issue #197 / PR #198 | `scripts/windows/tools/profile.ps1` | Em dash in error message string | Replaced with ` - ` |
| Issue #197 / PR #200 | `tests/test_windows_setup.ps1` | 8 emoji markers, 4 em dashes, 2 arrows (14 total) | Replaced with ASCII equivalents |

## Common Offenders

| Character | Unicode | UTF-8 Bytes | CP1252 Interpretation | Safe Replacement |
|-----------|---------|-------------|----------------------|------------------|
| Em dash `--` | U+2014 | E2 80 **94** | 0x94 = `"` (RIGHT DOUBLE QUOTE -- **terminates strings**) | ` - ` or `--` |
| Left double quote | U+201C | E2 80 **9C** | 0x9C = `oe` (harmless but confusing) | `"` |
| Right double quote | U+201D | E2 80 **9D** | 0x9D = undefined (may crash) | `"` |
| Right single quote | U+2019 | E2 80 **99** | 0x99 = TM (trade mark, undefined control) | `'` |
| Arrow | U+2192 | E2 86 **92** | 0x92 = `'` (RIGHT SINGLE QUOTE -- **may terminate strings**) | `->` |
| Checkmark | U+2713 | E2 9C **93** | 0x93 = `"` (LEFT DOUBLE QUOTE -- **terminates strings!**) | `[ok]` |
| Cross mark | U+2717 | E2 9D **97** | 0x97 = `--` (em dash in CP1252) | `[fail]` |
| Emoji range | U+1F000+ | 4 bytes | Multiple undefined bytes | ASCII tags: `[PASS]`, `[FAIL]`, `[SKIP]` |

## How: Detection

### Scan a single file

PowerShell one-liner safe to run in both PS 5.1 and PS 7+:

```powershell
$file = "path\to\script.ps1"
$lines = Get-Content $file -Encoding UTF8
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -cmatch '[^\x00-\x7F]') {
        Write-Host "Line $($i+1): $($lines[$i])"
    }
}
```

### Scan all .ps1 files in the repo

```powershell
Get-ChildItem -Recurse -Filter "*.ps1" | ForEach-Object {
    $path = $_.FullName
    $lines = Get-Content $path -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '[^\x00-\x7F]') {
            Write-Host "$path line $($i+1): $($lines[$i])"
        }
    }
}
```

If either script produces output, the file has non-ASCII content that must be replaced.

## How: Fix Patterns

| Context | Before (non-ASCII) | After (ASCII-safe) |
|---------|--------------------|--------------------|
| Write-Host test pass marker | `Write-Host "* PASS: test name"` | `Write-Host "[PASS] test name"` |
| Write-Host test fail marker | `Write-Host "X FAIL: test name"` | `Write-Host "[FAIL] test name"` |
| Write-Host skip marker | `Write-Host ">> SKIP: reason"` | `Write-Host "[SKIP] reason"` |
| Error message with em dash | `"Failed -- see log"` | `"Failed - see log"` |
| Comment with arrow | `# foo -> bar` | `# foo -> bar` |
| Comment with em dash | `# this -- that` | `# this - that` or `# this -- that` |
| Smart double quotes in string | `"some 'value' here"` | `"some 'value' here"` |
| Smart single quotes in string | `'it is done'` | `'it is done'` |

**Rule of thumb:** if you cannot type it on a standard US keyboard without an Alt-code or emoji picker, replace it with an ASCII equivalent.

## When to Apply This Skill

- **Before writing ANY new `.ps1` file** (setup scripts, tool scripts, test scripts)
- **Before committing edits** to existing `.ps1` files
- **When reviewing a PR** that touches `.ps1` files -- scan for non-ASCII FIRST
- **When writing CI steps** that execute `.ps1` files under `shell: powershell`

## When It Does NOT Apply

- `.sh` and `.zsh` files (run under bash/zsh; encoding handled differently)
- YAML workflow files (not parsed by PS 5.1)
- Markdown documentation (not executed)
- `.ps1` files that are **exclusively** run under PS 7+ (`shell: pwsh`) -- but this repo does not have any such files; all `.ps1` files must pass PS 5.1 validation

## References

- Issue [#197](https://github.com/primetimetank21/dev-setup/issues/197)
- PR [#198](https://github.com/primetimetank21/dev-setup/pull/198) -- em dash fix in `profile.ps1`
- PR [#200](https://github.com/primetimetank21/dev-setup/pull/200) -- 14-char ASCII cleanup in `test_windows_setup.ps1`
- [CP1252 encoding table](https://en.wikipedia.org/wiki/Windows-1252)
- `.github/workflows/validate.yml` -- `Validate PowerShell 5.1 Compatibility` job
