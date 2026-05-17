---
name: per-topic-inbox-routing
confidence: medium
applications: 2
last_updated: 2026-05-17
---

# per-topic-inbox-routing

## When to use
Scribe applies this skill on every inbox drain cycle -- whenever `.squad/decisions/inbox/*.md` drops need to be folded into the canonical decisions store.

## Routing decision tree
For each drop in `.squad/decisions/inbox/`:

1. **Append to existing per-topic file?** -- If the drop's topic matches an existing `.squad/decisions/{topic}.md` thread (same agent area, same recurring theme, or explicit continuation), append the drop content there. Broaden the topic title only if the new content genuinely widens scope (do not narrow).
2. **Create new per-topic file?** -- If the drop introduces a new theme with no existing home (e.g., new policy, new skill seed, new recurring-incident class), create `.squad/decisions/{kebab-topic}.md` with the drop content plus a short header (By / Issue / Date).
3. **Delete stale drop?** -- If the drop's content is already folded into a per-topic file or agent history (verify by content scan, not filename), physically delete the drop without re-merging. Record the no-op in the fold-cycle session log.

## Atomic-rm model (CRITICAL)
The inbox `.squad/decisions/inbox/` is **gitignored** (`.gitignore:4`). `git rm` cannot stage tracked deletions of untracked files. Therefore:

- **Physical delete IS the atomic action.** Remove the source drop from the main-checkout filesystem in the SAME wall-clock action as the per-topic append commit.
- **Validation:** After fold, `Get-ChildItem .squad/decisions/inbox/` in the main checkout must NOT contain any drained filenames.
- **Anti-pattern:** Do NOT search for `git rm` of inbox files in commit history -- you will not find it, and the absence is not a bug.

## Dual-model coexistence
Two parallel decision stores live side-by-side -- BOTH are canonical:

- **`.squad/decisions/*.md`** (per-topic) -- canonical destination for inbox drains. Topic-scoped, append-as-you-go. This is where future archaeology for "what did we decide about X?" should look first.
- **`.squad/decisions.md`** (chronological journal) -- parallel reverse-chronological log. Still receives select retro / sprint-close summaries. Not the inbox-drain target.

Future Scribes: do NOT collapse the two stores. Both serve distinct lookup modes (topic vs. timeline).

## Applications
1. **PR #333 (Sprint 13 W1 fold)** -- 3 drops drained:
   - `mickey-w1-2026-05-17-issues-325-326.md` -> appended to `mickey-architecture-entry-point.md` (topic broadened)
   - `jiminy-w1-2026-05-17-issue-317-skill.md` -> appended to `doc-and-jiminy-automation.md` (hygiene-automation theme)
   - `scribe-w1-2026-05-17-history-archival.md` -> NEW `scribe-history-compression.md` (new theme)
2. **PR #336 (Sprint 13 W2 fold)** -- 3 drops drained:
   - `scribe-w1-fold-2026-05-17.md` -> appended to `scribe-history-compression.md` (continuation)
   - `mickey-w2-2026-05-17-hook-extension.md` -> NEW `mickey-hook-policy.md` (new theme)
   - `goofy-w2-2026-05-17-ascii-sweep.md` -> NEW `goofy-ascii-sweep.md` (skill seed)

## Forward-fix history
- **PR #323 (origin of atomic-rm forward-fix):** First inbox-drain implementation merged drop CONTENT but did NOT remove source drops -- caused next cycle to re-fold same content. Initial Scribe theory was "use `git rm`". WRONG: inbox is gitignored, so `git rm` was a misconception. Corrected forward-fix recorded in `scribe-history-compression.md`: physical delete IS the atomic action.
- **PR #333 + PR #336:** Forward-fix verified twice. Model stable.

## Validation
Per fold cycle, before close:
- `Get-ChildItem .squad/decisions/inbox/` should be empty (or contain only drops NOT being drained this cycle).
- Each appended per-topic file should have a dated header for the new content.
- Session log (`.squad/log/{timestamp}-*.md`) should enumerate routing decisions per drop.
