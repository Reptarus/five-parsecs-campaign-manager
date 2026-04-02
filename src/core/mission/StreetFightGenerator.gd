class_name StreetFightGenerator
extends RefCounted
## Street Fight Generator - Urban combat mission type from the Compendium
##
## Generates street fight missions with suspect markers, building types,
## identification mechanics, police response timers, and evasion.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STREET_FIGHTS.
##
## CANONICAL DATA: CompendiumStreetFights (src/data/compendium_street_fights.gd)
## This generator adds orchestration and text formatting on top of the compendium data layer.
##
## Key mechanics:
##   - Suspect markers placed on buildings (crew size markers)
##   - Building types rolled per marker (D6)
##   - Identification: Within LoS and (4 + Savvy) inches
##   - Police response timer: D6 each round, accumulates
##   - Evasion: D6+Savvy to avoid police when fleeing


## ============================================================================
## POLICE RESPONSE TEXT (generator-only instruction data)
## ============================================================================

## Police response text loaded from StealthAndStreet.json
static var POLICE_RESPONSE_TEXT: Array: # @no-lint:variable-name
	get:
		_ensure_ref_loaded()
		var a: Array = _ref_data.get("police_response", [])
		if a.is_empty():
			return ["POLICE: Response data unavailable."]
		return a


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/StealthAndStreet.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

static func get_ref_data() -> Dictionary:
	_ensure_ref_loaded()
	return _ref_data

static func get_street_fight_rules() -> Dictionary:
	_ensure_ref_loaded()
	var missions: Dictionary = _ref_data.get("special_missions", {})
	return missions.get("street_fights", {})


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STREET_FIGHTS)


## ============================================================================
## MISSION GENERATION
## Delegates to CompendiumStreetFights for canonical data tables.
## ============================================================================

static func generate_street_fight() -> Dictionary:
	if not _is_enabled():
		return {}

	_ensure_ref_loaded()
	var objective := _roll_objective()
	# Compendium doesn't specify per-objective suspect count; use crew size per deployment rules
	var suspect_count: int = 6  # Default; actual count set by deployment rules (= crew size)
	var buildings: Array[Dictionary] = []
	for i in range(suspect_count):
		buildings.append(_roll_building())

	return {
		"type": "street_fight",
		"objective": objective,
		"buildings": buildings,
		"suspects_identified": 0,
		"police_timer": 0,
		"current_round": 0,
	}


static func _roll_objective() -> Dictionary:
	var result := CompendiumStreetFights.roll_objective()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 100)
	for obj in CompendiumStreetFights.STREET_FIGHT_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			return obj.duplicate()
	return CompendiumStreetFights.STREET_FIGHT_OBJECTIVES[0].duplicate()


static func _roll_building() -> Dictionary:
	var result := CompendiumStreetFights.roll_building_type()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 6)
	for b in CompendiumStreetFights.BUILDING_TYPES:
		if roll >= b.roll_min and roll <= b.roll_max:
			return b.duplicate()
	return CompendiumStreetFights.BUILDING_TYPES[0].duplicate()


static func roll_suspect_identity() -> Dictionary:
	var result := CompendiumStreetFights.roll_suspect_identification()
	if not result.is_empty():
		return result
	# Fallback
	var roll := randi_range(1, 6)
	for s in CompendiumStreetFights.SUSPECT_IDENTIFICATION:
		if roll >= s.roll_min and roll <= s.roll_max:
			return s.duplicate()
	return CompendiumStreetFights.SUSPECT_IDENTIFICATION[0].duplicate()


## ============================================================================
## INSTRUCTION TEXT GENERATION
## ============================================================================

static func generate_setup_instructions(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objective", {})
	var obj_name: String = obj.get("id", "unknown").replace("_", " ").capitalize()
	var buildings: Array = mission.get("buildings", [])

	var lines: Array[String] = [
		"[b]STREET FIGHT SETUP[/b]",
		"",
		"[b]Objective:[/b] %s" % obj_name,
		obj.get("instruction", ""),
		"",
		"[b]Deployment:[/b]",
		CompendiumStreetFights.DEPLOYMENT_RULES,
		"",
		"[b]Buildings (%d rolled):[/b]" % buildings.size(),
	]

	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		lines.append("    %d: %s" % [i + 1, b.get("instruction", b.get("name", "Unknown"))])

	lines.append_array([
		"",
		"[b]Identification:[/b] Move within (4\" + Savvy) with LoS. Roll D6 on Suspect table.",
		"",
		"[b]Police Response:[/b] After any weapon is fired, police timer starts.",
		"  Round after first shot: Roll D6. On 5+, police arrive.",
		"  Each subsequent round: Threshold decreases by 1 (4+, 3+, 2+, auto).",
	])

	if obj.get("has_individual", false):
		lines.append("")
		lines.append("[b]Individual:[/b]")
		lines.append(CompendiumStreetFights.INDIVIDUAL_RULES)

	return "\n".join(lines)


static func generate_round_instructions(round_num: int, police_timer: int) -> String:
	var lines: Array[String] = [
		"[b]STREET FIGHT ROUND %d[/b]" % round_num,
		"",
		"[b]Actions:[/b]",
		"  - Move + Action (standard combat rules)",
		"  - Identify suspect: Move within (4\" + Savvy) with LoS, roll D6",
		"  - Search building: Enter building, 1 action, roll D6 for contents",
		"",
	]

	if police_timer > 0:
		var threshold := maxi(2, 6 - police_timer)
		if police_timer >= 4:
			lines.append("[color=#DC2626][b]POLICE: Automatic response! D6 enforcers arrive.[/b][/color]")
		else:
			lines.append("[color=#D97706]POLICE CHECK: Roll D6. On %d+, police arrive.[/color]" % threshold)

	lines.append("")
	lines.append("[b]Evasion:[/b] To flee the area, crew must reach table edge.")
	lines.append("  If police are present: Roll D6+Savvy. 6+ = escape clean. Otherwise: +1 Rival (Enforcers).")

	return "\n".join(lines)
