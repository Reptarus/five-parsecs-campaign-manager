"""
Wiring-audit lint: a `signal X` declared in src/**/*.gd should be emitted
somewhere (X.emit( / emit_signal("X") / call_deferred("emit_signal","X")).
A declared-never-emitted signal is dead wiring; if it ALSO has a listener
(.connect), that listener can never fire (the reroll_requested class of bug).

~90% true-positive in practice. Mirrors scripts/lint_data_ownership.py: stdlib
only, os.walk over src/, "# lint:ignore" on the declaration suppresses, exit 0/1.
Findings with listeners > 0 (live dead-wires) are printed first.

Run: py scripts/lint_signal_wiring.py
"""

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJECT_ROOT, "src")
SCM = os.path.join(SRC_DIR, "core", "systems", "SignalConnectionManager.gd")

SIGNAL_RE = re.compile(r'^\s*signal\s+([A-Za-z_]\w*)')
# A file that emits via a NON-literal first arg is a "dynamic emitter" — its
# signals can't be proven dead by literal search, so we skip them.
DYNAMIC_EMIT_RE = re.compile(r'emit_signal\(\s*[^"\'&)\s]')


def gather_gd_files():
    out = []
    for dp, _, fns in os.walk(SRC_DIR):
        for fn in fns:
            if fn.endswith(".gd"):
                out.append(os.path.join(dp, fn))
    return out


def read(fp):
    try:
        with open(fp, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def main():
    gd_files = gather_gd_files()
    texts = {fp: read(fp) for fp in gd_files}
    all_text = "\n".join(texts.values())

    # tscn corpus for connection evidence
    tscn_text = ""
    for dp, _, fns in os.walk(SRC_DIR):
        for fn in fns:
            if fn.endswith(".tscn"):
                tscn_text += read(os.path.join(dp, fn)) + "\n"

    # Signal-variant literals from the dynamic hub count as consumption evidence.
    scm_text = read(SCM)

    # Collect declarations, skipping dynamic-emitter files.
    decls = []  # (fp, lineno, name)
    for fp, text in texts.items():
        if DYNAMIC_EMIT_RE.search(text):
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if "# lint:ignore" in line:
                continue
            m = SIGNAL_RE.match(line)
            if m:
                decls.append((fp, lineno, m.group(1)))

    findings = []
    for fp, lineno, name in decls:
        emit_pat = re.compile(r'\b' + re.escape(name) + r'\.emit\s*\(|emit_signal\(\s*[&"\']+'
                              + re.escape(name) + r'["\']')
        if emit_pat.search(all_text):
            continue  # emitted somewhere
        # Count listeners (for severity ranking).
        conn_pat = re.compile(r'\.' + re.escape(name) + r'\.connect\(|connect\(\s*["\']'
                              + re.escape(name) + r'["\']')
        listeners = len(conn_pat.findall(all_text))
        listeners += len(re.findall(r'\[connection signal="' + re.escape(name) + r'"', tscn_text))
        # Suppress if the dynamic hub lists it as a signal variant.
        if '"' + name + '"' in scm_text:
            continue
        findings.append((fp, lineno, name, listeners))

    if not findings:
        print("lint_signal_wiring: CLEAN (0 findings)")
        return 0

    findings.sort(key=lambda t: (-t[3], t[0], t[1]))
    print(f"lint_signal_wiring: {len(findings)} declared-never-emitted signal(s)\n")
    for fp, lineno, name, listeners in findings:
        rel = os.path.relpath(fp, PROJECT_ROOT)
        tag = f"  [LIVE DEAD-WIRE: {listeners} listener(s)]" if listeners else ""
        print(f"  {rel}:{lineno}: signal '{name}' declared but never emitted{tag}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
