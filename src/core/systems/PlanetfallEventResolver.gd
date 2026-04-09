class_name PlanetfallEventResolver
extends RefCounted

## Resolves D100/D6/2D6 table lookups for Planetfall turn events.
## Loads JSON data from data/planetfall/ and provides typed resolve methods
## for each table: colony events, enemy activity, character events,
## injuries, replacements, and scout discoveries.
## Source: Planetfall pp.58-71

var _colony_events: Array = []
var _enemy_activity: Array = []
var _character_events: Array = []
var _injury_table: Array = []
var _grunt_casualty_data: Dictionary = {}
var _replacement_table: Array = []
var _replacement_rules: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	_colony_events = _load_json_entries(
		"res://data/planetfall/colony_events.json", "entries")
	_enemy_activity = _load_json_entries(
		"res://data/planetfall/enemy_activity.json", "entries")
	_character_events = _load_json_entries(
		"res://data/planetfall/pf_character_events.json", "entries")

	var injury_data: Dictionary = _load_json(
		"res://data/planetfall/injury_table.json")
	_injury_table = injury_data.get("character_injuries", [])
	_grunt_casualty_data = injury_data.get("grunt_casualties", {})

	var replacement_data: Dictionary = _load_json(
		"res://data/planetfall/replacement_table.json")
	_replacement_table = replacement_data.get("replacement_roll", [])
	_replacement_rules = replacement_data.get("replacement_rules", {})

	_loaded = not _colony_events.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallEventResolver: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallEventResolver: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


func _load_json_entries(path: String, key: String) -> Array:
	var data: Dictionary = _load_json(path)
	return data.get(key, [])


## ============================================================================
## D100 TABLE LOOKUPS
## ============================================================================

func resolve_colony_event(roll: int) -> Dictionary:
	## Resolve a D100 colony event. Returns the matching entry or empty dict.
	## Planetfall pp.63-64.
	return _lookup_d100(_colony_events, roll)


func resolve_enemy_activity(roll: int) -> Dictionary:
	## Resolve a D100 enemy activity. Planetfall p.62.
	return _lookup_d100(_enemy_activity, roll)


func resolve_character_event(roll: int) -> Dictionary:
	## Resolve a D100 character event. Planetfall pp.70-71.
	return _lookup_d100(_character_events, roll)


func resolve_injury(roll: int) -> Dictionary:
	## Resolve a D100 injury result. Planetfall p.66.
	return _lookup_d100(_injury_table, roll)


func resolve_grunt_casualty(roll: int) -> Dictionary:
	## Resolve a D6 grunt casualty roll. Planetfall p.66.
	## Returns {permanent: bool, description: String}.
	var perm_range: Dictionary = _grunt_casualty_data.get("permanent_range", {})
	var perm_min: int = perm_range.get("min", 1)
	var perm_max: int = perm_range.get("max", 2)
	if roll >= perm_min and roll <= perm_max:
		return {
			"permanent": true,
			"description": _grunt_casualty_data.get(
				"permanent_description", "Permanent casualty.")
		}
	return {
		"permanent": false,
		"description": _grunt_casualty_data.get(
			"okay_description", "Okay, recovers for next mission.")
	}


func resolve_replacement(roll_2d6: int) -> Dictionary:
	## Resolve a 2D6 replacement roll. Planetfall p.69.
	## Returns the matching entry with result type.
	for entry in _replacement_table:
		if entry is Dictionary:
			var entry_min: int = entry.get("min", 0)
			var entry_max: int = entry.get("max", 0)
			if roll_2d6 >= entry_min and roll_2d6 <= entry_max:
				return entry.duplicate()
	return {"result": "none", "description": "No replacement available."}


func resolve_replacement_class(roll_d6: int) -> String:
	## For random_class replacement result, determine class from D6.
	## 1-2: trooper, 3-4: scientist, 5-6: scout. Planetfall p.69.
	if roll_d6 <= 2:
		return "trooper"
	elif roll_d6 <= 4:
		return "scientist"
	return "scout"


## ============================================================================
## DICE ROLLING HELPERS
## ============================================================================

func roll_d100() -> int:
	return randi_range(1, 100)


func roll_d6() -> int:
	return randi_range(1, 6)


func roll_2d6() -> int:
	return randi_range(1, 6) + randi_range(1, 6)


func roll_1d3() -> int:
	return randi_range(1, 3)


## ============================================================================
## PRIVATE — TABLE LOOKUP
## ============================================================================

func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			var entry_min: int = entry.get("min", 0)
			var entry_max: int = entry.get("max", 0)
			if roll >= entry_min and roll <= entry_max:
				return entry.duplicate()
	return {}


## ============================================================================
## ACCESSORS
## ============================================================================

func is_loaded() -> bool:
	return _loaded


func get_colony_events() -> Array:
	return _colony_events


func get_enemy_activity_table() -> Array:
	return _enemy_activity


func get_character_events() -> Array:
	return _character_events


func get_replacement_rules() -> Dictionary:
	return _replacement_rules
