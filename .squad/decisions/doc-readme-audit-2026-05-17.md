# README Fact-Check Audit -- 2026-05-17 (Issue #342)

**Auditor:** Doc
**Target:** README.md (commit bf1b44f baseline; branch squad/342-readme-audit)
**Method:** Cross-referenced README.md line-by-line against:

- hooks/pre-commit (active hook script, 193 lines)
- hooks/pre-push, hooks/commit-msg, hooks/prepare-commit-msg
- scripts/lib/ (read-tool-version.sh, Read-ToolVersion.ps1, ascii-sweep.py)
- scripts/linux/, scripts/linux/tools/, scripts/linux/lib/
- scripts/windows/, scripts/windows/tools/, scripts/windows/lib/
- .tool-versions
- ARCHITECTURE.md (file-tree section)
- CHANGELOG.md (Unreleased + 0.9.3 entries)
- .squad/team.md (active roster)
- .squad/agents/ (directory enumeration)
- .squad/retros/2026-05-17-sprint-13-retro.md

## Summary

**8 divergences found** (3 high, 2 medium, 3 low).

The most consequential is **F3**: the README itself contains 645 non-ASCII
bytes (box-drawing glyphs + em dashes) inside the file-tree fenced code block
at L80-L130. Sprint 13's pre-commit ASCII extension (#322B / PR #334) scans
the entire staged file -- it does NOT skip fenced code blocks -- so any
in-place edit to README.md in Wave 2 will fail Check 2 unless those bytes are
converted to ASCII first. `scripts/lib/ascii-sweep.py` will NOT clean them
(the sweep deliberately preserves fenced code verbatim). Mickey must
hand-convert the file-tree block or risk a blocked commit.

Sprint 13 also added two artifacts the README does not mention:
1. The pre-commit ASCII scan was extended from .ps1 only to .ps1 + .md + .sh
   (#322B / PR #334). README's pre-commit description (L194-L196) still
   describes only the shellcheck step.
2. `scripts/lib/ascii-sweep.py` is a new reusable tool (#322A / PR #335) that
   contributors should know about when they hit ASCII-check failures.

## Findings

### F1 (HIGH): pre-commit description omits Sprint 13 ASCII scan and 4 other checks

- **README line(s):** L194-L196 (and indirectly the file-tree summary at L115)
- **Current claim:**
  > Runs shellcheck on staged `.sh` files. Blocks commit if shellcheck fails.
  > Silently skips if shellcheck not installed.
- **Actual:** `hooks/pre-commit` performs six ordered checks (per the header
  comment at L3-L9 of the hook):
  1. Branch ancestry (squad/* must descend from develop)
  2. ASCII-only on staged `*.ps1`, `*.md`, `*.sh` (extended in #322B / PR #334)
  3. Rogue path check under `.squad/`
  4. Staged inbox file check (`.squad/decisions/inbox/` must be gitignored)
  5. Refuse commits directly on develop / main / master
  6. Shellcheck on staged .sh files
  Check 2's scope expansion to `.md` and `.sh` (was `.ps1` only) is the
  Sprint 13 change explicitly called out in CHANGELOG 0.9.3 ("Fixed" entry
  for #322 part B).
- **Suggested fix:** Replace L194-L196 with a short bulleted list mirroring
  the six checks. Explicitly mention that ASCII enforcement covers `.ps1`,
  `.md`, and `.sh` so contributors editing Markdown understand the policy.
  Cross-link `scripts/lib/ascii-sweep.py` (see F2) as the recommended
  remediation tool.

### F2 (HIGH): scripts/lib/ascii-sweep.py is not mentioned anywhere

- **README line(s):** Absent -- searched README.md for "ascii-sweep", "ASCII",
  "non-ASCII"; zero matches.
- **Current claim:** N/A (omission)
- **Actual:** `scripts/lib/ascii-sweep.py` exists (230 lines), was added in
  PR #335 (Goofy, #322 part A) and used to sweep all repo Markdown.
  Usage: `python scripts/lib/ascii-sweep.py [--dry-run] [--root <path>]`.
  The script maps em/en dashes, smart quotes, arrows, box-drawing glyphs,
  status emoji, etc. to ASCII equivalents while preserving fenced code
  blocks verbatim.
- **Suggested fix:** Add a short paragraph under "Contributing" (near L244)
  or as a sub-bullet inside the new pre-commit description (F1) along the
  lines of: "If pre-commit rejects your commit for non-ASCII bytes in a
  `.md` file, run `python scripts/lib/ascii-sweep.py --dry-run` to preview
  fixes, then drop `--dry-run` to apply them. The sweep preserves fenced
  code blocks verbatim, so non-ASCII inside ``` ... ``` must be cleaned
  manually."

### F3 (HIGH): README.md itself violates the ASCII policy (645 non-ASCII bytes inside the file-tree fence)

- **README line(s):** L80-L130 (the entire file-tree fenced code block) plus
  L82-L129 (em dashes used as separators inside the tree). Total: 645
  non-ASCII bytes per `[System.IO.File]::ReadAllBytes` count.
- **Current claim:** N/A -- this is a latent state issue, not a claim.
- **Actual:** The file-tree code block uses Unicode box-drawing glyphs:
  - `U+251C` ("|--") box-drawing tee
  - `U+2502` ("|") box-drawing vertical
  - `U+2514` ("`--") box-drawing corner
  - `U+2500` ("--") box-drawing horizontal
  - `U+2014` ("--") em dash as separator
  These were preserved by Goofy's #322A sweep because the sweep explicitly
  skips fenced code blocks (`sweep_text` in `scripts/lib/ascii-sweep.py`
  L154-L175 -- "Sweep a markdown document, preserving fenced code blocks").
  Pre-commit Check 2 (post-#322B), however, scans the full staged content
  via `git show ":$file" | grep -nP '[^\x00-\x7f]'` and does NOT respect
  code-fence boundaries. Therefore: **any in-place edit + stage of
  README.md will trip the ASCII check on these 645 bytes** and fail to
  commit.
- **Suggested fix:** Before Mickey makes any other Wave 2 edit, replace the
  file-tree glyphs with ASCII equivalents in a single sweep:
  - `U+251C` -> `+--` or `|--`
  - `U+2502` -> `|`
  - `U+2514` -> `+--` or `\` + `--`
  - `U+2500` -> `--`
  - `U+2014` -> `--`
  Optionally, the file-tree block can also be regenerated from ARCHITECTURE.md's
  file-tree (which uses `#` as separator and may already be ASCII-clean -- worth
  checking before copy-pasting). Without this step, Wave 2 is blocked or has
  to land via `--no-verify`, which violates the hooks contract.

### F4 (MEDIUM): scripts/lib/ tree entry is incomplete

- **README line(s):** L88-L90
- **Current claim:**
  ```
  scripts/
  +-- lib/
  |   +-- read-tool-version.sh  -- POSIX sh: reads pinned version ...
  |   +-- Read-ToolVersion.ps1  -- PowerShell: Get-ToolVersion function
  ```
- **Actual:** `scripts/lib/` now contains THREE files:
  - `read-tool-version.sh`
  - `Read-ToolVersion.ps1`
  - `ascii-sweep.py` (added Sprint 13 / PR #335)
- **Suggested fix:** Add an `ascii-sweep.py` line to the tree under
  `scripts/lib/` with a one-line description ("Sweep `.md` files for
  non-ASCII characters; preserves fenced code blocks").

### F5 (MEDIUM): file-tree pre-commit one-liner is understated

- **README line(s):** L115
- **Current claim:**
  > pre-commit            -- Shellcheck on staged .sh files
- **Actual:** As detailed in F1, pre-commit performs six checks; shellcheck
  is only the last (Check 6) and is silently skipped if shellcheck is not
  installed.
- **Suggested fix:** Either expand the one-liner ("Branch ancestry + ASCII
  on .ps1/.md/.sh + .squad/ allow-list + shellcheck") to match
  ARCHITECTURE.md L83 style, or replace with a short cross-reference
  ("Hygiene checks; see Git Hooks section below"). The expansion is
  preferred because the file-tree should self-document.

### F6 (LOW): scripts/linux/ and scripts/windows/ trees omit lib/ subdirs

- **README line(s):** L91-L100 (linux/), L101-L109 (windows/)
- **Current claim:** No `lib/` subdir shown under either `scripts/linux/`
  or `scripts/windows/`.
- **Actual:**
  - `scripts/linux/lib/log.sh` exists (added Sprint 9 / #223 -- shared
    `log_info`/`log_ok`/`log_warn`/`log_error` helpers)
  - `scripts/windows/lib/logging.ps1` exists (Write-Info/Write-Ok/Write-Warn
    /Write-Err + Assert-LastExit)
  - `scripts/windows/lib/path.ps1` exists (Refresh-SessionPath)
  Both are documented in ARCHITECTURE.md (L41-L42, L55-L57) but invisible
  from README.
- **Suggested fix:** Optional. README operates at a coarser detail level
  than ARCHITECTURE.md, so omission is defensible. If included, add one
  `lib/` line per OS subtree mirroring ARCHITECTURE.md's wording.

### F7 (LOW): README does not surface that pre-commit also rejects direct commits on develop/main/master

- **README line(s):** L194-L196 (pre-commit), L214 (pre-push)
- **Current claim:** Pre-push "Blocks direct pushes to `main` (hard stop)".
  No mention that pre-commit also refuses develop/main/master commits.
- **Actual:** `hooks/pre-commit` Check 5 (L168-L179) hard-rejects commits
  authored directly on develop, main, or master regardless of push state.
- **Suggested fix:** Roll into the F1 rewrite -- the new pre-commit
  description should list "refuses direct commits on develop/main/master"
  as one of the bullets.

### F8 (LOW): "team of nine specialized AI agents" -- VERIFIED against repo, divergent from task brief

- **README line(s):** L246
- **Current claim:**
  > a team of nine specialized AI agents (Mickey, Donald, Goofy, Pluto,
  > Chip on engineering; Jiminy, Doc, Scribe, Ralph on process and hygiene)
- **Actual:** `.squad/team.md` lists exactly 9 active members (Mickey,
  Donald, Goofy, Pluto, Chip, Jiminy, Doc, Scribe, Ralph). The
  `.squad/agents/` directory has 9 entries: chip, doc, donald, goofy,
  jiminy, mickey, pluto, ralph, scribe. Sprint 13 retro (L9) confirms
  "nine agent dispatches". README's claim matches repo state.
- **Note:** The dispatch task brief stated "10 agents now (was 8/9)", which
  does NOT match current repo state. No 10th agent charter exists. Either
  the task brief is aspirational (a 10th hire is pending and the README
  count will need bumping when it lands) or it is a typo. **Confidence:
  Verified** against current repo; recommend Mickey confirm with Earl
  whether a 10th agent is in flight before Wave 2.
- **Suggested fix:** Leave at "nine" pending Mickey's confirmation. If a
  10th agent is landing in Sprint 14, defer the L246 bump to that PR.

## Cross-checks that PASSED (no finding)

These items were inspected and confirmed accurate; included so Mickey does
not waste cycles re-verifying:

- **L40 -- auth.sh / auth.ps1 paths.** `scripts/linux/tools/auth.sh` and
  `scripts/windows/tools/auth.ps1` both exist (auth.ps1 moved into tools/ in
  PR #297, Sprint 11 #230). No stale top-level reference remains.
- **L192 -- "four hooks are active".** Verified: `hooks/` contains exactly
  four files (commit-msg, pre-commit, prepare-commit-msg, pre-push). The
  3-to-4 fix landed in PR #330 / #326.
- **L198-L210 -- commit-msg + prepare-commit-msg descriptions.** Match the
  active hook scripts (Conventional Commits regex; merge/revert rewrite
  cases).
- **L213-L217 -- pre-push behaviour.** Block-main + advisory shellcheck +
  advisory PSScriptAnalyzer all match `hooks/pre-push` (with `|| true`
  load-bearing on PSSA per #233).
- **L226-L227 -- .tool-versions reader paths.** `scripts/lib/read-tool-version.sh`
  (POSIX) and `scripts/lib/Read-ToolVersion.ps1` (Get-ToolVersion) both
  exist and match the README claim.
- **L229-L236 -- .tool-versions excerpt.** Byte-for-byte match with the
  on-disk `.tool-versions` (nodejs 22.11.0, nvm 0.39.7, nvm-windows 1.2.2,
  uv 0.4.18, copilot-cli 1.0.48, squad-cli 0.9.4, gh 2.92.0).
- **L249-L250 -- CONTRIBUTING/CHANGELOG references.** Both files exist and
  contain the sections the README cross-links to (sprint naming convention,
  Keep a Changelog format with letter-named-sprint aliases).
- **Supported platforms (L22-L28).** Linux native, macOS, WSL, Windows
  PowerShell, Dev Container/Codespace all still supported per setup.sh /
  setup.ps1 routers. No platform claim divergence.
- **Quick-start install snippets (L32-L48).** `git clone` URL
  (`https://github.com/primetimetank21/dev-setup.git`) matches the
  configured remote (origin: primetimetank21/dev-setup). PowerShell
  invocation `powershell -ExecutionPolicy Bypass -File setup.ps1` still
  matches setup.ps1's CLI surface.

## Recommendations for Mickey (Wave 2)

1. **Apply F3 FIRST** -- the file-tree ASCII conversion is a hard
   prerequisite. Without it, pre-commit Check 2 blocks every subsequent
   edit. Suggested approach: replace `|-- | +-- - --` glyphs with their
   ASCII counterparts (`|`, `+--`, `|--`, `--`) in one focused pass, then
   stage to confirm the hook is clean before layering F1/F2/F4/F5 edits.
2. **Bundle F1, F2, F5, F7** -- all touch the Git Hooks section (L184-L218)
   and the related file-tree summary line (L115). Single coherent rewrite
   of the pre-commit description, with a contributor-facing note pointing
   at `scripts/lib/ascii-sweep.py`. Cross-reference the SKILL file at
   `.squad/skills/pwsh-lastexitcode/` style if a similar skill is ever
   formalized for ASCII hygiene.
3. **Apply F4** in the same pass -- one new line in the `scripts/lib/`
   tree, matching the indentation style already used.
4. **Skip or defer F6** -- README's level of detail does not require
   per-OS lib/ visibility; ARCHITECTURE.md handles it.
5. **Skip F8 unless Earl confirms a 10th agent** -- current "nine" is
   correct against `.squad/team.md`. The task brief's "10" appears to be
   ahead of repo state.
6. **Preserve README's existing tone and structure** -- the file is
   contributor-facing and lightly humorous (e.g., the "team of nine
   specialized AI agents" framing). Don't switch to a clinical
   reference-doc tone in the rewrite.
7. **Maintain ASCII cleanliness** throughout. After the F3 conversion,
   keep new prose ASCII-clean so the pre-commit hook stays green.

---

**Confidence:** Verified for all 8 findings (each citation includes
line/file reference; no hand-waving). Counter-hypotheses considered:

- "F3 is a false alarm because the sweep handles it." Counter: the sweep
  preserves fenced code blocks by design (L154-L175 of ascii-sweep.py),
  so running it on README leaves the 645 bytes intact. The pre-commit
  hook does not share that exemption.
- "F8 is wrong because Earl said 10." Counter: source of truth is
  `.squad/team.md` (9 entries) and `.squad/agents/` (9 dirs). Until a
  charter for a 10th agent is committed, "nine" is the correct claim.
- "F1 is over-broad because most checks predate Sprint 13." Counter: F1
  is scoped to the documentation gap; whether the gap was opened in
  Sprint 9 or Sprint 13 is irrelevant to Mickey's Wave 2 fix. The
  Sprint 13 ASCII scope expansion is the immediate trigger and the
  rewrite addresses both the pre-existing and the new gaps in one pass.

**Verdict:** PROCEED to Wave 2 (Mickey edit pass). F3 is the only finding
that gates further edits and is mechanical to fix.
