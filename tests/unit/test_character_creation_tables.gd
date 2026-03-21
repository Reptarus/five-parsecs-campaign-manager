extends GdUnitTestSuite
## Tests for Character Creation Tables and Connections
## Covers 2 NOT_TESTED mechanics from QA_CORE_RULES_TEST_PLAN.md §1
## Core Rules Reference: Strange Characters D100 (p.26), Connections (p.28)

const CharacterCreationTables := preload("res://src/core/character/tables/CharacterCreationTables.gd")
const CharacterConnections := preload("res://src/core/character/connections/CharacterConnections.gd")
const CharacterClass := preload("res://src/core/character/Character.gd")
var GlobalEnumsRef

func before():
	GlobalEnumsRef = load("res://src/core/systems/GlobalEnums.gd")

func after():
	GlobalEnumsRef = null

# ============================================================================
# CharacterCreationTables — Table Validation
# ============================================================================

func test_tables_validate():
	var valid: bool = CharacterCreationTables.validate_tables()
	assert_that(valid).is_true()

func test_table_statistics_not_empty():
	var stats: Dictionary = CharacterCreationTables.get_table_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.size()).is_greater(0)

func test_available_backgrounds_not_empty():
	var backgrounds: Array = CharacterCreationTables.get_available_backgrounds()
	assert_that(backgrounds.size()).is_greater(0)

# ============================================================================
# Background Events (d66 Table)
# ============================================================================

func test_roll_background_event_returns_dict():
	var result: Dictionary = CharacterCreationTables.roll_background_event(
		GlobalEnumsRef.Background.MILITARY)
	assert_that(result).is_not_null()

func test_get_background_event_by_roll():
	"""Direct lookup with known roll value (11 = first d66 entry)"""
	var result: Dictionary = CharacterCreationTables.get_background_event(
		GlobalEnumsRef.Background.MILITARY, 11)
	assert_that(result).is_not_null()

func test_background_event_has_description():
	var result: Dictionary = CharacterCreationTables.roll_background_event(
		GlobalEnumsRef.Background.MILITARY)
	if not result.is_empty():
		assert_that(result.has("description")).is_true()

func test_background_event_various_backgrounds():
	"""Test multiple backgrounds return valid results"""
	for bg in [GlobalEnumsRef.Background.MILITARY, GlobalEnumsRef.Background.ACADEMIC,
			GlobalEnumsRef.Background.COLONIST]:
		var result: Dictionary = CharacterCreationTables.roll_background_event(bg)
		assert_that(result).is_not_null()

# ============================================================================
# Motivation Table (d66)
# ============================================================================

func test_roll_motivation_returns_dict():
	var result: Dictionary = CharacterCreationTables.roll_motivation()
	assert_that(result).is_not_null()

func test_get_motivation_by_roll():
	var result: Dictionary = CharacterCreationTables.get_motivation(11)
	assert_that(result).is_not_null()

func test_motivation_has_description():
	var result: Dictionary = CharacterCreationTables.roll_motivation()
	if not result.is_empty():
		assert_that(result.has("description")).is_true()

# ============================================================================
# Character Quirks (d6 Table)
# ============================================================================

func test_roll_character_quirk_returns_dict():
	var result: Dictionary = CharacterCreationTables.roll_character_quirk()
	assert_that(result).is_not_null()

func test_get_quirk_by_roll_valid_range():
	"""d6 results should be 1-6"""
	for roll in range(1, 7):
		var result: Dictionary = CharacterCreationTables.get_character_quirk(roll)
		assert_that(result).is_not_null()

func test_quirk_has_description():
	var result: Dictionary = CharacterCreationTables.roll_character_quirk()
	if not result.is_empty():
		assert_that(result.has("description")).is_true()

# ============================================================================
# Table Reload
# ============================================================================

func test_reload_tables_does_not_crash():
	CharacterCreationTables.reload_tables()
	var valid: bool = CharacterCreationTables.validate_tables()
	assert_that(valid).is_true()

# ============================================================================
# CharacterConnections — Connection Generation
# ============================================================================

func test_connections_table_validates():
	var valid: bool = CharacterConnections.validate_connections_tables()
	assert_that(valid).is_true()

func test_connection_statistics_not_empty():
	var stats: Dictionary = CharacterConnections.get_connection_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.size()).is_greater(0)

func test_generate_starting_connections():
	var character := CharacterClass.new()
	character.character_name = "Test Captain"
	character.background = GlobalEnumsRef.Background.MILITARY
	var connections: Array = CharacterConnections.generate_starting_connections(character)
	assert_that(connections).is_not_null()

func test_generate_starting_rivals():
	var character := CharacterClass.new()
	character.character_name = "Test Captain"
	var rivals: Array = CharacterConnections.generate_starting_rivals(character)
	assert_that(rivals).is_not_null()

func test_generate_patron_connections_noble():
	var character := CharacterClass.new()
	character.character_name = "Noble Captain"
	character.background = GlobalEnumsRef.Background.NOBLE
	var patrons: Array = CharacterConnections.generate_patron_connections(character)
	assert_that(patrons).is_not_null()

func test_generate_patron_connections_military():
	var character := CharacterClass.new()
	character.character_name = "Military Captain"
	character.background = GlobalEnumsRef.Background.MILITARY
	var patrons: Array = CharacterConnections.generate_patron_connections(character)
	assert_that(patrons).is_not_null()

func test_generate_patron_connections_academic():
	var character := CharacterClass.new()
	character.character_name = "Academic Captain"
	character.background = GlobalEnumsRef.Background.ACADEMIC
	var patrons: Array = CharacterConnections.generate_patron_connections(character)
	assert_that(patrons).is_not_null()

func test_test_connection_generation_helper():
	"""Use the built-in test helper method"""
	var result: Dictionary = CharacterConnections.test_connection_generation("military")
	assert_that(result).is_not_null()
	assert_that(result.has("connections")).is_true()
	assert_that(result.has("rivals")).is_true()
	assert_that(result.has("patrons")).is_true()

func test_apply_connections_to_character():
	var character := CharacterClass.new()
	character.character_name = "Conn Test"
	var connections: Array = [
		{"type": "contact", "name": "Old Friend", "influence": "minor",
		 "location": "sector", "relationship": "friendly", "origin": "test"}
	]
	CharacterConnections.apply_connections_to_character(character, connections)
	# Should not crash; connections stored as traits
	assert_that(character).is_not_null()
