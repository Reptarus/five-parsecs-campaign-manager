#!/usr/bin/env python
"""Reachability lint for src/ scripts and scenes.

WHY A GRAPH AND NOT A GREP
--------------------------
A one-pass "is this script referenced anywhere?" scan gives the wrong answer,
because a DEAD scene keeps its script alive. Found in the Jul 30 sweep:
src/ui/screens/campaign/MainCampaignScene.tscn is referenced by nothing at all,
yet its ext_resource kept MainCampaignScene.gd looking live. Deleting only the
script pass's findings would have left both, and iterating the two passes by hand
is error-prone. So this walks the real reference graph from real entry points and
reports everything unreachable, in one shot.

ENTRY POINTS (roots)
--------------------
  * project.godot  run/main_scene  and every [autoload] script
  * anything referenced from tests/  (a test-only file is production-dead but
    deleting it silently breaks the suite, so it is reported separately)

EDGES
-----
  * a "res://....gd|tscn|tres" literal inside any .gd
  * path="res://..." in a .tscn/.tres ext_resource
    (verified: every Script ext_resource in this repo carries a path, so there
     are no uid-only references to miss)
  * class_name usage: file A mentions class B declared by file B, word-bounded.
    Word boundaries matter — "CampaignManager" is a substring of
    "CampaignPhaseManager" and "MissionGenerator" of "StealthMissionGenerator",
    and a substring match reports both as live. Same trap as the replace_all
    rule in CLAUDE.md.

NOT AN EDGE
-----------
Runtime-composed paths. Verified for this repo: every dynamic load() takes a
DATA path (texture, portrait, pooled scene), never a script name built from
parts. If that changes, this lint goes stale — add the case here.

Usage:  python scripts/lint_orphan_assets.py [--list]
Exit 1 if any unreachable file is found.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TESTS = ROOT / "tests"

# Standalone entry points: launched directly by path, so nothing in the repo
# references them and the graph cannot see them. Each entry needs a DOCUMENTED
# launch command — "it looks like a dev tool" is not enough. DeveloperQuickStart
# was rejected from this list: the strategy doc shows it being preloaded from a
# .tscn that does not exist, i.e. an integration that was proposed and never built.
ALLOWLIST = {
    # docs/sop/narrative-scene-authoring.md:252 and CLAUDE.md:421 both give the
    # exact command:  <godot> --path <proj> res://src/ui/screens/dev/SceneViewer.tscn
    #                 -- scene_id=story_event_01 test_crew=... autoshot
    "src/ui/screens/dev/SceneViewer.tscn",
    "src/ui/screens/dev/SceneViewer.gd",
}

RES_LITERAL = re.compile(r'res://([^"\'\s]+?\.(?:gd|tscn|tres))')
CLASS_NAME = re.compile(r'^\s*class_name\s+([A-Za-z_][A-Za-z_0-9]*)', re.M)
AUTOLOAD_LINE = re.compile(r'^\s*[A-Za-z_][A-Za-z_0-9]*\s*=\s*"\*?(res://[^"]+)"', re.M)
MAIN_SCENE = re.compile(r'^run/main_scene\s*=\s*"(res://[^"]+)"', re.M)


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def read(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def collect(base: Path, exts) -> list[Path]:
    out = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in (".godot", ".import", "addons")]
        for fn in filenames:
            if fn.rsplit(".", 1)[-1] in exts:
                out.append(Path(dirpath) / fn)
    return out


def main() -> int:
    show_list = "--list" in sys.argv

    files = collect(SRC, {"gd", "tscn", "tres"})
    by_path = {rel(p): p for p in files}
    text = {rel(p): read(p) for p in files}

    # class_name -> owning file
    owner: dict[str, str] = {}
    for k, t in text.items():
        if k.endswith(".gd"):
            m = CLASS_NAME.search(t)
            if m:
                owner[m.group(1)] = k

    # Pre-compile one word-bounded matcher per class_name (fast enough at this size).
    cls_re = {c: re.compile(r'\b%s\b' % re.escape(c)) for c in owner}

    def edges_from(key: str) -> set[str]:
        t = text.get(key, "")
        out: set[str] = set()
        for m in RES_LITERAL.finditer(t):
            tgt = m.group(1)
            if tgt in by_path:
                out.add(tgt)
        for c, ck in cls_re.items():
            tgt = owner[c]
            if tgt != key and ck.search(t):
                out.add(tgt)
        return out

    # ---- roots -------------------------------------------------------------
    proj = read(ROOT / "project.godot")
    roots: set[str] = set()
    ms = MAIN_SCENE.search(proj)
    if ms:
        p = ms.group(1)[len("res://"):]
        if p in by_path:
            roots.add(p)
    autoload_block = proj.split("[autoload]", 1)[-1].split("\n[", 1)[0] if "[autoload]" in proj else ""
    for m in AUTOLOAD_LINE.finditer(autoload_block):
        p = m.group(1)[len("res://"):]
        if p in by_path:
            roots.add(p)
    for p in ALLOWLIST:
        if p in by_path:
            roots.add(p)
        else:
            print(f"WARNING: allowlist entry no longer exists, drop it: {p}")

    # Anything the test suite touches, by path or by class_name.
    test_text = "\n".join(read(p) for p in collect(TESTS, {"gd", "tscn", "tres"}))
    test_roots: set[str] = set()
    for m in RES_LITERAL.finditer(test_text):
        if m.group(1) in by_path:
            test_roots.add(m.group(1))
    for c, ck in cls_re.items():
        if ck.search(test_text):
            test_roots.add(owner[c])

    # ---- reachability ------------------------------------------------------
    def reach(seed: set[str]) -> set[str]:
        seen = set(seed)
        stack = list(seed)
        while stack:
            cur = stack.pop()
            for nxt in edges_from(cur):
                if nxt not in seen:
                    seen.add(nxt)
                    stack.append(nxt)
        return seen

    live = reach(roots)
    live_or_test = reach(roots | test_roots)

    orphans = sorted(set(by_path) - live_or_test)
    test_only = sorted(live_or_test - live)

    print(f"files={len(by_path)}  roots={len(roots)}  "
          f"reachable_from_product={len(live)}  test_only={len(test_only)}  "
          f"orphans={len(orphans)}")

    if test_only:
        print("\nPRODUCTION-DEAD (reachable only from tests/):")
        for k in test_only:
            print(f"  {k}")
    if orphans:
        print("\nORPHANS (unreachable from product AND tests):")
        if show_list or len(orphans) <= 200:
            for k in orphans:
                print(f"  {k}")
    return 1 if (orphans or test_only) else 0


if __name__ == "__main__":
    raise SystemExit(main())
