"""
Wiring-audit lint: every [connection method="X"] in a .tscn must resolve to a
real `func X` on the script attached to the connection's target node. A
connection to a nonexistent method is a load-time error and a dead control
(this rule found the RewardsPanel + legacy TravelPhaseUI dead buttons).

Mirrors scripts/lint_data_ownership.py conventions (stdlib-only, os.walk, exit
0/1). .tscn files cannot carry "# lint:ignore" comments, so intentional
exceptions go in the ALLOWED set keyed "relpath.tscn::method".

Run: py scripts/lint_tscn_connections.py
"""

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJECT_ROOT, "src")

# Engine methods a [connection] may legitimately target (no script needed).
BUILTIN_METHODS = {"hide", "show", "queue_free", "grab_focus", "set_visible",
                   "free", "set_process", "set_physics_process"}

# Intentional exceptions: "relative/path.tscn::method".
ALLOWED = set()

EXT_RE = re.compile(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"')
NODE_RE = re.compile(r'\[node name="([^"]+)"(?:[^\]]*parent="([^"]+)")?[^\]]*\]')
SCRIPT_PROP_RE = re.compile(r'script = ExtResource\("?([^")]+)"?\)')
CONN_RE = re.compile(r'\[connection signal="([^"]+)" from="([^"]+)" to="([^"]+)" method="([^"]+)"\]')
FUNC_RE = re.compile(r'^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(')
CLASSNAME_RE = re.compile(r'^\s*class_name\s+([A-Za-z_]\w*)')
EXTENDS_PATH_RE = re.compile(r'^\s*extends\s+"([^"]+)"')
EXTENDS_NAME_RE = re.compile(r'^\s*extends\s+([A-Za-z_]\w*)')


def res_to_abs(res_path):
    return os.path.join(PROJECT_ROOT, res_path.replace("res://", "").replace("/", os.sep))


def build_classname_map():
    m = {}
    for dp, _, fns in os.walk(SRC_DIR):
        for fn in fns:
            if not fn.endswith(".gd"):
                continue
            fp = os.path.join(dp, fn)
            try:
                with open(fp, "r", encoding="utf-8", errors="replace") as f:
                    for line in f:
                        cm = CLASSNAME_RE.match(line)
                        if cm:
                            m[cm.group(1)] = fp
                            break
                        if line.strip() and not line.strip().startswith("#") \
                                and not line.startswith("@"):
                            break
            except OSError:
                pass
    return m


_METHOD_CACHE = {}


def script_has_method(script_abs, method, classmap, seen=None):
    if script_abs is None or not os.path.exists(script_abs):
        return None  # unresolved
    if seen is None:
        seen = set()
    if script_abs in seen:
        return False
    seen.add(script_abs)
    if script_abs not in _METHOD_CACHE:
        methods, parent = set(), None
        try:
            with open(script_abs, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    fm = FUNC_RE.match(line)
                    if fm:
                        methods.add(fm.group(1))
                    ep = EXTENDS_PATH_RE.match(line)
                    if ep:
                        parent = res_to_abs(ep.group(1))
                    else:
                        en = EXTENDS_NAME_RE.match(line)
                        if en and en.group(1) not in ("Node", "Control", "Resource",
                                                       "RefCounted", "Object"):
                            parent = classmap.get(en.group(1))
        except OSError:
            pass
        _METHOD_CACHE[script_abs] = (methods, parent)
    methods, parent = _METHOD_CACHE[script_abs]
    if method in methods:
        return True
    if parent:
        up = script_has_method(parent, method, classmap, seen)
        if up:
            return True
    return False


def scan_tscn(filepath, classmap):
    findings = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return findings
    ext = {i: res_to_abs(p) for p, i in EXT_RE.findall(text)}

    # Map node scene-path -> attached script abs path.
    node_scripts = {}
    lines = text.splitlines()
    cur_path = None
    for line in lines:
        nm = NODE_RE.match(line)
        if nm:
            name, parent = nm.group(1), nm.group(2)
            if parent is None:
                cur_path = "."
            elif parent == ".":
                cur_path = name
            else:
                cur_path = parent + "/" + name
            node_scripts.setdefault(cur_path, None)
            continue
        sp = SCRIPT_PROP_RE.search(line)
        if sp and cur_path is not None:
            node_scripts[cur_path] = ext.get(sp.group(1))

    rel = os.path.relpath(filepath, PROJECT_ROOT)
    for lineno, line in enumerate(lines, start=1):
        cm = CONN_RE.search(line)
        if not cm:
            continue
        method, to = cm.group(4), cm.group(3)
        if method in BUILTIN_METHODS:
            continue
        if f"{rel}::{method}" in ALLOWED:
            continue
        script_abs = node_scripts.get(to)
        if script_abs is None:
            continue  # target has no script -> unresolvable, not a failure
        result = script_has_method(script_abs, method, classmap)
        if result is False:
            findings.append((rel, lineno,
                             f"[connection] method '{method}' not found on target '{to}' "
                             f"({os.path.relpath(script_abs, PROJECT_ROOT)})"))
    return findings


def main():
    classmap = build_classname_map()
    all_findings = []
    for dp, _, fns in os.walk(SRC_DIR):
        for fn in fns:
            if fn.endswith(".tscn"):
                all_findings.extend(scan_tscn(os.path.join(dp, fn), classmap))

    if not all_findings:
        print("lint_tscn_connections: CLEAN (0 findings)")
        return 0
    print(f"lint_tscn_connections: {len(all_findings)} finding(s)\n")
    for rel, lineno, message in all_findings:
        print(f"  {rel}:{lineno}: {message}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
