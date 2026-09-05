"""GATING lint: a `has_method("X")` guard where `func X` has ZERO definitions
repo-wide is a permanently-false branch, not a safety net.

WHY THIS GATES NOW
------------------
CLAUDE.md has named this trap for months and it kept happening anyway:

  * `CampaignEventEffects` / `CharacterEventEffects` guarded on `damage_hull()`,
    which does not exist. Both returned a string claiming the ship took damage.
    (Aug 1 2026)
  * `PrintSheetScreen` guarded on `journal.has_method("get_entries")`. The real
    accessor is `get_all_entries()`, so `entries` was ALWAYS [] and the Encounter
    Log's journal block printed blank in every campaign on every platform. Found
    on hardware, deploy #5. (Aug 9 2026)
  * `HouseRulesHelper.is_enabled()` probed `GameState.is_house_rule_enabled` and
    `GameStateManager.get_house_rules`. Neither exists, so the whole house-rules
    feature was inert across 8 guarded call sites. (Sep 4 2026)
  * `CampaignTurnController` guarded on `mark_rival_defeated()` and
    `register_patron_contact()`, feeding two nodes nothing else read. (Sep 4 2026)

Both halves of each look like a careful null-guard and read as "the feature was
never built".

HOW IT GATES
------------
Same shape as the other seven `lint_*.py`: every finding that existed when this
was promoted is recorded in ALLOWLIST **with a reason**, so the lint is a
REGRESSION GUARD. A new name means you just introduced one — fix it, or add it
here with evidence for why it must be probed at runtime.

Legitimate reasons to allowlist:
  * GDExtension / platform-plugin APIs that genuinely only exist on some
    platforms (GodotSteam, Google Billing, StoreKit, libharu). Probing those with
    has_method() is the CORRECT pattern.
  * Methods defined in `addons/` — those ARE indexed, so a genuine addon
    method will not appear here at all; if one does, the addon is missing.
  * A duck-typed call across two shapes where one shape really does define it.

NOT a legitimate reason: "it might exist somewhere". Grep `func <name>` first.

    python scripts/lint_dead_has_method_guards.py [--path src/core/export]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directories that contain GDScript but are NOT this project's code.
_NON_PROJECT = {".mcp", ".godot", ".git", "node_modules", "mcp-servers"}

# Godot built-ins commonly probed with has_method() that are NOT project funcs.
ENGINE = set("""
get set call free duplicate has_method get_class is_class connect emit_signal
add_child remove_child get_node find_child get_parent get_children get_child_count
queue_free get_index get_path get_rect get_size set_size get_position set_position
get_global_rect grab_focus release_focus show hide popup popup_centered
get_item_count add_item clear select get_selected_id get_line_count get_text set_text
serialize deserialize to_dictionary from_dictionary get_value set_value has
get_data set_data resize instantiate get_current_scene get_tree get_viewport
get_window get_texture get_image save_png get_string get_meta has_meta set_meta
get_property_list get_static_memory_usage set_pressed is_pressed play stop seek
_ready _init _process _draw _input _gui_input get_stylebox get_font get_color
""".split())

# ---------------------------------------------------------------------------
# ALLOWLIST — every finding present when this lint was promoted (2026-09-04),
# with the reason it is allowed. A name NOT in here fails the build.
# ---------------------------------------------------------------------------

_PLATFORM = "platform/GDExtension API — only exists on some platforms, so has_method() is the correct probe"
_DEAD_FILE = "sits in a file that is production-dead (tier-7 wire-or-delete backlog); goes away with the file"
_NOT_A_CALL = "not a real guard — comment text or a dynamically built name"
_DUCK = "duck-typed across two shapes; the live path uses the other branch"

ALLOWLIST: dict[str, str] = {
    # --- GodotSteam ---------------------------------------------------------
    "activateGameOverlayToStore": _PLATFORM,
    "activateGameOverlayToWebPage": _PLATFORM,
    "steamInitEx": _PLATFORM,
    # --- Google Play Billing -------------------------------------------------
    "acknowledge_purchase": _PLATFORM,
    "query_product_details": _PLATFORM,
    "query_purchases": _PLATFORM,
    "start_connection": _PLATFORM,
    # --- Apple StoreKit ------------------------------------------------------
    "finish": _PLATFORM,
    "request_products": _PLATFORM,
    # --- libharu (godotharu PDF backend, desktop only) -----------------------
    "begin_text": _PLATFORM,
    "text_out": _PLATFORM,
    "text_width": _PLATFORM,
    "load_raw_image_from_mem": _PLATFORM,
    "set_author": _PLATFORM,
    "set_creation_date": _PLATFORM,
    "set_creator": _PLATFORM,
    "set_keywords": _PLATFORM,
    "set_subject": _PLATFORM,
    "set_text_rendering_mode": _PLATFORM,
    "set_title": _PLATFORM,
    # --- inside production-dead files ---------------------------------------
    "mark_unit_casualty": _DEAD_FILE,
    "mark_unit_injured": _DEAD_FILE,
    "modify_movement": _DEAD_FILE,
    "set_parent_node": _DEAD_FILE,
    "get_current_scale_factor": _DEAD_FILE,
    "get_current_turn": _DEAD_FILE,
    "set_character_type": _DEAD_FILE,
    # --- not actually guards -------------------------------------------------
    "check_rival_encounter": _NOT_A_CALL,
    "set_": _NOT_A_CALL,
    # --- pre-existing, a live fallback runs ---------------------------------
    # Each of these has a working branch after the guard, so the dead probe is
    # inert rather than harmful. They are recorded so the lint gates on NEW
    # findings; deleting the dead branch is tidy-up, not a defect fix.
    "add_crew_experience": _DUCK,
    "clear_pending_purchases": _DUCK,
    "create_patron": _DUCK,
    "expand_section_for_phase": _DUCK,
    "generate_connections": _DUCK,
    "get_campaign": _DUCK,
    "get_campaign_state": _DUCK,
    "get_context": _DUCK,
    "get_customization_completeness": _DUCK,
    "get_equipment_generator": _DUCK,
    "get_equipment_state": _DUCK,
    "get_manager": _DUCK,
    "get_pending_purchases": _DUCK,
    "get_victory_condition": _DUCK,
    "handle_equipment_generation": _DUCK,
    "is_bot": _DUCK,
    "is_captain": _DUCK,
    "navigate_to_scene": _DUCK,
    "populate": _DUCK,
    "register_campaign_coordinator": _DUCK,
    "serialize_enhanced": _DUCK,
    "set_crew_training": _DUCK,
    "set_equipment": _DUCK,
    "set_gear": _DUCK,
    "set_max_health": _DUCK,
    "set_personal_equipment": _DUCK,
    "set_ship_stash": _DUCK,
    "set_situation_modifier": _DUCK,
    "set_weapons": _DUCK,
    "transfer_from_ship_stash": _DUCK,
    "update_navigation_state": _DUCK,
    "validate_complete_state": _DUCK,
    "verify_campaign_handoff": _DUCK,
}


def main() -> int:
    scope = ROOT / "src"
    if "--path" in sys.argv:
        scope = ROOT / sys.argv[sys.argv.index("--path") + 1]

    # GROUND TRUTH = project code only.
    #
    # ROOT.rglob("*.gd") also walks .mcp/ - an MCP server's vendored cache
    # holding ~2,800 unrelated GDScript files. Their `func` definitions were
    # being counted as project definitions, which MASKS real dead guards in src/
    # and makes the result drift whenever that cache changes (two runs minutes
    # apart reported 12,424 and 14,879 definitions). Fixed 2026-09-04.
    everything = [p for p in ROOT.rglob("*.gd")
                  if not any(part in _NON_PROJECT for part in p.parts)]
    defined: set[str] = set()
    for p in everything:
        defined.update(re.findall(r"^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)",
                                  p.read_text(encoding="utf-8", errors="replace"), re.M))

    hits: dict[str, list[str]] = {}
    for p in scope.rglob("*.gd"):
        rel = p.relative_to(ROOT).as_posix()
        text = p.read_text(encoding="utf-8", errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            for m in re.finditer(r'has_method\(\s*&?"([A-Za-z_]\w*)"', line):
                name = m.group(1)
                if name not in defined and name not in ENGINE:
                    hits.setdefault(name, []).append("%s:%d" % (rel, i))

    new = {k: v for k, v in hits.items() if k not in ALLOWLIST}
    stale = sorted(set(ALLOWLIST) - set(hits))

    print("scope=%s | %d func names defined repo-wide" % (
        scope.relative_to(ROOT).as_posix(), len(defined)))
    print("dead has_method guards: %d total, %d allowlisted, %d NEW"
          % (len(hits), len(hits) - len(new), len(new)))

    if stale:
        print("\nSTALE allowlist entries (the guard is gone — delete these):")
        for name in stale:
            print("  %s" % name)

    if not new:
        print("\nCLEAN — no new permanently-false has_method guards.")
        return 0

    print("\nNEW permanently-false guards. `func <name>` has ZERO definitions "
          "repo-wide, so each branch can never be taken:")
    for name in sorted(new):
        print("  %-40s %s" % (name, ", ".join(new[name][:3])))
    print("\nFix the call (grep `func <name>` for the real accessor), delete the "
          "dead branch, or add the name to ALLOWLIST with evidence.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
