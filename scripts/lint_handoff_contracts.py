#!/usr/bin/env python
"""Exhaustive producer/consumer census for every handoff carrier in the project.

The recurring defect in this codebase is not a crash — it is a CONSUMER reading a
key that no PRODUCER anywhere writes. `.get(key, default)` on a missing key is a
silent default, not a fault, so the rule simply never fires and nothing in the log
says so. Half a dozen sprints have found these one subsystem at a time.

This enumerates ALL of them at once, so coverage is a denominator rather than an
impression. It reports four carrier families:

  progress_data[...]   campaign-level turn state
  temp_data(...)       cross-scene handoff payloads
  dict keys            per-container producer/consumer pairs for the well-known
                       campaign containers (crew_data, equipment_data, world_data,
                       ship_data, qol_data, battle_result, mission_data)
  signals              declared vs connected

It also resolves LOCAL ALIASES (`var pd = campaign.progress_data`) so a write
through an alias still counts as a producer — without that, this reports a wall of
false positives and gets ignored, which is the failure mode of every lint nobody
runs.

Findings are classified:
  ORPHAN-READ    a consumer reads it; nothing writes it        -> rule never fires
  ORPHAN-WRITE   a producer writes it; nothing reads it        -> dead data
  DEAD-PRODUCER  the ONLY writer lives in a file nothing        -> rule held hostage
                 instantiates                                     by dead code

Exit code is 0 always; this is a REPORT, not a gate (the project has a known
legacy backlog). Use --strict to fail on ORPHAN-READ and DEAD-PRODUCER, which are
the two that mean a book rule silently does not happen.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Containers whose string keys form a producer/consumer contract.
CONTAINERS = [
    "progress_data",
    "crew_data",
    "equipment_data",
    "world_data",
    "ship_data",
    "qol_data",
    "battle_result",
    "mission_data",
    "campaign_data",
]

KEY = r"[A-Za-z_][A-Za-z_0-9]*"


def gd_files() -> list[Path]:
    return sorted(p for p in SRC.rglob("*.gd") if ".godot" not in p.parts)


def tscn_files() -> list[Path]:
    return sorted(p for p in SRC.rglob("*.tscn") if ".godot" not in p.parts)


def read(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def strip_comments(text: str) -> str:
    """Drop line comments so commented-out code cannot fake a producer.

    A previous sweep was misled exactly this way: a dead class chain looked
    'reachable' because its name appeared only inside comments.
    """
    out = []
    for line in text.splitlines():
        in_str = False
        quote = ""
        cut = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            if in_str:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    in_str = False
            elif ch in "\"'":
                in_str = True
                quote = ch
            elif ch == "#":
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def alias_map(text: str) -> dict[str, str]:
    """Local names bound to a known container: `var pd = campaign.progress_data`."""
    aliases: dict[str, str] = {}
    for container in CONTAINERS:
        pat = rf"var\s+({KEY})\s*(?::\s*\w+)?\s*=\s*[\w\.\(\)]*\b{container}\b"
        for m in re.finditer(pat, text):
            aliases[m.group(1)] = container
    return aliases


def scan_container_keys(text: str, path: str, writes, reads) -> None:
    aliases = alias_map(text)
    names = {c: c for c in CONTAINERS}
    names.update(aliases)

    for name, container in names.items():
        n = re.escape(name)
        # WRITES: name["key"] = ...   /   name["key"].append(...)
        for m in re.finditer(rf'\b{n}\[\s*["\']({KEY})["\']\s*\]\s*(?:=[^=]|\.append|\.assign|\.erase)', text):
            writes[(container, m.group(1))].add(path)
        # WRITES via merge-style helpers
        for m in re.finditer(rf'\b{n}\.merge\(', text):
            writes[(container, "<merge>")].add(path)
        # READS: name.get("key"...)  /  name["key"] used as a value  /  name.has("key")
        for m in re.finditer(rf'\b{n}\.get\(\s*["\']({KEY})["\']', text):
            reads[(container, m.group(1))].add(path)
        for m in re.finditer(rf'\b{n}\.has\(\s*["\']({KEY})["\']', text):
            reads[(container, m.group(1))].add(path)
        for m in re.finditer(rf'\b{n}\[\s*["\']({KEY})["\']\s*\](?!\s*=[^=])', text):
            reads[(container, m.group(1))].add(path)


def scan_any_dict_writes(text: str, out: dict[str, set[str]], path: str) -> None:
    """`anything["key"] = ...` for ANY local name, not just the known containers.

    A key does not stay in one variable. BattleResultNormalizer builds the battle
    result in a local called `results` and every post-battle processor reads it as
    `ctx.battle_result` — so a per-container match accuses the ONE file that was
    written specifically to produce those keys. Producer/consumer is therefore
    matched on the KEY NAME globally; the container is kept only for reporting.
    """
    for m in re.finditer(rf'\b{KEY}\[\s*["\']({KEY})["\']\s*\]\s*(?:=[^=]|\.append|\.assign)', text):
        out[m.group(1)].add(path)
    # `d.set("key", v)` / `d.merge({...})` style producers
    for m in re.finditer(rf'\.set\(\s*["\']({KEY})["\']\s*,', text):
        out[m.group(1)].add(path)


def scan_dict_literal_keys(text: str, out: dict[str, set[str]]) -> None:
    """Keys that appear as `"key":` in a dictionary literal ANYWHERE.

    A huge share of this codebase's writes never touch `container["key"] =` —
    they are built as literals and handed to an initializer
    (`campaign.initialize_resources({"credits": ...})`) or returned wholesale from
    a builder. Without this, every such key looks like an orphan read and the
    report becomes a wall nobody reads.
    """
    for m in re.finditer(rf'["\']({KEY})["\']\s*:', text):
        out[m.group(1)].add("literal")
    # Keys named inside an ARRAY literal. The passthrough idiom
    #     for key in ["rival_id", "is_invasion", ...]:
    #         results[key] = mission[key]
    # writes through a VARIABLE subscript, so a literal-subscript scan cannot see
    # it — and BattleResultNormalizer, the chokepoint every battle path crosses,
    # is built entirely that way. Without this the report accuses the one file
    # that was specifically fixed to carry these keys.
    for arr in re.finditer(r"\[([^\[\]]*?)\]", text):
        inner = arr.group(1)
        if '"' not in inner and "'" not in inner:
            continue
        if "," not in inner:
            continue
        for m in re.finditer(rf'["\']({KEY})["\']', inner):
            out[m.group(1)].add("array-literal")


def scan_temp_data(text: str, path: str, writes, reads) -> None:
    for m in re.finditer(rf'set_temp_data\(\s*["\']({KEY})["\']', text):
        writes[("temp_data", m.group(1))].add(path)
    for m in re.finditer(rf'(?:get|has|clear)_temp_data\(\s*["\']({KEY})["\']', text):
        reads[("temp_data", m.group(1))].add(path)


def scan_signals(text: str, path: str, declared, emitted, connected) -> None:
    for m in re.finditer(rf"^\s*signal\s+({KEY})", text, re.M):
        declared[m.group(1)].add(path)
    for m in re.finditer(rf"\b({KEY})\.emit\(", text):
        emitted[m.group(1)].add(path)
    for m in re.finditer(rf"\bemit_signal\(\s*[\"']({KEY})[\"']", text):
        emitted[m.group(1)].add(path)
    for m in re.finditer(rf"\.({KEY})\.connect\(", text):
        connected[m.group(1)].add(path)
    for m in re.finditer(rf"\bconnect\(\s*[\"']({KEY})[\"']", text):
        connected[m.group(1)].add(path)


RULE_VERB = re.compile(
    r"^(roll|check|apply|resolve|determine|calculate|process|generate|award|grant|trigger|enforce)_")

RULES_DIRS = (
    "src/core/systems/", "src/core/campaign/", "src/core/battle/",
    "src/core/mission/", "src/core/equipment/", "src/core/character/",
    "src/core/world/", "src/core/story/", "src/core/rivals/",
)


def scan_uncalled_rules(all_gd: list[Path]) -> list[tuple[str, str]]:
    """Public rule-EXECUTING functions in rules systems that nobody calls.

    The key census cannot see this class. PsionicSystem.
    check_highly_unusual_reinforcements() implemented the Compendium p.22
    "psionics draw attention" reinforcements exactly right and had zero callers —
    no dict key was involved, so nothing flagged it, and a rule that fires on
    ~30% of worlds simply never happened.

    Restricted to names that denote a rule being APPLIED (roll_/check_/apply_/
    resolve_/...) because a plain data-class setter with no caller is unused API
    surface, not a missing rule. Without that filter this reports 630 functions
    and is useless.
    """
    defs: dict[str, list[str]] = {}
    calls: dict[str, int] = defaultdict(int)
    bodies: dict[str, str] = {}
    for p in all_gd:
        rel = p.relative_to(ROOT).as_posix()
        body = strip_comments(read(p))
        bodies[rel] = body
        if rel.startswith(RULES_DIRS):
            for m in re.finditer(r"^\s*(?:static\s+)?func\s+([a-z][A-Za-z_0-9]*)\s*\(", body, re.M):
                defs.setdefault(m.group(1), []).append(rel)
    for body in bodies.values():
        for m in re.finditer(r"\b([a-z][A-Za-z_0-9]*)\s*\(", body):
            calls[m.group(1)] += 1
    out: list[tuple[str, str]] = []
    for fn, where in defs.items():
        if fn.startswith("_") or not RULE_VERB.match(fn):
            continue
        if calls[fn] - len(where) <= 0:
            out.append((where[0], fn))
    return sorted(out)


def find_live_files(all_gd: list[Path]) -> set[str]:
    """Files reachable from a .tscn, an autoload, a preload/load, or `extends`.

    Anything else is a candidate dead file — the shape that has repeatedly held a
    real rule hostage (TravelPhase / WorldPhase held the only callers of the
    Galactic War table, hull repair and fuel credits).
    """
    referenced: set[str] = set()

    def note(res_path: str) -> None:
        referenced.add(res_path.replace("res://", "").replace("\\", "/"))

    # A .gd attached to a scene, or pulled in by project.godot (autoloads,
    # main scene), or preloaded/extended by another script, is reachable.
    for p in tscn_files():
        for m in re.finditer(r'path="(res://[^"]+\.gd)"', read(p)):
            note(m.group(1))
    project = read(ROOT / "project.godot")
    for m in re.finditer(r'res://[^\s"\']+\.gd', project):
        note(m.group(0))
    for p in all_gd:
        body = strip_comments(read(p))
        for m in re.finditer(r'(?:preload|load)\(\s*["\'](res://[^"\']+\.gd)["\']', body):
            note(m.group(1))
        for m in re.finditer(r'extends\s+["\'](res://[^"\']+\.gd)["\']', body):
            note(m.group(1))
        # `SomeClass.new()` / `extends SomeClass` via a global class_name.
        for m in re.finditer(rf"\b({KEY})\.new\(", body):
            referenced.add("class:" + m.group(1))
        for m in re.finditer(rf"^\s*extends\s+({KEY})\s*$", body, re.M):
            referenced.add("class:" + m.group(1))

    # Map class_name -> file so a class-based instantiation marks its file live.
    for p in all_gd:
        body = strip_comments(read(p))
        m = re.search(rf"^\s*class_name\s+({KEY})", body, re.M)
        if m and ("class:" + m.group(1)) in referenced:
            note("res://" + p.relative_to(ROOT).as_posix())
    return referenced


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 on ORPHAN-READ / DEAD-PRODUCER")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--container", help="limit to one container")
    args = ap.parse_args()

    all_gd = gd_files()
    live = find_live_files(all_gd)

    writes: dict[tuple[str, str], set[str]] = defaultdict(set)
    reads: dict[tuple[str, str], set[str]] = defaultdict(set)
    literal_keys: dict[str, set[str]] = defaultdict(set)
    any_writes: dict[str, set[str]] = defaultdict(set)
    declared: dict[str, set[str]] = defaultdict(set)
    emitted: dict[str, set[str]] = defaultdict(set)
    connected: dict[str, set[str]] = defaultdict(set)

    for p in all_gd:
        rel = p.relative_to(ROOT).as_posix()
        body = strip_comments(read(p))
        scan_container_keys(body, rel, writes, reads)
        scan_dict_literal_keys(body, literal_keys)
        scan_any_dict_writes(body, any_writes, rel)
        scan_temp_data(body, rel, writes, reads)
        scan_signals(body, rel, declared, emitted, connected)

    def is_dead(path: str) -> bool:
        # `live` already holds repo-relative paths ("src/ui/.../X.gd"), which is
        # exactly the form `path` arrives in. Normalising either side again is how
        # this produced a list of "dead" files that included FinalPanel.
        return path not in live

    orphan_reads, orphan_writes, dead_producers = [], [], []
    maybe_literal = []
    for key in sorted(set(list(writes) + list(reads))):
        container, name = key
        if args.container and container != args.container:
            continue
        if name == "<merge>":
            continue
        w, r = writes.get(key, set()), reads.get(key, set())
        if r and not w:
            # A write to ANY dict under this key name counts as a producer —
            # keys move between locals (results -> battle_result).
            if name in any_writes:
                continue
            # Tier B: a literal `"name":` exists somewhere, so a builder probably
            # produces it. Real but lower-confidence; needs a human/agent look.
            if name in literal_keys:
                maybe_literal.append((container, name, sorted(r)))
            else:
                orphan_reads.append((container, name, sorted(r)))
        elif w and not r:
            orphan_writes.append((container, name, sorted(w)))
        elif w and r:
            live_writers = [f for f in w if not is_dead(f)]
            if not live_writers:
                dead_producers.append((container, name, sorted(w), sorted(r)))

    dead_signals = []
    for sig, decl_files in sorted(declared.items()):
        if not emitted.get(sig) and connected.get(sig):
            dead_signals.append((sig, sorted(decl_files), sorted(connected[sig])))

    if args.json:
        print(json.dumps({
            "orphan_reads": orphan_reads,
            "maybe_literal": maybe_literal,
            "orphan_writes": orphan_writes,
            "dead_producers": dead_producers,
            "listened_never_emitted": dead_signals,
            "uncalled_rules_live": scan_uncalled_rules(all_gd),
        }, indent=1))
        return 0

    print("=" * 72)
    print("HANDOFF CONTRACT CENSUS")
    print("=" * 72)
    print(f"scanned {len(all_gd)} .gd files; {len(writes)} written keys, {len(reads)} read keys\n")

    print(f"-- DEAD-PRODUCER ({len(dead_producers)}) "
          "— the only writer is in a file nothing instantiates; the rule cannot fire")
    for container, name, w, r in dead_producers:
        print(f"   {container}[{name}]")
        print(f"      written only by : {', '.join(w)}")
        print(f"      read by         : {', '.join(r[:3])}")

    print(f"\n-- ORPHAN-READ ({len(orphan_reads)}) — read but NOTHING writes it")
    for container, name, r in orphan_reads:
        print(f"   {container}[{name}]  <- {', '.join(r[:3])}")

    print(f"\n-- ORPHAN-WRITE ({len(orphan_writes)}) — written but nothing reads it")
    for container, name, w in orphan_writes:
        print(f"   {container}[{name}]  -> {', '.join(w[:3])}")

    uncalled = scan_uncalled_rules(all_gd)
    live_uncalled = [(f, fn) for f, fn in uncalled if f in live]
    dead_file_uncalled = [(f, fn) for f, fn in uncalled if f not in live]
    print(f"\n-- UNCALLED RULE ({len(live_uncalled)}) — a rule-executing function in a"
          " LIVE file that nothing calls; the rule never fires")
    for f, fn in live_uncalled:
        print(f"   {fn:44s} {f}")
    print(f"\n-- UNCALLED RULE, DEAD FILE ({len(dead_file_uncalled)}) — port or delete")
    for f, fn in dead_file_uncalled:
        print(f"   {fn:44s} {f}")

    print(f"\n-- LISTENED-NEVER-EMITTED ({len(dead_signals)}) "
          "— someone connects to a signal nothing emits")
    for sig, d, c in dead_signals[:40]:
        print(f"   {sig}  declared {d[0]}  connected {c[0]}")
    if len(dead_signals) > 40:
        print(f"   ... {len(dead_signals) - 40} more")

    fatal = len(orphan_reads) + len(dead_producers) + len(live_uncalled)
    print("\n" + "=" * 72)
    print(f"rule-silencing findings (orphan-read + dead-producer + uncalled-rule): {fatal}")
    if args.strict and fatal:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
