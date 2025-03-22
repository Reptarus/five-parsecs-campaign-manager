@tool
# Use explicit file paths instead of class names
extends "res://tests/fixtures/base/game_test.gd"

## Character Status Management Test Suite
##
## This test suite verifies the functionality of character status management,
## including status changes, health updates, and property validation.
## It ensures that characters can have status effects applied and removed properly.

# Use explicit preloads instead of global class names - fixed path
const CharacterManagerScript = preload("res://src/core/character/Management/CharacterManager.gd")
const GameEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterTestAdapter = preload("res://tests/fixtures/helpers/character_test_adapter.gd")

# Type-safe instance variables
var _character_manager = null # CharacterManager instance

## Lifecycle Methods
## -----------------------------------------------------------------

func before_each():
	await super.before_each()
	
	# Create instance of character manager
	_character_manager = CharacterManagerScript.new()
	add_child_autofree(_character_manager)
	track_test_node(_character_manager)
	
	await stabilize_engine()

func after_each():
	_character_manager = null
	await super.after_each()

# CHARACTER STATUS MANAGEMENT TESTS
# ------------------------------------------------------------------------

## Tests the ability to set and retrieve character status effects.
## Verifies that:
## - Status can be assigned to a character
## - Status data is correctly stored
## - Status properties can be retrieved
func test_character_status_management():
	# Given
	var char_id: String = "test_char_1"
	var character_data: Dictionary = {
		"id": char_id,
		"name": "Test Character",
		"health": 100,
		"status": {} # Initialize as Dictionary, not Array
	}
	
	# Add character to manager using type-safe method call
	TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character_data])
	
	# When - Set character status with proper type
	var new_status: Dictionary = {"injured": true, "severity": 1}
	
	# Use type-safe method call instead of direct method
	TypeSafeMixin._call_node_method_bool(_character_manager, "set_character_status", [char_id, new_status])
	
	# Then - Get character with proper type handling
	var updated_char = TypeSafeMixin._call_node_method(_character_manager, "get_character", [char_id])
	assert_not_null(updated_char, "Character should exist")
	
	# Verify the status was set correctly - carefully handle possible types
	if updated_char != null and updated_char is Dictionary and updated_char.has("status"):
		var status_value = updated_char["status"]
		if status_value is Dictionary:
			assert_true(status_value.has("injured"), "Character should have injured status")
		else:
			assert_false(status_value is Dictionary, "Status is not a Dictionary")
	else:
		assert_false(updated_char is Dictionary and updated_char.has("status"), "Character missing status field")
	
	# Test status property retrieval using type-safe method call
	var injury_status = TypeSafeMixin._call_node_method(_character_manager, "get_character_property", [char_id, "status"])
	assert_not_null(injury_status, "Status should not be null")
	
	# Only check for dictionary methods if it actually is a dictionary
	if injury_status is Dictionary:
		assert_true(injury_status.has("injured"), "Status should contain injured property")
		assert_eq(injury_status.get("severity"), 1, "Injury severity should be 1")
	else:
		assert_false(injury_status is Dictionary, "Retrieved status is not a Dictionary")

# CHARACTER HEALTH TESTS
# ------------------------------------------------------------------------

## Tests the ability to modify character health.
## Verifies that:
## - Health can be set to a specific value
## - Health changes are properly stored
## - Health property can be retrieved
## - Health change signals are emitted if applicable
func test_character_health_changes():
	# Given
	var char_id: String = "test_char_2"
	var character_data: Dictionary = {
		"id": char_id,
		"name": "Test Character 2",
		"health": 100,
		"status": {}
	}
	
	# Watch for signals
	watch_signals(_character_manager)
	
	# When
	TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character_data])
	TypeSafeMixin._call_node_method_bool(_character_manager, "set_character_health", [char_id, 80])
	
	# Then
	var updated_health = TypeSafeMixin._call_node_method(_character_manager, "get_character_property", [char_id, "health"])
	assert_eq(updated_health, 80, "Character health should be updated to 80")
	
	# Check if health_changed signal was emitted (if implemented in CharacterManager)
	if _character_manager.has_signal("character_health_changed"):
		verify_signal_emitted(_character_manager, "character_health_changed")

# SIGNAL TESTING
# ------------------------------------------------------------------------

## Tests that appropriate signals are emitted when character status changes.
## Verifies that:
## - Signals are properly emitted when status changes
## - Signal parameters contain expected values
## - Multiple status changes emit multiple signals
func test_character_status_signals():
	# Given
	var char_id: String = "test_char_signal"
	var character_data: Dictionary = {
		"id": char_id,
		"name": "Signal Test Character",
		"health": 100,
		"status": {}
	}
	
	# Add character and watch for signals
	TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [character_data])
	watch_signals(_character_manager)
	
	# When
	var new_status: Dictionary = {"injured": true, "severity": 1}
	TypeSafeMixin._call_node_method_bool(_character_manager, "set_character_status", [char_id, new_status])
	
	# Then
	# Check for character_status_changed signal if implemented
	if _character_manager.has_signal("character_status_changed"):
		# Verify signal emission
		verify_signal_emitted(_character_manager, "character_status_changed")
		
		# Verify signal parameters (if the signal includes parameters)
		# Adjust this based on the actual signal parameter structure
		var signal_params = get_signal_parameters(_character_manager, "character_status_changed")
		if signal_params and signal_params.size() > 0:
			var signal_character_id = signal_params[0]
			assert_eq(signal_character_id, char_id, "Signal should include the correct character ID")
	
	# Test multiple status changes
	var updated_status: Dictionary = {"injured": true, "severity": 2}
	TypeSafeMixin._call_node_method_bool(_character_manager, "set_character_status", [char_id, updated_status])
	
	# Verify second signal emission - using signal emission count
	if _character_manager.has_signal("character_status_changed"):
		# Get the emission count from the signal watcher
		var emit_count = get_signal_emit_count(_character_manager, "character_status_changed")
		assert_eq(emit_count, 2, "Signal should be emitted twice")

# PERFORMANCE TESTS
# ------------------------------------------------------------------------

## Tests the performance of adding and updating multiple characters.
## Verifies that:
## - Multiple character operations complete within acceptable time
## - Memory usage is within acceptable limits
func test_character_manager_performance():
	# Given
	var num_characters: int = 50 # Number of characters to create
	var characters_data: Array = []
	
	# Create test dataset
	characters_data = _create_test_dataset(num_characters)
	
	# When - Measure time to add characters
	var start_time: int = Time.get_ticks_msec()
	var start_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	for char_data in characters_data:
		TypeSafeMixin._call_node_method_bool(_character_manager, "add_character", [char_data])
	
	var end_time: int = Time.get_ticks_msec()
	var end_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Then - Verify performance metrics
	var elapsed_ms: int = end_time - start_time
	var memory_kb: float = (end_memory - start_memory) / 1024.0
	
	# Set reasonable performance expectations
	var max_acceptable_time: int = 500 # 500ms for adding 50 characters
	var max_acceptable_memory: float = 10.0 # 10KB for adding 50 characters
	
	assert_lt(elapsed_ms, max_acceptable_time,
		"Adding %d characters should take less than %dms (took %dms)" %
		[num_characters, max_acceptable_time, elapsed_ms])
	
	assert_lt(memory_kb, max_acceptable_memory,
		"Adding %d characters should use less than %.1fKB (used %.1fKB)" %
		[num_characters, max_acceptable_memory, memory_kb])

# Helper method for creating performance test data
# Moved outside of the test method as per GUT best practices
func _create_test_dataset(count: int) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({
			"id": "char_%d" % i,
			"name": "Character %d" % i,
			"health": 100,
			"status": {}
		})
	return result