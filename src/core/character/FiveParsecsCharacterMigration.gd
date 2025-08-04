extends RefCounted
class_name FiveParsecsCharacterMigration

## Character System Migration Adapter
## Provides backward compatibility during character system consolidation
## Handles migration from legacy character creators to new factory pattern

const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacter = preload("res://src/core/character/FiveParsecsCharacter.gd")

## Migration entry point for legacy character data
static func migrate_character_data(legacy_data: Dictionary) -> Character:
	"""
	Migrate character data from legacy creators to new factory system
	Handles data from BaseCharacterCreationSystem, BaseCharacterCreator, SimpleCharacterCreator
	"""
	print("FiveParsecsCharacterMigration: Migrating legacy character data")
	
	var creator_type = legacy_data.get("creator_type", "unknown")
	var factory = FiveParsecsCharacter.new()
	
	match creator_type:
		"BaseCharacterCreationSystem", "FiveParsecsCharacterCreationSystem":
			return _migrate_from_base_system(legacy_data, factory)
		"SimpleCharacterCreator":
			return _migrate_from_simple_creator(legacy_data, factory)
		"BaseCharacterCreator":
			return _migrate_from_base_creator(legacy_data, factory)
		_:
			# Try generic migration for unknown formats
			return _migrate_generic_character_data(legacy_data, factory)

## Migration Methods for Specific Legacy Creators

static func _migrate_from_base_system(legacy_data: Dictionary, factory: FiveParsecsCharacter) -> Character:
	"""Migrate from BaseCharacterCreationSystem format"""
	var params = {
		"name": legacy_data.get("character_name", ""),
		"background": legacy_data.get("background", 0),
		"motivation": legacy_data.get("motivation", 0),
		"stats": {
			"combat": legacy_data.get("combat", 1),
			"toughness": legacy_data.get("toughness", 1),
			"savvy": legacy_data.get("savvy", 1),
			"tech": legacy_data.get("tech", 1),
			"speed": legacy_data.get("speed", 1),
			"luck": legacy_data.get("luck", 1)
		},
		"equipment": legacy_data.get("equipment", [])
	}
	
	# Determine creation mode from legacy data
	var mode = FiveParsecsCharacter.CreationMode.CUSTOM
	if legacy_data.get("is_captain", false):
		mode = FiveParsecsCharacter.CreationMode.CAPTAIN
	elif legacy_data.get("creation_mode") == "CREW_MEMBER":
		mode = FiveParsecsCharacter.CreationMode.INITIAL_CREW
	
	return factory.create_character(mode, FiveParsecsCharacter.CreationContext.CAMPAIGN_START, params)

static func _migrate_from_simple_creator(legacy_data: Dictionary, factory: FiveParsecsCharacter) -> Character:
	"""Migrate from SimpleCharacterCreator format"""
	var params = {
		"name": legacy_data.get("name", ""),
		"background": legacy_data.get("background_id", 0),
		"motivation": legacy_data.get("motivation_id", 0),
		"stats": {
			"combat": legacy_data.get("combat_value", 1),
			"toughness": legacy_data.get("toughness_value", 1),
			"savvy": legacy_data.get("savvy_value", 1),
			"tech": legacy_data.get("tech_value", 1),
			"speed": legacy_data.get("speed_value", 1),
			"luck": legacy_data.get("luck_value", 1)
		}
	}
	
	# SimpleCharacterCreator typically creates crew members
	return factory.create_character(FiveParsecsCharacter.CreationMode.INITIAL_CREW, FiveParsecsCharacter.CreationContext.CAMPAIGN_START, params)

static func _migrate_from_base_creator(legacy_data: Dictionary, factory: FiveParsecsCharacter) -> Character:
	"""Migrate from BaseCharacterCreator format"""
	var params = {
		"name": legacy_data.get("character_name", ""),
		"background": legacy_data.get("selected_background", 0),
		"motivation": legacy_data.get("selected_motivation", 0),
		"stats": {
			"combat": legacy_data.get("combat_stat", 1),
			"toughness": legacy_data.get("toughness_stat", 1),
			"savvy": legacy_data.get("savvy_stat", 1),
			"tech": legacy_data.get("tech_stat", 1),
			"speed": legacy_data.get("speed_stat", 1),
			"luck": legacy_data.get("luck_stat", 1)
		},
		"equipment": legacy_data.get("starting_equipment", [])
	}
	
	# BaseCharacterCreator used for various purposes
	var mode = FiveParsecsCharacter.CreationMode.CUSTOM
	return factory.create_character(mode, FiveParsecsCharacter.CreationContext.CAMPAIGN_START, params)

static func _migrate_generic_character_data(legacy_data: Dictionary, factory: FiveParsecsCharacter) -> Character:
	"""Generic migration for unknown legacy formats"""
	var params = {
		"name": _extract_name_from_legacy(legacy_data),
		"background": _extract_background_from_legacy(legacy_data),
		"motivation": _extract_motivation_from_legacy(legacy_data),
		"stats": _extract_stats_from_legacy(legacy_data),
		"equipment": _extract_equipment_from_legacy(legacy_data)
	}
	
	return factory.create_character(FiveParsecsCharacter.CreationMode.CUSTOM, FiveParsecsCharacter.CreationContext.CAMPAIGN_START, params)

## Legacy Data Extraction Helpers

static func _extract_name_from_legacy(data: Dictionary) -> String:
	"""Extract character name from various legacy formats"""
	var possible_keys = ["character_name", "name", "char_name", "display_name"]
	for key in possible_keys:
		if data.has(key) and not data[key].is_empty():
			return data[key]
	return "Migrated Character"

static func _extract_background_from_legacy(data: Dictionary) -> int:
	"""Extract background from various legacy formats"""
	var possible_keys = ["background", "background_id", "selected_background", "character_background"]
	for key in possible_keys:
		if data.has(key):
			return data[key]
	return 0

static func _extract_motivation_from_legacy(data: Dictionary) -> int:
	"""Extract motivation from various legacy formats"""
	var possible_keys = ["motivation", "motivation_id", "selected_motivation", "character_motivation"]
	for key in possible_keys:
		if data.has(key):
			return data[key]
	return 0

static func _extract_stats_from_legacy(data: Dictionary) -> Dictionary:
	"""Extract character stats from various legacy formats"""
	var stats = {
		"combat": 1,
		"toughness": 1,
		"savvy": 1,
		"tech": 1,
		"speed": 1,
		"luck": 1
	}
	
	# Try different stat key formats
	var stat_mappings = {
		"combat": ["combat", "combat_value", "combat_stat"],
		"toughness": ["toughness", "toughness_value", "toughness_stat"],
		"savvy": ["savvy", "savvy_value", "savvy_stat"],
		"tech": ["tech", "tech_value", "tech_stat"],
		"speed": ["speed", "speed_value", "speed_stat", "move"],
		"luck": ["luck", "luck_value", "luck_stat"]
	}
	
	for stat_name in stat_mappings:
		for key in stat_mappings[stat_name]:
			if data.has(key):
				stats[stat_name] = data[key]
				break
	
	return stats

static func _extract_equipment_from_legacy(data: Dictionary) -> Array:
	"""Extract equipment from various legacy formats"""
	var possible_keys = ["equipment", "starting_equipment", "gear", "items"]
	for key in possible_keys:
		if data.has(key) and data[key] is Array:
			return data[key]
	return []

## Migration Validation

static func validate_migration(legacy_data: Dictionary, migrated_character: Character) -> bool:
	"""Validate that migration preserved essential character data"""
	if not migrated_character:
		return false
	
	# Check name preservation
	var legacy_name = _extract_name_from_legacy(legacy_data)
	if not legacy_name.is_empty() and migrated_character.character_name != legacy_name:
		push_warning("Migration warning: Character name mismatch")
		return false
	
	# Check stat preservation (basic validation)
	var legacy_stats = _extract_stats_from_legacy(legacy_data)
	if migrated_character.combat != legacy_stats["combat"]:
		push_warning("Migration warning: Combat stat mismatch")
		return false
	
	# Check background preservation
	var legacy_background = _extract_background_from_legacy(legacy_data)
	if migrated_character.background != legacy_background:
		push_warning("Migration warning: Background mismatch")
		return false
	
	print("FiveParsecsCharacterMigration: Migration validation successful")
	return true

## Save Game Migration Support

static func migrate_save_game_characters(save_data: Dictionary) -> Dictionary:
	"""Migrate character data in save games to new format"""
	var migrated_save = save_data.duplicate(true)
	
	if migrated_save.has("crew") and migrated_save.crew is Array:
		var migrated_crew = []
		for crew_member in migrated_save.crew:
			if crew_member is Dictionary:
				var migrated_character = migrate_character_data(crew_member)
				if migrated_character:
					migrated_crew.append(migrated_character.to_dict())
				else:
					# Keep original if migration fails
					migrated_crew.append(crew_member)
			else:
				migrated_crew.append(crew_member)
		migrated_save.crew = migrated_crew
	
	return migrated_save

## Testing and Debug Support

static func test_migration(test_data: Array[Dictionary]) -> Dictionary:
	"""Test migration with various legacy data formats"""
	var results = {
		"successful": [],
		"failed": [],
		"total": test_data.size()
	}
	
	for i in range(test_data.size()):
		var legacy_data = test_data[i]
		var migrated = migrate_character_data(legacy_data)
		
		if migrated and validate_migration(legacy_data, migrated):
			results.successful.append(i)
		else:
			results.failed.append(i)
	
	print("Migration test results: %d successful, %d failed out of %d total" % [results.successful.size(), results.failed.size(), results.total])
	return results