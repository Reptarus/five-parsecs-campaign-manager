@tool
extends GameTest

const TestedClass = preload("res://src/core/battle/state/BattleStateMachine.gd")
const Character = preload("res://src/core/battle/BattleCharacter.gd")

var _instance: Node
var _phase_started_signal_emitted := false
var _phase_ended_signal_emitted := false
var _action_points_changed_signal_emitted := false
var _unit_activated_signal_emitted := false
var _unit_deactivated_signal_emitted := false
var _last_phase: int
var _last_unit: Character
var _last_action_points: int

func before_each() -> void:
	_instance = TestedClass.new()
	add_child(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_instance.queue_free()
	_instance = null

func _connect_signals() -> void:
	_instance.phase_started.connect(_on_phase_started)
	_instance.phase_ended.connect(_on_phase_ended)
	_instance.action_points_changed.connect(_on_action_points_changed)
	_instance.unit_activated.connect(_on_unit_activated)
	_instance.unit_deactivated.connect(_on_unit_deactivated)

func _disconnect_signals() -> void:
	if _instance:
		if _instance.phase_started.is_connected(_on_phase_started):
			_instance.phase_started.disconnect(_on_phase_started)
		if _instance.phase_ended.is_connected(_on_phase_ended):
			_instance.phase_ended.disconnect(_on_phase_ended)
		if _instance.action_points_changed.is_connected(_on_action_points_changed):
			_instance.action_points_changed.disconnect(_on_action_points_changed)
		if _instance.unit_activated.is_connected(_on_unit_activated):
			_instance.unit_activated.disconnect(_on_unit_activated)
		if _instance.unit_deactivated.is_connected(_on_unit_deactivated):
			_instance.unit_deactivated.disconnect(_on_unit_deactivated)

func _reset_signals() -> void:
	_phase_started_signal_emitted = false
	_phase_ended_signal_emitted = false
	_action_points_changed_signal_emitted = false
	_unit_activated_signal_emitted = false
	_unit_deactivated_signal_emitted = false
	_last_phase = GameEnums.CombatPhase.NONE
	_last_unit = null
	_last_action_points = 0

func _on_phase_started(phase: int) -> void:
	_phase_started_signal_emitted = true
	_last_phase = phase

func _on_phase_ended(phase: int) -> void:
	_phase_ended_signal_emitted = true
	_last_phase = phase

func _on_action_points_changed(unit: Character, points: int) -> void:
	_action_points_changed_signal_emitted = true
	_last_unit = unit
	_last_action_points = points

func _on_unit_activated(unit: Character) -> void:
	_unit_activated_signal_emitted = true
	_last_unit = unit

func _on_unit_deactivated(unit: Character) -> void:
	_unit_deactivated_signal_emitted = true
	_last_unit = unit

func test_initial_state() -> void:
	assert_eq(_instance.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_instance.active_combatants.size(), 0)
	assert_null(_instance.current_unit_action)

func test_initialize_phase() -> void:
	var test_phase = GameEnums.CombatPhase.ACTION
	_instance.transition_to_phase(test_phase)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_last_phase, test_phase)

func test_handle_setup_state() -> void:
	_instance.transition_to(GameEnums.BattleState.SETUP)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_instance.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_instance.active_combatants.size(), 0)
	assert_null(_instance.current_unit_action)

func test_handle_deployment_phase() -> void:
	_instance.transition_to_phase(GameEnums.CombatPhase.DEPLOYMENT)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_last_phase, GameEnums.CombatPhase.DEPLOYMENT)

func test_handle_battle_phase() -> void:
	_instance.transition_to_phase(GameEnums.CombatPhase.ACTION)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_last_phase, GameEnums.CombatPhase.ACTION)

func test_handle_resolution_phase() -> void:
	_instance.transition_to_phase(GameEnums.CombatPhase.END)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_last_phase, GameEnums.CombatPhase.END)

func test_handle_cleanup_phase() -> void:
	_instance.transition_to(GameEnums.BattleState.CLEANUP)
	
	assert_true(_phase_started_signal_emitted)
	assert_eq(_instance.current_phase, GameEnums.CombatPhase.NONE)
	assert_eq(_instance.active_combatants.size(), 0)
	assert_null(_instance.current_unit_action)