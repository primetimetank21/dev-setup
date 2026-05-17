---
name: "ascii-docs-about-non-ascii"
description: "When documenting non-ASCII chars, reference by Unicode codepoint name only -- never include the literal char. Avoids the meta-trap of docs failing the very ASCII hook they describe."
domain: "documentation-discipline"
confidence: "medium"
source: "earned (Sprint 14 #340, Sprint 15 #356/#359 -- 2 independent applications)"
---

## Context

The repository pre-commit hook (hooks/pre-commit, Check 2) rejects any staged
`.md`, `.ps1`, or `.sh` file containing bytes above 0x7F. This is correct and
intentional -- it keeps all committed text portable and toolchain-safe.

The meta-trap arises when an agent writes documentation *about* non-ASCII
characters. The natural impulse is to include the literal character "for
clarity" (e.g., writing the actual em-dash character next to its codepoint
name so the reader can see what it looks like). This makes the doc itself
fail the hook it is meant to describe.

This pattern appeared in two independent incidents:

- **Sprint 14 #340** -- Doc audit notes included literal arrow characters
  next to their codepoint labels. Commit failed; Coordinator recovery required.
- **Sprint 15 #356/#359** -- The decision file documenting the ASCII sweep
  methodology included a mapping table with literal em-dash, right-arrow, and
  box-drawing characters in the "before" column -- the very characters being
  documented. Same failure, same recovery cost.

Two independent applications at different sprint cadences satisfies the medium
confidence threshold per the confidence lifecycle rules.

## Patterns

### Reference rule

When writing any documentation that names or describes a non-ASCII character,
use ONLY the Unicode codepoint name. Never include the literal character
anywhere in the committed file -- not in prose, not in parens, not in a code
fence, not in a markdown table cell.

**Correct forms:**
- `em-dash U+2014`
- `right-arrow U+2192`
- `smart-quote-left U+2018`
- `box-drawing-horizontal U+2500`

**Incorrect forms (these all introduce non-ASCII bytes):**
- Writing the actual em-dash character inline
- Writing the codepoint name followed by the literal character in parens
- Placing the literal character inside a code fence "to show the raw form"
- Putting the literal character in a markdown table "before/after" column

### ASCII substitution mapping table

Use this table when converting non-ASCII to ASCII-safe text:

| Codepoint name              | Codepoint | ASCII substitute |
|-----------------------------|-----------|------------------|
| em-dash                     | U+2014    | --               |
| en-dash                     | U+2013    | -                |
| left-single-quote           | U+2018    | '                |
| right-single-quote          | U+2019    | '                |
| left-double-quote           | U+201C    | "                |
| right-double-quote          | U+201D    | "                |
| ellipsis                    | U+2026    | ...              |
| right-arrow                 | U+2192    | ->               |
| box-drawing-horizontal      | U+2500    | -                |
| box-drawing-vertical        | U+2502    | \|               |
| box-drawing-tee-right       | U+251C    | \|--             |
| box-drawing-corner-up-right | U+2514    | `--              |
| non-breaking-space          | U+00A0    | (regular space)  |

### Pre-commit verification

Before committing any documentation file, verify the non-ASCII byte count:

```
python -c "from pathlib import Path; print(f'non-ASCII bytes: {sum(1 for b in Path(\"<file>\").read_bytes() if b > 127)}')"
```

The output MUST read `non-ASCII bytes: 0`. If it does not, find and replace
each offending byte using the mapping table above. Do not commit until the
count is zero.

Do NOT rely on "the diff looks fine" -- terminal renderers and editors can
silently normalize or hide non-ASCII characters while the underlying bytes
remain.

### Code-fenced blocks are not exempt

Some agents assume that a code fence preserves raw bytes without triggering
the hook. This is false -- the hook scans the full file content, not just
prose lines. A non-ASCII character inside a triple-backtick block will fail
identically to one in a paragraph.

## Examples

### Correct: documenting the sweep methodology

```
The Sprint 15 ASCII sweep converted the following characters:
- em-dash U+2014 -> -- (double hyphen)
- right-arrow U+2192 -> -> (hyphen + greater-than)
- box-drawing-horizontal U+2500 -> - (single hyphen)
```

No literal characters appear. Codepoint names carry all the meaning a reader
needs, and the substitution column shows the ASCII form.

### Correct: referencing a character in a decision record

```
Hook Check 2 catches characters including em-dash U+2014 and smart-quote
U+2018/U+2019. Run the sweep script (scripts/ascii-sweep.py) to replace
these before staging.
```

### Incorrect: including literal characters for "clarity"

The following pattern introduces non-ASCII bytes and will fail the hook.
Do not do this -- it is shown here only as a description, not as actual chars.

The mistake is: writing the Unicode codepoint name and then the actual
character immediately after, believing the reader benefits from seeing the
visual form. The visual form is irrelevant in committed text; the codepoint
name and ASCII substitute are sufficient.

## Anti-patterns

- Including the literal character "for clarity" -- it is never necessary;
  the codepoint name fully identifies the character for any reader.
- Placing a literal character inside a code fence assuming the fence
  provides an exemption from the ASCII hook -- it does not.
- Writing a mapping table with a "raw char" column -- the column itself
  introduces the bytes you are documenting as problematic.
- Trusting that the diff looks clean in your terminal -- always verify with
  the python byte-count command before committing.
- Reporting commit success without running the verification command --
  the hook can fail silently in some agent execution environments, leaving
  the commit un-made while the agent reports success.

## Related skills

- `.copilot/skills/secret-handling/SKILL.md` -- analogous discipline:
  do not include the sensitive material itself in committed text; reference
  it by name or placeholder only.
- `.copilot/skills/docs-standards/SKILL.md` -- parent documentation
  conventions; this skill extends them for the ASCII-safety constraint.
- `scripts/ascii-sweep.py` -- automated sweep tool; run before staging
  any file that may have been edited in an environment that introduces
  smart quotes or typographic dashes.
- `hooks/pre-commit` Check 2 -- the enforcement gate; understanding this
  skill prevents hook rejections at commit time.
