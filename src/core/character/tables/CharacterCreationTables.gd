@tool
class_name CharacterCreationTables
extends RefCounted

## Five Parsecs character creation table management system
## Implements d66 and d6 table lookups for character background events,
## motivations, and quirks following Core Rules pp.14-17

# Safe imports using Universal Safety System
const UniversalResourceLoader := preload("res://src/core/systems/UniversalResourceLoader.gd")
const UniversalDataAccess := preload("res://src/core/systems/UniversalDataAccess.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Cached table data - loaded once for performance
static var _background_events: Dictionary = {}
static var _motivation_table: Dictionary = {}
static var _quirks_table: Dictionary = {}
static var _tables_loaded: bool = false

## Roll background event using d66 (Core Rules p.14-15)
static func roll_background_event(background: GlobalEnums.Background) -> Dictionary:
	_ensure_tables_loaded()

	# Get DiceManager safely through autoload
	var dice_manager: Node = Engine.get_singleton("DiceManager")
	if not dice_manager or not dice_manager.has_method("roll_d66"):
		push_error("CharacterCreationTables: DiceManager not available")
		return {"event": "Default background", "effect": "None"}

	var roll: int = dice_manager.roll_d66("Background Event")

	# Convert background enum to string key safely
	var background_key: String = _safe_get_background_name(background)
	var events: Dictionary = _background_events.get(background_key, {})

	return _lookup_table_result(events, roll, "background_event")

## Roll character motivation (Core Rules p.16)
static func roll_motivation() -> Dictionary:
	_ensure_tables_loaded()

	var dice_manager: Node = Engine.get_singleton("DiceManager")
	if not dice_manager or not dice_manager.has_method("roll_d66"):
		push_error("CharacterCreationTables: DiceManager not available")
		return {"name": "Survival", "description": "Basic survival instinct", "bonus": "None"}

	var roll: int = dice_manager.roll_d66("Character Motivation")
	return _lookup_table_result(_motivation_table, roll, "motivation")

## Roll character quirk/trait
static func roll_character_quirk() -> Dictionary:
	_ensure_tables_loaded()

	var dice_manager: Node = Engine.get_singleton("DiceManager")
	if not dice_manager or not dice_manager.has_method("roll_d6"):
		push_error("CharacterCreationTables: DiceManager not available")
		return {"name": "Reliable", "effect": "No special effect"}

	var roll: int = dice_manager.roll_d6("Character Quirk")
	return _lookup_table_result(_quirks_table, roll, "quirk")

## Get background event without rolling (for testing)
static func get_background_event(background: GlobalEnums.Background, roll: int) -> Dictionary:
	_ensure_tables_loaded()

	var background_key: String = _safe_get_background_name(background)
	var events: Dictionary = _background_events.get(background_key, {})

	return _lookup_table_result(events, roll, "background_event")

## Get motivation without rolling (for testing)
static func get_motivation(roll: int) -> Dictionary:
	_ensure_tables_loaded()
	return _lookup_table_result(_motivation_table, roll, "motivation")

## Get quirk without rolling (for testing)
static func get_character_quirk(roll: int) -> Dictionary:
	_ensure_tables_loaded()
	return _lookup_table_result(_quirks_table, roll, "quirk")

## Load all table data safely
static func _ensure_tables_loaded() -> void:
	if _tables_loaded:
		return

	# Load background events table
	var bg_path := "res://data/character_creation_tables/background_events.json"
	_background_events = UniversalResourceLoader.load_json_safe(bg_path, "CharacterCreationTables background events")

	# Load motivation table
	var motivation_path := "res://data/character_creation_tables/motivation_table.json"
	_motivation_table = UniversalResourceLoader.load_json_safe(motivation_path, "CharacterCreationTables motivation table")

	# Load quirks table
	var quirks_path := "res://data/character_creation_tables/quirks_table.json"
	_quirks_table = UniversalResourceLoader.load_json_safe(quirks_path, "CharacterCreationTables quirks table")

	_tables_loaded = true

	# Log successful loading
	print("CharacterCreationTables: Loaded tables - Background events: ", _background_events.size(), " backgrounds")
	print("CharacterCreationTables: Loaded tables - Motivations: ", _motivation_table.size(), " entries")
	print("CharacterCreationTables: Loaded tables - Quirks: ", _quirks_table.size(), " entries")

## Safe background name getter with error handling
static func _safe_get_background_name(background: GlobalEnums.Background) -> String:
	var bg_index: int = int(background)
	var keys: Array = GlobalEnums.Background.keys()
	var name: String = keys[bg_index] if bg_index >= 0 and bg_index < keys.size() else ""
	if not name.is_empty():
		return name.to_lower()
	else:
		push_warning("CharacterCreationTables: Invalid background enum: " + str(background))
		return "unknown"

## Lookup table result with d66/d6 range support
static func _lookup_table_result(table_data: Dictionary, roll: int, context: String) -> Dictionary:
	var roll_str := str(roll)

	# Direct match first
	if table_data.has(roll_str):
		return table_data[roll_str]

	# Range matching for d66 tables (e.g. "11-16" or "21-26")
	for key: String in table_data.keys():
		if "-" in key:
			var parts: PackedStringArray = key.split("-")
			if parts.size() == 2:
				var min_val: int = parts[0].to_int()
				var max_val: int = parts[1].to_int()
				if roll >= min_val and roll <= max_val:
					return table_data[key]

	# Fallback result
	push_warning("CharacterCreationTables: No table entry found for roll %d in %s" % [roll, context])
	return {"result": "No result found", "effect": "None"}

## Validate all tables are properly loaded
static func validate_tables() -> bool:
	_ensure_tables_loaded()

	var is_valid := true

	# Check background events
	if _background_events.is_empty():
		push_error("CharacterCreationTables: Background events table is empty")
		is_valid = false

	# Check motivation table
	if _motivation_table.is_empty():
		push_error("CharacterCreationTables: Motivation table is empty")
		is_valid = false

	# Check quirks table  
	if _quirks_table.is_empty():
		push_error("CharacterCreationTables: Quirks table is empty")
		is_valid = false

	if is_valid:
		print("CharacterCreationTables: All tables validated successfully")

	return is_valid

## Force reload tables (for development/testing)
static func reload_tables() -> void:
	_tables_loaded = false
	_background_events.clear()
	_motivation_table.clear()
	_quirks_table.clear()
	_ensure_tables_loaded()

## Get all available backgrounds
static func get_available_backgrounds() -> Array[String]:
	_ensure_tables_loaded()
	return _background_events.keys()

## Get table statistics for debugging
static func get_table_statistics() -> Dictionary:
	_ensure_tables_loaded()

	var stats := {
		"background_events": {},
		"motivation_entries": _motivation_table.size(),
		"quirk_entries": _quirks_table.size()
	}

	# Count entries per background
	for bg_key: String in _background_events.keys():
		var bg_data = _background_events[bg_key]
		if bg_data is Dictionary:
			stats.background_events[bg_key] = bg_data.size()

	return stats
