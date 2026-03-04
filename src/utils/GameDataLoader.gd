class_name GameDataLoader
extends RefCounted

## GameDataLoader - JSON Data Table Integration Utility
## Loads and processes JSON data tables for Five Parsecs game systems
## Handles dice-based table lookups with range support (e.g., "2-6", "7-8")

## Load JSON file from data directory
## Returns parsed Dictionary or empty Dict on failure
static func load_json(json_path: String) -> Dictionary:
	var full_path = "res://data/" + json_path
	var file = FileAccess.open(full_path, FileAccess.READ)
	
	if not file:
		push_error("GameDataLoader: Failed to load JSON file: %s (Error: %d)" % [full_path, FileAccess.get_open_error()])
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("GameDataLoader: JSON parse error in %s at line %d: %s" % [full_path, json.get_error_line(), json.get_error_message()])
		return {}
	
	var data = json.get_data()
	
	if data is Dictionary:
		return data
	else:
		push_error("GameDataLoader: JSON root is not a Dictionary in %s" % full_path)
		return {}

## Roll on a dice table and return the result
## Handles both single values ("1": {...}) and ranges ("2-6": {...})
## 
## @param table_data: Dictionary with "dice_type" and "results" keys
## @param dice_result: The dice roll value (e.g., 3 for d6, 7 for 2d6)
## @return Dictionary: The result entry for the roll, or empty dict if not found
static func roll_on_table(table_data: Dictionary, dice_result: int) -> Dictionary:
	if not table_data.has("results"):
		push_error("GameDataLoader: Table data missing 'results' key")
		return {}
	
	var results = table_data.get("results", {})
	var dice_type = table_data.get("dice_type", "unknown")
	
	# First try exact match (e.g., "3")
	var exact_key = str(dice_result)
	if results.has(exact_key):
		var result = results[exact_key]
		if result is Dictionary:
			return result.duplicate()
		else:
			push_error("GameDataLoader: Result for '%s' is not a Dictionary" % exact_key)
			return {}
	
	# Then try range match (e.g., "2-6", "7-8")
	for key in results.keys():
		if "-" in key:
			var range_parts = key.split("-")
			if range_parts.size() == 2:
				var min_val = range_parts[0].to_int()
				var max_val = range_parts[1].to_int()
				
				if dice_result >= min_val and dice_result <= max_val:
					var result = results[key]
					if result is Dictionary:
						return result.duplicate()
					else:
						push_error("GameDataLoader: Result for range '%s' is not a Dictionary" % key)
						return {}
	
	# No match found
	push_warning("GameDataLoader: No result found for %s roll of %d (table type: %s)" % [dice_type, dice_result, dice_type])
	return {}

## Helper: Roll d6 using DiceSystem
## Falls back to randi_range if DiceSystem not available
static func roll_d6() -> int:
	var dice_system = _get_dice_system()
	if dice_system and dice_system.has_method("roll_dice"):
		var roll_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "GameDataLoader")
		return roll_result.total
	else:
		return randi_range(1, 6)

## Helper: Roll 2d6 using DiceSystem
static func roll_2d6() -> int:
	var dice_system = _get_dice_system()
	if dice_system and dice_system.has_method("roll_custom"):
		var roll_result = dice_system.roll_custom(2, 6, 0, "GameDataLoader")
		return roll_result.total
	else:
		return randi_range(1, 6) + randi_range(1, 6)

## Helper: Roll d10 using DiceSystem
static func roll_d10() -> int:
	var dice_system = _get_dice_system()
	if dice_system and dice_system.has_method("roll_dice"):
		var roll_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D10, "GameDataLoader")
		return roll_result.total
	else:
		return randi_range(1, 10)

## Helper: Roll d100 using DiceSystem
static func roll_d100() -> int:
	var dice_system = _get_dice_system()
	if dice_system and dice_system.has_method("roll_dice"):
		var roll_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D100, "GameDataLoader")
		return roll_result.total
	else:
		return randi_range(1, 100)

## Get DiceSystem autoload (cached lookup)
static func _get_dice_system() -> Node:
	# Try to get from SceneTree
	if Engine.get_main_loop() and Engine.get_main_loop() is SceneTree:
		var tree = Engine.get_main_loop() as SceneTree
		if tree.root:
			var dice_node = tree.root.get_node_or_null("/root/DiceSystem")
			if dice_node:
				return dice_node
			
			# Try OptimizedSystemsAutoload which might contain DiceSystem
			var systems = tree.root.get_node_or_null("/root/OptimizedSystemsAutoload")
			if systems and systems.has_method("get_dice_system"):
				return systems.get_dice_system()
	
	return null

## Load and cache battlefield finds table
static var _battlefield_finds_cache: Dictionary = {}
static func get_battlefield_finds_table() -> Dictionary:
	if _battlefield_finds_cache.is_empty():
		_battlefield_finds_cache = load_json("loot/battlefield_finds.json")
	return _battlefield_finds_cache

## Load and cache patron jobs table
static var _patron_jobs_cache: Dictionary = {}
static func get_patron_jobs_table() -> Dictionary:
	if _patron_jobs_cache.is_empty():
		_patron_jobs_cache = load_json("campaign_tables/world_phase/patron_jobs.json")
	return _patron_jobs_cache

## Load and cache ship components data
static var _ship_components_cache: Dictionary = {}
static func get_ship_components() -> Dictionary:
	if _ship_components_cache.is_empty():
		_ship_components_cache = load_json("ship_components.json")
	return _ship_components_cache

## Clear all caches (useful for testing or data reload)
static func clear_caches() -> void:
	_battlefield_finds_cache.clear()
	_patron_jobs_cache.clear()
	_ship_components_cache.clear()
