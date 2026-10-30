#!/usr/bin/env python3
"""Journal vocabulary lint - every create_entry() type/tag/mood must be canonical.

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

MOOD - the third vocabulary, added 2026-09-06 (T11-44)
------------------------------------------------------
This lint shipped covering `type` and `tags` and contained ZERO references to
`mood`, so it reported CLEAN for a month while EIGHT producer sites wrote five
spellings that are not in the vocabulary - `positive`, `negative`, `informative`,
`discovery`, `bittersweet`. Every one fell through MOOD_STRING_TO_ENUM to
Mood.NEUTRAL, so those entries rendered with the wrong label AND the wrong colour.
It was found on a tablet only because the warning happened to survive in
`godot.log`; the very defect class this lint exists to end, in the one field it
did not look at. If you add a fourth journal vocabulary, add it here in the same
commit.

Validated against MOOD_STRING_TO_ENUM only - deliberately NOT against
MOOD_LEGACY_ALIASES, which exists so entries already written into save files still
render correctly. Old data is tolerated at runtime; new code is not.

KEYS - the fourth check, added 2026-10-30 (Sprint 7b)
-----------------------------------------------------
create_entry() rebuilds every entry from a FIXED key literal and drops every other
key. Three producers passed their text as `content`, so those entries had an empty
body; ten passed `turn`, which never reached the entry (the chokepoint derives the
turn). Every top-level key of a dict literal handed to create_entry() must be one the
chokepoint reads, and that set is parsed out of create_entry() itself so the lint
cannot drift from it. Nested dicts (`stats`) are not checked: their keys are the
entry's own data. Measured on introduction: 90 literal calls, 13 dropped keys, no
false hits.

Exit 0 clean, 1 on any finding. Add `# lint:ignore` on the offending line for a
deliberate exception.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPES_FILE = ROOT / "src" / "core" / "campaign" / "JournalEntryTypes.gd"
JOURNAL_FILE = ROOT / "src" / "core" / "campaign" / "CampaignJournal.gd"
SRC = ROOT / "src"

# How far past a create_entry( call the dict literal may run.
LOOKAHEAD = 24


def canonical_sets():
    text = TYPES_FILE.read_text(encoding="utf-8")
    m = re.search(r"const STRING_TO_TYPE[^{]*\{(.*?)\n\}", text, re.S)
    m2 = re.search(r"const TAGS[^{]*\{(.*?)\n\}", text, re.S)
    # MOOD_STRING_TO_ENUM only. MOOD_LEGACY_ALIASES is for data already on disk.
    m3 = re.search(r"const MOOD_STRING_TO_ENUM[^{]*\{(.*?)\n\}", text, re.S)
    if not m or not m2 or not m3:
        print("lint_journal_vocabulary: could not parse JournalEntryTypes.gd", file=sys.stderr)
        sys.exit(2)
    return (
        set(re.findall(r'"([a-z_]+)"\s*:', m.group(1))),
        set(re.findall(r'"([a-z_]+)"\s*:', m2.group(1))),
        set(re.findall(r'"([a-z_]+)"\s*:', m3.group(1))),
    )


def kept_keys():
    """The keys CampaignJournal.create_entry() reads from its argument."""
    text = JOURNAL_FILE.read_text(encoding="utf-8")
    m = re.search(r"\nfunc create_entry\(.*?(?=\nfunc )", text, re.S)
    keys = set(re.findall(r'data\.get\("([a-z_]+)"', m.group(0))) if m else set()
    if not keys:
        print("lint_journal_vocabulary: could not parse create_entry()", file=sys.stderr)
        sys.exit(2)
    return keys


def top_level_keys(text, start):
    """(key, line index) for each key at depth 1 of the dict literal at text[start]."""
    depth = 0
    i = start
    keys = []
    while i < len(text):
        c = text[i]
        if c == '"':
            j = i + 1
            while j < len(text) and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            k = j + 1
            while k < len(text) and text[k] in " \t":
                k += 1
            if depth == 1 and k < len(text) and text[k] == ":":
                keys.append((text[i + 1:j], text.count("\n", 0, i)))
            i = j + 1
            continue
        if c == "#":
            i = text.find("\n", i)
            if i == -1:
                break
            continue
        if c in "{[(":
            depth += 1
        elif c in "}])":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return keys


def main():
    types, tags, moods = canonical_sets()
    kept = kept_keys()
    findings = []

    for path in sorted(SRC.rglob("*.gd")):
        if path.name == "JournalEntryTypes.gd":
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
        full = "\n".join(lines)
        for call in re.finditer(r"create_entry\(\s*", full):
            if full[call.end():call.end() + 1] != "{":
                continue
            for key, at in top_level_keys(full, call.end()):
                if key in kept or "lint:ignore" in lines[at]:
                    continue
                findings.append(
                    f"{path.relative_to(ROOT).as_posix()}:{at + 1}  journal key '{key}'"
                    f" is dropped by create_entry() (it keeps: {', '.join(sorted(kept))})")
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

            # ⚠ Take the rest of the LINE, not just the next literal: one live site
            # writes a ternary - `"mood": "positive" if found else "negative"` - and a
            # single-literal match would have validated the true arm and silently
            # skipped the false one. Both arms were wrong there.
            # ⚠ But strip CALL ARGUMENTS first. Another live site reads its
            # condition from a dict -
            #   "mood": "somber" if d.get("detected", false) else "neutral"
            # - and a naive sweep of the line reports the KEY "detected" as a bad
            # mood. Both real arms there are canonical, so that is a pure false
            # positive, and this lint's own docstring is about why a noisy lint gets
            # disabled. Only parens attached to an identifier or subscript are
            # removed, so a deliberate grouping - ("triumph" if x else "defeat") -
            # is still checked.
            for mm in re.finditer(r'"mood"\s*:\s*([^\n]*)', block):
                off = block[:mm.start()].count("\n")
                if "lint:ignore" in block_lines[off]:
                    continue
                expr = mm.group(1)
                while True:
                    stripped = re.sub(r'(?<=[\w\]])\([^()]*\)', '', expr)
                    if stripped == expr:
                        break
                    expr = stripped
                for mood in re.findall(r'"([a-z_]+)"', expr):
                    if mood not in moods:
                        findings.append(
                            f"{rel}:{i + 1 + off}  non-canonical journal mood '{mood}'"
                            f"  (falls to NEUTRAL; wrong label AND wrong colour)")

            for mm in re.finditer(r'"tags"\s*:\s*\[([^\]]*)\]', block):
                off = block[:mm.start()].count("\n")
                if "lint:ignore" in block_lines[off]:
                    continue
                for tag in re.findall(r'"([a-z_]+)"', mm.group(1)):
                    if tag not in tags:
                        findings.append(
                            f"{rel}:{i + 1 + off}  non-canonical journal tag '{tag}'"
                            f"  (renders unlabelled and uncoloured)")

    # Two create_entry( calls within LOOKAHEAD lines of each other scan OVERLAPPING
    # blocks, so one offending line can be reported twice. file:line makes identical
    # strings the same finding, so a set is safe and the count stays honest.
    findings = sorted(set(findings))
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
