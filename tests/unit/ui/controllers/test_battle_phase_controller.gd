@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const TestedClass := preload("res://src/core/battle/state/BattleStateMachine.gd")
const Character := preload("res://src/game/combat/BattleCharacter.gd")

# Type-safe instance variables
var _last_phase: int
var _last_unit: Character
var _last_action_points: int

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	return TestedClass.new()

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
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_phase = GameEnums.CombatPhase.NONE
	_last_unit = null
	_last_action_points = 0

# Signal handlers
func _on_phase_started(phase: int) -> void:
	_last_phase = phase

func _on_phase_ended(phase: int) -> void:
	_last_phase = phase

func _on_action_points_changed(unit: Character, points: int) -> void:
	_last_unit = unit
	_last_action_points = points

func _on_unit_activated(unit: Character) -> void:
	_last_unit = unit

func _on_unit_deactivated(unit: Character) -> void:
	_last_unit = unit

# Test cases
func test_initial_state() -> void:
	assert_eq(_controller.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_controller.active_combatants.size(), 0)
	assert_null(_controller.current_unit_action)

func test_initialize_phase() -> void:
	var test_phase := GameEnums.CombatPhase.ACTION
	_controller.transition_to_phase(test_phase)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_last_phase, test_phase)

func test_handle_setup_state() -> void:
	_controller.transition_to(GameEnums.BattleState.SETUP)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_controller.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_controller.active_combatants.size(), 0)
	assert_null(_controller.current_unit_action)

func test_handle_deployment_phase() -> void:
	_controller.transition_to_phase(GameEnums.CombatPhase.DEPLOYMENT)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_last_phase, GameEnums.CombatPhase.DEPLOYMENT)

func test_handle_battle_phase() -> void:
	_controller.transition_to_phase(GameEnums.CombatPhase.ACTION)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_last_phase, GameEnums.CombatPhase.ACTION)

func test_handle_resolution_phase() -> void:
	_controller.transition_to_phase(GameEnums.CombatPhase.END)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_last_phase, GameEnums.CombatPhase.END)

func test_handle_cleanup_phase() -> void:
	_controller.transition_to(GameEnums.BattleState.CLEANUP)
	
	assert_signal_emitted(_controller, "phase_started")
	assert_eq(_controller.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_controller.active_combatants.size(), 0)
	assert_null(_controller.current_unit_action)

# Additional tests using base class functionality
func test_controller_state() -> void:
	await super.test_controller_state()
	
	# Additional state checks for battle phase controller
	assert_valid_controller_state({
		"current_phase": GameEnums.CombatPhase.NONE,
		"active_combatants": [],
		"current_unit_action": null
	})

func test_controller_signals() -> void:
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
	var phases := [
		GameEnums.CombatPhase.DEPLOYMENT,
		GameEnums.CombatPhase.ACTION,
		GameEnums.CombatPhase.END
	]
	
	for phase in phases:
		_controller.transition_to_phase(phase)
		assert_signal_emitted(_controller, "phase_started")
		assert_eq(_last_phase, phase)
		
		_controller.transition_to_phase(GameEnums.CombatPhase.NONE)
		assert_signal_emitted(_controller, "phase_ended")

func test_controller_performance() -> void:
	start_performance_monitoring()
	
	# Perform battle phase controller specific operations
	var phases := [
		GameEnums.CombatPhase.DEPLOYMENT,
		GameEnums.CombatPhase.ACTION,
		GameEnums.CombatPhase.END
	]
	
	for phase in phases:
		_controller.transition_to_phase(phase)
		await get_tree().process_frame
		_controller.transition_to_phase(GameEnums.CombatPhase.NONE)
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 15
	})