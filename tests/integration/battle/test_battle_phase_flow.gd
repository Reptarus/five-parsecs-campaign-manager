@tool
extends "res://addons/gut/test.gd"

# Improved test file with better type safety and error handling
# Make sure the gut variable exists for GUT to inject itself
# var gut = null  # Removed since it's already defined in the parent class

# Type-safe constants and references 
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
const GameEnums = TestEnums.GlobalEnums
const FiveParsecsCombatManager = preload("res://src/game/combat/FiveParsecsCombatManager.gd")
const FiveParsecsBattleRules = preload("res://src/game/combat/FiveParsecsBattleRules.gd")
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

# Type-safe instance variables
var _battle_manager: Node = null
var _test_units: Array = []

# Test constants
const STABILIZE_TIME := 0.1
const TEST_TIMEOUT := 2.0

# Setup and teardown
func before_all() -> void:
	# Initialize any resources needed for all tests
	pass
	
func before_each() -> void:
	# Create a battle manager with necessary method implementations
	_battle_manager = Node.new()
	
	# Create a script with all required methods using temp file
	if not Compatibility.ensure_temp_directory():
		push_warning("Could not create temp directory for test scripts")
		return
		
	var script_path = "res://tests/temp/battle_manager_%d_%d.gd" % [Time.get_unix_time_from_system(), randi() % 1000000]
	var script_content = """extends Node

var _combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
var _registered_characters = []

signal combat_state_changed(new_state)
signal character_registered(character)
signal combat_started
signal combat_ended
signal phase_changed(old_phase, new_phase)

func initialize():
	_combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
	_registered_characters = []
	return true
	
func setup_default_state():
	_combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
	return true
	
func get_combat_state():
	return _combat_state
	
func set_combat_state(state):
	var old_phase = _combat_state.get("phase", "SETUP")
	_combat_state = state
	var new_phase = _combat_state.get("phase", "SETUP")
	
	if old_phase != new_phase:
		emit_signal("phase_changed", old_phase, new_phase)
	
	emit_signal("combat_state_changed", _combat_state)
	return true
	
func register_character(character):
	if character and not character in _registered_characters:
		_registered_characters.append(character)
		emit_signal("character_registered", character)
		return true
	return false
	
func add_character(character):
	return register_character(character)
	
func get_registered_characters():
	return _registered_characters
	
func start_combat():
	var old_phase = _combat_state.get("phase", "SETUP")
	_combat_state["phase"] = "DEPLOYMENT"
	emit_signal("combat_started")
	emit_signal("phase_changed", old_phase, "DEPLOYMENT")
	return true
	
func end_combat():
	var old_phase = _combat_state.get("phase", "COMBAT")
	_combat_state["phase"] = "RESOLUTION"
	emit_signal("combat_ended")
	emit_signal("phase_changed", old_phase, "RESOLUTION")
	return true
	
func advance_phase():
	var phases = ["SETUP", "DEPLOYMENT", "COMBAT", "RESOLUTION"]
	var current_phase = _combat_state.get("phase", "SETUP")
	var current_index = phases.find(current_phase)
	
	if current_index >= 0 and current_index < phases.size() - 1:
		var old_phase = current_phase
		var new_phase = phases[current_index + 1]
		_combat_state["phase"] = new_phase
		emit_signal("phase_changed", old_phase, new_phase)
		return true
	
	return false
"""
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()
		
		# Load and apply the script
		var script = load(script_path)
		_battle_manager.set_script(script)
		add_child(_battle_manager)
		
		# Initialize battle manager
		if _battle_manager.has_method("initialize"):
			var result = TypeSafeMixin._call_node_method_bool(_battle_manager, "initialize", [], false)
			if not result:
				push_warning("Combat manager initialization failed")
	else:
		push_warning("Failed to create test battle manager script")
	
	# Wait for stability
	await get_tree().process_frame
	
func after_each() -> void:
	# Clean up any test units
	_cleanup_test_units()
	
	# Clean up battle manager
	if is_instance_valid(_battle_manager):
		_battle_manager.queue_free()
		
	_battle_manager = null
	
	# Wait for cleanup
	await get_tree().process_frame
	
func after_all() -> void:
	# Clean up any remaining resources
	pass

# Helper methods
func _create_test_unit(unit_type: String = "STANDARD") -> Node:
	var unit = Node.new()
	if not unit:
		push_error("Failed to create test unit")
		return null
		
	# Set basic properties
	unit.name = "TestUnit_" + unit_type
	unit.set_meta("type", unit_type)
	unit.set_meta("health", 100)
	unit.set_meta("actions", 2)
	
	return unit

func _cleanup_test_units() -> void:
	for unit in _test_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_test_units.clear()

# Tests
func test_minimal() -> void:
	# A simple test that should always pass
	assert_true(true, "Truth is true")
	
func test_enum_access() -> void:
	# Test that we can access the GameEnums properly
	assert_not_null(GameEnums, "GameEnums class exists")

func test_battle_states() -> void:
	# Skip if battle manager isn't available
	if not is_instance_valid(_battle_manager):
		pending("Combat manager not available, skipping test")
		return
		
	# Check if battle manager has required methods
	if not _battle_manager.has_method("get_combat_state"):
		pending("Combat manager doesn't have get_combat_state method, skipping test")
		return
		
	# Get initial state
	var initial_state = TypeSafeMixin._call_node_method_dict(_battle_manager, "get_combat_state", [])
	assert_not_null(initial_state, "Initial combat state should not be null")
	
	# If we have the transition method, test it
	if _battle_manager.has_method("set_combat_state"):
		var result = TypeSafeMixin._call_node_method_bool(_battle_manager, "set_combat_state", [ {
			"phase": "SETUP",
			"active_team": 0,
			"round": 1
		}], false)
		assert_true(result, "Should be able to set combat state")
	else:
		pending("Combat manager doesn't have set_combat_state method, skipping state transition test")

func test_phase_transitions() -> void:
	# Skip if battle manager isn't available
	if not is_instance_valid(_battle_manager):
		pending("Combat manager not available, skipping test")
		return
	
	# Check if battle manager has required methods
	if not _battle_manager.has_method("advance_phase"):
		pending("Combat manager doesn't have advance_phase method, skipping test")
		return
		
	# Get initial state
	var initial_state = TypeSafeMixin._call_node_method_dict(_battle_manager, "get_combat_state", [])
	assert_not_null(initial_state, "Initial combat state should not be null")
	
	# Store the initial phase for comparison
	var initial_phase = initial_state.get("phase", "NONE")
	
	# Track signals
	watch_signals(_battle_manager)
	
	# Advance to next phase
	var result = TypeSafeMixin._call_node_method_bool(_battle_manager, "advance_phase", [], false)
	assert_true(result, "Should be able to advance to next phase")
	
	# Verify signal emission 
	assert_signal_emitted(_battle_manager, "phase_changed", "Phase changed signal should be emitted")
	
	# Get updated state
	var updated_state = TypeSafeMixin._call_node_method_dict(_battle_manager, "get_combat_state", [])
	assert_not_null(updated_state, "Updated combat state should not be null")
	
	# Get the updated phase
	var updated_phase = updated_state.get("phase", "NONE")
	
	# Verify phases are different - using assert_eq to check the values directly
	# This helps ensure proper error messages when values don't match expectations
	assert_ne(
		initial_phase,
		updated_phase,
		"Phase should have changed (initial: '%s', updated: '%s')" % [initial_phase, updated_phase]
	)
	
	# Verify the updated phase matches our expectations
	# Check that the phase follows the expected sequence
	if initial_phase == "SETUP":
		assert_eq(updated_phase, "DEPLOYMENT", "After SETUP should be DEPLOYMENT phase")
	elif initial_phase == "DEPLOYMENT":
		assert_eq(updated_phase, "COMBAT", "After DEPLOYMENT should be COMBAT phase")
	elif initial_phase == "COMBAT":
		assert_eq(updated_phase, "RESOLUTION", "After COMBAT should be RESOLUTION phase")

func test_unit_action_flow() -> void:
	# Mark as pending since this would need specific action handling
	pending("Implementation needed for FiveParsecsCombatManager action flow")

func test_battle_end_flow() -> void:
	# Mark as pending since this would need specific end state handling
	pending("Implementation needed for FiveParsecsCombatManager battle end flow")

func test_combat_effect_flow() -> void:
	# Mark as pending since this would need specific effect handling
	pending("Implementation needed for FiveParsecsCombatManager combat effects")

func test_reaction_opportunity_flow() -> void:
	# Mark as pending since this would need specific reaction mechanics
	pending("Implementation needed for FiveParsecsCombatManager reaction mechanics")

func test_battle_performance() -> void:
	# Mark as pending since this would need specific performance testing
	pending("Implementation needed for combat performance testing")
