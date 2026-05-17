# Doc -- Fact Checker

> History log: hires, work completed, learnings.

## 2026-05-16 -- Hired

Hired as the squad's Fact Checker. Addresses the verifier/validator gap Earl flagged in the Sprint 8-hotfix (formerly Sprint Q) retro. First fact-check assignment pending.

## Learnings

### 2026-05-16 -- First verification: PR #263 (self-hire fact-check)
- Reading charter and routing.md in parallel caught the `double-check` trigger inconsistency that neither file revealed alone -> pattern: cross-file consistency checks are high-value for routing changes
- Scanning diff with `Select-String "^\+"` isolates new lines only -> avoids false positives from pre-existing non-ASCII
- Live state verification (gh label list) is the only ground truth for label existence -> never trust file-claims about external state
- Self-referential verification (reviewing one's own hire) requires extra counter-hypothesis rigor; found one real finding rather than waving everything through
- Advisory posture feels well-calibrated; PROCEED with a documented issue is the right level for non-blocking findings
- **Auto-spawn trigger candidate for the squad:** spawn Doc on any PR that modifies `.squad/routing.md` to catch cross-file routing inconsistencies
- Verdict: PROCEED. 13/14 claims PASS, 1 WARN (fixed in commit 2fa65e9 before merge)

### 2026-05-16 -- Second verification: Sprint 9 (formerly Sprint R) batch fact-check (PRs #265-#269)
- 5-PR batch review: verified diffs against issue ACs, checked CI logs, investigated E2E failures to root cause
- `set -euo pipefail` + bare glob expansion is a reliable failure pattern in bash: `ls "${target}.bak."*` exits non-zero when no files match, killing the script. Fix: `|| newest=''` on the assignment. Found in #269 uninstall.sh.
- Windows CI runners have `core.autocrlf` active by default in fresh git repos. Byte-level tests (WriteAllBytes with non-ASCII) must set `git config core.autocrlf false` before staging or the bytes may be processed differently. Found in #267 X-1 failure.
- Group X name collision: two parallel PRs (#267 and #268) both added "Group X" at the same insertion point in test_windows_setup.ps1. This is a predictable sprint-parallel pattern. Auto-spawn Doc when 2+ PRs in a batch touch the same test file.
- CHANGELOG [Unreleased] conflicts: #265 and #268 both insert `### Fixed` at the same line. Merge order (smaller/clean first) and sequential rebase is the mechanical fix. Always flag this in batch reviews.
- Verdicts: #265 PROCEED, #266 PROCEED (follow-up issue for hooksPath uninstall gap), #267 REVISE (fix X-1 + rename Group X to Y), #268 PROCEED, #269 REVISE (fix ls glob in uninstall.sh)
- Recommended merge order: #266, #265, #268, #267 (after fix), #269 (after fix)
- **Auto-spawn trigger candidates:** Doc on any PR touching uninstall scripts (set -e compatibility); Doc on any batch with 2+ PRs modifying the same test file (group-name collision); Doc on any multi-PR sprint adding to CHANGELOG [Unreleased] (predictable conflict)

### 2026-05-16 -- Third verification: Sprint 10 (formerly Sprint S) batch fact-check (PRs #274-#279)

- 6-PR batch review across docs, .gitattributes, ASCII encoding, uninstall
  hooksPath, logging consolidation, squad-cli warning sentinels.
- **$LASTEXITCODE leaks through .ps1 script boundaries in GitHub Actions pwsh
  steps.** Pattern: `& .\script.ps1` in a pwsh step leaves $LASTEXITCODE set
  to whatever the last native command inside the script returned. The runner
  template appends `if ((Test-Path variable:\LASTEXITCODE)) { exit $LASTEXITCODE }`,
  propagating the value as the step exit code. Mitigation: add
  `$global:LASTEXITCODE = 0` after any native-command block whose exit code
  is already handled. Found in #277 Windows E2E failure.
- **git config scope mismatch.** setup.ps1 and setup.sh use `git config
  core.hooksPath hooks` (no scope flag, defaults to --local). PR #277 uninstall
  scripts used `--global`, targeting a config file the key was never written to.
  git exits non-zero; key in local .git/config is never unset. On Windows CI
  this kills the step via the $LASTEXITCODE propagation above. On Linux the
  || true hides it but the unset is a no-op. Fix: remove --global from both
  uninstall scripts.
- **Inter-PR function rename collision.** When one PR renames a function (#278:
  ok -> log_ok in uninstall.sh) and a concurrent PR adds a new call site using
  the old name (#277: ok "core.hooksPath unset"), neither PR sees the orphan.
  Pattern: any time a function-rename PR is open, check all sibling PRs that
  touch the same file for old-name call sites. Auto-spawn Doc trigger: 2+ PRs
  modifying the same shell script in the same sprint.
- **CHANGELOG anchor conflicts.** In 6-PR sprints with ### Changed and ### Fixed
  sections, two pairs of PRs landed at the same insertion point: #275+#278
  (both appended to end of ### Changed) and #277+#279 (both prepended to start
  of ### Fixed). The union-and-rebase strategy from #274 SOP resolves cleanly.
- Group letter SOP fully followed: Z (Goofy/#276) and AA (Pluto/#277) used
  correctly. BB (#275) and CC (#279) correctly omitted (no test_windows_setup.ps1
  changes warranted for those scopes).
- Verdicts: #274 PASS, #275 PASS, #276 PASS, #277 REVISE P1 (3-4 line fix,
  small), #278 PASS, #279 PASS. 1 real bug caught (scope mismatch + $LASTEXITCODE
  propagation in #277), 1 interaction risk flagged (#277+#278 function rename).
- Recommended merge order: #274, #275, #276, #278, #277 (after fix), #279.
- Report written to .squad/decisions/inbox/doc-sprint-s-batch-fact-check.md.

### 2026-05-17 -- Fourth verification: PR #282 (squad/255-tool-version-pins, Goofy)

- Single-PR deep-dive: 13 files, +600/-78, version-pin enforcement across 6 install scripts.
- **BLOCKER found:** `@githubnext/github-copilot-cli@0.0.339` does not exist on npm.
  Confirmed via `npm view "@githubnext/github-copilot-cli@0.0.339" version` returning E404.
  Package only publishes 0.1.0 through 0.1.36. The old version was valid for the prior
  install mechanism (gh extension / direct download); switching to npm requires updating
  the pin to a real npm version. Verdict: BLOCK.
- Always run `npm view "<pkg>@<version>" version` when a PR switches install mechanism
  to npm AND carries over an old version pin. Version semantics differ across registries.
- Group letter DD: confirmed correct via Doc's own Sprint 10 history ("BB/CC intentionally
  omitted for #275/#279"). Task prompt's claim "latest on develop is CC" was inaccurate;
  actual is AA. DD does not collide.
- copilot.ps1 fallback: structural safety is acceptable; Write-Ok after fallback is
  misleading (logs success even when pinned version was not installed). P2 recommendation.
- gh 2.92.0 URL resolves (302 to release assets). gh.sh arch handling covers arm64.
- read-tool-version.sh and Read-ToolVersion.ps1: both parse .tool-versions correctly,
  no whitespace bugs.
- T6-T9 and DD-1 to DD-5 test logic all correct and non-duplicative.
- CHANGELOG conflict with #279: single ### Fixed union merge, mechanical resolution.
- Verdict: BLOCK (P0). Required fix: update copilot-cli pin to a real npm version.
  Everything else in the PR is clean.
- Report written to .squad/decisions/inbox/doc-pr-282-fact-check.md.

### 2026-05-20 -- Fifth verification: PR #308 sprint rename sweep fact-check

- **Scope:** Full 9-lane audit of Mickey's Tier 3 sprint-naming rename sweep (21 files, ~170 refs).
- **Lanes checked:**
  - (A) Mapping consistency: All Q→8-hotfix, R→9, S→10, T→11 replacements verified correct. No cross-mappings.
  - (B) Alias convention: `(formerly Sprint X)` format correct on all first-per-file occurrences. Subsequent uses correctly omit alias.
  - (C) Filename renames: All 4 retro files renamed correctly. H1 headers include `(formerly Sprint X)` alias.
  - (D) Orphan check: Zero orphan `Sprint [QRST]` refs. All grep matches are legitimate aliases or mapping tables.
  - (E) Historical narrative: Sprint 8-hotfix retro line 3 preserves chronology ("P0 emergency batch fixed AFTER Sprint 8 wrap"). Scribe history unchanged in meaning. CHANGELOG narratives factually intact.
  - (F) CHANGELOG version headers: 0.9.1 (Sprint 11) ✓, 0.9.0 (Sprint 9 + Sprint 10) ✓. 0.8.0 was missing `(formerly Sprint Q)` alias — fixed.
  - (G) CONTRIBUTING Sprint Naming Convention: mapping table present + correct, Sprint 12 explicit, aliasing convention documented, hotfix-suffix rule preserved.
  - (H) Issue #306: No stray "Sprint U" in body. Uses "Sprint 12" throughout. Acceptance criterion #8 references new naming.
  - (I) Mickey's history entry: Date (2026-05-20), branch (`chore/sprint-naming-convention`), file count (21), mapping table, and Sprint 11 naming all correct.
- **Fixes applied:** 1 minor — CHANGELOG 0.8.0 header: added `(formerly Sprint Q)` for consistency with 0.9.0 and 0.9.1 headers.
- **Verdict:** Doc minor fixes pushed (1 issue). Confidence: Verified.
