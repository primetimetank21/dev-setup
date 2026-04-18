### [2026-04-18]: Test-Path Variable:* DOES NOT work under PS 5.1 strict mode (#132)
**By:** Mickey
**What:** Confirmed that (Test-Path Variable:IsWindows -and $IsWindows) throws VariableIsUndefined under Set-StrictMode -Version Latest on PS 5.1, even with short-circuit -and.
**Correct pattern:** ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows) — PSVersion check short-circuits first, $IsWindows is never evaluated on PS 5.x.
**Why:** Regression from Chip's PR #130 CI "fix". PSVersion-based guards are the only safe approach.
