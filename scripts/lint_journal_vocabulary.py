#!/usr/bin/env python3
"""Journal vocabulary lint - every create_entry() type/tag must be canonical.

WHY THIS EXISTS
---------------
JournalEntryTypes.validate_entry() push_warning()s on a non-canonical `type` or
`tag` but never rejects the entry, by design (producers predate the taxonomy). The
cost of that leniency is that a typo is invisible at runtime except as log noise -
and the log is where genuine warnings are supposed to be visible.

It was NOT just noise. A non-canonical type falls to EntryType.CUSTOM, so the entry
loses its colour and drops out of any type-filtered view of the journal; a
non-canonical tag renders as an unlabelled, uncoloured chip.

The Aug 8 2026 tablet sprint filed this as W2-08 with TWO sites. Running the app for
one turn surfaced a third ('travel') that no code review had found, because the
warning only appears when that exact branch executes. A proper sweep then found 17
type uses and 27 tag uses across 29 sites. This lint is the answer to "how do we
stop finding these one campaign turn at a time".

SCOPE - and why the obvious grep is WRONG
-----------------------------------------
The first attempt matched `"type": "..."` anywhere in src/ and reported ~200 hits.
Almost all were false: weapon types, terrain types, mission types, world types,
enemy types - unrelated taxonomies that happen to use the same key name. Only dicts
actually passed to a journal create_entry() call are in scope, which is what this
checks. A lint that cries wolf 200 times gets disabled, so the narrowing matters
more than the catching.

Exit 0 clean, 1 on any finding. Add `# lint:ignore` on the offending line for a
deliberate exception.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPES_FILE = ROOT / "src" / "core" / "campaign" / "JournalEntryTypes.gd"
SRC = ROOT / "src"

# How far past a create_entry( call the dict literal may run.
LOOKAHEAD = 24


def canonical_sets():
    text = TYPES_FILE.read_text(encoding="utf-8")
    m = re.search(r"const STRING_TO_TYPE[^{]*\{(.*?)\n\}", text, re.S)
    m2 = re.search(r"const TAGS[^{]*\{(.*?)\n\}", text, re.S)
    if not m or not m2:
        print("lint_journal_vocabulary: could not parse JournalEntryTypes.gd", file=sys.stderr)
        sys.exit(2)
    return (
        set(re.findall(r'"([a-z_]+)"\s*:', m.group(1))),
        set(re.findall(r'"([a-z_]+)"\s*:', m2.group(1))),
    )


def main():
    types, tags = canonical_sets()
    findings = []

    for path in sorted(SRC.rglob("*.gd")):
        if path.name == "JournalEntryTypes.gd":
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
        for i, line in enumerate(lines):
            if "create_entry(" not in line:
                continue
            block_lines = lines[i:i + LOOKAHEAD]
            block = "\n".join(block_lines)
            end = block.find("})")
            if end != -1:
                block = block[:end + 2]
            rel = path.relative_to(ROOT).as_posix()

            for mm in re.finditer(r'"type"\s*:\s*"([a-z_]+)"', block):
                if mm.group(1) in types:
                    continue
                off = block[:mm.start()].count("\n")
                if "lint:ignore" in block_lines[off]:
                    continue
                findings.append(
                    f"{rel}:{i + 1 + off}  non-canonical journal type '{mm.group(1)}'"
                    f"  (falls to CUSTOM; drops out of type-filtered views)")

            for mm in re.finditer(r'"tags"\s*:\s*\[([^\]]*)\]', block):
                off = block[:mm.start()].count("\n")
                if "lint:ignore" in block_lines[off]:
                    continue
                for tag in re.findall(r'"([a-z_]+)"', mm.group(1)):
                    if tag not in tags:
                        findings.append(
                            f"{rel}:{i + 1 + off}  non-canonical journal tag '{tag}'"
                            f"  (renders unlabelled and uncoloured)")

    if findings:
        print(f"lint_journal_vocabulary: {len(findings)} finding(s)\n")
        for f in findings:
            print("  " + f)
        print(
            "\nFix by mapping to an existing name, or - if the concept is genuinely new"
            "\nand book-grounded - add it to JournalEntryTypes. Do NOT tag a runtime"
            "\nvalue (an item id, a character name): a tag is a fixed vocabulary."
        )
        return 1

    print("lint_journal_vocabulary: CLEAN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
