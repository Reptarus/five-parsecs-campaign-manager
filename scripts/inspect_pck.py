"""Probe an exported Godot binary (.pck, or .exe with an embedded pack) for leaked paths.

WHAT THIS TOOL CAN AND CANNOT PROVE — read before trusting a result.

  ABSENCE IS CONCLUSIVE.   Zero byte-occurrences of "CLAUDE.md" means the string is
                           not in the package at all, so neither the file nor any
                           reference to it shipped.
  PRESENCE IS NOT.         A hit does NOT prove the file shipped. Godot packs its own
                           UID / script-class caches, and those name project paths
                           regardless of export filters. Decoded from a 4.6 build, the
                           cache entries are literally:
                               path_len(4) path uid(8) type_len(4) type_name
                           so an excluded file's path can still appear as a string.

  For a .aab / .apk, do NOT use this — use zipfile.namelist(), which IS authoritative:
      py -c "import zipfile;print([n for n in zipfile.ZipFile('x.aab').namelist() if 'CLAUDE' in n])"

  A full pack-directory walk would be authoritative here too, but Godot 4.6 uses pack
  format v3 whose directory layout is not the documented v2 one (the header's
  file_base did not locate it, and the first res:// string in the pack belongs to the
  uid cache rather than the directory). Left unimplemented rather than shipped subtly
  wrong — a file lister that silently parses one entry and reports "clean" is worse
  than no lister at all.

WHY THIS EXISTS
  Jul 27 2026: export_presets.cfg include_filter was "*.tscn, *.json, *.gd, *.tres,
  *.cfg, *.md, *.txt". Godot export globs use String::matchn(), where * matches across
  "/", so those swept the whole repo into the build. CLAUDE.md — which documents
  confidential Modiphius partnership terms — shipped in 16+ Android test builds and in
  the April Windows build. See docs/RELEASE_SIGNING.md and commit b3b434b4.

Run:  py scripts/inspect_pck.py <path> [substring ...]
      py scripts/inspect_pck.py build/wintest/FiveParsecsAlpha.exe CLAUDE.md .mcp.json
"""

import os
import struct
import sys

MAGIC = b"GDPC"

# Paths that must never appear in a shipped build, checked when no probes are given.
DEFAULT_PROBES = [
    "CLAUDE.md",
    ".mcp.json",
    "export_presets.cfg",
    "node_modules",
    "mcp-servers",
    "MODIPHIUS_",
    "settings.example.cfg",
    "RELEASE_SIGNING",
]


def pack_bounds(data):
    """Return (start, end) of the embedded pack, or (0, len) for a bare .pck."""
    if data[:4] == MAGIC:
        return 0, len(data)
    if len(data) >= 12 and data[-4:] == MAGIC:
        size = struct.unpack_from("<Q", data, len(data) - 12)[0]
        return len(data) - 12 - size, len(data) - 12
    return None, None


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    if not os.path.exists(path):
        print("no such file: %s" % path)
        return 2

    probes = argv[2:] or DEFAULT_PROBES
    data = open(path, "rb").read()
    start, end = pack_bounds(data)

    print("%s  %.1f MB" % (path, len(data) / 1048576.0))
    if start is None:
        print("  (no GDPC magic — scanning the whole file)")
        start, end = 0, len(data)
    else:
        ver = struct.unpack_from("<I", data, start + 4)[0]
        print("  embedded pack at %d, %.1f MB, format v%d"
              % (start, (end - start) / 1048576.0, ver))
    print()

    blob = data[start:end]
    definitely_absent = []
    inconclusive = []
    for p in probes:
        n = blob.count(p.encode("utf-8"))
        if n == 0:
            definitely_absent.append(p)
            print("  ABSENT (conclusive)  %s" % p)
        else:
            inconclusive.append((p, n))
            print("  PRESENT AS STRING    %-24s x%d  <-- may be a uid-cache path, not a file" % (p, n))

    print()
    if not inconclusive:
        print("RESULT: every probe is conclusively absent from the package.")
        return 0
    print("RESULT: %d probe(s) absent; %d appear as strings and need a manual check "
          "(see the epistemics note at the top of this file)."
          % (len(definitely_absent), len(inconclusive)))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
