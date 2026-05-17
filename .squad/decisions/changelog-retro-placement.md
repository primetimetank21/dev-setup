# CHANGELOG: Sprint retro entry placement

**Decided:** 2026-05-17
**By:** Mickey (Lead)
**Triggered by:** Sprint 13 retro (#339) merged after 0.9.3 tag; Jiminy CONCERN in EOS audit.

## Decision

**Option A -- Move the Sprint 13 retro entry to `[0.9.3]`.** CHANGELOG.md is a curated narrative, not a commit-by-commit replay of the tagged ref. Prior-sprint convention places the retro entry under the sprint's release section (Sprint 11 retro lives under `[0.9.1]` line 65; Sprint 12 retro lives under `[0.9.2]` line 51). Diverging from this for Sprint 13 just because PR #339 merged a few hours after the `0.9.3` tag (`edc67e2`) was pushed would create an inconsistent reader experience and bury the retro under a future release header. The tag is immutable; the CHANGELOG-on-develop is a living document and is allowed to be edited retroactively for editorial coherence as long as the change is itself documented (which this decision file does).

## Rule going forward

When a sprint retro PR merges to develop AFTER the sprint's release tag has already been pushed:

1. **Fold the retro entry into the already-released sprint's section** of `CHANGELOG.md` on `develop` (under `### Added`), matching the prior-sprint format `` `.squad/retros/<file>.md`: Sprint N retrospective (#PR; folded retroactively into X.Y.Z -- PR merged after tag) ``.
2. **Do NOT re-tag the released version.** The tag stays at the commit it was pushed to. The retroactive CHANGELOG edit ships with the next regular `develop -> main` merge.
3. **The Lead (Mickey) owns this editorial call** at sprint wrap or during EOS audit. Codify each instance via a per-topic file in `.squad/decisions/` so the retroactive edit is auditable.
4. **If multiple post-tag drops accumulate** before the next release cut, batch them under the released section and reference each PR.
5. **Coordinator preference:** Scribe should target the retro PR to land BEFORE the release-cut PR whenever possible, which avoids this whole class of issue. Sprint 14 dispatch sequencing should put `retro write -> retro PR merge -> release fold PR -> develop->main merge -> tag` in that order.

## Applied to

- Sprint 13 retro (#339) -- moved from `[Unreleased]` to `[0.9.3]` ### Added with a retroactive-fold annotation referencing this decision file.
