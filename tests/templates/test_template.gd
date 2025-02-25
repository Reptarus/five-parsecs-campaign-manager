@tool
extends "res://tests/fixtures/specialized/battle_test.gd" # Choose the appropriate specialized test class path:
                                                         # "res://tests/fixtures/specialized/ui_test.gd"
                                                         # "res://tests/fixtures/specialized/battle_test.gd"
                                                         # "res://tests/fixtures/specialized/campaign_test.gd"
                                                         # "res://tests/fixtures/specialized/mobile_test.gd"
                                                         # "res://tests/fixtures/specialized/enemy_test.gd"
                                                         # "res://tests/fixtures/base/game_test.gd"

## [TEST_NAME] Test Suite
##
## Tests the functionality of the [FEATURE] including:
## - [TEST_ASPECT_1]
## - [TEST_ASPECT_2]
## - [TEST_ASPECT_3]

# Type-safe script references (use actual script paths)
const TestedClass: GDScript = preload("res://path/to/tested/class.gd")
const DependencyClass: GDScript = preload("res://path/to/dependency.gd")

# Type-safe constants with explicit typing
const TEST_TIMEOUT := 1.0 as float
const DEFAULT_VALUE := "test" as String
const TEST_DATA := {
	"id": "test_id" as String,
	"value": 42 as int,
	"enabled": true as bool
}

# Type-safe instance variables
var _instance: Node = null
var _dependency: Node = null

## Lifecycle methods

func before_each() -> void:
	# Always call super first
	await super.before_each()
	
	# Create test instance
	_instance = TestedClass.new()
	if not _instance:
		push_error("Failed to create test instance")
		return
	add_child_autofree(_instance)
	track_test_node(_instance)
	
	# Setup test dependencies
	_dependency = DependencyClass.new()
	if not _dependency:
		push_error("Failed to create dependency")
		return
	add_child_autofree(_dependency)
	track_test_node(_dependency)
	
	# Configure test instance
	TypeSafeMixin._call_node_method_bool(_instance, "initialize", [TEST_DATA])
	
	# Wait for system to stabilize
	await stabilize_engine()

func after_each() -> void:
	# Clean up test state
	_instance = null
	_dependency = null
	
	# Always call super last
	await super.after_each()

## Test methods

func test_initialization() -> void:
	# Given
	var data := TEST_DATA.duplicate()
	data.value = 100
	
	# When
	TypeSafeMixin._call_node_method_bool(_instance, "initialize", [data])
	
	# Then
	assert_eq(
		TypeSafeMixin._call_node_method_int(_instance, "get_value", []),
		100,
		"Instance should be initialized with correct value"
	)

func test_functionality() -> void:
	# Given
	watch_signals(_instance)
	var expected_result := 42
	
	# When
	var result := TypeSafeMixin._call_node_method_int(_instance, "calculate", [10, 32])
	
	# Then
	assert_eq(result, expected_result, "Calculation should return expected result")
	assert_signal_emitted(_instance, "calculation_completed")

func test_error_handling() -> void:
	# Given
	var invalid_input := -1
	
	# When/Then
	assert_false(
		TypeSafeMixin._call_node_method_bool(_instance, "validate", [invalid_input]),
		"Validation should fail for invalid input"
	)
	
	# Verify error state
	assert_true(
		TypeSafeMixin._call_node_method_bool(_instance, "has_error", []),
		"Error flag should be set after invalid input"
	)

## Helper methods

func _create_test_data(variant: String = "default") -> Dictionary:
	var data := TEST_DATA.duplicate()
	
	match variant:
		"special":
			data.id = "special_test"
			data.value = 99
		"minimal":
			data.erase("value")
			data.erase("enabled")
		_:
			# Use defaults
			pass
	
	return data