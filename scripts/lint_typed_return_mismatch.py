#!/usr/bin/env python3
"""Flag GDScript functions that declare a TYPED container return but return an
untyped one.

Why this needs a lint at all
----------------------------
Godot 4 accepts

    func f() -> Array[Dictionary]:
        var out: Array = []
        return out

at PARSE time and fails at RUNTIME with

    Trying to return an array of type "Array" where expected return type is
    "Array[Dictionary]".

That error ABORTS the function and lets the process keep running, so the caller
silently receives nothing and whatever it was building never appears. No crash,
no dialog, nothing in a headless parse check, and `--headless --quit` is blind to
it because the function is never called.

Found on the tablet 2026-08-08: submitting a battle result tore down the battle
screen and the 14-step post-battle sequence simply never appeared.
`PostBattleSequence._get_current_crew()` had been widened in the BODY (crew are
Resources on a fresh campaign and Dictionaries on a loaded save) while the
SIGNATURE kept `Array[Resource]`. Widening a container's element type is only
half the change; the signature is the other half.

Two directions of fix, and the choice is not arbitrary:
  * if the body legitimately holds mixed types, widen the SIGNATURE to `Array`
  * if callers assign into a typed variable, narrow the BODY instead

Usage:  py scripts/lint_typed_return_mismatch.py
Exit 0 when clean, 1 when any mismatch is found.
"""

from __future__ import annotations

import pathlib
import re
import sys

SIG = re.compile(
    r"^\s*(?:static\s+)?func\s+(\w+)\s*\(.*?\)\s*->\s*"
    r"(Array\[[^\]]+\]|Dictionary\[[^\]]+\])\s*:"
)
DECL = re.compile(r"^\s*var\s+(\w+)\s*:\s*(Array|Dictionary)\s*=")
RET = re.compile(r"^\s*return\s+(\w+)\s*$")
FUNC_START = re.compile(r"^(func |class |static func )")

ROOTS = ("src", "tests")


def scan(root: pathlib.Path) -> list[tuple[str, int, str, str, str, str]]:
    hits: list[tuple[str, int, str, str, str, str]] = []
    for path in sorted(root.rglob("*.gd")):
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
        i = 0
        while i < len(lines):
            m = SIG.match(lines[i])
            if not m:
                i += 1
                continue
            fname, rtype = m.group(1), m.group(2)
            bare: dict[str, str] = {}
            j = i + 1
            while j < len(lines) and not FUNC_START.match(lines[j]):
                d = DECL.match(lines[j])
                if d:
                    bare[d.group(1)] = d.group(2)
                r = RET.match(lines[j])
                if r and r.group(1) in bare:
                    hits.append(
                        (
                            path.as_posix(),
                            j + 1,
                            fname,
                            rtype,
                            r.group(1),
                            bare[r.group(1)],
                        )
                    )
                j += 1
            i = j
    return hits


def main() -> int:
    base = pathlib.Path(__file__).resolve().parent.parent
    hits: list[tuple[str, int, str, str, str, str]] = []
    for root_name in ROOTS:
        root = base / root_name
        if root.is_dir():
            hits.extend(scan(root))

    if not hits:
        print("lint_typed_return_mismatch: CLEAN (0 findings)")
        return 0

    print("lint_typed_return_mismatch: %d finding(s)\n" % len(hits))
    for path, line, fname, rtype, var, vtype in hits:
        print("%s:%d" % (path, line))
        print("    func %s() -> %s" % (fname, rtype))
        print("    returns `var %s: %s` — untyped, aborts at runtime" % (var, vtype))
        print(
            "    fix: widen the signature to `%s` if the body is genuinely mixed,\n"
            "         otherwise narrow the body to `%s`" % (vtype, rtype)
        )
        print()
    return 1


if __name__ == "__main__":
    sys.exit(main())
