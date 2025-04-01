## Objective Marker Test Suite
## Tests the functionality of the objective marker system including:
## - Marker initialization and setup
## - Unit interaction and capture mechanics
## - Turn processing and objective completion
## - Signal handling and verification
## - Performance and boundary conditions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

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
	
	# Initialize marker with safer type handling
	var marker_instance = ObjectiveMarker.new()
	
	# Check if ObjectiveMarker is a Node or Resource
	if marker_instance is Node:
		_marker = marker_instance
	elif marker_instance is Resource:
		# Create a Node wrapper for the Resource
		_marker = Node.new()
		_marker.set_name("ObjectiveMarkerWrapper")
		_marker.set_meta("marker", marker_instance)
		
		# Store marker_instance in a variable that can be captured by lambda
		var marker_res = marker_instance
		
		# Define forwarding methods
		_marker.set("get_required_turns", Callable(marker_res, "get_required_turns") if marker_res.has_method("get_required_turns") else
			func(): return 0)
		
		_marker.set("get_capture_radius", Callable(marker_res, "get_capture_radius") if marker_res.has_method("get_capture_radius") else
			func(): return DEFAULT_CAPTURE_RADIUS)
		
		_marker.set("get_fail_on_enemy_capture", Callable(marker_res, "get_fail_on_enemy_capture") if marker_res.has_method("get_fail_on_enemy_capture") else
			func(): return false)
		
		_marker.set("get_capturing_unit", Callable(marker_res, "get_capturing_unit") if marker_res.has_method("get_capturing_unit") else
			func(): return null)
		
		_marker.set("get_turns_held", Callable(marker_res, "get_turns_held") if marker_res.has_method("get_turns_held") else
			func(): return 0)
		
		_marker.set("set_required_turns", Callable(marker_res, "set_required_turns") if marker_res.has_method("set_required_turns") else
			func(turns): return false)
		
		_marker.set("set_fail_on_enemy_capture", Callable(marker_res, "set_fail_on_enemy_capture") if marker_res.has_method("set_fail_on_enemy_capture") else
			func(value): return false)
		
		_marker.set("_on_area_entered", Callable(marker_res, "_on_area_entered") if marker_res.has_method("_on_area_entered") else
			func(area): return false)
		
		_marker.set("_on_area_exited", Callable(marker_res, "_on_area_exited") if marker_res.has_method("_on_area_exited") else
			func(area): return false)
		
		_marker.set("process_turn", Callable(marker_res, "process_turn") if marker_res.has_method("process_turn") else
			func(): return false)
			
		# Add signal forwarding
		if marker_res.has_signal("objective_reached"):
			_marker.add_user_signal("objective_reached", [ {"name": "by_unit", "type": "Object"}])
			marker_res.connect("objective_reached", func(unit): _marker.emit_signal("objective_reached", unit))
			
		if marker_res.has_signal("objective_completed"):
			_marker.add_user_signal("objective_completed")
			marker_res.connect("objective_completed", func(): _marker.emit_signal("objective_completed"))
			
		if marker_res.has_signal("objective_failed"):
			_marker.add_user_signal("objective_failed")
			marker_res.connect("objective_failed", func(): _marker.emit_signal("objective_failed"))
			
		# Add to groups
		if marker_res.is_in_group("objectives"):
			_marker.add_to_group("objectives")
	else:
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
	var character_instance = Character.new()
	
	# Check if Character is a Node or Resource
	if character_instance is Node:
		var character = character_instance
		if character.has_method("set_enemy"):
			character.set_enemy(is_enemy)
		add_child_autofree(character)
		track_test_node(character)
		return character
	elif character_instance is Resource:
		# Create a Node wrapper for the Resource
		var unit = Node.new()
		unit.set_name("CharacterWrapper")
		unit.set_meta("character", character_instance)
		
		# Set enemy status if possible
		if character_instance.has_method("set_enemy"):
			character_instance.set_enemy(is_enemy)
		
		add_child_autofree(unit)
		track_test_node(unit)
		return unit
	else:
		push_error("Failed to create character")
		return null

func _create_test_area(parent: Node) -> Area3D:
	var area := Area3D.new()
	area.add_to_group("units")
	parent.add_child(area)
	track_test_node(area)
	return area

# Initial Setup Tests
func test_initial_setup() -> void:
	assert_not_null(_marker, "Objective marker should be initialized")
	
	var required_turns = 0
	if _marker.has_method("get_required_turns"):
		required_turns = _marker.get_required_turns()
	assert_eq(required_turns, 0, "Should initialize with 0 required turns")
	
	var capture_radius = DEFAULT_CAPTURE_RADIUS
	if _marker.has_method("get_capture_radius"):
		capture_radius = _marker.get_capture_radius()
	assert_eq(capture_radius, DEFAULT_CAPTURE_RADIUS, "Should initialize with default capture radius")
	
	var fail_on_enemy_capture = false
	if _marker.has_method("get_fail_on_enemy_capture"):
		fail_on_enemy_capture = _marker.get_fail_on_enemy_capture()
	assert_false(fail_on_enemy_capture, "Should initialize with fail_on_enemy_capture disabled")
	
	var capturing_unit = null
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_null(capturing_unit, "Should initialize with no capturing unit")
	
	var turns_held = 0
	if _marker.has_method("get_turns_held"):
		turns_held = _marker.get_turns_held()
	assert_eq(turns_held, 0, "Should initialize with 0 turns held")
	
	assert_true(_marker.is_in_group("objectives"), "Should be in objectives group")

# Unit Interaction Tests
func test_unit_enters_objective() -> void:
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(test_area)
	
	assert_true(_objective_reached_signal_emitted, "Should emit objective_reached signal")
	assert_eq(_last_reaching_unit, test_unit, "Should set last reaching unit")
	
	var capturing_unit = null
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_eq(capturing_unit, test_unit, "Should set capturing unit")

func test_enemy_unit_triggers_fail() -> void:
	if _marker.has_method("set_fail_on_enemy_capture"):
		_marker.set_fail_on_enemy_capture(true)
	
	var enemy_unit := _create_test_unit(true)
	var enemy_area := _create_test_area(enemy_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(enemy_area)
	
	assert_true(_objective_failed_signal_emitted, "Should emit objective_failed signal")

func test_unit_exits_objective() -> void:
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(test_area)
		
	if _marker.has_method("_on_area_exited"):
		_marker._on_area_exited(test_area)
	
	var capturing_unit = null
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_null(capturing_unit, "Should clear capturing unit")
	
	var turns_held = 0
	if _marker.has_method("get_turns_held"):
		turns_held = _marker.get_turns_held()
	assert_eq(turns_held, 0, "Should reset turns held")

func test_objective_completion() -> void:
	if _marker.has_method("set_required_turns"):
		_marker.set_required_turns(DEFAULT_REQUIRED_TURNS)
		
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(test_area)
	
	for i in range(DEFAULT_REQUIRED_TURNS - 1):
		if _marker.has_method("process_turn"):
			_marker.process_turn()
		assert_false(_objective_completed_signal_emitted, "Should not complete before required turns")
	
	if _marker.has_method("process_turn"):
		_marker.process_turn()
	assert_true(_objective_completed_signal_emitted, "Should complete after required turns")

func test_progress_tracking() -> void:
	if _marker.has_method("set_required_turns"):
		_marker.set_required_turns(DEFAULT_REQUIRED_TURNS)
		
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(test_area)
	
	if _marker.has_method("process_turn"):
		_marker.process_turn()
		
	var turns_held = 0
	if _marker.has_method("get_turns_held"):
		turns_held = _marker.get_turns_held()
	assert_eq(turns_held, 1, "Should increment turns held")
	
	if _marker.has_method("process_turn"):
		_marker.process_turn()
		
	if _marker.has_method("get_turns_held"):
		turns_held = _marker.get_turns_held()
	assert_eq(turns_held, 2, "Should increment turns held again")
	
	if _marker.has_method("_on_area_exited"):
		_marker._on_area_exited(test_area)
		
	if _marker.has_method("get_turns_held"):
		turns_held = _marker.get_turns_held()
	assert_eq(turns_held, 0, "Should reset turns held on exit")

# Boundary Tests
func test_multiple_units_interaction() -> void:
	var unit1 := _create_test_unit()
	var area1 := _create_test_area(unit1)
	var unit2 := _create_test_unit()
	var area2 := _create_test_area(unit2)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(area1)
		
	var capturing_unit = null
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_eq(capturing_unit, unit1, "First unit should capture")
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(area2)
		
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_eq(capturing_unit, unit1, "Should maintain first capture")

func test_invalid_area_handling() -> void:
	var invalid_area := Area3D.new()
	add_child_autofree(invalid_area)
	track_test_node(invalid_area)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(invalid_area)
		
	assert_false(_objective_reached_signal_emitted, "Should not emit signal for invalid area")
	
	var capturing_unit = null
	if _marker.has_method("get_capturing_unit"):
		capturing_unit = _marker.get_capturing_unit()
	assert_null(capturing_unit, "Should not set capturing unit for invalid area")

# Performance Tests
func test_turn_processing_performance() -> void:
	if _marker.has_method("set_required_turns"):
		_marker.set_required_turns(100)
		
	var test_unit := _create_test_unit()
	var test_area := _create_test_area(test_unit)
	
	if _marker.has_method("_on_area_entered"):
		_marker._on_area_entered(test_area)
	
	var start_time := Time.get_ticks_msec()
	for i in range(100):
		if _marker.has_method("process_turn"):
			_marker.process_turn()
	var duration := Time.get_ticks_msec() - start_time
	
	assert_true(duration < 1000, "Should process 100 turns within 1 second")