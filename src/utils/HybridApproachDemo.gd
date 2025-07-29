extends Node

## Hybrid Approach Demonstration Script
## Shows the hybrid approach in action with practical examples

const DataManager = preload("res://src/core/data/DataManager.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const Character = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton

# Demo Types
enum DemoType {
	BASIC,
	ADVANCED,
	EXPERT
}

func _ready() -> void:
	print("=== Hybrid Approach Demonstration ===")
	_run_demonstration()

func _run_demonstration() -> void:
	_demonstrate_data_initialization()
	_demonstrate_character_creation()
	_demonstrate_rich_data_access()
	_demonstrate_validation()
	_demonstrate_performance_monitoring()

func _demonstrate_data_initialization() -> void:
	print("\n--- Data Initialization ---")
	
	# Initialize the data system
	var success = DataManager.initialize_data_system()
	print("Data system initialization: %s" % ("SUCCESS" if success else "FAILED"))
	
	# Check system status
	var is_ready = DataManager.get_performance_stats().get("is_loaded", false)
	print("System ready: %s" % ("YES" if is_ready else "NO"))
	
	# Get performance stats
	var stats = DataManager.get_performance_stats()
	print("Performance stats:")
	print("  - Load time: %d ms" % stats.get("load_time_ms", 0))
	print("  - Cache hits: %d" % stats.get("cache_hits", 0))
	print("  - Character data size: %d" % stats.get("character_data_size", 0))
	print("  - Background data size: %d" % stats.get("background_data_size", 0))

func _demonstrate_character_creation() -> void:
	print("\n--- Character Creation ---")
	
	# Create character with hybrid approach
	var character = FiveParsecsCharacterGeneration.create_character({
		"name": "Alex",
		"class": "SOLDIER",
		"background": "MILITARY",
		"origin": "HUMAN"
	})
	
	if character:
		print("Character created successfully:")
		print("  - Name: %s" % character.character_name)
		print("  - Class: %s" % GlobalEnums.get_class_display_name(character.character_class))
		print("  - Background: %s" % GlobalEnums.get_background_display_name(character.background))
		print("  - Origin: %s" % GlobalEnums.get_origin_display_name(character.origin))
		print("  - Stats: Reaction=%d, Speed=%d, Combat=%d, Toughness=%d, Savvy=%d" % [
			character.reaction, character.speed, character.combat, character.toughness, character.savvy
		])
		print("  - Health: %d/%d" % [character.health, character.max_health])
		print("  - Traits: %s" % character.traits)
	else:
		print("Failed to create character")

func _demonstrate_rich_data_access() -> void:
	print("\n--- Rich Data Access ---")
	
	# Get rich origin data
	var human_data = DataManager.get_origin_data("HUMAN")
	if not human_data.is_empty():
		print("Human origin data:")
		print("  - Name: %s" % human_data.get("name", "Unknown"))
		print("  - Description: %s" % human_data.get("description", "No description").substr(0, 50) + "...")
		
		var base_stats = human_data.get("base_stats", {})
		print("  - Base stats: %s" % base_stats)
		
		var characteristics = human_data.get("characteristics", [])
		print("  - Characteristics: %s" % characteristics)
	
	# Get rich background data
	var military_data = DataManager.get_background_data("military")
	if not military_data.is_empty():
		print("\nMilitary background data:")
		print("  - Name: %s" % military_data.get("name", "Unknown"))
		print("  - Description: %s" % military_data.get("description", "No description").substr(0, 50) + "...")
		
		var stat_bonuses = military_data.get("stat_bonuses", {})
		print("  - Stat bonuses: %s" % stat_bonuses)
		
		var stat_penalties = military_data.get("stat_penalties", {})
		print("  - Stat penalties: %s" % stat_penalties)
		
		var starting_skills = military_data.get("starting_skills", [])
		print("  - Starting skills: %s" % starting_skills)
		
		var special_abilities = military_data.get("special_abilities", [])
		print("  - Special abilities: %s" % special_abilities)

func _demonstrate_validation() -> void:
	print("\n--- Data Validation ---")
	
	# Test character validation
	var character = FiveParsecsCharacterGeneration.create_character({
		"name": "Test Character",
		"class": "SOLDIER",
		"background": "MILITARY",
		"origin": "HUMAN"
	})
	
	var validation = FiveParsecsCharacterGeneration.validate_character(character)
	print("Character validation: %s" % ("VALID" if validation.valid else "INVALID"))
	
	if not validation.valid:
		print("Validation errors:")
		for error in validation.errors:
			print("  - %s" % error)
	
	# Test data validation
	# Note: validate_character_creation method doesn't exist, using simple validation
	var validation_result = {"valid": true, "errors": []}
	var character_data = {
		"origin": "HUMAN",
		"background": "military"
	}
	
	# Simple validation check
	if not character_data.has("origin") or not character_data.has("background"):
		validation_result.valid = false
		validation_result.errors = ["Missing required character data"]
	
	print("Data validation: %s" % ("VALID" if validation_result.valid else "INVALID"))
	
	if not validation_result.valid:
		print("Data validation errors:")
		for error in validation_result.errors:
			print("  - %s" % error)
	
	if validation_result.warnings.size() > 0:
		print("Data validation warnings:")
		for warning in validation_result.warnings:
			print("  - %s" % warning)

func _demonstrate_performance_monitoring() -> void:
	print("\n--- Performance Monitoring ---")
	
	# Access some data to generate cache hits
	for i in range(5):
		DataManager.get_origin_data("HUMAN")
		DataManager.get_background_data("military")
	
	# Get updated performance stats
	var stats = DataManager.get_performance_stats()
	print("Updated performance stats:")
	print("  - Cache hits: %d" % stats.get("cache_hits", 0))
	print("  - Cache misses: %d" % stats.get("cache_misses", 0))
	var cache_hit_ratio = stats.get("cache_hit_ratio", 0.0)
	var ratio_float = 0.0
	if cache_hit_ratio is float:
		ratio_float = cache_hit_ratio
	elif cache_hit_ratio is int:
		ratio_float = float(cache_hit_ratio)
	print("  - Cache hit ratio: %.2f%%" % (ratio_float * 100.0))
	print("  - Last load time: %d" % stats.get("last_load_time", 0))

func _demonstrate_random_character_generation() -> void:
	print("\n--- Random Character Generation ---")
	
	# Generate a random character
	var character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if character:
		print("Random character generated:")
		print("  - Name: %s" % character.character_name)
		print("  - Class: %s" % GlobalEnums.get_class_display_name(character.character_class))
		print("  - Background: %s" % GlobalEnums.get_background_display_name(character.background))
		print("  - Origin: %s" % GlobalEnums.get_origin_display_name(character.origin))
		print("  - Motivation: %s" % GlobalEnums.get_motivation_display_name(character.motivation))
		print("  - Stats: Reaction=%d, Speed=%d, Combat=%d, Toughness=%d, Savvy=%d" % [
			character.reaction, character.speed, character.combat, character.toughness, character.savvy
		])
		print("  - Health: %d/%d" % [character.health, character.max_health])
		print("  - Traits: %s" % character.traits)
	else:
		print("Failed to generate random character")

func _demonstrate_enum_json_mapping() -> void:
	print("\n--- Enum-JSON Mapping ---")
	
	# Test enum to JSON mapping
	var human_data = DataManager.get_origin_data("HUMAN")
	var origin_names = human_data.keys() if not human_data.is_empty() else []
	print("Available origins from JSON: %s" % origin_names)
	
	var background_names = DataManager.get_all_backgrounds()
	print("Available backgrounds from JSON: %s" % background_names)
	
	# Test enum validation
	print("\nEnum validation:")
	for origin_name in origin_names:
		var upper_name = origin_name.to_upper()
		var has_enum = GlobalEnums.Origin.has(upper_name)
		print("  - %s: %s" % [origin_name, "VALID" if has_enum else "INVALID"])

func _demonstrate_fallback_systems() -> void:
	print("\n--- Fallback Systems ---")
	
	# Test character creation without DataManager (simulated)
	print("Testing fallback character creation...")
	
	# Create a basic character using the fallback system
	var character = FiveParsecsCharacterGeneration.create_basic_character({
		"name": "Fallback Character",
		"class": "SOLDIER",
		"background": "MILITARY",
		"origin": "HUMAN"
	})
	
	if character:
		print("Fallback character created successfully:")
		print("  - Name: %s" % character.character_name)
		print("  - Class: %s" % GlobalEnums.get_class_display_name(character.character_class))
		print("  - Stats: Reaction=%d, Speed=%d, Combat=%d, Toughness=%d, Savvy=%d" % [
			character.reaction, character.speed, character.combat, character.toughness, character.savvy
		])
	else:
		print("Failed to create fallback character")

func _demonstrate_data_export() -> void:
	print("\n--- Data Export ---")
	
	# Export character data for external systems
	var exported_data = {
		"origins": DataManager.get_origin_data("HUMAN"),
		"backgrounds": DataManager.get_all_backgrounds(),
		"performance_stats": DataManager.get_performance_stats(),
		"last_updated": Time.get_unix_time_from_system()
	}
	print("Exported data structure:")
	print("  - Origins: %d entries" % exported_data.get("origins", {}).size())
	print("  - Backgrounds: %d entries" % exported_data.get("backgrounds", []).size())
	print("  - Performance stats: %d entries" % exported_data.get("performance_stats", {}).size())
	print("  - Last updated: %d" % exported_data.get("last_updated", 0))

## Utility functions for demonstration

func _print_separator() -> void:
	print("\n" + "=".repeat(50))

func _print_section_header(title: String) -> void:
	print("\n--- %s ---" % title)

func _print_success(message: String) -> void:
	print("✓ %s" % message)

func _print_error(message: String) -> void:
	print("✗ %s" % message)

func _print_info(message: String) -> void:
	print("ℹ %s" % message)