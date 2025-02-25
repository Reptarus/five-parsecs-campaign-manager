## Objective Marker Test Suite
## Tests the functionality of the objective marker system including:
## - Marker initialization and setup
## - Unit interaction and capture mechanics
## - Turn processing and objective completion
## - Signal handling and verification
## - Performance and boundary conditions
@tool
extends GameTest

# Type-safe script references
const ObjectiveMarker := preload("res://src/data/resources/Deployment/ObjectiveMarker.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0
const DEFAULT_CAPTURE_RADIUS := 2.0
const DEFAULT_REQUIRED_TURNS := 3

# Type-safe instance variables
var _marker: Node = null
var _objective_reached_signal_emitted: bool = false
var _objective_completed_signal_emitted: bool = false
var _objective_failed_signal_emitted: bool = false
var _last_reaching_unit: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize marker
	var marker_instance: Node = ObjectiveMarker.new()
	_marker = TypeSafeMixin._safe_cast_node(marker_instance)
	if not _marker:
		push_error("Failed to create objective marker")
		return
	add_child_autofree(_marker)
	track_test_node(_marker)
	
	_reset_signals()
	_connect_signals()
	watch_signals(_marker)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_marker = null
	_last_reaching_unit = null
	await super.after_each()

# Signal Management Methods
func _reset_signals() -> void:
	_objective_reached_signal_emitted = false
	_objective_completed_signal_emitted = false
	_objective_failed_signal_emitted = false
	_last_reaching_unit = null

func _connect_signals() -> void:
	if not _marker:
		push_error("Cannot connect signals: marker is null")
		return
		
	if _marker.has_signal("objective_reached"):
		var err := _marker.connect("objective_reached", _on_objective_reached)
		if err != OK:
			push_error("Failed to connect objective_reached signal")
			
	if _marker.has_signal("objective_completed"):
		var err := _marker.connect("objective_completed", _on_objective_completed)
		if err != OK:
			push_error("Failed to connect objective_completed signal")
			
	if _marker.has_signal("objective_failed"):
		var err := _marker.connect("objective_failed", _on_objective_failed)
		if err != OK:
			push_error("Failed to connect objective_failed signal")

# Signal Handlers
func _on_objective_reached(by_unit: Node) -> void:
	_objective_reached_signal_emitted = true
	_last_reaching_unit = by_unit

func _on_objective_completed() -> void:
	_objective_completed_signal_emitted = true

func _on_objective_failed() -> void:
	_objective_failed_signal_emitted = true

# Helper Methods
func _create_test_unit(is_enemy: bool = false) -> Node:
	var character: FiveParsecsCharacter = Character.new()
	var unit: Node = Node.new()
	unit.set_meta("character", character)
	TypeSafeMixin._safe_method_call_bool(character, "set_enemy", [is_enemy])
	add_child_autofree(unit)
	track_test_node(unit)
	return unit

func _create_test_area(parent: Node) -> Area3D:
	var area := Area3D.new()
	area.add_to_group("units")
	parent.add_child(area)
	track_test_node(area)
	return area

# Initial Setup Tests
func test_initial_setup() -> void:
	assert_not_null(_marker, "Objective marker should be initialized")
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_required_turns", []), 0, "Should initialize with 0 required turns")
	assert_eq(TypeSafeMixin._safe_method_call_float(_marker, "get_capture_radius", []), DEFAULT_CAPTURE_RADIUS, "Should initialize with default capture radius")
	assert_false(TypeSafeMixin._safe_method_call_bool(_marker, "get_fail_on_enemy_capture", []), "Should initialize with fail_on_enemy_capture disabled")
	assert_null(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), "Should initialize with no capturing unit")
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_turns_held", []), 0, "Should initialize with 0 turns held")
	assert_true(_marker.is_in_group("objectives"), "Should be in objectives group")

# Unit Interaction Tests
func test_unit_enters_objective() -> void:
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [test_area])
	
	assert_true(_objective_reached_signal_emitted, "Should emit objective_reached signal")
	assert_eq(_last_reaching_unit, test_unit, "Should set last reaching unit")
	assert_eq(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), test_unit, "Should set capturing unit")

func test_enemy_unit_triggers_fail() -> void:
	TypeSafeMixin._safe_method_call_bool(_marker, "set_fail_on_enemy_capture", [true])
	
	var enemy_unit := _create_test_unit(true)
	var enemy_area := _create_test_area(enemy_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [enemy_area])
	
	assert_true(_objective_failed_signal_emitted, "Should emit objective_failed signal")

func test_unit_exits_objective() -> void:
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [test_area])
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_exited", [test_area])
	
	assert_null(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), "Should clear capturing unit")
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_turns_held", []), 0, "Should reset turns held")

func test_objective_completion() -> void:
	TypeSafeMixin._safe_method_call_bool(_marker, "set_required_turns", [DEFAULT_REQUIRED_TURNS])
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [test_area])
	
	for i in range(DEFAULT_REQUIRED_TURNS - 1):
		TypeSafeMixin._safe_method_call_bool(_marker, "process_turn", [])
		assert_false(_objective_completed_signal_emitted, "Should not complete before required turns")
	
	TypeSafeMixin._safe_method_call_bool(_marker, "process_turn", [])
	assert_true(_objective_completed_signal_emitted, "Should complete after required turns")

func test_progress_tracking() -> void:
	TypeSafeMixin._safe_method_call_bool(_marker, "set_required_turns", [DEFAULT_REQUIRED_TURNS])
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [test_area])
	
	TypeSafeMixin._safe_method_call_bool(_marker, "process_turn", [])
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_turns_held", []), 1, "Should increment turns held")
	
	TypeSafeMixin._safe_method_call_bool(_marker, "process_turn", [])
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_turns_held", []), 2, "Should increment turns held again")
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_exited", [test_area])
	assert_eq(TypeSafeMixin._safe_method_call_int(_marker, "get_turns_held", []), 0, "Should reset turns held on exit")

# Boundary Tests
func test_multiple_units_interaction() -> void:
	var unit1 := _create_test_unit()
	var area1 := _create_test_area(unit1)
	var unit2 := _create_test_unit()
	var area2 := _create_test_area(unit2)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [area1])
	assert_eq(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), unit1, "First unit should capture")
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [area2])
	assert_eq(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), unit1, "Should maintain first capture")

func test_invalid_area_handling() -> void:
	var invalid_area := Area3D.new()
	add_child_autofree(invalid_area)
	track_test_node(invalid_area)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [invalid_area])
	assert_false(_objective_reached_signal_emitted, "Should not emit signal for invalid area")
	assert_null(TypeSafeMixin._safe_method_call_object(_marker, "get_capturing_unit", []), "Should not set capturing unit for invalid area")

# Performance Tests
func test_turn_processing_performance() -> void:
	TypeSafeMixin._safe_method_call_bool(_marker, "set_required_turns", [100])
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	TypeSafeMixin._safe_method_call_bool(_marker, "_on_area_entered", [test_area])
	
	var start_time := Time.get_ticks_msec()
	for i in range(100):
		TypeSafeMixin._safe_method_call_bool(_marker, "process_turn", [])
	var duration := Time.get_ticks_msec() - start_time
	
	assert_true(duration < 1000, "Should process 100 turns within 1 second")