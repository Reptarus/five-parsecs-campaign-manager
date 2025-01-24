extends "res://addons/gut/test.gd"

const ObjectiveMarker = preload("res://src/data/resources/Deployment/ObjectiveMarker.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var marker: ObjectiveMarker
var objective_reached_signal_emitted := false
var objective_completed_signal_emitted := false
var objective_failed_signal_emitted := false
var last_reaching_unit: Character = null

func before_each() -> void:
	marker = ObjectiveMarker.new()
	add_child(marker)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	marker.queue_free()

func _reset_signals() -> void:
	objective_reached_signal_emitted = false
	objective_completed_signal_emitted = false
	objective_failed_signal_emitted = false
	last_reaching_unit = null

func _connect_signals() -> void:
	marker.objective_reached.connect(_on_objective_reached)
	marker.objective_completed.connect(_on_objective_completed)
	marker.objective_failed.connect(_on_objective_failed)

func _on_objective_reached(by_unit: Character) -> void:
	objective_reached_signal_emitted = true
	last_reaching_unit = by_unit

func _on_objective_completed() -> void:
	objective_completed_signal_emitted = true

func _on_objective_failed() -> void:
	objective_failed_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(marker)
	assert_eq(marker.required_turns, 0)
	assert_eq(marker.capture_radius, 2.0)
	assert_false(marker.fail_on_enemy_capture)
	assert_null(marker.capturing_unit)
	assert_eq(marker.turns_held, 0)
	assert_true(marker.is_in_group("objectives"))

func test_unit_enters_objective() -> void:
	var test_unit = Character.new()
	var test_area = Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	
	marker._on_area_entered(test_area)
	
	assert_true(objective_reached_signal_emitted)
	assert_eq(last_reaching_unit, test_unit)
	assert_eq(marker.capturing_unit, test_unit)

func test_enemy_unit_triggers_fail() -> void:
	marker.fail_on_enemy_capture = true
	
	var enemy_unit = Character.new()
	enemy_unit.set_enemy(true)
	var enemy_area = Area3D.new()
	enemy_area.add_to_group("units")
	enemy_unit.add_child(enemy_area)
	
	marker._on_area_entered(enemy_area)
	
	assert_true(objective_failed_signal_emitted)

func test_unit_exits_objective() -> void:
	var test_unit = Character.new()
	var test_area = Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	
	marker._on_area_entered(test_area)
	marker._on_area_exited(test_area)
	
	assert_null(marker.capturing_unit)
	assert_eq(marker.turns_held, 0)

func test_objective_completion() -> void:
	marker.required_turns = 2
	var test_unit = Character.new()
	var test_area = Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	
	marker._on_area_entered(test_area)
	
	marker.process_turn() # Turn 1
	assert_false(objective_completed_signal_emitted)
	
	marker.process_turn() # Turn 2
	assert_true(objective_completed_signal_emitted)

func test_progress_tracking() -> void:
	marker.required_turns = 3
	var test_unit = Character.new()
	var test_area = Area3D.new()
	test_area.add_to_group("units")
	test_unit.add_child(test_area)
	
	marker._on_area_entered(test_area)
	
	marker.process_turn()
	assert_eq(marker.turns_held, 1)
	
	marker.process_turn()
	assert_eq(marker.turns_held, 2)
	
	marker._on_area_exited(test_area)
	assert_eq(marker.turns_held, 0)