## Unit tests for the Battle State Machine component
##
## Tests the core functionality of the battle state management system including:
## - State transitions
## - Phase management
## - Combatant tracking
## - Battle lifecycle
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends "res://tests/fixtures/game_test.gd"

# Constants and preloads
const BattleStateMachine := preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")
const BattleCharacterScript := preload("res://src/core/battle/BattleCharacter.gd")
const TEST_TIMEOUT := 1000 # ms timeout for performance tests

# Test instance variables
var battle_state: BattleStateMachine = null
var game_state_manager: GameStateManager = null
var _signal_count: int = 0
var _signal_data: Dictionary = {}

# Helper methods
func create_test_battle_state() -> BattleStateMachine:
	var state := BattleStateMachine.new(game_state_manager)
	if not state:
		push_error("Failed to create battle state")
		return null
		
	var added_node := add_child_autofree(state)
	if not added_node:
		push_error("Failed to add battle state node")
		return null
		
	track_test_node(state)
	return state

func setup_active_battle() -> void:
	if not battle_state:
		push_error("Battle state not initialized")
		return
		
	_call_node_method(battle_state, "start_battle", [])
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	game_state_manager = GameStateManager.new()
	if not game_state_manager:
		push_error("Failed to create game state manager")
		return
		
	var added_node := add_child_autofree(game_state_manager)
	if not added_node:
		push_error("Failed to add game state manager node")
		return
		
	track_test_node(game_state_manager)
	
	battle_state = create_test_battle_state()
	if not battle_state:
		push_error("Failed to create battle state")
		return
		
	_signal_count = 0
	_signal_data.clear()
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	battle_state = null
	game_state_manager = null
	_signal_data.clear()

# Signal handlers
func _on_battle_started() -> void:
	_signal_count += 1
	_signal_data["battle_started"] = true

func _on_battle_ended(victory_type: GameEnums.VictoryConditionType) -> void:
	_signal_count += 1
	_signal_data["battle_ended"] = true
	_signal_data["victory_type"] = victory_type

func _on_phase_changed(from_phase: GameEnums.CombatPhase, to_phase: GameEnums.CombatPhase) -> void:
	_signal_count += 1
	_signal_data["phase_changed"] = true
	_signal_data["from_phase"] = from_phase
	_signal_data["to_phase"] = to_phase

func _on_phase_transition_test(_from_phase: GameEnums.CombatPhase, _to_phase: GameEnums.CombatPhase) -> void:
	_signal_count += 1

# Basic state tests
func test_initial_state() -> void:
	assert_not_null(battle_state, "Battle state should be initialized")
	
	var current_state: int = _get_state_property(battle_state, "current_state", GameEnums.BattleState.NONE)
	assert_eq(current_state, GameEnums.BattleState.SETUP, "Battle should start in SETUP state")
	
	var current_phase: int = _get_state_property(battle_state, "current_phase", GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.NONE, "Combat phase should start as NONE")
	
	var current_round: int = _get_state_property(battle_state, "current_round", 0)
	assert_eq(current_round, 1, "Battle should start at round 1")
	
	var is_active: bool = _get_state_property(battle_state, "is_battle_active", true)
	assert_false(is_active, "Battle should not be active initially")

func test_start_battle() -> void:
	var connect_result: Error = battle_state.connect("battle_started", _on_battle_started)
	if connect_result != OK:
		push_error("Failed to connect battle_started signal")
		return
	
	_call_node_method(battle_state, "start_battle", [])
	
	var is_active: bool = _get_state_property(battle_state, "is_battle_active", false)
	assert_true(is_active, "Battle should be active after starting")
	
	assert_true(_signal_data.has("battle_started"), "Battle started signal should be emitted")
	
	var current_state: int = _get_state_property(battle_state, "current_state", GameEnums.BattleState.NONE)
	assert_eq(current_state, GameEnums.BattleState.ROUND, "Battle should transition to ROUND state")

func test_end_battle() -> void:
	_call_node_method(battle_state, "start_battle", [])
	
	var connect_result: Error = battle_state.connect("battle_ended", _on_battle_ended)
	if connect_result != OK:
		push_error("Failed to connect battle_ended signal")
		return
	
	_call_node_method(battle_state, "end_battle", [GameEnums.VictoryConditionType.ELIMINATION])
	
	var is_active: bool = _get_state_property(battle_state, "is_battle_active", true)
	assert_false(is_active, "Battle should not be active after ending")
	
	assert_true(_signal_data.has("battle_ended"), "Battle ended signal should be emitted")
	
	var victory_type: int = _signal_data.get("victory_type", -1)
	assert_eq(victory_type, GameEnums.VictoryConditionType.ELIMINATION, "Victory type should match")

func test_phase_transitions() -> void:
	_call_node_method(battle_state, "start_battle", [])
	
	var connect_result: Error = battle_state.connect("phase_changed", _on_phase_changed)
	if connect_result != OK:
		push_error("Failed to connect phase_changed signal")
		return
	
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])
	
	var current_phase: int = _get_state_property(battle_state, "current_phase", GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.INITIATIVE, "Should transition to initiative phase")
	
	assert_true(_signal_data.has("phase_changed"), "Phase changed signal should be emitted")
	
	var to_phase: int = _signal_data.get("to_phase", GameEnums.CombatPhase.NONE)
	assert_eq(to_phase, GameEnums.CombatPhase.INITIATIVE, "Target phase should match")
	
	_signal_data.clear()
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	current_phase = _get_state_property(battle_state, "current_phase", GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.ACTION, "Should transition to action phase")
	
	var from_phase: int = _signal_data.get("from_phase", GameEnums.CombatPhase.NONE)
	assert_eq(from_phase, GameEnums.CombatPhase.INITIATIVE, "Previous phase should match")
	
	to_phase = _signal_data.get("to_phase", GameEnums.CombatPhase.NONE)
	assert_eq(to_phase, GameEnums.CombatPhase.ACTION, "New phase should match")

func test_add_combatant() -> void:
	var character := create_test_character()
	if not character:
		push_error("Failed to create test character")
		return
		
	track_test_node(character)
	_call_node_method(battle_state, "add_combatant", [character])
	
	var active_combatants: Array = _call_node_method(battle_state, "get_active_combatants", []) as Array
	assert_true(active_combatants.has(character), "Character should be added to active combatants")

func test_save_and_load_state() -> void:
	_call_node_method(battle_state, "start_battle", [])
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var saved_state: Dictionary = _call_node_method(battle_state, "save_state", []) as Dictionary
	assert_not_null(saved_state, "Should create save state")
	
	var new_battle_state := BattleStateMachine.new(game_state_manager)
	if not new_battle_state:
		push_error("Failed to create new battle state")
		return
		
	var added_node := add_child_autofree(new_battle_state)
	if not added_node:
		push_error("Failed to add new battle state")
		return
		
	track_test_node(new_battle_state)
	
	_call_node_method(new_battle_state, "load_state", [saved_state])
	
	var loaded_phase: int = _get_state_property(new_battle_state, "current_phase", GameEnums.CombatPhase.NONE)
	assert_eq(loaded_phase, GameEnums.CombatPhase.ACTION, "Should load correct phase")
	
	var loaded_round: int = _get_state_property(new_battle_state, "current_round", 0)
	assert_eq(loaded_round, 1, "Should load correct round")

# Performance tests
func test_rapid_state_transitions() -> void:
	setup_active_battle()
	watch_signals(battle_state)
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])
		_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < TEST_TIMEOUT, "Should handle rapid state transitions efficiently")

# Error boundary tests
func test_invalid_phase_transition() -> void:
	watch_signals(battle_state)
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var current_phase: int = _get_state_property(battle_state, "current_phase", GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.NONE, "Should not allow phase transition before battle starts")

func test_invalid_battle_start() -> void:
	_call_node_method(battle_state, "start_battle", [])
	
	var connect_result: Error = battle_state.connect("battle_started", _on_battle_started)
	if connect_result != OK:
		push_error("Failed to connect battle_started signal")
		return
	
	_signal_data.clear()
	_call_node_method(battle_state, "start_battle", [])
	assert_false(_signal_data.has("battle_started"), "Should not emit signal when starting an already active battle")

# Signal verification tests
func test_phase_transition_signals() -> void:
	setup_active_battle()
	watch_signals(battle_state)
	
	var connect_result: Error = battle_state.phase_changed.connect(_on_phase_transition_test)
	if connect_result != OK:
		push_error("Failed to connect phase_changed signal")
		return
		
	_call_node_method(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	assert_eq(_signal_count, 1, "Should emit phase_changed signal once")
