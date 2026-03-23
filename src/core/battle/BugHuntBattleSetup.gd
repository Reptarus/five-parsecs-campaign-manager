class_name BugHuntBattleSetup
extends RefCounted

## Generates Bug Hunt battle parameters from mission context.
## Creates contact markers, tactical locations, spawn points,
## and battle context for TacticalBattleUI.

const TACTICAL_LOCATIONS_PATH := "res://data/bug_hunt/bug_hunt_tactical_locations.json"
const SPAWN_RULES_PATH := "res://data/bug_hunt/bug_hunt_spawn_rules.json"
const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"
const ARMOR_PATH := "res://data/bug_hunt/bug_hunt_armor.json"
const GEAR_PATH := "res://data/bug_hunt/bug_hunt_gear.json"

var _tactical_data: Dictionary = {}
var _spawn_data: Dictionary = {}
var _weapons_data: Dictionary = {}
var _armor_data: Dictionary = {}
var _gear_data: Dictionary = {}


func _init() -> void:
	_tactical_data = _load_json(TACTICAL_LOCATIONS_PATH)
	_spawn_data = _load_json(SPAWN_RULES_PATH)
	_weapons_data = _load_json(WEAPONS_PATH)
	_armor_data = _load_json(ARMOR_PATH)
	_gear_data = _load_json(GEAR_PATH)


func generate_battle_context(mission_context: Dictionary, campaign: Resource = null) -> Dictionary:
	## Build a complete battle context dict for TacticalBattleUI.
	var priority: int = mission_context.get("priority", 1)
	var spawn_rating: int = mission_context.get("spawn_rating", 1)
	var contact_count: int = mission_context.get("contact_markers", 4)
	var objective: Dictionary = mission_context.get("objective", {})

	# Generate contact marker positions (4 sectors of a 4x4 grid)
	var contact_markers: Array = _generate_contact_markers(contact_count)

	# Generate tactical locations (D6 per mission, typically 2-4)
	var tactical_locations: Array = _generate_tactical_locations()

	# Generate spawn points
	var spawn_points: Array = _generate_spawn_points(spawn_rating)

	return {
		"battle_mode": "bug_hunt",
		"no_morale": true,
		"priority": priority,
		"spawn_rating": spawn_rating,
		"objective": objective,
		"contact_markers": contact_markers,
		"tactical_locations": tactical_locations,
		"spawn_points": spawn_points,
		"terrain_theme": "indoor",  # Bug Hunt is typically indoor/facility
		"contact_table_rules": _spawn_data.get("contact_table", {}),
		"aggression_dice": _spawn_data.get("aggression_dice", {}),
		"chance_dice": _spawn_data.get("chance_dice", {}),
		"weapons_table": _weapons_data.get("weapons", []),
		"armor_table": _armor_data.get("armor", []),
		"gear_table": _gear_data.get("gear", [])
	}

## Look up weapon stats by ID from bug_hunt_weapons.json
func get_weapon(weapon_id: String) -> Dictionary:
	for weapon in _weapons_data.get("weapons", []):
		if weapon.get("id", "") == weapon_id:
			return weapon
	return {}

## Look up armor stats by ID from bug_hunt_armor.json
func get_armor(armor_id: String) -> Dictionary:
	for armor in _armor_data.get("armor", []):
		if armor.get("id", "") == armor_id:
			return armor
	return {}


func _generate_contact_markers(count: int) -> Array:
	## Place contact markers in random sectors.
	var markers: Array = []
	# Bug Hunt uses a 4x4 sector grid (16 sectors)
	var available_sectors: Array = []
	for r in range(4):
		for c in range(4):
			available_sectors.append({"row": r, "col": c})

	# Shuffle and pick
	available_sectors.shuffle()
	for i in range(mini(count, available_sectors.size())):
		markers.append({
			"id": "contact_%d" % (i + 1),
			"sector": available_sectors[i],
			"revealed": false,
			"enemy_type": "",
			"enemy_count": 0
		})

	return markers


func _generate_tactical_locations() -> Array:
	## Roll for tactical locations present on the battlefield.
	var location_types: Array = _tactical_data.get("tactical_location_types", [])
	if location_types.is_empty():
		return []

	var locations: Array = []
	var num_locations: int = (randi() % 4) + 1  # 1-4 locations

	for i in range(num_locations):
		var loc: Dictionary = location_types[randi() % location_types.size()]
		locations.append({
			"id": "tac_loc_%d" % (i + 1),
			"type": loc.get("id", ""),
			"name": loc.get("name", "Unknown"),
			"effect": loc.get("effect", ""),
			"activation": loc.get("activation", ""),
			"activated": false,
			"sector": {"row": randi() % 4, "col": randi() % 4}
		})

	return locations


func _generate_spawn_points(spawn_rating: int) -> Array:
	## Generate spawn points based on spawn rating.
	var points: Array = []
	var spawn_config: Dictionary = _spawn_data.get("spawn_points", {})
	var base_count: int = spawn_config.get("base_count", 2)
	var total: int = base_count + spawn_rating

	# Place spawn points along map edges (Bug Hunt convention)
	for i in range(total):
		var edge: int = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
		var pos: Dictionary = {}
		match edge:
			0: pos = {"row": 0, "col": randi() % 4}
			1: pos = {"row": randi() % 4, "col": 3}
			2: pos = {"row": 3, "col": randi() % 4}
			3: pos = {"row": randi() % 4, "col": 0}

		points.append({
			"id": "spawn_%d" % (i + 1),
			"sector": pos,
			"active": true
		})

	return points


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data
	file.close()
	return {}
