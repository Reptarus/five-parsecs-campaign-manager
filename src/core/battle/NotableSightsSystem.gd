class_name NotableSightsSystem
extends RefCounted

## Notable Sights D100 roller — consumes data/notable_sights.json (Core Rules p.88)
##
## Roll on the correct column based on mission type (opportunity_patron, rival, quest).
## Not used during Invasion battles.
## Usage:
##   var system := NotableSightsSystem.new()
##   var result: Dictionary = system.roll_notable_sight("opportunity_patron")
##   # result = { "key": "LOOT_CACHE", "name": "Loot Cache", "instruction": "..." }

const DATA_PATH := "res://data/notable_sights.json"

var _data: Dictionary = {}

func _init() -> void:
	_load_data()

func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("NotableSightsSystem: %s not found" % DATA_PATH)
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("NotableSightsSystem: Failed to parse %s" % DATA_PATH)
		return
	if json.data is Dictionary:
		_data = json.data

func is_loaded() -> bool:
	return not _data.is_empty()

func is_excluded(mission_type: String) -> bool:
	## Returns true if notable sights are excluded for this mission type (e.g. INVASION)
	var exclusions: Array = _data.get("exclusions", [])
	return mission_type.to_upper() in exclusions

func get_placement_rules() -> Dictionary:
	## Returns placement rules: distance, direction, acquisition method
	return _data.get("placement", {})

func roll_notable_sight(column: String) -> Dictionary:
	## Roll D100 on the specified column and return the sight result.
	## column: "opportunity_patron", "rival", or "quest"
	## Returns: { "key": "SIGHT_KEY", "name": "...", "instruction": "..." }
	## Returns empty dict if no notable sight or column not found.
	var columns: Dictionary = _data.get("columns", {})
	var col_data: Dictionary = columns.get(column, {})
	var entries: Array = col_data.get("entries", [])
	if entries.is_empty():
		push_warning("NotableSightsSystem: Column '%s' not found or empty" % column)
		return {}

	var roll: int = (randi() % 100) + 1  # 1-100
	var result_key: String = ""
	for entry in entries:
		var roll_range: Array = entry.get("roll_range", [])
		if roll_range.size() == 2:
			if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
				result_key = entry.get("result", "")
				break

	if result_key.is_empty() or result_key == "NOTHING":
		return {}

	# Look up the sight effect details
	var effects: Dictionary = _data.get("sight_effects", {})
	var effect: Dictionary = effects.get(result_key, {})
	return {
		"key": result_key,
		"name": effect.get("name", result_key),
		"instruction": effect.get("instruction", ""),
		"roll": roll
	}

func get_mission_column(is_patron: bool, is_rival: bool, is_quest: bool) -> String:
	## Determine the correct column from mission flags.
	if is_quest:
		return "quest"
	if is_rival:
		return "rival"
	return "opportunity_patron"
