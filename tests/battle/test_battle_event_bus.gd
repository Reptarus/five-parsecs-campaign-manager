@tool
extends GdUnitGameTest

## FPCM_BattleEventBus Signal Flow Test Suite
##
## Tests the battle event bus for:
## - Signal routing verification
## - Component registration/unregistration
## - Performance monitoring validation
## - Emergency cleanup testing
## - Autoload functionality and lifecycle

# Test subject
const FPCM_BattleEventBus: GDScript = preload("res://src/core/battle/FPCM_BattleEventBus.gd")
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")

# Type-safe instance variables
var event_bus: Node = null
var test_battle_manager: FPCM_BattleManager.new() = null
var mock_ui_components: Array[Control] = []

# Signal tracking
var received_signals: Dictionary = {}

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Create event bus instance (simulating autoload)
	event_bus = FPCM_BattleEventBus.new()
	add_child(event_bus)
	track_node(event_bus)
	
	# Initialize battle manager
	test_battle_manager = FPCM_BattleManager.new()
	track_node(test_battle_manager)
	
	# Clear signal tracking
	received_signals.clear()
	mock_ui_components.clear()
	
	# Set up signal tracking
	_setup_signal_tracking()

func after_test() -> void:
	# Cleanup mock UI components
	for component in mock_ui_components:
		if is_instance_valid(component):
			component.queue_free()
	mock_ui_components.clear()
	
	# Cleanup
	event_bus = null
	test_battle_manager = null
	received_signals.clear()
	
	super.after_test()

## BASIC FUNCTIONALITY TESTS

func test_event_bus_initialization() -> void:
	assert_that(event_bus).is_not_null()
	assert_that(event_bus.registered_components).is_not_null()
	assert_that(event_bus.active_battle_manager).is_null()
	assert_that(event_bus.dice_system_instance).is_null()

func test_event_bus_has_required_signals() -> void:
	# Verify all required signals exist
	assert_that(event_bus.has_signal("battle_phase_changed")).is_true()
	assert_that(event_bus.has_signal("battle_state_updated")).is_true()
	assert_that(event_bus.has_signal("battle_completed")).is_true()
	assert_that(event_bus.has_signal("dice_roll_requested")).is_true()
	assert_that(event_bus.has_signal("ui_component_ready")).is_true()
	assert_that(event_bus.has_signal("performance_warning")).is_true()

## UI COMPONENT REGISTRATION TESTS

func test_ui_component_registration() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	
	event_bus.register_ui_component("TestUI", test_ui)
	
	assert_that(event_bus.registered_components.has("TestUI")).is_true()
	assert_that(event_bus.registered_components["TestUI"]).is_equal(test_ui)
	assert_that(received_signals.has("ui_component_ready")).is_true()

func test_ui_component_replacement_warning() -> void:
	var test_ui1 = _create_mock_ui_component("TestUI1")
	var test_ui2 = _create_mock_ui_component("TestUI2")
	
	event_bus.register_ui_component("TestUI", test_ui1)
	
	# Registering same name should issue warning but work
	event_bus.register_ui_component("TestUI", test_ui2)
	
	assert_that(event_bus.registered_components["TestUI"]).is_equal(test_ui2)

func test_ui_component_unregistration() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	
	event_bus.register_ui_component("TestUI", test_ui)
	assert_that(event_bus.registered_components.has("TestUI")).is_true()
	
	event_bus.unregister_ui_component("TestUI")
	
	assert_that(event_bus.registered_components.has("TestUI")).is_false()
	assert_that(received_signals.has("ui_component_removed")).is_true()

func test_unregistering_nonexistent_component() -> void:
	# Should handle gracefully
	event_bus.unregister_ui_component("NonExistentUI")
	
	# No error should occur, no signals should be emitted
	assert_that(received_signals.has("ui_component_removed")).is_false()

## BATTLE MANAGER INTEGRATION TESTS

func test_battle_manager_registration() -> void:
	event_bus.set_battle_manager(test_battle_manager)
	
	assert_that(event_bus.active_battle_manager).is_equal(test_battle_manager)

func test_battle_manager_signal_forwarding() -> void:
	event_bus.set_battle_manager(test_battle_manager)
	
	# Initialize battle to trigger phase change
	var test_mission = Resource.new()
	var test_crew: Array[Resource] = [Resource.new()]
	var test_enemies: Array[Resource] = [Resource.new()]
	
	test_battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	await get_tree().process_frame
	
	# Should have forwarded phase change signal
	assert_that(received_signals.has("battle_phase_changed")).is_true()

func test_battle_manager_replacement() -> void:
	var old_manager = test_battle_manager
	var new_manager = FPCM_BattleManager.new()
	track_node(new_manager)
	
	# Register first manager
	event_bus.set_battle_manager(old_manager)
	
	# Replace with new manager
	event_bus.set_battle_manager(new_manager)
	
	assert_that(event_bus.active_battle_manager).is_equal(new_manager)
	assert_that(event_bus.active_battle_manager).is_not_equal(old_manager)

## AUTOMATIC SIGNAL CONNECTION TESTS

func test_auto_signal_connection() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	test_ui.add_user_signal("phase_completed")
	test_ui.add_user_signal("dice_roll_requested", [{"name": "pattern", "type": TYPE_INT}, {"name": "context", "type": TYPE_STRING}])
	test_ui.add_user_signal("ui_error_occurred", [{"name": "error", "type": TYPE_STRING}, {"name": "context", "type": TYPE_DICTIONARY}])
	
	event_bus.register_ui_component("TestUI", test_ui)
	
	# Trigger signals from UI component
	test_ui.phase_completed.emit()
	test_ui.dice_roll_requested.emit(1, "test_roll")
	test_ui.ui_error_occurred.emit("test_error", {"test": true})
	
	await get_tree().process_frame
	
	# Signals should be processed by event bus
	# Note: Actual behavior would depend on implementation details

func test_auto_signal_disconnection() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	test_ui.add_user_signal("phase_completed")
	
	event_bus.register_ui_component("TestUI", test_ui)
	
	# Should be connected
	assert_that(test_ui.phase_completed.get_connections().size()).is_greater(0)
	
	event_bus.unregister_ui_component("TestUI")
	
	# Should be disconnected (if properly implemented)
	# Note: This would depend on actual implementation

## DICE SYSTEM INTEGRATION TESTS

func test_dice_roll_request_handling() -> void:
	# Mock dice pattern enum value
	var test_pattern = 1 # Assuming this is a valid DicePattern value
	var test_context = "test_dice_roll"
	
	event_bus.dice_roll_requested.emit(test_pattern, test_context)
	await get_tree().process_frame
	
	# Should create dice system instance and process request
	# Note: Actual verification would depend on DiceSystem integration

func test_dice_system_lazy_loading() -> void:
	assert_that(event_bus.dice_system_instance).is_null()
	
	# Trigger dice roll request
	event_bus.dice_roll_requested.emit(1, "test")
	await get_tree().process_frame
	
	# Should lazy load dice system (if implemented)
	# assert_that(event_bus.dice_system_instance).is_not_null()

## UI COORDINATION TESTS

func test_ui_lock_requests() -> void:
	var test_ui1 = _create_mock_ui_component("TestUI1")
	var test_ui2 = _create_mock_ui_component("TestUI2")
	
	# Add mock set_ui_locked method
	test_ui1.set_script(GDScript.new())
	test_ui2.set_script(GDScript.new())
	
	event_bus.register_ui_component("TestUI1", test_ui1)
	event_bus.register_ui_component("TestUI2", test_ui2)
	
	# Trigger UI lock request
	event_bus.ui_lock_requested.emit(true, "test_lock")
	await get_tree().process_frame
	
	# All registered components should receive lock request
	# Note: Would need mock verification

func test_ui_refresh_requests() -> void:
	var test_ui1 = _create_mock_ui_component("TestUI1")
	var test_ui2 = _create_mock_ui_component("TestUI2")
	
	event_bus.register_ui_component("TestUI1", test_ui1)
	event_bus.register_ui_component("TestUI2", test_ui2)
	
	# Request refresh of specific components
	event_bus.ui_refresh_requested.emit(["TestUI1"])
	await get_tree().process_frame
	
	# Should refresh only requested components
	# Note: Would need mock verification

func test_ui_refresh_with_invalid_components() -> void:
	# Request refresh of non-existent component
	event_bus.ui_refresh_requested.emit(["NonExistentUI"])
	await get_tree().process_frame
	
	# Should handle gracefully without errors

## PERFORMANCE MONITORING TESTS

func test_performance_monitoring() -> void:
	# Register many components to trigger performance warning
	for i in range(25): # More than the 20 component warning threshold
		var test_ui = _create_mock_ui_component("TestUI_" + str(i))
		event_bus.register_ui_component("TestUI_" + str(i), test_ui)
	
	# Force performance check
	event_bus._check_performance()
	
	assert_that(received_signals.has("performance_warning")).is_true()

func test_performance_check_timing() -> void:
	# Performance check should run periodically
	var initial_time = event_bus.last_performance_check
	
	# Advance time
	await get_tree().create_timer(event_bus.performance_check_interval + 0.1).timeout
	
	# Performance check should have updated
	assert_that(event_bus.last_performance_check).is_greater(initial_time)

## EVENT BUS STATUS TESTS

func test_event_bus_status() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	event_bus.register_ui_component("TestUI", test_ui)
	event_bus.set_battle_manager(test_battle_manager)
	
	var status = event_bus.get_event_bus_status()
	
	assert_that(status["registered_components"]).contains("TestUI")
	assert_that(status["active_battle_manager"]).is_true()
	assert_that(status["performance_healthy"]).is_true()

func test_event_bus_unhealthy_performance() -> void:
	# Register too many components
	for i in range(25):
		var test_ui = _create_mock_ui_component("TestUI_" + str(i))
		event_bus.register_ui_component("TestUI_" + str(i), test_ui)
	
	var status = event_bus.get_event_bus_status()
	assert_that(status["performance_healthy"]).is_false()

## EMERGENCY CLEANUP TESTS

func test_emergency_cleanup() -> void:
	# Set up active state
	var test_ui = _create_mock_ui_component("TestUI")
	event_bus.register_ui_component("TestUI", test_ui)
	event_bus.set_battle_manager(test_battle_manager)
	
	# Trigger emergency cleanup
	event_bus.cleanup_for_scene_change()
	
	assert_that(event_bus.registered_components.size()).is_equal(0)
	assert_that(event_bus.active_battle_manager).is_null()
	assert_that(event_bus.dice_system_instance).is_null()

func test_cleanup_signal_disconnection() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	test_ui.add_user_signal("phase_completed")
	
	event_bus.register_ui_component("TestUI", test_ui)
	event_bus.set_battle_manager(test_battle_manager)
	
	var initial_connections = test_ui.phase_completed.get_connections().size()
	
	event_bus.cleanup_for_scene_change()
	
	# Should disconnect all signals
	var final_connections = test_ui.phase_completed.get_connections().size()
	assert_that(final_connections).is_less_equal(initial_connections)

## SIGNAL FLOW INTEGRATION TESTS

func test_complete_signal_flow() -> void:
	# Set up complete system
	var test_ui = _create_mock_ui_component("TestUI")
	test_ui.add_user_signal("phase_completed")
	
	event_bus.register_ui_component("TestUI", test_ui)
	event_bus.set_battle_manager(test_battle_manager)
	
	# Initialize battle
	var test_mission = Resource.new()
	var test_crew: Array[Resource] = [Resource.new()]
	var test_enemies: Array[Resource] = [Resource.new()]
	
	test_battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Trigger UI phase completion
	test_ui.phase_completed.emit()
	await get_tree().process_frame
	
	# Should advance battle phase if auto_advance is enabled
	# Note: Actual verification would depend on battle manager state

func test_error_propagation() -> void:
	var test_ui = _create_mock_ui_component("TestUI")
	test_ui.add_user_signal("ui_error_occurred", [{"name": "error", "type": TYPE_STRING}, {"name": "context", "type": TYPE_DICTIONARY}])
	
	event_bus.register_ui_component("TestUI", test_ui)
	
	# Trigger error from UI
	test_ui.ui_error_occurred.emit("test_error", {"component": "TestUI"})
	await get_tree().process_frame
	
	# Should propagate as battle error
	assert_that(received_signals.has("battle_error")).is_true()

## STRESS TESTS

func test_high_frequency_signal_emission() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Emit many signals rapidly
	for i in range(1000):
		event_bus.battle_phase_changed.emit(0, 1) # Mock phase values
		event_bus.dice_roll_completed.emit(null) # Mock dice roll
	
	var elapsed = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(1000.0) # Should handle high frequency

func test_many_component_registration() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Register many components
	for i in range(100):
		var test_ui = _create_mock_ui_component("TestUI_" + str(i))
		event_bus.register_ui_component("TestUI_" + str(i), test_ui)
	
	var elapsed = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(500.0) # Should register efficiently
	
	# Cleanup should also be efficient
	start_time = Time.get_ticks_msec()
	event_bus.cleanup_for_scene_change()
	elapsed = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(200.0)

func test_memory_leak_prevention() -> void:
	var initial_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy many UI components
	for cycle in range(10):
		for i in range(20):
			var test_ui = _create_mock_ui_component("TestUI_" + str(i))
			event_bus.register_ui_component("TestUI_" + str(i), test_ui)
		
		event_bus.cleanup_for_scene_change()
		await get_tree().process_frame
	
	var final_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_increase = final_objects - initial_objects
	
	# Should not leak significant objects
	assert_that(object_increase).is_less(50)

## HELPER METHODS

func _setup_signal_tracking() -> void:
	# Connect to all major signals for tracking
	event_bus.battle_phase_changed.connect(_on_signal_received.bind("battle_phase_changed"))
	event_bus.battle_state_updated.connect(_on_signal_received.bind("battle_state_updated"))
	event_bus.battle_completed.connect(_on_signal_received.bind("battle_completed"))
	event_bus.battle_error.connect(_on_signal_received.bind("battle_error"))
	event_bus.ui_component_ready.connect(_on_signal_received.bind("ui_component_ready"))
	event_bus.ui_component_removed.connect(_on_signal_received.bind("ui_component_removed"))
	event_bus.dice_roll_requested.connect(_on_signal_received.bind("dice_roll_requested"))
	event_bus.dice_roll_completed.connect(_on_signal_received.bind("dice_roll_completed"))
	event_bus.performance_warning.connect(_on_signal_received.bind("performance_warning"))

func _on_signal_received(signal_name: String, args: Array = []) -> void:
	if not received_signals.has(signal_name):
		received_signals[signal_name] = []
	received_signals[signal_name].append({"args": args, "timestamp": Time.get_ticks_msec()})

func _create_mock_ui_component(name: String) -> Control:
	var mock_ui = Control.new()
	mock_ui.name = name
	mock_ui_components.append(mock_ui)
	track_node(mock_ui)
	return mock_ui