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
