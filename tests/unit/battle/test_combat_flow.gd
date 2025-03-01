## Combat Flow Test Suite
## Tests the functionality of the combat flow system including:
## - Battle phase transitions
## - Combat actions and resolution
## - Reaction system
## - Status effects
## - Combat tactics
@tool
extends GameTest

# Type-safe script references
const BattleStateMachine: GDScript = preload("res://src/core/battle/state/BattleStateMachine.gd")
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _state_machine: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state manager
	var game_state_instance: Node = GameStateManager.new()
	_game_state = game_state_instance as Node
	if not _game_state:
		push_error("Failed to create game state manager")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize battle state machine
	var state_machine_instance: Node = BattleStateMachine.new()
	_state_machine = state_machine_instance as Node
	if not _state_machine:
		push_error("Failed to create battle state machine")
		return
	_call_node_method_bool(_state_machine, "initialize", [_game_state])
	add_child_autofree(_state_machine)
	track_test_node(_state_machine)
	
	watch_signals(_state_machine)
	watch_signals(_game_state)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_state_machine = null
	await super.after_each()

# Battle Phase Tests
func test_battle_phase_transitions() -> void:
	# Test initial state
	var current_phase: int = _call_node_method_int(_state_machine, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.BattlePhase.NONE, "Should start in NONE phase")
	
	# Start battle
	_call_node_method_bool(_state_machine, "start_battle", [])
	current_phase = _call_node_method_int(_state_machine, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.BattlePhase.SETUP, "Should transition to SETUP phase")
	
	# Move through phases
	_call_node_method_bool(_state_machine, "advance_phase", [])
	current_phase = _call_node_method_int(_state_machine, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.BattlePhase.DEPLOYMENT, "Should transition to DEPLOYMENT phase")
	
	_call_node_method_bool(_state_machine, "advance_phase", [])
	current_phase = _call_node_method_int(_state_machine, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.BattlePhase.INITIATIVE, "Should transition to INITIATIVE phase")
	
	_call_node_method_bool(_state_machine, "advance_phase", [])
	current_phase = _call_node_method_int(_state_machine, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.BattlePhase.ACTIVATION, "Should transition to ACTIVATION phase")

# Combat Action Tests
func test_combat_actions() -> void:
	# Setup test characters
	var attacker := _create_test_character("Attacker")
	var defender := _create_test_character("Defender")
	
	_call_node_method_bool(_state_machine, "start_battle", [])
	_call_node_method_bool(_state_machine, "add_combatant", [attacker])
	_call_node_method_bool(_state_machine, "add_combatant", [defender])
	
	# Move to activation phase
	while _call_node_method_int(_state_machine, "get_current_phase", []) != GameEnums.BattlePhase.ACTIVATION:
		_call_node_method_bool(_state_machine, "advance_phase", [])
	
	# Test attack action
	var action := {
		"type": GameEnums.UnitAction.ATTACK,
		"actor": attacker,
		"target": defender,
		"weapon": _call_node_method_object(attacker, "get_primary_weapon", [])
	}
	
	var attack_result: Dictionary = _call_node_method_dict(_state_machine, "execute_action", [action])
	assert_not_null(attack_result, "Attack should return result")
	assert_true(attack_result.has("hit"), "Result should include hit status")
	assert_true(attack_result.has("damage"), "Result should include damage")

# Reaction System Tests
func test_reaction_system() -> void:
	var active_unit := _create_test_character("Active")
	var overwatch_unit := _create_test_character("Overwatch")
	
	_call_node_method_bool(_state_machine, "start_battle", [])
	_call_node_method_bool(_state_machine, "add_combatant", [active_unit])
	_call_node_method_bool(_state_machine, "add_combatant", [overwatch_unit])
	
	# Setup overwatch
	var overwatch_action := {
		"type": GameEnums.UnitAction.OVERWATCH,
		"actor": overwatch_unit,
		"weapon": _call_node_method_object(overwatch_unit, "get_primary_weapon", [])
	}
	_call_node_method_dict(_state_machine, "execute_action", [overwatch_action])
	
	# Test movement triggering overwatch
	var move_action := {
		"type": GameEnums.UnitAction.MOVE,
		"actor": active_unit,
		"target_position": Vector2i(5, 5)
	}
	var move_result: Dictionary = _call_node_method_dict(_state_machine, "execute_action", [move_action])
	
	assert_true(move_result.has("reactions"), "Movement should trigger reactions")
	assert_true(move_result.reactions.size() > 0, "Should have at least one reaction")

# Status Effect Tests
func test_combat_status_effects() -> void:
	var unit := _create_test_character("TestUnit")
	
	_call_node_method_bool(_state_machine, "start_battle", [])
	_call_node_method_bool(_state_machine, "add_combatant", [unit])
	
	# Apply suppression
	_call_node_method_bool(_state_machine, "apply_status_effect", [unit, GameEnums.CombatStatus.SUPPRESSED])
	var has_status: bool = _call_node_method_bool(unit, "has_status", [GameEnums.CombatStatus.SUPPRESSED])
	assert_true(has_status, "Unit should be suppressed")
	
	# Test status effect removal
	_call_node_method_bool(_state_machine, "remove_status_effect", [unit, GameEnums.CombatStatus.SUPPRESSED])
	has_status = _call_node_method_bool(unit, "has_status", [GameEnums.CombatStatus.SUPPRESSED])
	assert_false(has_status, "Suppression should be removed")

# Combat Tactics Tests
func test_combat_tactics() -> void:
	var unit := _create_test_character("TacticalUnit")
	
	_call_node_method_bool(_state_machine, "start_battle", [])
	_call_node_method_bool(_state_machine, "add_combatant", [unit])
	
	# Test different tactical stances
	var tactics := [
		GameEnums.CombatTactic.AGGRESSIVE,
		GameEnums.CombatTactic.DEFENSIVE,
		GameEnums.CombatTactic.BALANCED
	]
	
	for tactic in tactics:
		_call_node_method_bool(_state_machine, "set_unit_tactic", [unit, tactic])
		var current_tactic: int = _call_node_method_int(unit, "get_current_tactic", [])
		assert_eq(current_tactic, tactic, "Unit should have correct tactic")
		
		# Verify combat modifiers
		var modifiers: Dictionary = _call_node_method_dict(unit, "get_combat_modifiers", [])
		match tactic:
			GameEnums.CombatTactic.AGGRESSIVE:
				assert_true(modifiers.attack > 0, "Aggressive should boost attack")
				assert_true(modifiers.defense < 0, "Aggressive should reduce defense")
			GameEnums.CombatTactic.DEFENSIVE:
				assert_true(modifiers.attack < 0, "Defensive should reduce attack")
				assert_true(modifiers.defense > 0, "Defensive should boost defense")
			GameEnums.CombatTactic.BALANCED:
				assert_eq(modifiers.attack, 0, "Balanced should not modify attack")
				assert_eq(modifiers.defense, 0, "Balanced should not modify defense")

# Error Handling Tests
func test_invalid_action_handling() -> void:
	var result: Dictionary = _call_node_method_dict(_state_machine, "execute_action", [ {}])
	assert_true(result.has("error"), "Should handle empty action")
	
	var invalid_action := {"type": - 1, "actor": null}
	result = _call_node_method_dict(_state_machine, "execute_action", [invalid_action])
	assert_true(result.has("error"), "Should handle invalid action type")

# Performance Tests
func test_action_processing_performance() -> void:
	var unit := _create_test_character("PerformanceTest")
	_call_node_method_bool(_state_machine, "start_battle", [])
	_call_node_method_bool(_state_machine, "add_combatant", [unit])
	
	var start_time := Time.get_ticks_msec()
	for i in range(1000):
		var action := {"type": GameEnums.UnitAction.MOVE, "actor": unit, "target_position": Vector2i(i % 10, i % 10)}
		_call_node_method_dict(_state_machine, "execute_action", [action])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should process 1000 actions within 1 second")

# Helper Methods
func _create_test_character(char_name: String) -> Node:
	var character_instance: Node = Character.new()
	var character: Node = character_instance as Node
	if not character:
		push_error("Failed to create test character")
		return null
	
	_call_node_method_bool(character, "set_character_name", [char_name])
	_call_node_method_bool(character, "set_max_health", [100])
	_call_node_method_bool(character, "set_current_health", [100])
	
	add_child_autofree(character)
	track_test_node(character)
	return character