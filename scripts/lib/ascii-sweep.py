"""ASCII sweep for repo Markdown files.

Replaces common non-ASCII characters (em/en dashes, smart quotes, arrows,
box-drawing glyphs, status emoji, etc.) with ASCII equivalents per the
dev-setup repo policy (Issue #322).

Content inside fenced code blocks (``` ... ```) is preserved verbatim so
that code examples remain literal.

Usage:
    python scripts/lib/ascii-sweep.py [--dry-run] [--root <path>]

By default the script scans the repo root the script lives in.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Per-character substitutions. Anything not listed is left untouched
# (and reported as a "remaining" hit at the end so a human can decide).
SUBS = {
    # Dashes
    "\u2014": "--",   # em dash
    "\u2013": "-",    # en dash
    "\u2212": "-",    # minus sign
    # Quotes
    "\u2018": "'",
    "\u2019": "'",
    "\u201A": "'",
    "\u201B": "'",
    "\u201C": '"',
    "\u201D": '"',
    "\u201E": '"',
    "\u2032": "'",
    "\u2033": '"',
    # Ellipsis / bullets
    "\u2026": "...",
    "\u2022": "*",
    "\u00B7": "*",
    # Arrows
    "\u2190": "<-",
    "\u2191": "^",
    "\u2192": "->",
    "\u2193": "v",
    "\u2194": "<->",
    "\u21D0": "<=",
    "\u21D2": "=>",
    "\u21D4": "<=>",
    # Math
    "\u2260": "!=",
    "\u2264": "<=",
    "\u2265": ">=",
    "\u00D7": "x",
    "\u00F7": "/",
    "\u00B1": "+/-",
    # Misc latin-1
    "\u00A0": " ",    # nbsp
    "\u00A7": "Sec.",
    "\u00A9": "(c)",
    "\u00AE": "(R)",
    "\u2122": "(TM)",
    # Checkmarks / crosses -> GFM task-list style
    "\u2713": "[x]",
    "\u2705": "[x]",
    "\u2717": "[ ]",
    "\u274C": "[ ]",
    # Warning / info / status glyphs
    "\u26A0": "!",
    "\u26A1": "!",
    "\u2139": "[i]",
    "\uFE0F": "",     # variation selector-16 (often follows emoji)
    # Circled digits
    "\u2460": "(1)",
    "\u2461": "(2)",
    "\u2462": "(3)",
    "\u2463": "(4)",
    "\u2464": "(5)",
    # Media controls
    "\u23ED": ">>|",
    "\u23EE": "|<<",
    # Squad status emoji
    "\U0001F534": "[RED]",
    "\U0001F7E0": "[ORANGE]",
    "\U0001F7E1": "[YELLOW]",
    "\U0001F7E2": "[GREEN]",
    "\U0001F535": "[BLUE]",
    "\U0001F7E3": "[PURPLE]",
    "\U0001F7E4": "[BROWN]",
    "\U000026AB": "[BLACK]",
    "\U000026AA": "[WHITE]",
    # Tooling emoji
    "\U0001F4CB": "[NOTE]",
    "\U0001F4CC": "[PIN]",
    "\U0001F4CA": "[CHART]",
    "\U0001F50D": "[SEARCH]",
    "\U0001F527": "[TOOL]",
    "\U0001F504": "[CYCLE]",
    "\U0001F4B0": "[COST]",
    "\U0001F389": "[CELEBRATE]",
    "\U0001F44B": "[WAVE]",
    "\U0001F916": "[BOT]",
    "\U0001F4E6": "[PKG]",
    "\U0001F6A8": "[!]",
    "\U0001F9EA": "[TEST]",
    "\U0001F3D7": "[BUILD]",
    "\U0001F464": "[USER]",
    "\U0001F4DD": "[MEMO]",
    "\U0001F512": "[LOCK]",
    "\u269B": "[ATOM]",
    "\u2699": "[GEAR]",
    "\u2B50": "*",
}


def _map_box(ch: str) -> str | None:
    """Map U+2500..U+257F box-drawing chars to ASCII."""
    cp = ord(ch)
    if not (0x2500 <= cp <= 0x257F):
        return None
    # Heavy/light horizontal lines
    if cp in (0x2500, 0x2504, 0x2508, 0x254C):
        return "-"
    if cp in (0x2501, 0x2505, 0x2509, 0x254D, 0x2550):
        return "="
    # Vertical lines
    if cp in (0x2502, 0x2506, 0x250A, 0x254E, 0x2503, 0x2507, 0x250B, 0x254F, 0x2551):
        return "|"
    # Corners / tees / crosses -> "+"
    return "+"


def transform_line(line: str, remaining: dict) -> str:
    out = []
    for ch in line:
        if ord(ch) < 128:
            out.append(ch)
            continue
        if ch in SUBS:
            out.append(SUBS[ch])
            continue
        box = _map_box(ch)
        if box is not None:
            out.append(box)
            continue
        # Unknown non-ASCII: leave it but record for reporting
        remaining[ch] = remaining.get(ch, 0) + 1
        out.append(ch)
    return "".join(out)


def sweep_text(text: str, remaining: dict) -> tuple[str, int]:
    """Sweep a markdown document, preserving fenced code blocks."""
    lines = text.split("\n")
    in_fence = False
    changes = 0
    new_lines = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            new_lines.append(line)
            continue
        if in_fence:
            new_lines.append(line)
            continue
        new = transform_line(line, remaining)
        if new != line:
            changes += sum(1 for c in line if ord(c) > 127) - sum(
                1 for c in new if ord(c) > 127
            )
        new_lines.append(new)
    return "\n".join(new_lines), changes


EXCLUDE_PARTS = {".git", "node_modules", ".copilot"}


def iter_markdown(root: Path):
    for p in root.rglob("*.md"):
        if any(part in EXCLUDE_PARTS for part in p.parts):
            continue
        yield p


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    total_files = 0
    edited_files = 0
    total_replaced = 0
    remaining: dict[str, int] = {}
    per_file = []

    for path in iter_markdown(root):
        total_files += 1
        original = path.read_text(encoding="utf-8")
        new_text, replaced = sweep_text(original, remaining)
        if new_text != original:
            edited_files += 1
            total_replaced += replaced
            per_file.append((replaced, path.relative_to(root)))
            if not args.dry_run:
                with path.open("w", encoding="utf-8", newline="\n") as fh:
                    fh.write(new_text)

    per_file.sort(reverse=True)
    print(f"Scanned: {total_files} .md files")
    print(f"Edited:  {edited_files}")
    print(f"Replaced: {total_replaced} non-ASCII chars")
    if remaining:
        print("Remaining non-ASCII (no mapping; left intact):")
        for ch, n in sorted(remaining.items(), key=lambda kv: -kv[1]):
            print(f"  U+{ord(ch):04X}  x {n}")
    print()
    print("Top files by hits:")
    for n, rel in per_file[:20]:
        print(f"  {n:5d}  {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
