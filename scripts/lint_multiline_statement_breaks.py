"""Flag a top-level declaration that lands INSIDE an unclosed multi-line statement.

WHY THIS EXISTS (Sep 3 2026). This defect class bit twice in one sprint:

  1. `_refresh_find_ship_button()` was inserted into the middle of
     `func _update_travel_button_text(` PARAMETERS. Loud: it broke the next test
     run immediately, so it cost minutes.

  2. `CheatSheetPanel.gd` got a new `const ... = preload(...)` inserted between
     the two halves of an existing continuation:

         const CompendiumGridMovementRef = preload(
         const CheatSheetSectionsRef = preload(".../CheatSheetSections.gd")
             "res://src/data/compendium_grid_movement.gd")

     SILENT, and far worse. The file stopped parsing, so
     `TacticalBattleUI._instance_log_only_components()` failed on
     `_get_res("cheat_sheet").new()` and ABORTED `_setup_ui()` — the live battle
     screen stopped building partway through. Nothing caught it:
       * the panel's own suite reads it as TEXT via FileAccess, so it is blind to
         whether the file compiles (14 content cases stayed green);
       * `--headless --quit` only touches startup scripts;
       * a broken script is silent until something instantiates it.
     Only `test_tactical_battle_responsive.gd`, which instantiates the real
     scene, went red — and it had been dismissed as a "harness gap".

WHY A TEXT LINT RATHER THAN A PARSE CHECK. Parsing the tree with the engine was
tried first and does not work as a gate:
  * `load()` serves the resource CACHE and a parse-broken GDScript still returns
    a NON-NULL object, so a null check detects nothing (proven by revert);
  * `ResourceLoader.load(..., CACHE_MODE_IGNORE)` and `GDScript.reload()` both
    re-parse every dependency chain and did not finish 555 scripts in 10 minutes;
  * `godot --check-only -s <file>` works per file but does not register
    autoloads, so 14 of 60 changed scripts reported "Compile Error: Identifier
    not found: DiceManager" — false positives that drown the one real row. It
    also EXITS 0 when it reports a parse error.
This lint is pure text, runs in well under a second, and targets the exact shape.

THE RULE. While bracket depth is > 0, a line at column 0 beginning a new
top-level declaration is always a break: real continuation lines are indented.

Run: python scripts/lint_multiline_statement_breaks.py
Exits 0 when clean, 1 with one line per finding.
"""

import io
import os
import sys

ROOTS = ("src", "tests", "addons/TweenFX")

# A line at ZERO indentation starting with one of these begins a new top-level
# declaration, so it can never legitimately sit inside an open bracket.
TOP_LEVEL_STARTS = (
    "const ", "var ", "func ", "static func ", "signal ", "class_name ",
    "extends ", "enum ", "@onready ", "@export", "@tool", "class ",
)

OPENERS = "([{"
CLOSERS = ")]}"


def strip_noise(line, pending):
    """Remove comments and string literals so their brackets are not counted.

    `pending` carries an unterminated string across the line boundary and is
    either None, a triple quote, or a SINGLE quote character.

    ⚠ THE SINGLE-QUOTE CASE IS NOT AN EDGE CASE — it is a real construct in this
    codebase. Unlike Python, GDScript accepts a RAW NEWLINE inside a "..."
    string, and `tests/unit/test_persistent_injuries.gd:524` uses one
    deliberately to search for the next top-level function:

        var after: int = src.find("
        func ", start + 10)

    Verified against the engine: the file parses and its suite runs 25/25. An
    earlier version of this lint reset string state at every line break, so that
    unterminated quote left `src.find(` counted as open for the rest of the file
    and produced SEVEN false findings off one line. A lint that cries wolf on
    working code gets switched off, which is worse than not having it.
    """
    out = []
    i = 0
    n = len(line)
    quote = chr(34)
    apos = chr(39)
    backslash = chr(92)

    while i < n:
        ch = line[i]

        if pending:
            if len(pending) == 3:
                if line.startswith(pending, i):
                    i += 3
                    pending = None
                else:
                    i += 1
            else:
                if ch == backslash:
                    i += 2
                    continue
                if ch == pending:
                    pending = None
                i += 1
            continue

        # Block string start
        if line.startswith(quote * 3, i):
            pending = quote * 3
            i += 3
            continue
        if line.startswith(apos * 3, i):
            pending = apos * 3
            i += 3
            continue

        # Comment runs to end of line
        if ch == "#":
            break

        # String start; may or may not close on this line.
        if ch == quote or ch == apos:
            pending = ch
            i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out), pending


def check_file(path):
    findings = []
    try:
        text = io.open(path, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        return findings

    depth = 0
    opened_at = 0
    pending = None

    for idx, raw in enumerate(text.split(chr(10)), start=1):
        # State BEFORE this line is stripped. A line that begins INSIDE a string
        # is string content, not code, however much it looks like a declaration:
        # the second half of test_persistent_injuries.gd's raw-newline search is
        # literally `func ", start + 10)` at column 0.
        opened_in_string = pending is not None
        cleaned, pending = strip_noise(raw, pending)

        # A top-level declaration while a bracket is still open is the defect.
        if depth > 0 and not opened_in_string and raw[:1] not in (" ", chr(9), ""):
            stripped = raw.lstrip()
            for kw in TOP_LEVEL_STARTS:
                if stripped.startswith(kw):
                    findings.append(
                        "%s:%d: top-level '%s' inside a statement still open "
                        "from line %d" % (path, idx, kw.strip(), opened_at)
                    )
                    break

        for ch in cleaned:
            if ch in OPENERS:
                if depth == 0:
                    opened_at = idx
                depth += 1
            elif ch in CLOSERS:
                depth = max(0, depth - 1)

    return findings


def main():
    findings = []
    scanned = 0
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for name in filenames:
                if name.endswith(".gd"):
                    scanned += 1
                    findings.extend(
                        check_file(os.path.join(dirpath, name).replace(chr(92), "/"))
                    )

    for f in findings:
        print(f)
    print("lint_multiline_statement_breaks: %d scripts scanned, %d findings"
          % (scanned, len(findings)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
