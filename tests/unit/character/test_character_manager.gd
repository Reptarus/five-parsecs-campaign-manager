@tool
extends GameTest
class_name TestCharacterManager

## Character Manager Test Suite
## Tests the functionality of the CharacterManager class, responsible for managing game characters
##
## This test suite verifies:
## - Character creation and management
## - State management and persistence
## - Performance under load
## - Error boundaries and edge cases
## - Signal emissions and handling

const FiveParsecsCharacter := preload("res://src/core/character/Base/Character.gd")
const FiveParsecsCharacterManager := preload("res://src/core/character/Management/CharacterManager.gd")
const CharacterBox := preload("res://src/core/character/Base/CharacterBox.gd")
const GameState := preload("res://src/core/state/GameState.gd")

# Test Constants
const MAX_CHARACTERS := 100
const PERFORMANCE_TEST_ITERATIONS := 1000

var game_state: GameState
var character_manager: FiveParsecsCharacterManager
var test_character: FiveParsecsCharacter

# Signal tracking
var character_added_signal_emitted: bool = false
var character_updated_signal_emitted: bool = false
var character_removed_signal_emitted: bool = false
var last_character_added: FiveParsecsCharacter = null
var last_character_updated: FiveParsecsCharacter = null
var last_character_removed_id: String = ""

# Lifecycle Methods
func before_each() -> void:
	super.before_each()
	
	game_state = GameState.new()
	character_manager = FiveParsecsCharacterManager.new()
	test_character = FiveParsecsCharacter.new()
	
	if test_character.has_method("initialize_managers"):
		test_character.initialize_managers(game_state)
	
	add_child_autofree(game_state)
	add_child_autofree(character_manager)
	track_test_node(game_state)
	track_test_node(character_manager)
	track_test_resource(test_character)
	
	_connect_signals()
	_reset_signals()
	
	get_tree().create_timer(STABILIZATION_TIME).timeout

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	game_state = null
	character_manager = null
	test_character = null
	super.after_each()

# Signal Methods
func _connect_signals() -> void:
	if not character_manager:
		return
		
	if character_manager.has_signal("character_added"):
		character_manager.connect("character_added", _on_character_added)
	if character_manager.has_signal("character_updated"):
		character_manager.connect("character_updated", _on_character_updated)
	if character_manager.has_signal("character_removed"):
		character_manager.connect("character_removed", _on_character_removed)

func _disconnect_signals() -> void:
	if not character_manager:
		return
		
	if character_manager.has_signal("character_added") and character_manager.is_connected("character_added", _on_character_added):
		character_manager.disconnect("character_added", _on_character_added)
	if character_manager.has_signal("character_updated") and character_manager.is_connected("character_updated", _on_character_updated):
		character_manager.disconnect("character_updated", _on_character_updated)
	if character_manager.has_signal("character_removed") and character_manager.is_connected("character_removed", _on_character_removed):
		character_manager.disconnect("character_removed", _on_character_removed)

func _reset_signals() -> void:
	character_added_signal_emitted = false
	character_updated_signal_emitted = false
	character_removed_signal_emitted = false
	last_character_added = null
	last_character_updated = null
	last_character_removed_id = ""

func _on_character_added(character: FiveParsecsCharacter) -> void:
	character_added_signal_emitted = true
	last_character_added = character

func _on_character_updated(character: FiveParsecsCharacter) -> void:
	character_updated_signal_emitted = true
	last_character_updated = character

func _on_character_removed(character_id: String) -> void:
	character_removed_signal_emitted = true
	last_character_removed_id = character_id

## Safe Property Access Methods
func _get_manager_property(property: String, default_value: Variant = null) -> Variant:
	if not character_manager:
		push_error("Trying to access property '%s' on null character manager" % property)
		return default_value
	if not property in character_manager:
		push_error("Character manager missing required property: %s" % property)
		return default_value
	return character_manager.get(property)

func _get_character_property(character: FiveParsecsCharacter, property: String, default_value: Variant = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return default_value
	return character.get(property)

func _set_manager_property(property: String, value: Variant) -> void:
	if not character_manager:
		push_error("Trying to set property '%s' on null character manager" % property)
		return
	if not property in character_manager:
		push_error("Character manager missing required property: %s" % property)
		return
	character_manager.set(property, value)

func _set_character_property(character: FiveParsecsCharacter, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, value)

# Helper Methods
func create_character_resource(name: String = "Test Character", char_class: int = GameEnums.CharacterClass.NONE) -> FiveParsecsCharacter:
	var character := FiveParsecsCharacter.new()
	character.set("name", name)
	character.set("class", char_class)
	track_test_resource(character)
	return character

func create_multiple_characters(count: int) -> Array[FiveParsecsCharacter]:
	var characters: Array[FiveParsecsCharacter] = []
	for i in range(count):
		characters.append(create_character_resource("Character %d" % i))
	return characters

# Performance Tests
func test_bulk_character_operations() -> void:
	var start_time := Time.get_ticks_msec()
	var characters := create_multiple_characters(100)
	
	for character in characters:
		if character_manager.has_method("add_character"):
			var result: bool = character_manager.add_character(character)
	
	if character_manager.has_method("get_character_count"):
		assert_eq(character_manager.get_character_count(), 100, "Should handle bulk additions")
	assert_true(Time.get_ticks_msec() - start_time < 1000, "Bulk operation should complete within 1 second")

# Boundary Tests
func test_character_limit_boundary() -> void:
	for i in range(MAX_CHARACTERS + 1):
		var character := create_character_resource("Character %d" % i)
		if i < MAX_CHARACTERS:
			if character_manager.has_method("add_character"):
				assert_true(character_manager.add_character(character), "Should add character within limit")
		else:
			if character_manager.has_method("add_character"):
				assert_false(character_manager.add_character(character), "Should reject character beyond limit")

# Signal Tests
func test_character_signals() -> void:
	var character := create_character_resource()
	_reset_signals()
	
	if character_manager.has_method("add_character"):
		var add_result: bool = character_manager.add_character(character)
	assert_true(character_added_signal_emitted, "Character added signal should be emitted")
	assert_eq(last_character_added, character, "Last added character should match")
	
	_reset_signals()
	var character_id: String = _get_character_property(character, "id", "")
	if character_manager.has_method("update_character"):
		var update_result: bool = character_manager.update_character(character_id, character)
	assert_true(character_updated_signal_emitted, "Character updated signal should be emitted")
	assert_eq(last_character_updated, character, "Last updated character should match")
	
	_reset_signals()
	if character_manager.has_method("remove_character"):
		var remove_result: bool = character_manager.remove_character(character_id)
	assert_true(character_removed_signal_emitted, "Character removed signal should be emitted")
	assert_eq(last_character_removed_id, character_id, "Last removed character ID should match")

# Error Tests
func test_invalid_character_operations() -> void:
	_reset_signals()
	
	if character_manager.has_method("add_character"):
		assert_false(character_manager.add_character(null), "Should handle null character")
	assert_false(character_added_signal_emitted, "Character added signal should not be emitted")
	
	if character_manager.has_method("update_character"):
		assert_false(character_manager.update_character("invalid_id", create_character_resource()), "Should handle invalid ID")
	assert_false(character_updated_signal_emitted, "Character updated signal should not be emitted")
	
	if character_manager.has_method("remove_character"):
		assert_false(character_manager.remove_character("nonexistent_id"), "Should handle nonexistent ID")
	assert_false(character_removed_signal_emitted, "Character removed signal should not be emitted")

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(character_manager, "Character manager should be initialized")
	if character_manager.has_method("get_character_count"):
		assert_eq(character_manager.get_character_count(), 0, "Should start with no characters")
	if character_manager.has_method("get_active_characters"):
		assert_eq(character_manager.get_active_characters().size(), 0, "Should have no active characters")

# Character Management Tests
func test_add_character() -> void:
	var character := create_character_resource()
	_reset_signals()
	
	if character_manager.has_method("add_character"):
		var add_result: bool = character_manager.add_character(character)
	var character_id: String = _get_character_property(character, "id", "")
	
	if character_manager.has_method("get_character_count"):
		assert_eq(character_manager.get_character_count(), 1, "Should have one character")
	if character_manager.has_method("has_character"):
		assert_true(character_manager.has_character(character_id), "Should find character by ID")
	assert_true(character_added_signal_emitted, "Character added signal should be emitted")
	assert_eq(last_character_added, character, "Last added character should match")
	
	if character_manager.has_method("get_character"):
		var retrieved := character_manager.get_character(character_id) as FiveParsecsCharacter
		assert_not_null(retrieved, "Should retrieve added character")
		assert_eq(_get_character_property(retrieved, "name", ""), "Test Character", "Character name should match")
		assert_eq(_get_character_property(retrieved, "class", -1), GameEnums.CharacterClass.NONE, "Character class should match")

func test_remove_character() -> void:
	var character := create_character_resource()
	if character_manager.has_method("add_character"):
		var add_result: bool = character_manager.add_character(character)
	var character_id: String = _get_character_property(character, "id", "")
	if character_manager.has_method("get_character_count"):
		assert_eq(character_manager.get_character_count(), 1, "Should have one character")
	
	_reset_signals()
	if character_manager.has_method("remove_character"):
		var remove_result: bool = character_manager.remove_character(character_id)
	if character_manager.has_method("get_character_count"):
		assert_eq(character_manager.get_character_count(), 0, "Should have no characters")
	if character_manager.has_method("has_character"):
		assert_false(character_manager.has_character(character_id), "Should not find removed character")
	assert_true(character_removed_signal_emitted, "Character removed signal should be emitted")
	assert_eq(last_character_removed_id, character_id, "Last removed character ID should match")

func test_get_character() -> void:
	var character := create_character_resource()
	if character_manager.has_method("add_character"):
		var add_result: bool = character_manager.add_character(character)
	var character_id: String = _get_character_property(character, "id", "")
	
	if character_manager.has_method("get_character"):
		var retrieved := character_manager.get_character(character_id) as FiveParsecsCharacter
		assert_not_null(retrieved, "Should retrieve character")
		assert_eq(_get_character_property(retrieved, "id", ""), character_id, "Should retrieve correct character")
		assert_eq(_get_character_property(retrieved, "name", ""), _get_character_property(character, "name", ""), "Should retrieve character with correct name")
		assert_eq(_get_character_property(retrieved, "class", -1), _get_character_property(character, "class", -1), "Should retrieve character with correct class")

func test_update_character() -> void:
	var character := create_character_resource("Original Name")
	if character_manager.has_method("add_character"):
		var add_result: bool = character_manager.add_character(character)
	var character_id: String = _get_character_property(character, "id", "")
	
	_reset_signals()
	_set_character_property(character, "name", "Updated Name")
	_set_character_property(character, "health", 5)
	if character_manager.has_method("update_character"):
		var update_result: bool = character_manager.update_character(character_id, character)
	
	assert_true(character_updated_signal_emitted, "Character updated signal should be emitted")
	assert_eq(last_character_updated, character, "Last updated character should match")
	
	if character_manager.has_method("get_character"):
		var updated := character_manager.get_character(character_id) as FiveParsecsCharacter
		assert_eq(_get_character_property(updated, "name", ""), "Updated Name", "Should update character name")
		assert_eq(_get_character_property(updated, "health", -1), 5, "Should update character properties")

# Character Class Tests
func test_character_class_management() -> void:
	var classes := [
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE
	]
	
	for char_class in classes:
		var character := create_character_resource("Character %d" % char_class, char_class)
		_reset_signals()
		if character_manager.has_method("add_character"):
			var add_result: bool = character_manager.add_character(character)
		var character_id: String = _get_character_property(character, "id", "")
		
		assert_true(character_added_signal_emitted, "Character added signal should be emitted")
		assert_eq(last_character_added, character, "Last added character should match")
		
		if character_manager.has_method("get_character"):
			var retrieved := character_manager.get_character(character_id) as FiveParsecsCharacter
			assert_eq(_get_character_property(retrieved, "class", -1), char_class,
				"Should store correct class for %s" % GameEnums.CharacterClass.keys()[char_class])

# Error Handling Tests
func test_invalid_operations() -> void:
	# Test getting non-existent character
	if character_manager.has_method("get_character"):
		var retrieved := character_manager.get_character("non_existent_id") as FiveParsecsCharacter
		assert_null(retrieved, "Should return null for non-existent character")
	
	# Test removing non-existent character
	_reset_signals()
	if character_manager.has_method("remove_character"):
		var remove_result: bool = character_manager.remove_character("non_existent_id")
	assert_false(character_removed_signal_emitted, "Should not emit signal for non-existent character")
	
	# Test updating non-existent character
	var character := create_character_resource()
	if character_manager.has_method("update_character"):
		var update_result: bool = character_manager.update_character("non_existent_id", character)
	assert_false(character_updated_signal_emitted, "Should not emit signal for non-existent character")
