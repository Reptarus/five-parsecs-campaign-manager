#!/usr/bin/env python3
"""Audit an exported Android artifact (.apk / .aab) WITHOUT trusting the export preset.

Godot's export filters glob ACROSS directories -- `*.md` once packed the entire
repo (CLAUDE.md, docs/, the Modiphius partnership material) into shipped APKs.
The preset can look correct while the artifact is not, and `--export-release`
can exit 0 having written nothing at all. The artifact is the only witness.

Usage:
    python scripts/verify_apk.py build/fpfh-0.9.7.apk [--expect ExpandedQuestProgression ...]

Exit 1 if any forbidden path is packed, or if an --expect script is missing.

Notes on the Android layout: Godot ships LOOSE files under `assets/`, not a
`.pck`, so scripts appear as `assets/src/**/*.gdc` + `.gd.remap`. Zip entry
timestamps are NOT a build date -- AndroidManifest.xml carries a fake 1981 date.
"""

import argparse
import os
import sys
import zipfile

# Paths that must NEVER ship. Matched as substrings against the zip entry name.
FORBIDDEN = [
    "CLAUDE.md",
    "assets/docs/",
    "assets/tests/",
    "assets/mcp-servers/",
    "assets/node_modules/",
    "assets/reports/",
    "assets/screenshots/",
    ".mcp.json",
    "MODIPHIUS",
    "MEETING_",
    "PARTNERSHIP",
    "BOILERPLATE",
]

# The only .md files allowed in the artifact: the shipped legal documents.
ALLOWED_MD = {
    "assets/data/legal/credits.md",
    "assets/data/legal/eula.md",
    "assets/data/legal/privacy_policy.md",
    "assets/data/legal/third_party_licenses.md",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("artifact")
    ap.add_argument(
        "--expect",
        nargs="*",
        default=[],
        help="Script basenames that must be present (freshness check)",
    )
    args = ap.parse_args()

    if not os.path.isfile(args.artifact):
        print(f"FAIL: no such artifact: {args.artifact}")
        print("      (an export that exits 0 can still write nothing)")
        return 1

    size_mb = os.path.getsize(args.artifact) / (1024 * 1024)
    with zipfile.ZipFile(args.artifact) as z:
        names = z.namelist()

    print(f"artifact : {args.artifact}")
    print(f"size     : {size_mb:.1f} MB")
    print(f"entries  : {len(names)}")

    failures = []

    leaked = [n for n in names if any(f in n for f in FORBIDDEN)]
    if leaked:
        failures.append(f"{len(leaked)} forbidden entries")
        print(f"\nLEAK: {len(leaked)} forbidden entries")
        for n in leaked[:40]:
            print(f"   {n}")
        if len(leaked) > 40:
            print(f"   ... and {len(leaked) - 40} more")
    else:
        print("\nleak check ...... PASS (no forbidden paths)")

    stray_md = [n for n in names if n.endswith(".md") and n not in ALLOWED_MD]
    if stray_md:
        failures.append(f"{len(stray_md)} unexpected .md files")
        print(f"\nLEAK: {len(stray_md)} unexpected .md files")
        for n in stray_md[:40]:
            print(f"   {n}")
    else:
        print("md check ........ PASS (only the 4 legal docs)")

    if args.expect:
        missing = []
        for want in args.expect:
            if not any(want in n for n in names):
                missing.append(want)
        if missing:
            failures.append(f"{len(missing)} expected scripts absent (STALE build)")
            print(f"\nSTALE: expected scripts absent from the artifact")
            for m in missing:
                print(f"   {m}")
        else:
            print(f"freshness ....... PASS (all {len(args.expect)} expected scripts present)")

    if failures:
        print("\nRESULT: FAIL -- " + "; ".join(failures))
        return 1
    print("\nRESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
