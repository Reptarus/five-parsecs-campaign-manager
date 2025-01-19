@tool
extends "../fixtures/base_test.gd"

const BattleStateMachine := preload("res://src/core/battle/state/BattleStateMachine.gd")
const MockGameStateManager := preload("res://tests/fixtures/mock_game_state_manager.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

var battle_state: BattleStateMachine
var mock_game_state_manager: MockGameStateManager

func before_each() -> void:
	mock_game_state_manager = MockGameStateManager.new()
	add_child(mock_game_state_manager)
	
	battle_state = BattleStateMachine.new(mock_game_state_manager)
	add_child(battle_state)

func test_initial_state() -> void:
	assert_eq(battle_state.current_state, GameEnums.BattleState.SETUP,
		"Battle should start in SETUP state")
	assert_eq(battle_state.current_phase, GameEnums.CombatPhase.NONE,
		"Combat phase should start as NONE")
	assert_eq(battle_state.current_round, 1,
		"Battle should start at round 1")
	assert_false(battle_state.is_battle_active,
		"Battle should not be active initially")

func test_start_battle() -> void:
	watch_signals(battle_state)
	
	battle_state.start_battle()
	
	assert_true(battle_state.is_battle_active,
		"Battle should be active after starting")
	assert_signal_emitted(battle_state, "battle_started")
	assert_eq(battle_state.current_state, GameEnums.BattleState.ROUND,
		"Battle should transition to ROUND state")

func test_end_battle() -> void:
	battle_state.start_battle()
	watch_signals(battle_state)
	
	battle_state.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	
	assert_false(battle_state.is_battle_active,
		"Battle should not be active after ending")
	assert_signal_emitted(battle_state, "battle_ended")

func test_phase_transitions() -> void:
	battle_state.start_battle()
	watch_signals(battle_state)
	
	battle_state.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
	assert_eq(battle_state.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should transition to initiative phase")
	assert_signal_emitted(battle_state, "phase_changed")
	
	battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
	assert_eq(battle_state.current_phase, GameEnums.CombatPhase.ACTION,
		"Should transition to action phase")

func test_add_combatant() -> void:
	var character := Character.new()
	battle_state.add_combatant(character)
	
	assert_true(battle_state.active_combatants.has(character),
		"Character should be added to active combatants")

func test_save_and_load_state() -> void:
	battle_state.start_battle()
	battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
	
	var saved_state = battle_state.save_state()
	assert_not_null(saved_state, "Should create save state")
	
	var new_battle_state := BattleStateMachine.new(mock_game_state_manager)
	add_child(new_battle_state)
	
	new_battle_state.load_state(saved_state)
	assert_eq(new_battle_state.current_phase, GameEnums.CombatPhase.ACTION,
		"Should load correct phase")
	assert_eq(new_battle_state.current_round, 1,
		"Should load correct round")
