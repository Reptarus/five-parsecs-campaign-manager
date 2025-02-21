@tool
extends GameTest

const ObjectiveMarker = preload("res://src/data/resources/Deployment/ObjectiveMarker.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var marker: ObjectiveMarker
var objective_reached_signal_emitted: bool = false
var objective_completed_signal_emitted: bool = false
var objective_failed_signal_emitted: bool = false
var last_reaching_unit: Character = null

# Override track_test_node to handle Character nodes
func track_test_node(node: Node) -> void:
	if node is Node:
		super.track_test_node(node)

func before_each() -> void:
	await super.before_each()
	
	marker = ObjectiveMarker.new()
	if not marker:
		push_error("Failed to create objective marker")
		return
		
	add_child_autofree(marker)
	track_test_node(marker)
	
	_reset_signals()
	_connect_signals()
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	marker = null
	last_reaching_unit = null

func _reset_signals() -> void:
	objective_reached_signal_emitted = false
	objective_completed_signal_emitted = false
	objective_failed_signal_emitted = false
	last_reaching_unit = null

func _connect_signals() -> void:
	if not marker:
		push_error("Cannot connect signals: marker is null")
		return
		
	if marker.has_signal("objective_reached"):
		var err := marker.connect("objective_reached", _on_objective_reached)
		if err != OK:
			push_error("Failed to connect objective_reached signal")
			
	if marker.has_signal("objective_completed"):
		var err := marker.connect("objective_completed", _on_objective_completed)
		if err != OK:
			push_error("Failed to connect objective_completed signal")
			
	if marker.has_signal("objective_failed"):
		var err := marker.connect("objective_failed", _on_objective_failed)
		if err != OK:
			push_error("Failed to connect objective_failed signal")

func _on_objective_reached(by_unit: Character) -> void:
	objective_reached_signal_emitted = true
	last_reaching_unit = by_unit

func _on_objective_completed() -> void:
	objective_completed_signal_emitted = true

func _on_objective_failed() -> void:
	objective_failed_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(marker, "Objective marker should be initialized")
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_required_turns", [], 0), 0, "Should initialize with 0 required turns")
	assert_eq(TypeSafeMixin._safe_method_call_float(marker, "get_capture_radius", [], 2.0), 2.0, "Should initialize with default capture radius")
	assert_false(TypeSafeMixin._safe_method_call_bool(marker, "get_fail_on_enemy_capture", [], false), "Should initialize with fail_on_enemy_capture disabled")
	assert_null(TypeSafeMixin._safe_method_call_object(marker, "get_capturing_unit", [], null), "Should initialize with no capturing unit")
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_turns_held", [], 0), 0, "Should initialize with 0 turns held")
	assert_true(marker.is_in_group("objectives"), "Should be in objectives group")

func test_unit_enters_objective() -> void:
	var test_unit := _safe_cast_to_node(Character.new(), "Character") as Node
	var test_area := Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	add_child_autofree(test_unit)
	add_child_autofree(test_area)
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_entered", [test_area])
	
	assert_true(objective_reached_signal_emitted, "Should emit objective_reached signal")
	assert_eq(last_reaching_unit, test_unit, "Should set last reaching unit")
	assert_eq(TypeSafeMixin._safe_method_call_object(marker, "get_capturing_unit", [], null), test_unit, "Should set capturing unit")

func test_enemy_unit_triggers_fail() -> void:
	TypeSafeMixin._safe_method_call_bool(marker, "set_fail_on_enemy_capture", [true])
	
	var enemy_unit := _safe_cast_to_node(Character.new(), "Character") as Node
	TypeSafeMixin._safe_method_call_bool(enemy_unit, "set_enemy", [true])
	var enemy_area := Area3D.new()
	enemy_area.add_to_group("units")
	enemy_unit.add_child(enemy_area)
	add_child_autofree(enemy_unit)
	add_child_autofree(enemy_area)
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_entered", [enemy_area])
	
	assert_true(objective_failed_signal_emitted, "Should emit objective_failed signal")

func test_unit_exits_objective() -> void:
	var test_unit := _safe_cast_to_node(Character.new(), "Character") as Node
	var test_area := Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	add_child_autofree(test_unit)
	add_child_autofree(test_area)
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_entered", [test_area])
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_exited", [test_area])
	
	assert_null(TypeSafeMixin._safe_method_call_object(marker, "get_capturing_unit", [], null), "Should clear capturing unit")
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_turns_held", [], 0), 0, "Should reset turns held")

func test_objective_completion() -> void:
	TypeSafeMixin._safe_method_call_bool(marker, "set_required_turns", [2])
	var test_unit := _safe_cast_to_node(Character.new(), "Character") as Node
	var test_area := Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	add_child_autofree(test_unit)
	add_child_autofree(test_area)
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_entered", [test_area])
	
	TypeSafeMixin._safe_method_call_bool(marker, "process_turn", []) # Turn 1
	assert_false(objective_completed_signal_emitted, "Should not complete after first turn")
	
	TypeSafeMixin._safe_method_call_bool(marker, "process_turn", []) # Turn 2
	assert_true(objective_completed_signal_emitted, "Should complete after second turn")

func test_progress_tracking() -> void:
	TypeSafeMixin._safe_method_call_bool(marker, "set_required_turns", [3])
	var test_unit := _safe_cast_to_node(Character.new(), "Character") as Node
	var test_area := Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	add_child_autofree(test_unit)
	add_child_autofree(test_area)
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_entered", [test_area])
	
	TypeSafeMixin._safe_method_call_bool(marker, "process_turn", [])
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_turns_held", [], 0), 1, "Should increment turns held")
	
	TypeSafeMixin._safe_method_call_bool(marker, "process_turn", [])
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_turns_held", [], 0), 2, "Should increment turns held again")
	
	TypeSafeMixin._safe_method_call_bool(marker, "_on_area_exited", [test_area])
	assert_eq(TypeSafeMixin._safe_method_call_int(marker, "get_turns_held", [], 0), 0, "Should reset turns held on exit")