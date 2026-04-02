class_name CompendiumNoMinisCombat
extends RefCounted
## No-Minis Combat Resolution - Compendium pp.68-75 (book pp.66-73)
##
## Abstract battle resolution without miniatures. Allows campaign
## progression without a physical table. Can be mixed with tabletop battles.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.NO_MINIS_COMBAT.
##
## Book structure:
##   - Round phases: (1) Battle Flow Events (optional), (2) Initiative, (3) Firefight
##   - Locations: Suspected → Known via Scout action. 1 character per Location.
##   - Initiative: Roll one die LESS than normal. Captain + those ≤ Reactions get actions.
##   - Firefight: Randomly select 3 enemies (4 if 7+ total). Resolve one at a time.
##   - NOT compatible with: AI Variations, Escalating Battles, Deployment Variables


## ============================================================================
## JSON DATA LOADING
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/no_minis_combat.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumNoMinisCombat: Could not load no_minis_combat.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.NO_MINIS_COMBAT)


## ============================================================================
## INITIATIVE ACTIONS (Compendium p.70)
## Characters with die ≤ Reactions + Captain each get 1 Initiative Action.
## 2D6 Battlefield Tests where indicated. +1 bonus if character has a
## logically applicable ability/item.
## ============================================================================

static var INITIATIVE_ACTIONS: Array:
	get:
		_ensure_loaded()
		return _data.get("initiative_actions", [])


## ============================================================================
## FIREFIGHT RULES (Compendium pp.71-72)
## Main phase: randomly select 3 enemies (4 if 7+ total). Resolve one at a time.
## ============================================================================

static var FIREFIGHT_RULES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("firefight_rules", {})

static var FIREFIGHT_INSTRUCTION: String:
	get:
		_ensure_loaded()
		return _data.get("firefight_instruction", "")


## ============================================================================
## BATTLE FLOW EVENTS — D100 table (Compendium p.73, optional)
## Roll at beginning of each round. Actions do not prevent normal activation.
## ============================================================================

static var BATTLE_FLOW_EVENTS: Array:
	get:
		_ensure_loaded()
		return _data.get("battle_flow_events", [])


## ============================================================================
## MORALE & RETREAT (Compendium p.74)
## ============================================================================

static var MORALE_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("morale_rules", "")

static var RETREAT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("retreat_rules", "")


## ============================================================================
## MISSION-SPECIFIC NOTES (Compendium pp.74-75)
## ============================================================================

static var MISSION_NOTES: Array:
	get:
		_ensure_loaded()
		return _data.get("mission_notes", [])


## ============================================================================
## OPTIONAL VARIANTS (Compendium p.72)
## ============================================================================

static var HECTIC_COMBAT: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("hectic_combat", {})

static var FASTER_COMBAT: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("faster_combat", {})


## ============================================================================
## INCOMPATIBLE FLAGS (cannot combine with no-minis)
## ============================================================================

static var INCOMPATIBLE_FLAGS: Array:
	get:
		_ensure_loaded()
		return _data.get("incompatible_flags", [])


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Generate a no-minis battle setup. Returns empty if disabled.
static func generate_battle_setup(crew_size: int, enemy_count: int) -> Dictionary:
	if not _is_enabled():
		return {}

	# Firefight selects 3 enemies normally, 4 if 7+ total
	var firefight_count := 4 if enemy_count >= 7 else 3

	return {
		"type": "no_minis",
		"crew_size": crew_size,
		"enemy_count": enemy_count,
		"firefight_selection_count": firefight_count,
		"current_round": 0,
		"suspected_locations": [], # Filled by scenario
		"known_locations": [],
	}


## Generate setup instruction text.
static func generate_setup_text(battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var crew_size: int = battle.get("crew_size", 4)
	var enemy_count: int = battle.get("enemy_count", 6)
	var ff_count: int = battle.get("firefight_selection_count", 3)

	var lines: Array[String] = [
		"[b]NO-MINIS COMBAT SETUP[/b] (Compendium pp.68-75)",
		"",
		"[b]Crew:[/b] %d figures." % crew_size,
		"[b]Enemies:[/b] %d figures." % enemy_count,
		"",
		"[b]Round Phases:[/b]",
		"  1. Battle Flow Events (optional — roll D100)",
		"  2. Initiative (roll one die LESS than normal)",
		"  3. Firefight (select %d random enemies)" % ff_count,
		"",
		"[b]Initiative:[/b] Captain + characters with die <= Reactions each get 1 Initiative Action.",
		"  Characters above their Reactions are in the general firefight (no specific actions).",
		"  Available actions: Scout / Move Up / Carry Out Task / Charge / Optimal Shot / Support / Take Cover / Keep Distance",
		"",
		FIREFIGHT_INSTRUCTION,
		"",
		MORALE_RULES,
		"",
		RETREAT_RULES,
	]

	return "\n".join(lines)


## Generate round instruction text.
static func generate_round_text(round_num: int, _battle: Dictionary) -> String:
	if not _is_enabled():
		return ""

	var ff_count: int = _battle.get("firefight_selection_count", 3)

	var lines: Array[String] = [
		"[b]NO-MINIS ROUND %d[/b]" % round_num,
		"",
	]

	lines.append("[b]1. Battle Flow Event (optional):[/b] Roll D100 on Battle Flow Events table.")
	lines.append("")
	lines.append("[b]2. Initiative:[/b] Roll initiative (one die LESS than normal).")
	lines.append("   Captain + characters with die <= Reactions get 1 Initiative Action each.")
	lines.append("")
	lines.append("[b]3. Firefight:[/b] Randomly select %d enemies. Resolve one at a time." % ff_count)
	lines.append("   Each targets a random crew member. Player chooses resolution order.")
	lines.append("")
	lines.append("[b]4. End of Round:[/b] Remove casualties. Enemy morale test (regulars removed first). May retreat up to 2 crew (1D6 <= Speed = escape).")

	return "\n".join(lines)


## Roll a D100 battle flow event.
static func roll_battle_flow_event() -> Dictionary:
	if not _is_enabled():
		return {}
	var roll := randi_range(1, 100)
	for event in BATTLE_FLOW_EVENTS:
		if roll >= event.roll_min and roll <= event.roll_max:
			var result: Dictionary = event.duplicate()
			result["roll"] = roll
			return result
	return BATTLE_FLOW_EVENTS[0]


## Get mission-specific notes for a mission type.
static func get_mission_notes(mission_id: String) -> String:
	for note in MISSION_NOTES:
		if note.id == mission_id:
			return note.instruction
	return ""


## Check if a flag is incompatible with no-minis mode.
static func is_incompatible(flag_name: String) -> bool:
	return flag_name in INCOMPATIBLE_FLAGS


## Get hectic combat variant text.
static func get_hectic_combat_text() -> String:
	if not _is_enabled():
		return ""
	return HECTIC_COMBAT.instruction


## Get faster combat variant text.
static func get_faster_combat_text() -> String:
	if not _is_enabled():
		return ""
	return FASTER_COMBAT.instruction


## Get firefight rules instruction text.
static func get_firefight_rules() -> String:
	if not _is_enabled():
		return ""
	return FIREFIGHT_INSTRUCTION
