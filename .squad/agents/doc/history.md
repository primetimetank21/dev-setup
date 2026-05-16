# Doc -- Fact Checker

> History log: hires, work completed, learnings.

## 2026-05-16 -- Hired

Hired as the squad's Fact Checker. Addresses the verifier/validator gap Earl flagged in the Sprint Q retro. First fact-check assignment pending.

## Learnings

### 2026-05-16 -- First verification: PR #263 (self-hire fact-check)
- Reading charter and routing.md in parallel caught the `double-check` trigger inconsistency that neither file revealed alone -> pattern: cross-file consistency checks are high-value for routing changes
- Scanning diff with `Select-String "^\+"` isolates new lines only -> avoids false positives from pre-existing non-ASCII
- Live state verification (gh label list) is the only ground truth for label existence -> never trust file-claims about external state
- Self-referential verification (reviewing one's own hire) requires extra counter-hypothesis rigor; found one real finding rather than waving everything through
- Advisory posture feels well-calibrated; PROCEED with a documented issue is the right level for non-blocking findings
- **Auto-spawn trigger candidate for the squad:** spawn Doc on any PR that modifies `.squad/routing.md` to catch cross-file routing inconsistencies
- Verdict: PROCEED. 13/14 claims PASS, 1 WARN (fixed in commit 2fa65e9 before merge)

### 2026-05-16 -- Second verification: Sprint R batch fact-check (PRs #265-#269)
- 5-PR batch review: verified diffs against issue ACs, checked CI logs, investigated E2E failures to root cause
- `set -euo pipefail` + bare glob expansion is a reliable failure pattern in bash: `ls "${target}.bak."*` exits non-zero when no files match, killing the script. Fix: `|| newest=''` on the assignment. Found in #269 uninstall.sh.
- Windows CI runners have `core.autocrlf` active by default in fresh git repos. Byte-level tests (WriteAllBytes with non-ASCII) must set `git config core.autocrlf false` before staging or the bytes may be processed differently. Found in #267 X-1 failure.
- Group X name collision: two parallel PRs (#267 and #268) both added "Group X" at the same insertion point in test_windows_setup.ps1. This is a predictable sprint-parallel pattern. Auto-spawn Doc when 2+ PRs in a batch touch the same test file.
- CHANGELOG [Unreleased] conflicts: #265 and #268 both insert `### Fixed` at the same line. Merge order (smaller/clean first) and sequential rebase is the mechanical fix. Always flag this in batch reviews.
- Verdicts: #265 PROCEED, #266 PROCEED (follow-up issue for hooksPath uninstall gap), #267 REVISE (fix X-1 + rename Group X to Y), #268 PROCEED, #269 REVISE (fix ls glob in uninstall.sh)
- Recommended merge order: #266, #265, #268, #267 (after fix), #269 (after fix)
- **Auto-spawn trigger candidates:** Doc on any PR touching uninstall scripts (set -e compatibility); Doc on any batch with 2+ PRs modifying the same test file (group-name collision); Doc on any multi-PR sprint adding to CHANGELOG [Unreleased] (predictable conflict)
