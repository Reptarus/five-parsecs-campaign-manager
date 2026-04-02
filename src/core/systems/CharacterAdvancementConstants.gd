class_name CharacterAdvancementConstants
## Character Advancement Constants for Five Parsecs Campaign Manager
## Data loaded from res://data/character_advancement.json (Core Rules pp.67-76)
##
## Usage: Reference these constants in CharacterManager and advancement systems
## Architecture: Lazy-loads JSON data, keeps static helper API

const _DATA_PATH := "res://data/character_advancement.json"

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("CharacterAdvancementConstants: Failed to open %s" % _DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	else:
		push_error("CharacterAdvancementConstants: Failed to parse %s" % _DATA_PATH)
	file.close()


## Backward-compatible property accessors

static var ADVANCEMENT_COSTS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("advancement_costs", {})

static var BASE_STAT_MAXIMUMS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("base_stat_maximums", {})

static var BACKGROUND_RESTRICTIONS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("background_restrictions", {})

static var SPECIES_RESTRICTIONS: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("species_restrictions", {})

static var MIN_ADVANCEMENT_XP: int:
	get:
		_ensure_loaded()
		return int(_data.get("min_advancement_xp", 5))

static var ABSOLUTE_STAT_MAX: int:
	get:
		_ensure_loaded()
		return int(_data.get("absolute_stat_max", 8))


## Helper functions (unchanged public API)

static func get_advancement_cost(stat: String) -> int:
	return ADVANCEMENT_COSTS.get(stat.to_lower(), 999)

static func get_stat_maximum(
	stat: String, character_data: Dictionary
) -> int:
	var stat_lower: String = stat.to_lower()

	if stat_lower == "toughness":
		var background: String = character_data.get("background", "")
		var bg_restrictions: Dictionary = BACKGROUND_RESTRICTIONS
		if bg_restrictions.has(background) and bg_restrictions[background].has("toughness"):
			return bg_restrictions[background]["toughness"]
		return BASE_STAT_MAXIMUMS.get("toughness", ABSOLUTE_STAT_MAX)

	if stat_lower == "luck":
		var species: String = character_data.get("species", "Human")
		var sp_restrictions: Dictionary = SPECIES_RESTRICTIONS
		if sp_restrictions.has(species) and sp_restrictions[species].has("luck"):
			return sp_restrictions[species]["luck"]
		if sp_restrictions.has("non_human_default"):
			return sp_restrictions["non_human_default"].get("luck", 1)
		return 1

	return BASE_STAT_MAXIMUMS.get(stat_lower, ABSOLUTE_STAT_MAX)

static func can_advance_stat(
	character_data: Dictionary, stat: String
) -> bool:
	var current_xp: int = character_data.get("experience", 0)
	var cost: int = get_advancement_cost(stat)
	var current_value: int = character_data.get(stat, 0)
	var max_value: int = get_stat_maximum(stat, character_data)
	return current_xp >= cost and current_value < max_value

static func get_available_advancements(
	character_data: Dictionary,
) -> Array[String]:
	var available: Array[String] = []
	for stat in ADVANCEMENT_COSTS.keys():
		if can_advance_stat(character_data, stat):
			available.append(stat)
	return available
