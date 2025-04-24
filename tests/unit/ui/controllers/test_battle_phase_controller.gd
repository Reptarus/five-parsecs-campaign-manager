@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const TestedClass := preload("res://src/core/battle/state/BattleStateMachine.gd")
# For accessing the renamed class
const BattleStateMachineClass = TestedClass
const Character := preload("res://src/game/combat/BattleCharacter.gd")

# Type-safe instance variables
var _last_phase: int = GameEnums.CombatPhase.NONE if "GameEnums" in get_parent() else 0
var _last_unit: Object = null # Using Object to avoid circular reference
var _last_action_points: int = 0
var _signal_handlers_connected: bool = false

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	var instance = TestedClass.new()
	if not is_instance_valid(instance):
		push_error("Failed to create BattleStateMachine instance")
	return instance

# Override _get_required_methods to specify required controller methods
func _get_required_methods() -> Array[String]:
	return [
		"transition_to_phase",
		"transition_to",
		"reset"
	]

func before_each() -> void:
	await super.before_each()
	_reset_state()
	connect_controller_signals()

func after_each() -> void:
	disconnect_controller_signals()
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_phase = GameEnums.CombatPhase.NONE if "GameEnums" in get_parent() else 0
	_last_unit = null
	_last_action_points = 0

# Connect controller signals
func connect_controller_signals() -> void:
	if not is_instance_valid(_controller):
		push_warning("Cannot connect signals: controller is null")
		return
		
	if _signal_handlers_connected:
		return
	
	if _controller.has_signal("phase_started") and not _controller.is_connected("phase_started", _on_phase_started):
		_controller.connect("phase_started", _on_phase_started)
		
	if _controller.has_signal("phase_ended") and not _controller.is_connected("phase_ended", _on_phase_ended):
		_controller.connect("phase_ended", _on_phase_ended)
		
	if _controller.has_signal("action_points_changed") and not _controller.is_connected("action_points_changed", _on_action_points_changed):
		_controller.connect("action_points_changed", _on_action_points_changed)
		
	if _controller.has_signal("unit_activated") and not _controller.is_connected("unit_activated", _on_unit_activated):
		_controller.connect("unit_activated", _on_unit_activated)
		
	if _controller.has_signal("unit_deactivated") and not _controller.is_connected("unit_deactivated", _on_unit_deactivated):
		_controller.connect("unit_deactivated", _on_unit_deactivated)
		
	_signal_handlers_connected = true

# Disconnect controller signals
func disconnect_controller_signals() -> void:
	if not is_instance_valid(_controller) or _controller.is_queued_for_deletion():
		return
		
	if not _signal_handlers_connected:
		return
		
	if _controller.has_signal("phase_started") and _controller.is_connected("phase_started", _on_phase_started):
		_controller.disconnect("phase_started", _on_phase_started)
		
	if _controller.has_signal("phase_ended") and _controller.is_connected("phase_ended", _on_phase_ended):
		_controller.disconnect("phase_ended", _on_phase_ended)
		
	if _controller.has_signal("action_points_changed") and _controller.is_connected("action_points_changed", _on_action_points_changed):
		_controller.disconnect("action_points_changed", _on_action_points_changed)
		
	if _controller.has_signal("unit_activated") and _controller.is_connected("unit_activated", _on_unit_activated):
		_controller.disconnect("unit_activated", _on_unit_activated)
		
	if _controller.has_signal("unit_deactivated") and _controller.is_connected("unit_deactivated", _on_unit_deactivated):
		_controller.disconnect("unit_deactivated", _on_unit_deactivated)
		
	_signal_handlers_connected = false

# Signal handlers
func _on_phase_started(phase: int) -> void:
	_last_phase = phase

func _on_phase_ended(phase: int) -> void:
	_last_phase = phase

func _on_action_points_changed(unit, points: int) -> void:
	_last_unit = unit
	_last_action_points = points

func _on_unit_activated(unit) -> void:
	_last_unit = unit

func _on_unit_deactivated(unit) -> void:
	_last_unit = unit

# Helper function to safely get enum values
func _get_combat_phase_value(phase_name: String) -> int:
	if "GameEnums" in get_parent() and "CombatPhase" in GameEnums:
		match phase_name:
			"NONE": return GameEnums.CombatPhase.NONE
			"INITIATIVE": return GameEnums.CombatPhase.INITIATIVE
			"DEPLOYMENT": return GameEnums.CombatPhase.DEPLOYMENT
			"ACTION": return GameEnums.CombatPhase.ACTION
			"REACTION": return GameEnums.CombatPhase.REACTION
			"END": return GameEnums.CombatPhase.END
	
	# Fallback to hardcoded values
	match phase_name:
		"NONE": return 0
		"INITIATIVE": return 1
		"DEPLOYMENT": return 2
		"ACTION": return 3
		"REACTION": return 4
		"END": return 5
	
	return 0

# Helper function to safely get battle state enum values
func _get_battle_state_value(state_name: String) -> int:
	if "GameEnums" in get_parent() and "BattleState" in GameEnums:
		match state_name:
			"SETUP": return GameEnums.BattleState.SETUP
			"ROUND": return GameEnums.BattleState.ROUND
			"CLEANUP": return GameEnums.BattleState.CLEANUP
	
	# Fallback to hardcoded values
	match state_name:
		"SETUP": return 0
		"ROUND": return 1
		"CLEANUP": return 2
	
	return 0

# Test cases
func test_initial_state() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_initial_state: controller is null or invalid")
		return
	
	# Use TypeSafeMixin or has_property to safely check for properties
	var has_current_phase := _controller.has_method("get_current_phase") or "current_phase" in _controller
	var has_active_combatants := _controller.has_method("get_active_combatants") or "active_combatants" in _controller
	var has_current_unit_action := _controller.has_method("get_current_unit_action") or "current_unit_action" in _controller
	
	if not (has_current_phase and has_active_combatants and has_current_unit_action):
		assert_fail("Skipping test_initial_state: required properties not found")
		return
	
	var current_phase = TypeSafeMixin._call_node_method_int(_controller, "get_current_phase", []) if _controller.has_method("get_current_phase") else _controller.current_phase
	var active_combatants = TypeSafeMixin._call_node_method_array(_controller, "get_active_combatants", []) if _controller.has_method("get_active_combatants") else _controller.active_combatants
	var current_unit_action = TypeSafeMixin._call_node_method_int(_controller, "get_current_unit_action", []) if _controller.has_method("get_current_unit_action") else _controller.current_unit_action
	
	var none_phase_value = _get_combat_phase_value("NONE")
	assert_eq(current_phase, none_phase_value, "Initial phase should be NONE")
	assert_eq(active_combatants.size(), 0, "Initial active_combatants should be empty")
	assert_null(current_unit_action, "Initial current_unit_action should be null")

func test_initialize_phase() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_initialize_phase: controller is null or invalid")
		return
	
	var test_phase := _get_combat_phase_value("ACTION")
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if _controller.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
			"phase": test_phase,
			"active_team": 0,
			"round": 1
		}])
	elif _controller.has_method("transition_to_phase"):
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [test_phase])
	else:
		assert_fail("Skipping test_initialize_phase: required methods not found")
		return
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	assert_eq(_last_phase, test_phase, "Last phase should be updated to test phase")

func test_handle_setup_state() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_handle_setup_state: controller is null or invalid")
		return
	
	if not _controller.has_method("transition_to"):
		assert_fail("Skipping test_handle_setup_state: transition_to method not found")
		return
	
	var setup_state = _get_battle_state_value("SETUP")
	TypeSafeMixin._call_node_method_bool(_controller, "transition_to", [setup_state])
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	
	var current_phase = TypeSafeMixin._call_node_method_int(_controller, "get_current_phase", []) if _controller.has_method("get_current_phase") else _controller.current_phase
	var active_combatants = TypeSafeMixin._call_node_method_array(_controller, "get_active_combatants", []) if _controller.has_method("get_active_combatants") else _controller.active_combatants
	var current_unit_action = TypeSafeMixin._call_node_method(_controller, "get_current_unit_action", []) if _controller.has_method("get_current_unit_action") else _controller.current_unit_action
	
	var none_phase_value = _get_combat_phase_value("NONE")
	assert_eq(current_phase, none_phase_value, "Phase should be NONE after SETUP state")
	assert_eq(active_combatants.size(), 0, "Active combatants should be empty after SETUP state")
	assert_null(current_unit_action, "Current unit action should be null after SETUP state")

func test_handle_deployment_phase() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_handle_deployment_phase: controller is null or invalid")
		return
	
	var deployment_phase = _get_combat_phase_value("DEPLOYMENT")
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if _controller.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
			"phase": deployment_phase,
			"active_team": 0,
			"round": 1
		}])
	elif _controller.has_method("transition_to_phase"):
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [deployment_phase])
	else:
		assert_fail("Skipping test_handle_deployment_phase: required methods not found")
		return
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	assert_eq(_last_phase, deployment_phase, "Last phase should be DEPLOYMENT")

func test_handle_battle_phase() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_handle_battle_phase: controller is null or invalid")
		return
	
	var action_phase = _get_combat_phase_value("ACTION")
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if _controller.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
			"phase": action_phase,
			"active_team": 0,
			"round": 1
		}])
	elif _controller.has_method("transition_to_phase"):
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [action_phase])
	else:
		assert_fail("Skipping test_handle_battle_phase: required methods not found")
		return
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	assert_eq(_last_phase, action_phase, "Last phase should be ACTION")

func test_handle_resolution_phase() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_handle_resolution_phase: controller is null or invalid")
		return
	
	var end_phase = _get_combat_phase_value("END")
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if _controller.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
			"phase": end_phase,
			"active_team": 0,
			"round": 1
		}])
	elif _controller.has_method("transition_to_phase"):
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [end_phase])
	else:
		assert_fail("Skipping test_handle_resolution_phase: required methods not found")
		return
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	assert_eq(_last_phase, end_phase, "Last phase should be END")

func test_handle_cleanup_phase() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_handle_cleanup_phase: controller is null or invalid")
		return
	
	if not _controller.has_method("transition_to"):
		assert_fail("Skipping test_handle_cleanup_phase: transition_to method not found")
		return
	
	var cleanup_state = _get_battle_state_value("CLEANUP")
	TypeSafeMixin._call_node_method_bool(_controller, "transition_to", [cleanup_state])
	
	assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted")
	
	var current_phase = TypeSafeMixin._call_node_method_int(_controller, "get_current_phase", []) if _controller.has_method("get_current_phase") else _controller.current_phase
	var active_combatants = TypeSafeMixin._call_node_method_array(_controller, "get_active_combatants", []) if _controller.has_method("get_active_combatants") else _controller.active_combatants
	var current_unit_action = TypeSafeMixin._call_node_method(_controller, "get_current_unit_action", []) if _controller.has_method("get_current_unit_action") else _controller.current_unit_action
	
	var none_phase_value = _get_combat_phase_value("NONE")
	assert_eq(current_phase, none_phase_value, "Phase should be NONE after CLEANUP state")
	assert_eq(active_combatants.size(), 0, "Active combatants should be empty after CLEANUP state")
	assert_null(current_unit_action, "Current unit action should be null after CLEANUP state")

# Additional tests using base class functionality
func test_controller_state() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_state: controller is null or invalid")
		return
		
	await super.test_controller_state()
	
	# Additional state checks for battle phase controller
	var current_phase = TypeSafeMixin._call_node_method_int(_controller, "get_current_phase", []) if _controller.has_method("get_current_phase") else _controller.current_phase
	var active_combatants = TypeSafeMixin._call_node_method_array(_controller, "get_active_combatants", []) if _controller.has_method("get_active_combatants") else _controller.active_combatants
	var current_unit_action = TypeSafeMixin._call_node_method(_controller, "get_current_unit_action", []) if _controller.has_method("get_current_unit_action") else _controller.current_unit_action
	
	var none_phase_value = _get_combat_phase_value("NONE")
	assert_eq(current_phase, none_phase_value, "Phase should be NONE")
	assert_true(active_combatants.is_empty(), "Active combatants should be empty")
	assert_null(current_unit_action, "Current unit action should be null")

func test_controller_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_signals: controller is null or invalid")
		return
		
	await super.test_controller_signals()
	
	# Additional signal checks for battle phase controller
	var required_signals := [
		"phase_started",
		"phase_ended",
		"action_points_changed",
		"unit_activated",
		"unit_deactivated"
	]
	
	for signal_name in required_signals:
		assert_true(_controller.has_signal(signal_name),
			"Controller should have signal %s" % signal_name)

func test_phase_transitions() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_phase_transitions: controller is null or invalid")
		return
	
	var phases := [
		_get_combat_phase_value("DEPLOYMENT"),
		_get_combat_phase_value("ACTION"),
		_get_combat_phase_value("END")
	]
	
	var can_transition := _controller.has_method("set_combat_state") or _controller.has_method("transition_to_phase")
	if not can_transition:
		assert_fail("Skipping test_phase_transitions: required methods not found")
		return
	
	for phase in phases:
		# Use set_combat_state if available, otherwise fall back to transition_to_phase
		if _controller.has_method("set_combat_state"):
			TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
				"phase": phase,
				"active_team": 0,
				"round": 1
			}])
		else:
			TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [phase])
			
		assert_signal_emitted(_controller, "phase_started", "phase_started signal should be emitted for phase %s" % phase)
		assert_eq(_last_phase, phase, "Last phase should be %s" % phase)
		
		# Use set_combat_state if available, otherwise fall back to transition_to_phase
		var none_phase = _get_combat_phase_value("NONE")
		if _controller.has_method("set_combat_state"):
			TypeSafeMixin._call_node_method_bool(_controller, "set_combat_state", [ {
				"phase": none_phase,
				"active_team": 0,
				"round": 1
			}])
		else:
			TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [none_phase])
			
		assert_signal_emitted(_controller, "phase_ended", "phase_ended signal should be emitted")

func test_controller_performance() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_performance: controller is null or invalid")
		return
	
	if not _controller.has_method("transition_to_phase"):
		assert_fail("Skipping test_controller_performance: transition_to_phase method not found")
		return
		
	var initial_memory = OS.get_static_memory_usage()
	var initial_time = Time.get_ticks_msec()
	
	start_performance_monitoring()
	
	# Perform battle phase controller specific operations
	var phases := [
		_get_combat_phase_value("DEPLOYMENT"),
		_get_combat_phase_value("ACTION"),
		_get_combat_phase_value("END")
	]
	
	var none_phase = _get_combat_phase_value("NONE")
	for phase in phases:
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [phase])
		await get_tree().process_frame
		TypeSafeMixin._call_node_method_bool(_controller, "transition_to_phase", [none_phase])
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	var elapsed_time = Time.get_ticks_msec() - initial_time
	var memory_delta = OS.get_static_memory_usage() - initial_memory
	
	# Verify reasonable performance
	assert_true(elapsed_time < 500, "Performance test should complete in under 500ms")
	assert_true(memory_delta < 1024 * 10, "Memory increase should be under 10KB")
	
	# Verify monitoring metrics
	assert_performance_metrics(metrics, {
		"layout_updates": {"max": 20, "description": "Should have reasonable layout updates"},
		"draw_calls": {"max": 10, "description": "Should have reasonable draw calls"},
		"theme_lookups": {"max": 20, "description": "Should have reasonable theme lookups"}
	})

# Override parent methods to specify properties that can be null
func _is_nullable_property(property_name: String) -> bool:
	var nullable_properties := [
		"current_unit_action",
		"active_combatants",
		"current_phase"
	]
	return property_name in nullable_properties

# Specify which properties should be compared during reset tests
func _is_simple_property(property_name: String) -> bool:
	var simple_properties := [
		"current_phase",
		"current_round",
		"is_battle_active"
	]
	return property_name in simple_properties

# Override parent test_accessibility to provide a Control parameter
func test_accessibility(control: Control = null) -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_accessibility: controller is null or invalid")
		return
		
	# Create a minimal Control object for testing accessibility if none provided
	var test_control = control
	if not is_instance_valid(test_control):
		test_control = Control.new()
		test_control.name = "TestAccessibilityControl"
		add_child_autofree(test_control)
		track_test_node(test_control)
		
		# Add some child controls for focus testing
		var child1 = Button.new()
		child1.name = "TestButton1"
		child1.text = "Test Button 1"
		child1.focus_mode = Control.FOCUS_ALL
		test_control.add_child(child1)
		
		var child2 = Button.new()
		child2.name = "TestButton2"
		child2.text = "Test Button 2"
		child2.focus_mode = Control.FOCUS_ALL
		test_control.add_child(child2)
	
	# Call parent method with the explicitly created control parameter
	super.test_accessibility(test_control)

# Helper method for better assert_performance_metrics
func assert_performance_metrics(metrics: Dictionary, expectations: Dictionary) -> void:
	for metric_name in expectations:
		if not metrics.has(metric_name):
			push_warning("Performance metric '%s' not found in results" % metric_name)
			continue
			
		var metric_value = metrics[metric_name]
		var expectation = expectations[metric_name]
		
		if typeof(expectation) == TYPE_DICTIONARY:
			if expectation.has("max"):
				assert_true(metric_value <= expectation.max,
					expectation.get("description", "Metric %s should be <= %s" % [metric_name, expectation.max]))
			elif expectation.has("min"):
				assert_true(metric_value >= expectation.min,
					expectation.get("description", "Metric %s should be >= %s" % [metric_name, expectation.min]))
			elif expectation.has("exact"):
				assert_eq(metric_value, expectation.exact,
					expectation.get("description", "Metric %s should be exactly %s" % [metric_name, expectation.exact]))
		else:
			# Simple case - exact match
			assert_eq(metric_value, expectation,
				"Metric %s should be exactly %s" % [metric_name, expectation])

# Override parent test_animations to provide a Control parameter
func test_animations(control: Control = null) -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_animations: controller is null or invalid")
		return
		
	# Create a minimal Control object for testing animations if none provided
	var test_control = control
	if not is_instance_valid(test_control):
		test_control = Control.new()
		test_control.name = "TestAnimationsControl"
		add_child_autofree(test_control)
		track_test_node(test_control)
		
		# Add a basic AnimationPlayer
		var animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		test_control.add_child(animation_player)
		
		# Add a simple animation
		var animation = Animation.new()
		animation.length = 0.3
		
		# Use the proper animation library API for Godot 4
		if not animation_player.has_animation_library(""):
			animation_player.add_animation_library("", AnimationLibrary.new())
		animation_player.get_animation_library("").add_animation("test_animation", animation)
	
	# Call parent method with the explicitly created control parameter
	super.test_animations(test_control)
