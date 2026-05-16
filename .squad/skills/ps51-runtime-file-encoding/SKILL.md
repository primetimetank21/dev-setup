# Skill: PS 5.1 Runtime File Encoding (BOM Trap)

**Confidence:** high (caught once in CI on PR #208; root cause well-understood; cross-version verified)
**Owner:** Chip (Tester)
**Issue:** #183
**Related skill:** `.squad/skills/ps51-ascii-safety/SKILL.md` (authoring-time encoding)

---

## What

When `.ps1` code **writes a file at runtime** that will be read by a POSIX/sh
tool, a non-PowerShell consumer, or any byte-sensitive reader, you MUST NOT
use `Set-Content -Encoding UTF8` or `Out-File -Encoding UTF8` on PowerShell
5.1. PS 5.1 writes UTF-8 **with a BOM** under those flags; PS 7+ writes UTF-8
**without** a BOM. The BOM (`EF BB BF`) becomes the first 3 bytes of the file,
silently breaking any reader that expects clean text.

**Safe choices** for ASCII content (commit messages, config snippets, hook
input, shell scripts):

```powershell
Set-Content $path -Value $content -Encoding ASCII
```

**Safe choices** for non-ASCII content that must be UTF-8 no-BOM on both PS
versions:

```powershell
[System.IO.File]::WriteAllText($absolutePath, $content)
```

(`WriteAllText` defaults to UTF-8 no-BOM; the path must be absolute.)

**Never use** in cross-version code:

| Cmdlet | PS 5.1 behavior | PS 7 behavior |
|---|---|---|
| `Set-Content -Encoding UTF8` | UTF-8 **with BOM** | UTF-8 **no BOM** |
| `Out-File -Encoding UTF8` | UTF-8 **with BOM** | UTF-8 **no BOM** |
| `>` / `>>` redirection | UTF-16 LE | UTF-8 no BOM |
| `Set-Content -Encoding utf8NoBOM` | **Error ??? not available** | UTF-8 no BOM |

---

## Why

The PowerShell 5.1 team chose "UTF-8 with BOM" as the meaning of `-Encoding
UTF8`. PS Core / 7 reversed this choice. There is no shared flag value that
produces no-BOM UTF-8 on both versions, so any script that must run on PS 5.1
AND write a file a POSIX consumer will read must pick one of:

1. `-Encoding ASCII` (works on both, no BOM, ASCII only).
2. `[System.IO.File]::WriteAllText` (works on both, no BOM, any UTF-8).

This bit us when `tests/test_git_hooks.ps1` wrote commit-msg files with
`Set-Content -Encoding UTF8`. Locally on PS 7 the test passed (no BOM). In
CI on PS 5.1 the same call wrote `EF BB BF feat(hooks): ...`. The
commit-msg hook is POSIX sh and reads the file byte-for-byte; its
conventional-commits regex `^(feat|fix|...)` saw bytes `EF BB BF` first
and rejected the message. Two tests failed; one passed only because the
expected behavior happened to be rejection.

---

## How (Decision Tree)

```
Need to write a file at runtime?
?????? Will only PowerShell read it?
???   ?????? Either Set-Content -Encoding UTF8 is fine
???      (the BOM is harmless to PS readers).
???
?????? Will a POSIX tool / sh / git / a byte-sensitive reader read it?
    ?????? Is the content pure ASCII?
    ???   ?????? Set-Content $path -Value $content -Encoding ASCII
    ???
    ?????? Does it need real UTF-8?
        ?????? [System.IO.File]::WriteAllText($absolutePath, $content)
```

---

## How to verify

Before merging any code that writes runtime files in a PS 5.1 path:

```powershell
# After running the code, check the file's first 3 bytes:
$bytes = [System.IO.File]::ReadAllBytes($path)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Warning "BOM present -- POSIX consumers will break"
}
```

In CI, the `Validate PowerShell 5.1 Compatibility` job catches this when
the downstream consumer actually fails. Watch for tests that pass on PS 7
but fail on PS 5.1 with garbled-looking input -- BOM is the usual suspect.

---

## When to read this

Read before:
- Writing tests that pipe data into shell-based tools (git hooks, jq, awk, sed).
- Adding any `Out-File`, `Set-Content`, or `>` redirection in a `.ps1` file
  that other-language code will consume.
- Reviewing PRs that touch `tests/test_*.ps1` or any setup script that
  generates config files for non-PowerShell tools.

---

## Citations

- `tests/test_git_hooks.ps1` ??? fixed in commit `60734ed` on `squad/183`.
- CI failure log: PR #208 run 25952592344, `Validate PowerShell 5.1
  Compatibility / Run git hooks tests (PS 5.1)` step. Visible BOM bytes
  rendered as `?` in the error message: `Got: ?feat(hooks): ...`.
- Microsoft docs: `Set-Content -Encoding` parameter ??? behavior differs
  between Windows PowerShell 5.1 and PowerShell 7.
