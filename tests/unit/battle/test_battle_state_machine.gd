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
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Constants and preloads
const BattleStateMachine: GDScript = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")
const BattleCharacterScript: GDScript = preload("res://src/game/combat/BattleCharacter.gd")
const TEST_TIMEOUT: float = 1.0 # seconds timeout for performance tests

# Type-safe instance variables
var battle_state: Node = null
var game_state_manager: Node = null
var _signal_data: Dictionary = {}

# Helper methods
func create_test_character() -> Node:
	var character: Node = Node.new()
	if not character:
		push_error("Failed to create character instance")
		return null
	character.set_script(BattleCharacterScript)
	add_child_autofree(character)
	track_test_node(character)
	return character

func create_test_battle_state() -> Node:
	var state := Node.new()
	if not state:
		push_error("Failed to create battle state")
		return null
		
	state.set_script(BattleStateMachine)
	add_child_autofree(state)
	if not state:
		push_error("Failed to add battle state node")
		return null
		
	track_test_node(state)
	return state

func setup_active_battle() -> void:
	if not battle_state:
		push_error("Cannot setup battle: battle state is null")
		return
		
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	# Use set_combat_state instead of transition_to_phase to match FiveParsecsCombatManager's API
	if battle_state.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.INITIATIVE,
			"active_team": 0,
			"round": 1
		}])
	else:
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state manager
	game_state_manager = Node.new()
	if not game_state_manager:
		push_error("Failed to create game state manager")
		return
	game_state_manager.set_script(GameStateManager)
	add_child_autofree(game_state_manager)
	track_test_node(game_state_manager)
	
	# Initialize battle state
	battle_state = Node.new()
	if not battle_state:
		push_error("Failed to create battle state")
		return
	battle_state.set_script(BattleStateMachine)
	add_child_autofree(battle_state)
	track_test_node(battle_state)
	
	_signal_data.clear()
	await stabilize_engine()

func after_each() -> void:
	battle_state = null
	game_state_manager = null
	_signal_data.clear()
	await super.after_each()

# Type-safe signal handlers
func _on_battle_started() -> void:
	_signal_data["battle_started"] = true

func _on_battle_ended(victory_type: int) -> void:
	_signal_data["battle_ended"] = true
	_signal_data["victory_type"] = victory_type

func _on_phase_changed(from_phase: int, to_phase: int) -> void:
	_signal_data["phase_changed"] = true
	_signal_data["from_phase"] = from_phase
	_signal_data["to_phase"] = to_phase

func _on_phase_transition_test() -> void:
	_signal_data["phase_transition"] = true

# Test cases
func test_battle_state_initialization() -> void:
	assert_not_null(battle_state, "Battle state should be initialized")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_state", [], GameEnums.BattleState.NONE)
	assert_eq(current_state, GameEnums.BattleState.SETUP, "Battle should start in SETUP state")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.NONE, "Combat phase should start as NONE")
	
	var current_round: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_round", [], 0)
	assert_eq(current_round, 1, "Battle should start at round 1")
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(battle_state, "is_battle_active", [], false)
	assert_false(is_active, "Battle should not be active initially")

func test_start_battle() -> void:
	var connect_result: Error = battle_state.connect("battle_started", _on_battle_started)
	if connect_result != OK:
		push_error("Failed to connect battle_started signal")
		return
	
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(battle_state, "is_battle_active", [], false)
	assert_true(is_active, "Battle should be active after starting")
	
	assert_true(_signal_data.has("battle_started"), "Battle started signal should be emitted")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_state", [], GameEnums.BattleState.NONE)
	assert_eq(current_state, GameEnums.BattleState.ROUND, "Battle should transition to ROUND state")

func test_end_battle() -> void:
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	
	var connect_result: Error = battle_state.connect("battle_ended", _on_battle_ended)
	if connect_result != OK:
		push_error("Failed to connect battle_ended signal")
		return
	
	TypeSafeMixin._call_node_method_bool(battle_state, "end_battle", [GameEnums.VictoryConditionType.ELIMINATION])
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(battle_state, "is_battle_active", [], true)
	assert_false(is_active, "Battle should not be active after ending")
	
	assert_true(_signal_data.has("battle_ended"), "Battle ended signal should be emitted")
	assert_eq(_signal_data["victory_type"], GameEnums.VictoryConditionType.ELIMINATION,
		"Victory type should be passed to signal")

func test_phase_transitions() -> void:
	# Setup observers
	var connect_result: Error = battle_state.connect("phase_changed", _on_phase_changed)
	if connect_result != OK:
		push_error("Failed to connect phase_changed signal")
		return
	
	# Start battle
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	
	# Transition to initiative phase
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if battle_state.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.INITIATIVE,
			"active_team": 0,
			"round": 1
		}])
	else:
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])
	
	# Verify phase is changed
	var current_phase: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.INITIATIVE, "Phase should be INITIATIVE")
	
	# Transition to action phase
	if battle_state.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.ACTION,
			"active_team": 0,
			"round": 1
		}])
	else:
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	# Verify phase is changed
	current_phase = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.ACTION, "Phase should be ACTION")
	
	# Verify signals were emitted
	assert_true(_signal_data.has("phase_changed"), "Phase changed signal should be emitted")
	assert_eq(_signal_data.get("to_phase"), GameEnums.CombatPhase.ACTION, "Phase change signal should have correct to_phase")

func test_add_combatant() -> void:
	var character: Node = create_test_character()
	if not character:
		push_error("Failed to create test character")
		return
		
	track_test_node(character)
	TypeSafeMixin._call_node_method_bool(battle_state, "add_combatant", [character])
	
	var active_combatants: Array = TypeSafeMixin._call_node_method_array(battle_state, "get_active_combatants", [])
	assert_true(active_combatants.has(character), "Character should be added to active combatants")

func test_save_and_load_state() -> void:
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var saved_state: Dictionary = TypeSafeMixin._call_node_method_dict(battle_state, "save_state", [])
	assert_not_null(saved_state, "Should create save state")
	
	var new_battle_state: Node = Node.new()
	if not new_battle_state:
		push_error("Failed to create new battle state")
		return
	new_battle_state.set_script(BattleStateMachine)
	add_child_autofree(new_battle_state)
	track_test_node(new_battle_state)
	
	TypeSafeMixin._call_node_method_bool(new_battle_state, "load_state", [saved_state])
	
	var loaded_phase: int = TypeSafeMixin._call_node_method_int(new_battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(loaded_phase, GameEnums.CombatPhase.ACTION, "Should load correct phase")
	
	var loaded_round: int = TypeSafeMixin._call_node_method_int(new_battle_state, "get_current_round", [], 0)
	assert_eq(loaded_round, 1, "Should load correct round")

# Performance tests
func test_rapid_state_transitions() -> void:
	setup_active_battle()
	_signal_watcher.watch_signals(battle_state)
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < TEST_TIMEOUT, "Should handle rapid state transitions efficiently")

# Error boundary tests
func test_invalid_phase_transition() -> void:
	_signal_watcher.watch_signals(battle_state)
	TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.NONE, "Should not allow phase transition before battle starts")

func test_invalid_battle_start() -> void:
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	
	var connect_result: Error = battle_state.connect("battle_started", _on_battle_started)
	if connect_result != OK:
		push_error("Failed to connect battle_started signal")
		return
	
	_signal_data.clear()
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	assert_false(_signal_data.has("battle_started"), "Should not emit signal when starting an already active battle")

# Signal verification tests
func test_phase_transition_signals() -> void:
	setup_active_battle()
	_signal_watcher.watch_signals(battle_state)
	
	var connect_result: Error = battle_state.phase_changed.connect(_on_phase_transition_test)
	if connect_result != OK:
		push_error("Failed to connect phase_changed signal")
		return
		
	TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	assert_eq(_signal_data.get("phase_transition", false), true, "Should emit phase_changed signal once")

func test_transition_with_invalid_phase() -> void:
	# Try to transition to an invalid phase
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if battle_state.has_method("set_combat_state"):
		var result = TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": - 999,
			"active_team": 0,
			"round": 1
		}])
		assert_false(result, "Invalid phase transition should fail")
	else:
		var result = TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [-999])
		assert_false(result, "Invalid phase transition should fail")
	
	# Verify phase didn't change
	var current_phase: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.NONE, "Phase should remain unchanged after invalid transition")

func test_round_increment() -> void:
	# Start a battle and go through multiple rounds
	TypeSafeMixin._call_node_method_bool(battle_state, "start_battle", [])
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if battle_state.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.INITIATIVE,
			"active_team": 0,
			"round": 1
		}])
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.ACTION,
			"active_team": 0,
			"round": 1
		}])
	else:
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.INITIATIVE])
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	# End the round and check if round incremented
	if battle_state.has_method("end_round"):
		TypeSafeMixin._call_node_method_bool(battle_state, "end_round", [])
	
	var current_round: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_round", [], 0)
	assert_eq(current_round, 2, "Round should increment after ending a round")

func test_action_phase_transitions() -> void:
	# Start an active battle
	setup_active_battle()
	
	# Use set_combat_state if available, otherwise fall back to transition_to_phase
	if battle_state.has_method("set_combat_state"):
		TypeSafeMixin._call_node_method_bool(battle_state, "set_combat_state", [ {
			"phase": GameEnums.CombatPhase.ACTION,
			"active_team": 0,
			"round": 1
		}])
	else:
		TypeSafeMixin._call_node_method_bool(battle_state, "transition_to_phase", [GameEnums.CombatPhase.ACTION])
	
	# Verify we're in action phase
	var current_phase: int = TypeSafeMixin._call_node_method_int(battle_state, "get_current_phase", [], GameEnums.CombatPhase.NONE)
	assert_eq(current_phase, GameEnums.CombatPhase.ACTION, "Phase should be ACTION")
