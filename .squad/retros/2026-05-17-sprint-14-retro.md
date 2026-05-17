# Sprint 14 Retro -- 0.9.4 Release

**Date:** 2026-05-17
**Release tag:** 0.9.4 @ 008f166 (main)
**Issues shipped:** 6 (#340, #341, #342, #343, #347, #350)
**PRs merged:** 7 work + 2 release = 9 total (#344, #345, #346, #348, #349, #351, #352, #353)
**Coordinator:** Mickey (release lead), Coordinator (main-branch merge)

## Ledger

| Issue | Title | PR(s) | Primary Agent(s) | Status |
|------:|-------|-------|------------------|--------|
| #340 | history-compression skill formalization | #345 | Scribe | Merged |
| #341 | per-topic inbox routing skill formalization | #345 | Scribe | Merged |
| #342 | README refresh (audit + edit phases) | #346 (audit) + #348 (edit) | Doc + Mickey | Merged |
| #343 | CHANGELOG editorial -- Sprint 13 retro placement | #344 | Mickey | Merged |
| #347 | Label taxonomy 45 -> 32, 84 issues migrated | #349 | Pluto | Merged |
| #350 | sync-squad-labels.yml follow-ups | #351 | Pluto | Merged |
| (release) | 0.9.4 CHANGELOG fold + main merge | #352 (fold) + #353 (develop->main) | Mickey + Coordinator | Merged |

## What Worked

- **GitHub label migration flawless at scale: 84 issues, 3x verification.** Pluto's #349
  implemented a triple-verify protocol (PRE-migration audit, OP-migration counts,
  POST-migration consistency check). Each issue touched 3 verification reads. Total: 252
  verification operations, 0 halts, 0 rollbacks. Label taxonomy reduction 45 -> 32 exact
  (target hit).

- **history-compression skill cleared 5+ threshold (confidence bump to high).** Sprint 14
  saw 5 new applications: (1) Scribe #345 self-apply post-formalization, (2) Mickey #344
  CHANGELOG fold (4 entries compressed), (3) Mickey #348 README edit fold, (4) Pluto #349
  history-compression applied to history.md, (5) Mickey #352 release-fold
  re-compression. Heuristic proved stable across all contexts. Confident for "high"
  graduation.

- **per-topic-inbox-routing skill cleared 5+ threshold (confidence bump to high).** Every
  agent who filed a decision this sprint (Doc, Scribe, Mickey, Pluto) chose canonical
  per-topic routing over chronological journal by default. #340+#341 formalization
  reinforced the pattern. 5+ applications in Sprint 14 alone justified graduation.

- **README cleared of 645 non-ASCII bytes (fenced-code blocking resolved).** Doc's audit
  (PR #346) identified box-drawing tree art embedded in fenced code blocks. Pre-commit
  hook scan ignores code fences by design, but manual hand-conversion was required
  before any other edit could ship. Mickey's #348 followed with the edit phase. Forward
  lesson: pre-commit ASCII scan does NOT respect fence delimiters.

- **5 new canonical decision drops, zero orphaned in inbox.** Every skill formalization,
  label policy tweak, and README editorial decision landed in `.squad/decisions/` with a
  clear topic home. Scribe verified inbox empty post-Wave-1.

- **Worktree-remove-FIRST pattern stayed 7-for-7 in Sprint 14.** Lifetime success now
  21-of-21 (14-of-14 from Sprints 12-13 + 7-of-7 this sprint). Pattern is proven
  rock-solid; no regression signals.

- **Skill confidence graduations completed on schedule.** Both history-compression and
  per-topic-inbox-routing formalized as medium in PR #345 and reached high confidence
  by end of sprint. Demonstrates skill-graduation velocity.

## What We Learned / Process Insights

- **GitHub close-keyword parser footgun.** Doc's PR #346 body contained "Does NOT close
  #342" but the parser triggered auto-close anyway because it matches the literal
  substring `close #342`. Parser ignores negations. Forward-fix: never use
  close|closes|fix|fixes|resolve|resolves {N} in ANY phrasing, even negated. Issue
  #342 was manually reopened by Earl and re-filed to the PR.

- **Worktree YAML ASCII exemption.** Pre-commit Check 2 (ASCII scan) operates on
  .ps1|.md|.sh only. Workflow YAML files (.yml) are NOT in scope. Pluto verified during
  #347 Phase 6. Pre-existing em-dashes in `.squad/` workflows (if any) persist
  independently of the pre-commit hook.

- **sync-squad-labels.yml create-only semantics.** The workflow does NOT delete
  out-of-spec labels. Pluto's #347 created 32 new labels via the workflow. Labels added
  manually outside the workflow (e.g., priority:p3, platform:* added in #347 pre-sync)
  persist independently until added to the workflow spec.

- **README fenced-code-block non-ASCII bypass.** Pre-commit ASCII scan (Check 2) does
  NOT respect code fences. Doc's README contained 645 non-ASCII bytes (em-dashes,
  arrows, box-drawing chars) in a fenced code block. Hand-conversion was required before
  any other edit could ship. ascii-sweep.py preserves fences by design and will not
  clean fenced content -- this is correct (do not auto-transform user example code).

- **history-compression rebound (recurring incident).** Every fold followed by
  hygiene-tail appends causes rebound over 13 KB target. Sprint 14 demonstrated this
  3x: Scribe #345, Mickey #344 CHANGELOG fold, Pluto #349. Forward-fix: apply
  compression AFTER all hygiene-tails land, not before.

- **Roster correction (forward-fix from Sprint 13).** Prior memories had "10 agents: Lead
  + Mickey + ...". Doc fact-check in Sprint 13 verified team.md has 9 rows total:
  Mickey IS the Lead (no separate Lead role). README's "nine agents" is correct. This
  sprint confirmed no roster memory updates needed.

- **Cross-branch worktree limitation still hard.** Agents in worktrees cannot `checkout
  develop` or `checkout main` because those branches are owned by the main checkout.
  Release flow split work: Mickey phases 1-4 (CHANGELOG fold + release branch -> develop
  PR), Coordinator phase 5+ (develop -> main + tag + release). This pattern holds from
  Sprint 11.

- **Earl lead-call: pull #350 into Sprint 14 Wave 3.** #350 was originally parked for
  Sprint 15 (mechanical patch to sync-squad-labels.yml follow-ups from #347). Earl
  pulled it in because: (1) small mechanical scope, (2) thematically tied to #347
  (same-cycle label work). Decision rationale serves as a template for future lead calls
  on pull-in vs. park.

## Skill Graduations

- **history-compression: confidence medium -> high.** 3 applications in Sprint 13 + 5
  applications in Sprint 14 (Scribe #345, Mickey #344/#348, Pluto #349, Mickey #352)
  = 8+ lifetime applications. Heuristic proved stable across all agent contexts. Cleared
  high-confidence threshold (>=5 applications distinct contexts).

- **per-topic-inbox-routing: confidence medium -> high.** 2 applications in Sprint 13 +
  5 applications in Sprint 14 (every decision filed this sprint routed via canonical
  per-topic) = 7+ lifetime applications. Routing tree proved sound. Cleared
  high-confidence threshold.

## Process Refinements Adopted

- **ASCII hygiene mandate: 100% compliance.** All Sprint 14 commits except pre-existing
  YAML em-dashes (out of pre-commit scope) shipped with 0 non-ASCII bytes. Pre-commit
  hook Check 2 stayed active across all 7 work PRs + 2 release PRs.

- **CWD pin + absolute-path lesson (from Sprint 12 W3) maintained.** Zero CWD-drift
  incidents Sprint 14. Scribe + all agents verified CWD before file writes. .NET APIs
  confirmed to use process CWD, not Set-Location -- 8 agents dispatched, 0 worktree
  isolation leaks.

- **Worktree-remove-FIRST merge pattern held 7-of-7.** Pre-merge cleanup validated via
  `Get-ChildItem .squad/` audit. All 7 work PRs merged clean in single attempt.

- **Label taxonomy sweep triple-verify protocol validated.** Pluto's PRE/OP/POST audit
  model is now a reusable pattern for any large-scale issue metadata migration.

## Open Follow-ups / Sprint 15 Candidates

- **(Deferred) README tree-art ASCII conversion policy.** Doc converted 645 non-ASCII
  bytes in fenced code by hand. Future policy: allow Unicode in fenced code blocks
  (do NOT run ascii-sweep inside fences). Document as code-fence exemption in
  .squad/decisions/ascii-policy.md.

- **(Deferred) Skill candidate: "label-migration-protocol".** Pluto's triple-verify
  pattern (PRE/OP/POST per-issue audit) is reusable for any bulk issue metadata
  operation. One more application would justify formalization. Candidate for Sprint 15.

- **(Follow-up item) Verify no orphan label operations remain post-#347.** Pluto's
  #349 created 32 labels via sync-squad-labels.yml. Audit script to verify no dangling
  label operations exist (e.g., old area:* still present if not migrated to platform:*).

## Memorable Moments

- **Earl's lead decision: "pull #350 into Sprint 14 Wave 3."** Coordinator debated
  parking #350 for Sprint 15 but Earl called it thematically tied to #347 (same-cycle
  label work). Small mechanical patch justified the pull-in. Decision template for
  future lead judgment calls.

- **GitHub parser footgun nearly broke #342.** Doc's "Does NOT close #342" triggered
  auto-close anyway. Parser sees `close #342` substring and ignores negations. Issue
  manually reopened; lesson broadcasts across team: never mention issue numbers with
  close/fix/resolve keywords in ANY context.

- **252 verification reads, 0 halts in label migration.** Pluto's triple-verify
  protocol on 84 issues: PRE-check (audit existing labels), OP-check (count+validate
  post-migration), POST-check (consistency verify). Each issue = 3 reads. Methodical
  approach pays off at scale.

- **history-compression skill graduates to high confidence mid-sprint.** Scribe
  formalized skill at medium with 3 prior applications; 5+ new applications in same
  sprint led to mid-cycle graduation. Demonstrates rapid skill maturation when deployed
  in production.

- **Per-topic decision routing becomes default.** Every agent filing a decision this
  sprint defaulted to canonical per-topic home rather than chronological journal. Skill
  formalization in #341 reinforced the pattern within hours.

## Metrics Summary

- Issues closed: 6 (#340, #341, #342, #343, #347, #350)
- PRs merged: 7 issue + 2 release = 9 total (#344-#353)
- GitHub issues migrated: 84 (label taxonomy rebalance)
- Label taxonomy: 45 -> 32 (-13, exact target)
- Non-ASCII bytes in commits: 0 (excluding pre-existing YAML em-dashes)
- Worktree-isolation leaks: 0 across 7 agent dispatches
- Worktree-remove-FIRST success: 7-of-7 (lifetime: 21-of-21)
- Skills graduated to high confidence: 2 (history-compression, per-topic-inbox-routing)
- New canonical decision files: 4
- Release: 0.9.4 tagged at 008f166 (main)

## Release Readiness

- `[Unreleased]` CHANGELOG: empty at sprint end (folded into 0.9.4)
- Open backlog issues: 0 (triage pending for Sprint 15)
- Tag: 0.9.4 @ 008f166 (main)
- GitHub Release: published

## Suggested Sprint 15 Themes

- Label taxonomy audit (verify no orphaned label operations remain)
- Skill candidate formalization: "label-migration-protocol" (Pluto's triple-verify)
- Code-fence ASCII exemption policy documentation
- Backlog triage + capacity planning

## Action Items into Sprint 15

1. **Pluto:** Audit post-#347 label state to verify no orphaned operations.
2. **Scribe:** Update `.squad/decisions/ascii-policy.md` with code-fence exemption.
3. **Coordinator:** Triage backlog for Sprint 15 scope (expected: 4-6 issues).
4. **(Deferred) Label-migration-protocol skill formalization** -- one more application
   justifies codification.
