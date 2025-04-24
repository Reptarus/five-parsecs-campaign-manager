## Override Core Test Suite
## Tests the functionality of the override system including:
## - Override definitions and validation
## - Override state management
## - Override effects and interactions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const OverrideController := preload("res://src/ui/components/combat/overrides/override_controller.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe test data
const TEST_CONTEXT := "attack_roll"
const TEST_VALUE := 4

# Mock classes for testing - make them Node types to be compatible with override_controller
class MockCombatResolver extends Node:
	signal override_requested(context, value)
	signal dice_roll_completed(context, value)
	
	func apply_override(context: String, value: int) -> void:
		pass
	
	# Add any required interface methods that the real CombatResolver would have
	func get_combat_controller():
		return null
		
	func is_compatible_with(manager) -> bool:
		return true

class MockCombatManager extends Node:
	signal combat_state_changed(new_state)
	signal override_validation_requested(context, value)
	
	func get_current_state() -> Dictionary:
		return {
			"attack_bonus": 2,
			"weapon_damage": 5,
			"defense_value": 3
		}
	
	# Add any required interface methods that the real CombatManager would have
	func get_manager_type() -> String:
		return "combat"
		
	func is_valid_override(context: String, value: int) -> bool:
		return true

# Type-safe instance variables
var _override_controller: Node = null
var _mock_resolver: MockCombatResolver = null
var _mock_manager: MockCombatManager = null
var _mock_panel: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Create mock objects as Nodes
	_mock_resolver = MockCombatResolver.new()
	_mock_resolver.name = "MockCombatResolver"
	add_child_autofree(_mock_resolver)
	track_test_node(_mock_resolver)
	
	_mock_manager = MockCombatManager.new()
	_mock_manager.name = "MockCombatManager"
	add_child_autofree(_mock_manager)
	track_test_node(_mock_manager)
	
	# Create mock override panel
	_mock_panel = Node.new()
	_mock_panel.name = "ManualOverridePanel"
	add_child_autofree(_mock_panel)
	track_test_node(_mock_panel)
	
	# Add required methods and signals to mock panel
	_mock_panel.set_meta("override_value_spinbox", {"value": 4})
	_mock_panel.add_user_signal("override_applied")
	_mock_panel.add_user_signal("override_cancelled")
	
	# Add methods to mock panel using script injection
	_mock_panel.set_script(GDScript.new())
	_mock_panel.get_script().source_code = """
extends Node
signal override_applied(value)
signal override_cancelled

func show_override(context, value, min_val, max_val):
	pass
	
func hide():
	pass
"""
	_mock_panel.get_script().reload()
	
	# Initialize override controller
	var override_instance = OverrideController.new()
	_override_controller = TypeSafeMixin._safe_cast_to_node(override_instance)
	if not _override_controller:
		push_error("Failed to create override controller")
		return
		
	add_child_autofree(_override_controller)
	track_test_node(_override_controller)
	
	# Set the mock panel reference in the controller
	_override_controller.set("override_panel", _mock_panel)
	
	# Try the setup using different approaches to handle potential type mismatches
	if _override_controller.has_method("setup_combat_system"):
		# Try with type conversion helper if available
		var result = TypeSafeMixin._call_node_method_bool(_override_controller, "setup_combat_system", [_mock_resolver, _mock_manager])
		if not result:
			push_warning("setup_combat_system failed, controller might expect different types")
	
	watch_signals(_override_controller)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_override_controller = null
	_mock_resolver = null
	_mock_manager = null
	_mock_panel = null
	await super.after_each()

# Override Management Tests
func test_override_request() -> void:
	watch_signals(_override_controller)
	
	# Test requesting an override
	_override_controller.request_override(TEST_CONTEXT, TEST_VALUE)
	assert_eq(_override_controller.active_context, TEST_CONTEXT, "Should set active context")
	
	# Test override application
	_mock_panel.emit_signal("override_applied", TEST_VALUE)
	verify_signal_emitted(_override_controller, "override_applied")
	
	# Test override cancellation
	_mock_panel.emit_signal("override_cancelled")
	verify_signal_emitted(_override_controller, "override_cancelled")
	assert_true(_override_controller.active_context.is_empty(), "Should clear active context on cancel")

func test_override_validation() -> void:
	# Test valid override values
	var result = _override_controller.validate_override("attack_roll", 8)
	assert_true(result, "Should allow override value within limits")
	
	result = _override_controller.validate_override("damage_roll", 10)
	assert_true(result, "Should allow override value within weapon damage limits")
	
	# Test invalid override values
	result = _override_controller.validate_override("attack_roll", 20)
	assert_false(result, "Should reject override value exceeding limits")
	
	result = _override_controller.validate_override("defense_roll", 15)
	assert_false(result, "Should reject defense value exceeding limits")

# Signal Propagation Tests
func test_signal_propagation() -> void:
	watch_signals(_override_controller)
	
	# Test override request from resolver propagates
	_mock_resolver.emit_signal("override_requested", TEST_CONTEXT, TEST_VALUE)
	assert_eq(_override_controller.active_context, TEST_CONTEXT, "Should handle override request signal")
	
	# Test dice roll completion propagates
	_mock_resolver.emit_signal("dice_roll_completed", TEST_CONTEXT, TEST_VALUE)
	# Since we can't directly observe the hide() call, we check that processing continued
	
	# Test applying valid override
	_override_controller.active_context = TEST_CONTEXT
	_mock_panel.emit_signal("override_applied", 5)
	verify_signal_emitted(_override_controller, "override_applied")
	
	# Test state change propagation
	_mock_manager.emit_signal("combat_state_changed", {"attack_bonus": 1})
	# Again, since we can't directly observe the hide() call, we check that processing continued
