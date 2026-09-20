#!/usr/bin/env python
"""Validate that every file/line citation in an audit document actually resolves.

WHY THIS EXISTS
---------------
`docs/QA_RULES_ACCURACY_AUDIT.md` section C4 recorded nineteen Bug Hunt rows as
"VERIFIED (2026-03-30)". Its first row cited `src/core/systems/BugHuntEnemyGenerator.gd`
-- a file that has never existed in this repository -- and another asserted a
`ContactMarkerPanel` that had been deleted. Nothing checked, so a green audit that
measured nothing stood for six months and was cited as coverage.

An audit's whole value is that a reader can re-derive its findings. A citation that
does not resolve is worse than no citation: it reads as evidence and costs the next
reader real time before they discover the file is not there.

This lint is the cheap mechanical half of that guarantee. It cannot tell you a
finding is TRUE -- only that the thing it points at exists. That is exactly the
check C4 needed and did not have.

WHAT IT CHECKS
--------------
For every citation of the form `path/to/file.ext:NNN` (or a bare `File.ext:NNN`)
appearing inside a markdown inline-code span or a markdown link:

  * the file exists, and
  * it has at least NNN lines.

A bare basename is resolved by searching the repo. An ambiguous basename (several
files share it) is reported as UNRESOLVED rather than failed -- flagging it without
guessing which one the author meant.

Citations without a line number are existence-checked only.

THE `[[missing]]` MARKER
------------------------
An audit sometimes has to cite a file precisely BECAUSE it does not exist -- this
very document cites `BugHuntEnemyGenerator.gd` to explain what C4 got wrong. Put
`[[missing]]` anywhere on that line and the check INVERTS: the citation must NOT
resolve, and the lint fails if the file turns up.

That inversion is deliberate. A marker that merely silenced the check could be
pasted over a typo and hide it forever; one that asserts absence stays honest, and
starts failing the day someone creates a file with that name.

USAGE
-----
    py scripts/lint_audit_citations.py                      # every docs/audits/*.md
    py scripts/lint_audit_citations.py docs/audits/X.md     # specific files

Exit 0 = every citation resolves. Exit 1 = at least one hard failure.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directories that are not project source. `.mcp/` in particular vendors ~2,800
# unrelated GDScript files whose basenames would mask or fake a resolution -- the
# same trap documented for lint_dead_has_method_guards.py.
_NON_PROJECT = {".git", ".godot", ".mcp", "node_modules", "android", "ios", "build"}

# Extensions worth treating as a citable project file.
_CITABLE = {
    ".gd", ".tscn", ".tres", ".json", ".py", ".md", ".cfg", ".txt", ".godot", ".import",
}

# A citation inside an inline-code span: `src/foo/Bar.gd:123`, `Bar.gd:123`, `data/x.json`
_CODE_SPAN = re.compile(r"`([^`\n]+)`")
# A citation inside a markdown link target: [Bar.gd:123](src/foo/Bar.gd#L123)
_LINK_TARGET = re.compile(r"\]\(([^)\s#]+)(?:#L(\d+))?\)")

# path[:line] -- the path part must look like a filename with a known extension.
_CITATION = re.compile(
    r"^(?P<path>[A-Za-z0-9_./\\-]+\.(?:" + "|".join(e[1:] for e in sorted(_CITABLE)) + r"))"
    r"(?::(?P<line>\d+))?$"
)


def _iter_project_files() -> list[Path]:
    out: list[Path] = []
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.suffix not in _CITABLE:
            continue
        if any(part in _NON_PROJECT for part in p.relative_to(ROOT).parts):
            continue
        out.append(p)
    return out


def _line_count(path: Path) -> int:
    # Audits cite line numbers as a reader would see them, so count physical lines.
    # errors="replace" keeps a stray byte in a data file from failing the lint for
    # the wrong reason.
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        return sum(1 for _ in fh)


def _collect_citations(doc: Path) -> list[tuple[int, str, int | None, bool]]:
    """Return (doc_line_no, cited_path, cited_line_or_None, expect_missing)."""
    found: list[tuple[int, str, int | None, bool]] = []
    for lineno, text in enumerate(doc.read_text(encoding="utf-8").splitlines(), 1):
        expect_missing = "[[missing]]" in text
        candidates = [(m.group(1).strip(), None) for m in _CODE_SPAN.finditer(text)]
        for m in _LINK_TARGET.finditer(text):
            candidates.append((m.group(1).strip(), int(m.group(2)) if m.group(2) else None))

        for raw, link_line in candidates:
            hit = _CITATION.match(raw.replace("\\", "/"))
            if not hit:
                continue
            cited_line = link_line if link_line is not None else (
                int(hit.group("line")) if hit.group("line") else None
            )
            found.append((lineno, hit.group("path"), cited_line, expect_missing))
    return found


def check(doc: Path, by_name: dict[str, list[Path]]) -> tuple[int, int, int]:
    """Returns (ok, failed, unresolved)."""
    ok = failed = unresolved = 0

    for doc_line, cited, cited_line, expect_missing in _collect_citations(doc):
        direct = ROOT / cited
        resolved = direct.is_file() or len(by_name.get(Path(cited).name, [])) >= 1

        if expect_missing:
            # Inverted: the finding IS that this file does not exist.
            if resolved:
                print(f"  FAIL  {doc.name}:{doc_line}  ->  {cited}"
                      f"  (marked [[missing]] but the file EXISTS -- stale marker?)")
                failed += 1
            else:
                ok += 1
            continue

        if direct.is_file():
            target = direct
        else:
            matches = by_name.get(Path(cited).name, [])
            if len(matches) == 1:
                target = matches[0]
            elif not matches:
                print(f"  FAIL  {doc.name}:{doc_line}  ->  {cited}"
                      f"  (no such file anywhere in the repo)")
                failed += 1
                continue
            else:
                # Several files share the basename. Not a failure -- we cannot know
                # which the author meant -- but the author should disambiguate.
                print(f"  ????  {doc.name}:{doc_line}  ->  {cited}"
                      f"  (ambiguous: {len(matches)} files share this name)")
                unresolved += 1
                continue

        if cited_line is not None:
            n = _line_count(target)
            if cited_line > n:
                rel = target.relative_to(ROOT).as_posix()
                print(f"  FAIL  {doc.name}:{doc_line}  ->  {rel}:{cited_line}"
                      f"  (file has only {n} lines)")
                failed += 1
                continue

        ok += 1

    return ok, failed, unresolved


def main(argv: list[str]) -> int:
    if argv:
        docs = [Path(a) if Path(a).is_absolute() else ROOT / a for a in argv]
    else:
        docs = sorted((ROOT / "docs" / "audits").glob("*.md"))

    docs = [d for d in docs if d.is_file()]
    if not docs:
        print("No audit documents found.")
        return 0

    project_files = _iter_project_files()
    by_name: dict[str, list[Path]] = {}
    for p in project_files:
        by_name.setdefault(p.name, []).append(p)

    total_ok = total_failed = total_unresolved = 0
    for doc in docs:
        print(f"\n{doc.relative_to(ROOT).as_posix()}")
        ok, failed, unresolved = check(doc, by_name)
        if not failed and not unresolved:
            print(f"  all {ok} citations resolve")
        total_ok += ok
        total_failed += failed
        total_unresolved += unresolved

    print(f"\nindexed={len(project_files)} ok={total_ok} "
          f"failed={total_failed} unresolved={total_unresolved}")
    return 1 if total_failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
