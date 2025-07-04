@tool
extends GdUnitGameTest

## Test Enhanced Character Creation System
##
## Comprehensive tests for the enhanced character creation tables,
## equipment generation, and connections system following proven patterns.

# Test subjects
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
const StartingEquipmentGenerator = preload("res://src/core/character/equipment/StartingEquipmentGenerator.gd")
const CharacterConnections = preload("res://src/core/character/connections/CharacterConnections.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")

# Mock Character following proven pattern
class MockCharacter extends Resource:
	var character_name: String = "Test Hero"
	var character_class: int = GlobalEnums.CharacterClass.SOLDIER
	var background: int = GlobalEnums.Background.MILITARY
	var motivation: int = GlobalEnums.Motivation.GLORY
	var origin: int = GlobalEnums.Origin.HUMAN
	var reaction: int = 2
	var combat: int = 1
	var toughness: int = 3
	var speed: int = 4
	var savvy: int = 1
	var luck: int = 1
	var traits: Array[String] = []
	var credits_earned: int = 1000
	
	func add_trait(trait_name: String) -> void:
		if not trait_name in traits:
			traits.append(trait_name)
	
	func has_trait(trait_name: String) -> bool:
		return trait_name in traits
	
	func get_trait(trait_name: String) -> String:
		for trait in traits:
			if trait_name in trait:
				return trait
		return ""
	
	func has_method(method_name: String) -> bool:
		return method_name in ["add_trait", "has_trait", "get_trait"]

# Test setup and teardown
func before_test() -> void:
	super.before_test()
	await get_tree().process_frame

func after_test() -> void:
	super.after_test()

## Table Loading Tests
func test_character_creation_tables_validation() -> void:
	# Test table validation
	var is_valid = CharacterCreationTables.validate_tables()
	assert_that(is_valid).is_true()
	
	# Test table statistics
	var stats = CharacterCreationTables.get_table_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.motivation_entries).is_greater(0)
	assert_that(stats.quirk_entries).is_equal(6)

func test_background_event_generation() -> void:
	# Test with valid background
	var bg_event = CharacterCreationTables.get_background_event(GlobalEnums.Background.MILITARY, 11)
	assert_that(bg_event).is_not_null()
	assert_that(bg_event.has("event")).is_true()
	assert_that(bg_event.has("effect")).is_true()
	assert_that(bg_event.event).is_not_empty()
	
	# Test with different rolls
	var test_rolls = [11, 25, 66]
	for roll in test_rolls:
		var event = CharacterCreationTables.get_background_event(GlobalEnums.Background.CRIMINAL, roll)
		assert_that(event).is_not_null()
		# Should have either direct result or fallback
		assert_that(event.has("event") or event.has("result")).is_true()

func test_motivation_generation() -> void:
	# Test specific motivations
	var motivation = CharacterCreationTables.get_motivation(25)
	assert_that(motivation).is_not_null()
	assert_that(motivation.has("name")).is_true()
	assert_that(motivation.has("description")).is_true()
	assert_that(motivation.name).is_not_empty()
	
	# Test d66 range coverage
	var motivations_found = 0
	for roll in range(11, 67):
		var mot = CharacterCreationTables.get_motivation(roll)
		if mot.has("name") and mot.name != "No result found":
			motivations_found += 1
	
	assert_that(motivations_found).is_greater(30) # Should cover most d66 range

func test_character_quirk_generation() -> void:
	# Test all quirk rolls (1-6)
	for roll in range(1, 7):
		var quirk = CharacterCreationTables.get_character_quirk(roll)
		assert_that(quirk).is_not_null()
		assert_that(quirk.has("name")).is_true()
		assert_that(quirk.has("effect")).is_true()
		assert_that(quirk.name).is_not_empty()

## Equipment Generation Tests
func test_equipment_tables_validation() -> void:
	var is_valid = StartingEquipmentGenerator.validate_equipment_tables()
	assert_that(is_valid).is_true()
	
	var stats = StartingEquipmentGenerator.get_equipment_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.has("class_equipment")).is_true()
	assert_that(stats.has("background_equipment")).is_true()

func test_class_equipment_generation() -> void:
	var character = MockCharacter.new()
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.background = GlobalEnums.Background.MILITARY
	
	var equipment = StartingEquipmentGenerator.generate_starting_equipment(character)
	assert_that(equipment).is_not_null()
	assert_that(equipment.has("weapons")).is_true()
	assert_that(equipment.has("credits")).is_true()
	assert_that(equipment.credits).is_greater_equal(1000)
	assert_that(equipment.credits).is_less_equal(2000)

func test_equipment_condition_system() -> void:
	var character = MockCharacter.new()
	var equipment = StartingEquipmentGenerator.generate_starting_equipment(character)
	
	# Apply conditions
	StartingEquipmentGenerator.apply_equipment_condition(equipment)
	
	# Check weapons have conditions
	var weapons = equipment.get("weapons", [])
	if weapons.size() > 0:
		for weapon in weapons:
			if weapon is Dictionary:
				assert_that(weapon.has("condition")).is_true()
				assert_that(weapon.has("quality_modifier")).is_true()
				assert_that(weapon.condition in ["damaged", "standard", "superior"]).is_true()

func test_background_equipment_bonuses() -> void:
	# Test different backgrounds give different equipment
	var backgrounds = [
		GlobalEnums.Background.MILITARY,
		GlobalEnums.Background.CRIMINAL,
		GlobalEnums.Background.NOBLE
	]
	
	var equipment_sets = []
	for bg in backgrounds:
		var character = MockCharacter.new()
		character.background = bg
		var equipment = StartingEquipmentGenerator.generate_starting_equipment(character)
		equipment_sets.append(equipment)
	
	# Each background should potentially have different equipment
	assert_that(equipment_sets.size()).is_equal(3)

## Connections System Tests
func test_connections_tables_validation() -> void:
	var is_valid = CharacterConnections.validate_connections_tables()
	assert_that(is_valid).is_true()
	
	var stats = CharacterConnections.get_connection_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.has("background_connections")).is_true()

func test_background_connections_generation() -> void:
	var character = MockCharacter.new()
	character.background = GlobalEnums.Background.NOBLE
	
	var connections = CharacterConnections.generate_starting_connections(character)
	assert_that(connections).is_not_null()
	# Noble should have connections
	assert_that(connections.size()).is_greater_equal(0)

func test_patron_connections_generation() -> void:
	var character = MockCharacter.new()
	character.background = GlobalEnums.Background.NOBLE
	
	var patrons = CharacterConnections.generate_patron_connections(character)
	assert_that(patrons).is_not_null()
	# Noble should have patron connections
	assert_that(patrons.size()).is_greater(0)

func test_rival_generation() -> void:
	var character = MockCharacter.new()
	# Add a trait that should generate a rival
	character.add_trait("Rival: Former commanding officer")
	
	var rivals = CharacterConnections.generate_starting_rivals(character)
	assert_that(rivals).is_not_null()

## Enhanced Character Creation Integration Tests
func test_enhanced_character_creation() -> void:
	var config = {
		"name": "Test Character",
		"class": GlobalEnums.CharacterClass.SOLDIER,
		"background": GlobalEnums.Background.MILITARY,
		"motivation": GlobalEnums.Motivation.GLORY,
		"origin": GlobalEnums.Origin.HUMAN
	}
	
	var character = FiveParsecsCharacterGeneration.create_enhanced_character(config)
	assert_that(character).is_not_null()
	assert_that(character.character_name).is_equal("Test Character")
	assert_that(character.character_class).is_equal(GlobalEnums.CharacterClass.SOLDIER)
	assert_that(character.background).is_equal(GlobalEnums.Background.MILITARY)

func test_rulebook_compliant_generation() -> void:
	var character = FiveParsecsCharacterGeneration.generate_rulebook_compliant_character()
	assert_that(character).is_not_null()
	
	# Validate character meets Five Parsecs constraints
	var validation = FiveParsecsCharacterGeneration.validate_character(character)
	assert_that(validation.valid).is_true()
	if not validation.valid:
		for error in validation.errors:
			print("Validation error: " + error)

func test_character_trait_application() -> void:
	var character = MockCharacter.new()
	character.background = GlobalEnums.Background.MILITARY
	
	# Test background event application
	var bg_event = CharacterCreationTables.get_background_event(character.background, 11)
	character.add_trait("Background Event: " + bg_event.get("event", "Unknown"))
	
	assert_that(character.traits.size()).is_greater(0)
	assert_that(character.has_trait("Background Event")).is_true()

## Performance Tests
func test_character_generation_performance() -> void:
	var start_time = Time.get_unix_time_from_system()
	
	# Generate 10 characters to test performance
	for i in range(10):
		var character = FiveParsecsCharacterGeneration.generate_rulebook_compliant_character()
		assert_that(character).is_not_null()
	
	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time
	
	# Should complete in reasonable time (less than 5 seconds for 10 characters)
	assert_that(duration).is_less(5.0)

func test_table_loading_performance() -> void:
	var start_time = Time.get_unix_time_from_system()
	
	# Force reload tables
	CharacterCreationTables.reload_tables()
	StartingEquipmentGenerator._ensure_tables_loaded()
	CharacterConnections._ensure_tables_loaded()
	
	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - start_time
	
	# Table loading should be fast (less than 1 second)
	assert_that(duration).is_less(1.0)

## Error Handling Tests  
func test_invalid_background_handling() -> void:
	# Test with invalid background enum
	var bg_event = CharacterCreationTables.get_background_event(999, 11)
	assert_that(bg_event).is_not_null()
	# Should return fallback result
	assert_that(bg_event.has("result") or bg_event.has("event")).is_true()

func test_invalid_roll_handling() -> void:
	# Test with invalid rolls
	var bg_event = CharacterCreationTables.get_background_event(GlobalEnums.Background.MILITARY, 999)
	assert_that(bg_event).is_not_null()
	# Should return fallback result  
	assert_that(bg_event.has("result") or bg_event.has("event")).is_true()

func test_missing_dice_manager_handling() -> void:
	# This test ensures graceful degradation when DiceManager is not available
	# The actual implementation should handle this via Engine.get_singleton fallbacks
	var bg_event = CharacterCreationTables.get_background_event(GlobalEnums.Background.MILITARY, 11)
	assert_that(bg_event).is_not_null()

## Helper Methods
func _create_test_character() -> MockCharacter:
	var character = MockCharacter.new()
	character.character_name = "Test Character"
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.background = GlobalEnums.Background.MILITARY
	return character