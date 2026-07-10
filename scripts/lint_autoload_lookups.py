"""
Wiring-audit lint: every literal "/root/Name" lookup in src/**/*.gd must resolve
to a real autoload registered in project.godot [autoload], OR to an allowlisted
runtime-added node. A lookup on a name that is neither always returns null, so
the guarded feature silently never runs (or, for a bare get_node, spams a
runtime error).

Mirrors scripts/lint_data_ownership.py: stdlib-only, os.walk over src/, regex
per line, skip comment lines + "# lint:ignore", exit 0 = clean / 1 = findings.

Run: py scripts/lint_autoload_lookups.py
"""

import os
import re
import sys
import difflib

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJECT_ROOT, "src")
PROJECT_GODOT = os.path.join(PROJECT_ROOT, "project.godot")

# Names that are NOT autoloads but ARE legitimately added under /root at runtime
# (scene roots routed by SceneRouter, nodes added via add_child). Each entry MUST
# carry evidence of where the node is actually created, or it does not belong here.
RUNTIME_NODE_ALLOWLIST = {
    # scene-tree root path, not an autoload (UIManager.gd:144 /root/Main/OptionsMenu)
    "Main": "scene root node (routed scene), not an autoload",
}

LOOKUP_RE = re.compile(r'["\']/root/([A-Za-z_]\w*)')
BARE_GET_NODE_RE = re.compile(r'\bget_node\(\s*["\']/root/')


def parse_autoloads():
    names = set()
    if not os.path.exists(PROJECT_GODOT):
        return names
    in_section = False
    with open(PROJECT_GODOT, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if s.startswith("["):
                in_section = s == "[autoload]"
                continue
            if in_section and "=" in s and not s.startswith(";"):
                names.add(s.split("=", 1)[0].strip())
    return names


def scan_file(filepath, valid_names):
    findings = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        return findings
    for lineno, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("#") or "# lint:ignore" in stripped:
            continue
        for m in LOOKUP_RE.finditer(stripped):
            name = m.group(1)
            if name in valid_names:
                continue
            bare = "  [BARE get_node - errors at runtime]" if BARE_GET_NODE_RE.search(stripped) else ""
            suggestion = difflib.get_close_matches(name, list(valid_names), n=1)
            hint = f" (did you mean '{suggestion[0]}'?)" if suggestion else ""
            findings.append((filepath, lineno, stripped,
                             f"'/root/{name}' is not an autoload{hint}{bare}"))
    return findings


def main():
    autoloads = parse_autoloads()
    valid = autoloads | set(RUNTIME_NODE_ALLOWLIST.keys())
    all_findings = []
    for dirpath, _, filenames in os.walk(SRC_DIR):
        for fn in filenames:
            if fn.endswith(".gd"):
                all_findings.extend(scan_file(os.path.join(dirpath, fn), valid))

    if not all_findings:
        print("lint_autoload_lookups: CLEAN (0 findings)")
        return 0
    print(f"lint_autoload_lookups: {len(all_findings)} finding(s)\n")
    for filepath, lineno, code, message in all_findings:
        rel = os.path.relpath(filepath, PROJECT_ROOT)
        print(f"  {rel}:{lineno}: {message}")
        print(f"    {code}\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
