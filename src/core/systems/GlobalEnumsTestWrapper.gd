class_name GlobalEnumsTestWrapper
extends RefCounted

## Test Wrapper for GlobalEnums with Simplified Function Signatures
## 
## This wrapper provides simplified function signatures that GdUnit4 can mock
## without complex type parsing issues. All functionality delegates to the 
## real GlobalEnums singleton while maintaining GdUnit4 compatibility.
##
## Used exclusively for testing - production code should use GlobalEnums directly.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# ============================================================================
# VALIDATION FUNCTIONS WITH SIMPLIFIED SIGNATURES
# ============================================================================

## Background validation without complex type hints
func is_valid_background_string(value):
	return GlobalEnums.is_valid_background_string(value)

func is_valid_background_int(value):
	# Validate integer background values
	if not value is int:
		return false
	return value >= 0 and value < GlobalEnums.Background.size()

## Character class validation without complex type hints  
func is_valid_character_class_string(value):
	return GlobalEnums.is_valid_character_class_string(value)

func is_valid_character_class_int(value):
	# Validate integer character class values
	if not value is int:
		return false
	return value >= 0 and value < GlobalEnums.CharacterClass.size()

## Motivation validation without complex type hints
func is_valid_motivation_string(value):
	return GlobalEnums.is_valid_motivation_string(value)

func is_valid_motivation_int(value):
	# Validate integer motivation values
	if not value is int:
		return false
	return value >= 0 and value < GlobalEnums.Motivation.size()

## Origin validation without complex type hints
func is_valid_origin_string(value):
	return GlobalEnums.is_valid_origin_string(value)

func is_valid_origin_int(value):
	# Validate integer origin values
	if not value is int:
		return false
	return value >= 0 and value < GlobalEnums.Origin.size()

# ============================================================================
# CONVERSION FUNCTIONS WITH SIMPLIFIED SIGNATURES
# ============================================================================

## Convert any format to validated string (simplified signature)
func to_string_value(enum_type, value):
	return GlobalEnums.to_string_value(enum_type, value)

## Convert validated string back to enum value (simplified signature)
func from_string_value(enum_type, string_value):
	return GlobalEnums.from_string_value(enum_type, string_value)

## Get enum integer from string (simplified signature)
func get_background_value(background_string):
	return GlobalEnums.from_string_value("background", background_string)

func get_character_class_value(class_string):
	return GlobalEnums.from_string_value("character_class", class_string)

func get_motivation_value(motivation_string):
	return GlobalEnums.from_string_value("motivation", motivation_string)

func get_origin_value(origin_string):
	return GlobalEnums.from_string_value("origin", origin_string)

# ============================================================================
# NAME LOOKUP FUNCTIONS WITH SIMPLIFIED SIGNATURES
# ============================================================================

## Get display names without complex type hints
func get_background_name(background_value):
	if background_value is String:
		return background_value
	return GlobalEnums.get_background_name(background_value)

func get_character_class_name(class_value):
	if class_value is String:
		return class_value
	return GlobalEnums.get_character_class_name(class_value)

func get_motivation_name(motivation_value):
	if motivation_value is String:
		return motivation_value
	return GlobalEnums.get_motivation_name(motivation_value)

func get_origin_name(origin_value):
	if origin_value is String:
		return origin_value
	return GlobalEnums.get_origin_name(origin_value)

# ============================================================================
# PERFORMANCE AND DEBUG FUNCTIONS
# ============================================================================

## Get migration metrics without complex type hints
func get_conversion_metrics():
	# Return basic metrics structure for testing
	# Note: GlobalEnums metrics are internal and not directly accessible
	return {
		"conversions": 0,
		"cache_hits": 0,
		"failures": {},
		"samples": [],
		"percentiles": {"p50": 0, "p95": 0, "p99": 0}
	}

## Reset metrics for testing
func reset_metrics():
	# Note: GlobalEnums metrics are internal and reset automatically
	# This function is provided for test compatibility
	pass

## Check migration flags
func is_string_validation_enabled():
	return GlobalEnums.MIGRATION_FLAGS.use_string_validation

func is_debug_logging_enabled():
	return GlobalEnums.MIGRATION_FLAGS.log_type_conversions

# ============================================================================
# ENUM ACCESS FUNCTIONS
# ============================================================================

## Direct enum access for testing
func get_background_enum():
	return GlobalEnums.Background

func get_character_class_enum():
	return GlobalEnums.CharacterClass

func get_motivation_enum():
	return GlobalEnums.Motivation

func get_origin_enum():
	return GlobalEnums.Origin

# ============================================================================
# HELPER FUNCTIONS FOR TEST VALIDATION
# ============================================================================

## Validate test data integrity
func validate_test_conversion(enum_type, original_value, expected_string):
	var converted = to_string_value(enum_type, original_value)
	var back_converted = from_string_value(enum_type, converted)
	
	return {
		"original": original_value,
		"converted_string": converted,
		"back_converted": back_converted,
		"string_matches": converted == expected_string,
		"round_trip_success": (original_value == back_converted) if original_value is int else true
	}

## Get all valid values for an enum type
func get_valid_values(enum_type):
	match enum_type:
		"background":
			return ["MILITARY", "COLONIST", "MERCHANT", "TRADER", "CRIMINAL", "ACADEMIC", "NOBLE"]
		"character_class":
			return ["BASELINE", "CAPTAIN", "SPECIALIST", "SOLDIER", "SCOUT"]
		"motivation":
			return ["WEALTH", "FAME", "KNOWLEDGE", "POWER", "JUSTICE", "SURVIVAL", "REVENGE"]
		"origin":
			return ["COLONY", "FRONTIER", "CORE_WORLD", "ASTEROID", "STATION", "SHIP"]
		_:
			return []

## Check if wrapper is functioning correctly
func self_test():
	var tests_passed = 0
	var tests_total = 4
	
	# Test background validation
	if is_valid_background_string("MILITARY") and not is_valid_background_string("INVALID"):
		tests_passed += 1
	
	# Test character class validation  
	if is_valid_character_class_string("SOLDIER") and not is_valid_character_class_string("INVALID"):
		tests_passed += 1
		
	# Test conversion
	var converted = to_string_value("background", 1)  # MILITARY
	if converted == "MILITARY":
		tests_passed += 1
		
	# Test round trip
	var back = from_string_value("background", "MILITARY")
	if back == 1:
		tests_passed += 1
	
	return {
		"tests_passed": tests_passed,
		"tests_total": tests_total,
		"success_rate": float(tests_passed) / float(tests_total),
		"wrapper_functional": tests_passed == tests_total
	}

# ============================================================================
# TEST UTILITY METHODS
# ============================================================================

## Create a test character with valid enum strings
func create_test_character():
	var character = Character.new()
	character.name = "Test Character"
	character.background = "MILITARY"
	character.character_class = "SOLDIER" 
	character.motivation = "WEALTH"
	character.origin = "COLONY"
	character.stats = {"reactions": 3, "speed": 4, "combat_skill": 5, "toughness": 4, "savvy": 2, "luck": 3}
	return character

## Get a random valid value for the specified enum type
func get_random_valid_value(enum_type: String):
	var valid_values = get_valid_values(enum_type)
	if valid_values.is_empty():
		return ""
	return valid_values[randi() % valid_values.size()]

## Validate all enum properties of a character
func validate_character(character):
	if not character:
		return false
	
	var validations = [
		is_valid_background_string(character.background),
		is_valid_character_class_string(character.character_class),
		is_valid_motivation_string(character.motivation),
		is_valid_origin_string(character.origin)
	]
	
	return validations.all(func(v): return v == true)

## Get comprehensive test data for all enum types
func get_all_test_data():
	return {
		"backgrounds": get_valid_values("background"),
		"character_classes": get_valid_values("character_class"),
		"motivations": get_valid_values("motivation"),
		"origins": get_valid_values("origin"),
		"sample_character": create_test_character(),
		"wrapper_status": self_test()
	}

## Create test character with specific enum values
func create_character_with_values(bg: String, cc: String, mot: String, orig: String):
	var character = Character.new()
	character.name = "Custom Test Character"
	character.background = bg if is_valid_background_string(bg) else "MILITARY"
	character.character_class = cc if is_valid_character_class_string(cc) else "SOLDIER"
	character.motivation = mot if is_valid_motivation_string(mot) else "WEALTH"
	character.origin = orig if is_valid_origin_string(orig) else "COLONY"
	character.stats = {"reactions": 3, "speed": 4, "combat_skill": 5, "toughness": 4, "savvy": 2, "luck": 3}
	return character

## Get test campaign data with valid enum values
func create_test_campaign_data():
	return {
		"captain": create_test_character(),
		"crew": [
			create_character_with_values("COLONIST", "BASELINE", "LOYALTY", "COLONY"),
			create_character_with_values("TRADER", "SCOUT", "SURVIVAL", "NEW_WORLDS")
		],
		"victory_conditions": ["WEALTH_ACCUMULATION", "REPUTATION_BUILDING"],
		"difficulty": "STANDARD",
		"use_story_track": true
	}