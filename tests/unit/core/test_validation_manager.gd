@tool
extends "res://tests/fixtures/base/game_test.gd"

const ValidationManagerScript = preload("res://src/core/systems/ValidationManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")

# Type-safe instance variables
var _validation_manager: Resource = null

# Safe method helpers to avoid dependency on TypeSafeMixin
func _has_method(obj, method_name: String) -> bool:
	if not obj:
		return false
	return obj.has_method(method_name)

func _safe_call_method(obj, method_name: String, args: Array = [], default_value = null):
	if not obj or not method_name:
		return default_value
	
	if not obj.has_method(method_name):
		push_warning("Method '%s' not found on object" % method_name)
		return default_value
		
	if args.is_empty():
		return obj.call(method_name)
	else:
		return obj.callv(method_name, args)

func _safe_cast_to_string(value) -> String:
	if value == null:
		return ""
	return str(value)

func before_each() -> void:
	# ALWAYS call super first
	await super.before_each()
	
	# Create a fresh game state for testing
	_game_state = GameState.new()
	
	# Ensure the game state has a valid path to prevent inst_to_dict errors
	# Use safe property checking - check directly if method exists
	if _has_method(_game_state, "set_resource_path"):
		_game_state.set_resource_path("res://tests/generated/test_game_state_%d.tres" % Time.get_unix_time_from_system())
	
	# Initialize ValidationManager with the test game state
	_validation_manager = ValidationManagerScript.new(_game_state)
	
	# Make sure the validation manager has a valid resource path
	if _has_method(_validation_manager, "set_resource_path"):
		_validation_manager.set_resource_path("res://tests/generated/test_validation_manager_%d.tres" % Time.get_unix_time_from_system())
	
	# Track the resources - ensure proper casting for type safety
	add_child_autofree(_game_state) # Add to tree instead of tracking directly
	track_test_resource(_validation_manager)
	
	await stabilize_engine()

func after_each() -> void:
	# Cleanup
	_validation_manager = null
	
	# ALWAYS call super last
	await super.after_each()

# Test initialization
func test_validation_manager_initialization() -> void:
	assert_not_null(_validation_manager, "ValidationManager should be initialized")
	assert_not_null(_validation_manager.game_state, "ValidationManager should have a game state")
	assert_eq(_validation_manager.game_state, _game_state, "ValidationManager should reference the correct game state")

# Test phase state validation with missing current_phase
func test_validate_phase_state_missing_current_phase() -> void:
	# Game state without current_phase
	# Instead of using direct erase, use a setter method if available or a dictionary-based approach
	if _has_method(_game_state, "remove_state_value"):
		_safe_call_method(_game_state, "remove_state_value", ["current_phase"])
	elif _has_method(_game_state, "set_current_phase"):
		# If we can set it to null or an invalid value
		_safe_call_method(_game_state, "set_current_phase", [null])
	
	var result = _validation_manager.validate_phase_state()
	
	assert_false(result.valid, "Validation should fail with missing current_phase")
	assert_true(result.errors.size() > 0, "Validation should report errors")
	
	# Check for the specific error we expect
	var has_phase_error = false
	for error in result.errors:
		if error.begins_with("Invalid current phase:"):
			has_phase_error = true
			break
	
	assert_true(has_phase_error, "Should report error about invalid phase")

# Test phase state validation with invalid current_phase
func test_validate_phase_state_invalid_current_phase() -> void:
	# Set an invalid phase value using proper setter method
	if _has_method(_game_state, "set_current_phase"):
		_safe_call_method(_game_state, "set_current_phase", [-999])
	else:
		# If no setter, try to use a property bag approach
		if _has_method(_game_state, "set_state_value"):
			_safe_call_method(_game_state, "set_state_value", ["current_phase", -999])
		else:
			# As last resort, we may need to skip this test
			pending("GameState doesn't have proper setters for current_phase")
			return
	
	var result = _validation_manager.validate_phase_state()
	
	assert_false(result.valid, "Validation should fail with invalid current_phase")
	assert_true(result.errors.size() > 0, "Validation should report errors")
	
	# Check for the specific error we expect
	var has_phase_error = false
	for error in result.errors:
		if error.begins_with("Invalid current phase:"):
			has_phase_error = true
			break
	
	assert_true(has_phase_error, "Should report error about invalid phase")

# Test phase state validation with valid current_phase
func test_validate_phase_state_valid_current_phase() -> void:
	# Set a valid phase value using proper setter method
	if _has_method(_game_state, "set_current_phase"):
		_safe_call_method(_game_state, "set_current_phase", [GameEnums.CampaignPhase.SETUP])
	else:
		# If no setter, try to use a property bag approach
		if _has_method(_game_state, "set_state_value"):
			_safe_call_method(_game_state, "set_state_value", ["current_phase", GameEnums.CampaignPhase.SETUP])
		else:
			# As last resort, we may need to skip this test
			pending("GameState doesn't have proper setters for current_phase")
			return
	
	# Set phase_data safely too
	if _has_method(_game_state, "set_phase_data"):
		_safe_call_method(_game_state, "set_phase_data", [ {}])
	elif _has_method(_game_state, "set_state_value"):
		_safe_call_method(_game_state, "set_state_value", ["phase_data", {}])
	
	var result = _validation_manager.validate_phase_state()
	
	# This might still fail for other reasons, but should pass the current_phase check
	# We're checking if the "Invalid current phase" error is NOT present
	var has_phase_error = false
	for error in result.errors:
		if error.begins_with("Invalid current phase:"):
			has_phase_error = true
			break
	
	assert_false(has_phase_error, "Should not report error about invalid phase")

# Test full game state validation
func test_validate_game_state() -> void:
	# Setup a minimal valid game state
	if _has_method(_game_state, "set_current_phase"):
		_safe_call_method(_game_state, "set_current_phase", [GameEnums.CampaignPhase.SETUP])
	else:
		if _has_method(_game_state, "set_state_value"):
			_safe_call_method(_game_state, "set_state_value", ["current_phase", GameEnums.CampaignPhase.SETUP])
	
	if _has_method(_game_state, "set_phase_data"):
		_safe_call_method(_game_state, "set_phase_data", [ {}])
	elif _has_method(_game_state, "set_state_value"):
		_safe_call_method(_game_state, "set_state_value", ["phase_data", {}])
	
	var result = _validation_manager.validate_game_state()
	
	# The result might still be invalid due to missing campaign or crew,
	# but we want to verify the ValidationManager is calling the appropriate methods
	assert_eq(result.context, "game_state", "Result context should be 'game_state'")
	assert_true(result.has("valid"), "Result should have 'valid' field")
	assert_true(result.has("errors"), "Result should have 'errors' field")
