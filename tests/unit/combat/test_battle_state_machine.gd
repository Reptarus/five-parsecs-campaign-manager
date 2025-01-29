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
const TEST_TIMEOUT := 1000 # ms timeout for performance tests

# Test instance variables
var battle_state: BattleStateMachine
var game_state_manager: GameStateManager
var _signal_count: int = 0

# Helper methods
func create_test_battle_state() -> BattleStateMachine:
    var state := BattleStateMachine.new(game_state_manager)
    add_child_autofree(state)
    track_test_node(state)
    return state

func setup_active_battle() -> void:
    battle_state.start_battle()
    battle_state.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)

# Test lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    game_state_manager = GameStateManager.new()
    add_child_autofree(game_state_manager)
    track_test_node(game_state_manager)
    
    battle_state = create_test_battle_state()
    _signal_count = 0
    
    await stabilize_engine()

func after_each() -> void:
    await super.after_each()
    battle_state = null
    game_state_manager = null

# Basic state tests
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
    var character = create_test_character()
    track_test_resource(character)
    battle_state.add_combatant(character)
    
    assert_true(battle_state.active_combatants.has(character),
        "Character should be added to active combatants")

func test_save_and_load_state() -> void:
    battle_state.start_battle()
    battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
    
    var saved_state = battle_state.save_state()
    assert_not_null(saved_state, "Should create save state")
    
    var new_battle_state := BattleStateMachine.new(game_state_manager)
    add_child_autofree(new_battle_state)
    track_test_node(new_battle_state)
    
    new_battle_state.load_state(saved_state)
    assert_eq(new_battle_state.current_phase, GameEnums.CombatPhase.ACTION,
        "Should load correct phase")
    assert_eq(new_battle_state.current_round, 1,
        "Should load correct round")

# Performance tests
func test_rapid_state_transitions() -> void:
    setup_active_battle()
    watch_signals(battle_state)
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        battle_state.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
        battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < TEST_TIMEOUT,
        "Should handle rapid state transitions efficiently")

# Error boundary tests
func test_invalid_phase_transition() -> void:
    watch_signals(battle_state)
    battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
    assert_eq(battle_state.current_phase, GameEnums.CombatPhase.NONE,
        "Should not allow phase transition before battle starts")

func test_invalid_battle_start() -> void:
    battle_state.start_battle()
    watch_signals(battle_state)
    battle_state.start_battle()
    assert_signal_not_emitted(battle_state, "battle_started",
        "Should not emit signal when starting an already active battle")

# Signal verification tests
func test_phase_transition_signals() -> void:
    setup_active_battle()
    watch_signals(battle_state)
    
    battle_state.phase_changed.connect(func(_from: int, _to: int): _signal_count += 1)
    battle_state.transition_to_phase(GameEnums.CombatPhase.ACTION)
    
    assert_eq(_signal_count, 1, "Should emit phase_changed signal once")
