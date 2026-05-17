# Sprint 8-hotfix (formerly Sprint Q) Retro -- 2026-05-16 (0.8.0 Release)

Sprint 8-hotfix = the P0 emergency batch fixed AFTER Sprint 8 wrap revealed install regressions on a fresh box. Three bugs (#249, #251, #252) had to ship before 0.8.0 could go out. Goofy's #251 (Windows nvm PATH) took 9 rounds.

## What Went Well

- **All 3 P0s shipped and verified.** E2E green on all 3 platforms for the first time (Linux 39s, macOS 1m3s, Windows 2m34s). 0.8.0 cut from develop -> main with no rollbacks.
- **Aggressive root-cause analysis from CI logs.** Goofy progressively identified each layer of the Windows install racy stack: timeout too low -> installer race vs winget return -> PATH unexpanded `%NVM_HOME%` literals -> fresh-shell registry blindness -> `$Args` PS automatic clash. Each round had data.
- **Escalation call was correct.** When winget+nvm-setup.exe proved unreliable after 3 rounds, Coordinator+Earl chose portable `nvm-noinstall.zip`. Deterministic, no installer race. Right tradeoff.
- **Surgical fixes over rewrites.** Once the root cause was found in a round, the fix was small and targeted. No "let me redesign the whole thing" thrashing.
- **Earl's hard gate.** "All of these items that were 'shipped' -- there's ABSOLUTELY no reason for me to doubt they work properly?" stopped premature ship signals 2x.
- **Jiminy hired.** New role: Hygiene Auditor. Audits squad's process compliance (history.md updates, branch hygiene, decision drains) after spawns. First session = stood up + charter shipped.
- **CI gate for `agents/{name}/history.md`** caught at least one missing update mid-sprint.

## What Could Be Better

- **#251 took 9 rounds.** Pattern: each round patched the symptom uncovered by the previous failure. We never did an upfront "list every way this can fail" analysis. By round 5 we were chasing tail (workflow `$Args` shadowing) instead of fundamentals (registry PATH for fresh shells). **Cost:** ~4 days, ~9 CI runs, fatigue.
- **Branch ancestry bleed (3rd occurrence).** Squad keeps forking branches off other squad branches instead of `develop`. Mickey flagged this twice prior. It happened again in Sprint 8-hotfix. The CI gate in `pre-commit` checks this but only on commit-time -- after the fact.
- **Stale branches kept accumulating.** Earl asked for branch cleanup TWICE this session. Despite `--delete-branch` on merge, stale tracking refs and remote orphans linger. Ralph's EOS sweep helps but is reactive.
- **No verifier/validator role.** Earl had to double/triple-check claims of "done." Goofy claimed #251 was fixed 4+ times before E2E actually went green. Jiminy is process QA, not technical validation. **Open question:** is this a teammate gap or a process gap (e.g., "require green E2E artifact before claiming done")?
- **HYGIENE backlog items underprioritized.** Earl explicitly bumped these for next sprint after seeing them cause real bugs (branch bleed, stale state, missing history updates).
- **CHANGELOG conflicts predictable in multi-PR sprints.** Resolved by union each time, but a CHANGELOG strategy doc would save 15 minutes per PR.

## Action Items

- **[Coordinator] "Two strikes" rule.** When a fix fails CI twice on the same issue, REQUIRE a written failure-mode analysis before round 3. No more reactive patching. Track in coordinator's spawn checklist.
- **[Mickey] Make "branch from develop" rule prominent.** Top of CONTRIBUTING.md, not buried. Add an example of the bleed pattern with concrete branch names. Reference the 3 occurrences.
- **[Earl + Coordinator] Decide verifier/validator scope.** Options: (a) extend Jiminy to technical validation, (b) hire a new teammate (Validator), (c) make "green E2E artifact + manual smoke" mandatory before merge. Decide before Sprint 9 (formerly Sprint R) kickoff.
- **[Mickey] Bump HYGIENE backlog to P0/P1.** #224 (hook tests), #227 (.bak rotation), #228 (docs core.hooksPath), branch hygiene automation. These keep causing P0s downstream.
- **[Ralph] EOS sweep is now standing directive.** Document in charter. Confirm every session ends with the 12-point sweep -- already done this session, lock it in.
- **[Chip] Track E2E nightly flake rate.** After 2-3 consecutive green nightlies, flip `continue-on-error: false` and make E2E a blocking check. #253 surfaces failures.
- **[Mickey] Write CHANGELOG conflict strategy doc.** 5-line cheatsheet on union resolution for multi-PR sprints. Add to CONTRIBUTING.md.

## Stats

- **Issues filed/closed this session:** 6 filed (#249, #251, #252 P0s; #253, #254, #255 chores), 3 closed (#249, #251, #252)
- **PRs merged this session:** ~10 (#244, #245, #248, #250, #256, #257, #258, #259, #260, + 0.8.0 tag)
- **Rounds per P0:** Pluto #249: 1, Chip #252: 3, Goofy #251: 9
- **Worktrees:** spun up 3, all cleaned
- **Stale branches deleted:** 7 (sprint wrap) + 3 (Sprint 8-hotfix wrap) + 1 (release/0.8.0)
- **Memories stored:** 5+ (portable nvm-windows, CI Windows PATH refresh, PS `$Args` pitfall, U+2014 in PS strings, winget IDs)
- **New teammate:** Jiminy (Hygiene Auditor) -- charter shipped, first audit complete
- **Release:** 0.8.0 cut, tagged, GH release published

## Reflection

Sprint 8-hotfix was a stress test of the squad's ability to ship when CI is the only feedback loop and the environment fights back. Goofy's 9-round saga proves we can iterate, but the cost was high -- 8 of 9 rounds were reactive, not predictive. The "two strikes" rule is the highest-leverage change from this retro: it forces a pause to think instead of yet another commit.

The hygiene gap is the second theme. Branch ancestry bleed, stale branches, and missing history updates aren't bugs -- they're symptoms of process drift. They've now caused real P0s (the install audit only happened because Earl checked manually; the squad missed it). HYGIENE bump for Sprint 9 is mandatory.

**Board status:** CLEAN. main = `7d9be7b`, develop synced, 0 worktrees beyond primary, 0 stray branches, 0 untracked. 0.8.0 shipped.
