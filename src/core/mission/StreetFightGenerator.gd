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
## Key mechanics:
##   - Suspect markers placed on buildings (3-6 markers)
##   - Building types rolled per marker (D6)
##   - Identification: Move within 4" with LoS, spend 1 action
##   - Police response timer: D6 each round, accumulates
##   - Evasion: D6+Savvy to avoid police when fleeing


## ============================================================================
## STREET FIGHT OBJECTIVES (D100 table)
## ============================================================================

const STREET_FIGHT_OBJECTIVES: Array[Dictionary] = [
	{
		"roll_min": 1, "roll_max": 20,
		"id": "gang_raid",
		"name": "Gang Raid",
		"description": "Eliminate a gang presence in the district.",
		"win_condition": "Eliminate all identified gang members or force them to flee.",
		"suspect_count": 5,
	},
	{
		"roll_min": 21, "roll_max": 35,
		"id": "protection_racket",
		"name": "Break Protection Racket",
		"description": "Locate and confront the racket enforcers.",
		"win_condition": "Identify and eliminate/capture the racket leader (marked suspect).",
		"suspect_count": 4,
	},
	{
		"roll_min": 36, "roll_max": 50,
		"id": "bounty_hunt",
		"name": "Street Bounty Hunt",
		"description": "Track down a target hiding in the district.",
		"win_condition": "Identify the target among suspects and move them off-table.",
		"suspect_count": 6,
	},
	{
		"roll_min": 51, "roll_max": 65,
		"id": "turf_war",
		"name": "Turf War",
		"description": "Claim territory from a rival gang.",
		"win_condition": "Control 3+ buildings (crew member inside, no enemies) by end of Round 6.",
		"suspect_count": 5,
	},
	{
		"roll_min": 66, "roll_max": 80,
		"id": "evidence_gathering",
		"name": "Evidence Gathering",
		"description": "Collect evidence from multiple locations.",
		"win_condition": "Search 3+ buildings (1 action per building) and extract.",
		"suspect_count": 4,
	},
	{
		"roll_min": 81, "roll_max": 100,
		"id": "ambush_response",
		"name": "Ambush Response",
		"description": "Respond to an ambush on a contact.",
		"win_condition": "Reach the contact (center marker) within 4 rounds and extract together.",
		"suspect_count": 5,
	},
]


## ============================================================================
## BUILDING TYPES (D6 per suspect marker)
## ============================================================================

const BUILDING_TYPES: Array[Dictionary] = [
	{"roll": 1, "name": "Hab Block", "cover": "heavy", "floors": 2, "instruction": "HAB BLOCK: 2 floors, heavy cover. May contain civilians."},
	{"roll": 2, "name": "Shop Front", "cover": "light", "floors": 1, "instruction": "SHOP FRONT: 1 floor, light cover. Glass windows (destructible)."},
	{"roll": 3, "name": "Warehouse", "cover": "heavy", "floors": 1, "instruction": "WAREHOUSE: 1 floor, heavy cover. Large open interior, crates for cover."},
	{"roll": 4, "name": "Bar / Cantina", "cover": "moderate", "floors": 1, "instruction": "BAR/CANTINA: 1 floor, moderate cover. Tables and bar for cover."},
	{"roll": 5, "name": "Office Block", "cover": "moderate", "floors": 3, "instruction": "OFFICE BLOCK: 3 floors, moderate cover. Multiple rooms per floor."},
	{"roll": 6, "name": "Alleyway", "cover": "light", "floors": 0, "instruction": "ALLEYWAY: Narrow passage, light cover. Dumpsters and debris."},
]


## ============================================================================
## SUSPECT IDENTIFICATION (D6 when identified)
## ============================================================================

const SUSPECT_IDENTITY: Array[Dictionary] = [
	{"roll": 1, "id": "civilian", "name": "Civilian", "hostile": false, "instruction": "IDENTIFIED: Civilian. No threat. Moves away next round."},
	{"roll": 2, "id": "civilian_panicked", "name": "Panicked Civilian", "hostile": false, "instruction": "IDENTIFIED: Panicked Civilian. Runs D6\" in random direction each round."},
	{"roll": 3, "id": "gang_basic", "name": "Gang Member", "hostile": true, "instruction": "IDENTIFIED: Gang Member! Combat +0, Toughness 3, Pistol. Hostile!"},
	{"roll": 4, "id": "gang_armed", "name": "Armed Gang Member", "hostile": true, "instruction": "IDENTIFIED: Armed Gang Member! Combat +1, Toughness 4, Auto Rifle. Hostile!"},
	{"roll": 5, "id": "gang_leader", "name": "Gang Lieutenant", "hostile": true, "instruction": "IDENTIFIED: Gang Lieutenant! Combat +1, Toughness 4, Shotgun + Blade. Hostile!"},
	{"roll": 6, "id": "target", "name": "Target / VIP", "hostile": false, "instruction": "IDENTIFIED: TARGET FOUND! This is the objective. Secure immediately."},
]


## ============================================================================
## POLICE RESPONSE TABLE
## ============================================================================

const POLICE_RESPONSE_TEXT: Array[String] = [
	"POLICE: No response yet. Tension building.",
	"POLICE: Sirens in the distance. Response imminent.",
	"POLICE: Police arriving! D3 enforcers deploy at random table edge next round.",
	"POLICE: Full response! D6 enforcers deploy. All crew gain 'Wanted' status if still present.",
]


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
	if not FileAccess.file_exists(path):
		return
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

## Enrich a const-based roll result with canonical JSON description.
## section_key supports dot-traversal: "suspect_markers.identification"
static func _enrich_from_ref(section_key: String, match_field: String,
		match_value, result: Dictionary) -> Dictionary:
	if _ref_data.is_empty():
		return result
	var sf: Dictionary = _ref_data.get("special_missions", {})
	sf = sf.get("street_fights", {})
	# Traverse dotted path
	for key in section_key.split("."):
		sf = sf.get(key, {})
		if sf.is_empty():
			return result
	var table: Array = sf.get("table", [])
	for entry in table:
		if entry.get(match_field, null) == match_value:
			if entry.has("result"):
				result["canonical_text"] = entry["result"]
			if entry.has("description"):
				result["canonical_description"] = entry["description"]
			if entry.has("action"):
				result["canonical_action"] = entry["action"]
			break
	return result


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
## ============================================================================

static func generate_street_fight() -> Dictionary:
	if not _is_enabled():
		return {}

	_ensure_ref_loaded()
	var objective := _roll_objective()
	var buildings: Array[Dictionary] = []
	for i in range(objective.suspect_count):
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
	var roll := randi_range(1, 100)
	for obj in STREET_FIGHT_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			return _enrich_from_ref("objectives", "objective",
				obj.get("name", ""), obj.duplicate())
	return STREET_FIGHT_OBJECTIVES[0].duplicate()


static func _roll_building() -> Dictionary:
	var roll := randi_range(1, 6)
	for b in BUILDING_TYPES:
		if b.roll == roll:
			return b
	return BUILDING_TYPES[0]


static func roll_suspect_identity() -> Dictionary:
	_ensure_ref_loaded()
	var roll := randi_range(1, 6)
	for s in SUSPECT_IDENTITY:
		if s.roll == roll:
			return _enrich_from_ref("suspect_markers.identification", "roll",
				roll, s.duplicate())
	return SUSPECT_IDENTITY[0].duplicate()


## ============================================================================
## INSTRUCTION TEXT GENERATION
## ============================================================================

static func generate_setup_instructions(mission: Dictionary) -> String:
	var obj: Dictionary = mission.get("objective", {})
	var buildings: Array = mission.get("buildings", [])

	var lines: Array[String] = [
		"[b]STREET FIGHT SETUP[/b]",
		"",
		"[b]Objective:[/b] %s" % obj.get("name", "Unknown"),
		obj.get("description", ""),
		"",
		"[b]Table Setup:[/b]",
		"  - Dense urban terrain: buildings, alleys, streets",
		"  - Place %d suspect markers on buildings:" % buildings.size(),
	]

	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		lines.append("    Marker %d: %s" % [i + 1, b.get("instruction", "")])

	lines.append_array([
		"",
		"[b]Crew Deployment:[/b] Within 6\" of your table edge.",
		"",
		"[b]Identification:[/b] Move within 4\" with LoS, spend 1 action. Roll D6 for identity.",
		"",
		"[b]Police Response:[/b] After any weapon is fired, police timer starts.",
		"  Round after first shot: Roll D6. On 5+, police arrive.",
		"  Each subsequent round: Threshold decreases by 1 (4+, 3+, 2+, auto).",
		"",
		"[b]Win Condition:[/b] %s" % obj.get("win_condition", "Complete the objective."),
	])

	return "\n".join(lines)


static func generate_round_instructions(round_num: int, police_timer: int) -> String:
	var lines: Array[String] = [
		"[b]STREET FIGHT ROUND %d[/b]" % round_num,
		"",
		"[b]Actions:[/b]",
		"  - Move + Action (standard combat rules)",
		"  - Identify suspect: Move within 4\" with LoS, 1 action, roll D6",
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
