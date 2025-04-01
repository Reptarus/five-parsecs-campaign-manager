## Combat Flow Test Suite
## Tests the functionality of the combat flow system including:
## - Battle phase transitions
## - Combat actions and resolution
## - Reaction system
## - Status effects
## - Combat tactics
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

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
	
	# Initialize battle state machine - handle the case where it might be a Resource
	var state_machine_instance = BattleStateMachine.new()
	
	# Check if BattleStateMachine is a Node or Resource
	if state_machine_instance is Node:
		_state_machine = state_machine_instance
	elif state_machine_instance is Resource:
		# Create a Node wrapper for the Resource
		_state_machine = Node.new()
		_state_machine.set_name("BattleStateMachineWrapper")
		_state_machine.set_meta("state_machine", state_machine_instance)
		
		# Store state_machine_instance in a variable that can be captured by the lambda
		var sm_instance = state_machine_instance
		
		# Define methods using set() to avoid reassignment issues
		_state_machine.set("initialize", Callable(sm_instance, "initialize") if sm_instance.has_method("initialize") else
			func(game_state): return false)
		
		_state_machine.set("get_current_phase", Callable(sm_instance, "get_current_phase") if sm_instance.has_method("get_current_phase") else
			func(): return GameEnums.BattlePhase.NONE)
		
		_state_machine.set("start_battle", Callable(sm_instance, "start_battle") if sm_instance.has_method("start_battle") else
			func(): return false)
		
		_state_machine.set("advance_phase", Callable(sm_instance, "advance_phase") if sm_instance.has_method("advance_phase") else
			func(): return false)
		
		_state_machine.set("add_combatant", Callable(sm_instance, "add_combatant") if sm_instance.has_method("add_combatant") else
			func(combatant): return false)
		
		_state_machine.set("execute_action", Callable(sm_instance, "execute_action") if sm_instance.has_method("execute_action") else
			func(action): return {})
		
		_state_machine.set("apply_status_effect", Callable(sm_instance, "apply_status_effect") if sm_instance.has_method("apply_status_effect") else
			func(unit, status): return false)
		
		_state_machine.set("remove_status_effect", Callable(sm_instance, "remove_status_effect") if sm_instance.has_method("remove_status_effect") else
			func(unit, status): return false)
		
		_state_machine.set("set_unit_tactic", Callable(sm_instance, "set_unit_tactic") if sm_instance.has_method("set_unit_tactic") else
			func(unit, tactic): return false)
	else:
		push_error("Failed to create BattleStateMachine instance")
		return
	
	# Initialize state machine
	if _state_machine.has_method("initialize"):
		_state_machine.initialize(_game_state)
	
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
	var current_phase: int = 0
	if _state_machine.has_method("get_current_phase"):
		current_phase = _state_machine.get_current_phase()
	assert_eq(current_phase, GameEnums.BattlePhase.NONE, "Should start in NONE phase")
	
	# Start battle
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("get_current_phase"):
		current_phase = _state_machine.get_current_phase()
	assert_eq(current_phase, GameEnums.BattlePhase.SETUP, "Should transition to SETUP phase")
	
	# Move through phases
	if _state_machine.has_method("advance_phase"):
		_state_machine.advance_phase()
	
	if _state_machine.has_method("get_current_phase"):
		current_phase = _state_machine.get_current_phase()
	assert_eq(current_phase, GameEnums.BattlePhase.DEPLOYMENT, "Should transition to DEPLOYMENT phase")
	
	if _state_machine.has_method("advance_phase"):
		_state_machine.advance_phase()
	
	if _state_machine.has_method("get_current_phase"):
		current_phase = _state_machine.get_current_phase()
	assert_eq(current_phase, GameEnums.BattlePhase.INITIATIVE, "Should transition to INITIATIVE phase")
	
	if _state_machine.has_method("advance_phase"):
		_state_machine.advance_phase()
	
	if _state_machine.has_method("get_current_phase"):
		current_phase = _state_machine.get_current_phase()
	assert_eq(current_phase, GameEnums.BattlePhase.ACTIVATION, "Should transition to ACTIVATION phase")

# Combat Action Tests
func test_combat_actions() -> void:
	# Setup test characters
	var attacker := _create_test_character("Attacker")
	var defender := _create_test_character("Defender")
	
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("add_combatant"):
		_state_machine.add_combatant(attacker)
		_state_machine.add_combatant(defender)
	
	# Move to activation phase
	if _state_machine.has_method("get_current_phase") and _state_machine.has_method("advance_phase"):
		while _state_machine.get_current_phase() != GameEnums.BattlePhase.ACTIVATION:
			_state_machine.advance_phase()
	
	# Test attack action
	var weapon = null
	if attacker.has_method("get_primary_weapon"):
		weapon = attacker.get_primary_weapon()
	
	var action := {
		"type": GameEnums.UnitAction.ATTACK,
		"actor": attacker,
		"target": defender,
		"weapon": weapon
	}
	
	var attack_result = {}
	if _state_machine.has_method("execute_action"):
		attack_result = _state_machine.execute_action(action)
	
	assert_not_null(attack_result, "Attack should return result")
	assert_true(attack_result.has("hit"), "Result should include hit status")
	assert_true(attack_result.has("damage"), "Result should include damage")

# Reaction System Tests
func test_reaction_system() -> void:
	var active_unit := _create_test_character("Active")
	var overwatch_unit := _create_test_character("Overwatch")
	
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("add_combatant"):
		_state_machine.add_combatant(active_unit)
		_state_machine.add_combatant(overwatch_unit)
	
	# Setup overwatch
	var weapon = null
	if overwatch_unit.has_method("get_primary_weapon"):
		weapon = overwatch_unit.get_primary_weapon()
		
	var overwatch_action := {
		"type": GameEnums.UnitAction.OVERWATCH,
		"actor": overwatch_unit,
		"weapon": weapon
	}
	
	if _state_machine.has_method("execute_action"):
		_state_machine.execute_action(overwatch_action)
	
	# Test movement triggering overwatch
	var move_action := {
		"type": GameEnums.UnitAction.MOVE,
		"actor": active_unit,
		"target_position": Vector2i(5, 5)
	}
	
	var move_result = {}
	if _state_machine.has_method("execute_action"):
		move_result = _state_machine.execute_action(move_action)
	
	assert_true(move_result.has("reactions"), "Movement should trigger reactions")
	assert_true(move_result.reactions.size() > 0, "Should have at least one reaction")

# Status Effect Tests
func test_combat_status_effects() -> void:
	var unit := _create_test_character("TestUnit")
	
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("add_combatant"):
		_state_machine.add_combatant(unit)
	
	# Apply suppression
	var has_status = false
	
	if _state_machine.has_method("apply_status_effect"):
		_state_machine.apply_status_effect(unit, GameEnums.CombatStatus.SUPPRESSED)
	
	if unit.has_method("has_status"):
		has_status = unit.has_status(GameEnums.CombatStatus.SUPPRESSED)
	
	assert_true(has_status, "Unit should be suppressed")
	
	# Test status effect removal
	if _state_machine.has_method("remove_status_effect"):
		_state_machine.remove_status_effect(unit, GameEnums.CombatStatus.SUPPRESSED)
	
	if unit.has_method("has_status"):
		has_status = unit.has_status(GameEnums.CombatStatus.SUPPRESSED)
	
	assert_false(has_status, "Suppression should be removed")

# Combat Tactics Tests
func test_combat_tactics() -> void:
	var unit := _create_test_character("TacticalUnit")
	
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("add_combatant"):
		_state_machine.add_combatant(unit)
	
	# Test different tactical stances
	var tactics := [
		GameEnums.CombatTactic.AGGRESSIVE,
		GameEnums.CombatTactic.DEFENSIVE,
		GameEnums.CombatTactic.BALANCED
	]
	
	for tactic in tactics:
		if _state_machine.has_method("set_unit_tactic"):
			_state_machine.set_unit_tactic(unit, tactic)
		
		var current_tactic = -1
		if unit.has_method("get_current_tactic"):
			current_tactic = unit.get_current_tactic()
		
		assert_eq(current_tactic, tactic, "Unit should have correct tactic")
		
		# Verify combat modifiers
		var modifiers = {}
		if unit.has_method("get_combat_modifiers"):
			modifiers = unit.get_combat_modifiers()
		
		match tactic:
			GameEnums.CombatTactic.AGGRESSIVE:
				assert_true(modifiers.has("attack") and modifiers.attack > 0, "Aggressive should boost attack")
				assert_true(modifiers.has("defense") and modifiers.defense < 0, "Aggressive should reduce defense")
			GameEnums.CombatTactic.DEFENSIVE:
				assert_true(modifiers.has("attack") and modifiers.attack < 0, "Defensive should reduce attack")
				assert_true(modifiers.has("defense") and modifiers.defense > 0, "Defensive should boost defense")
			GameEnums.CombatTactic.BALANCED:
				assert_true(modifiers.has("attack") and modifiers.attack == 0, "Balanced should not modify attack")
				assert_true(modifiers.has("defense") and modifiers.defense == 0, "Balanced should not modify defense")

# Error Handling Tests
func test_invalid_action_handling() -> void:
	var result = {}
	if _state_machine.has_method("execute_action"):
		result = _state_machine.execute_action({})
	
	assert_true(result.has("error"), "Should handle empty action")
	
	var invalid_action := {"type": - 1, "actor": null}
	
	if _state_machine.has_method("execute_action"):
		result = _state_machine.execute_action(invalid_action)
	
	assert_true(result.has("error"), "Should handle invalid action type")

# Performance Tests
func test_action_processing_performance() -> void:
	var unit := _create_test_character("PerformanceTest")
	
	if _state_machine.has_method("start_battle"):
		_state_machine.start_battle()
	
	if _state_machine.has_method("add_combatant"):
		_state_machine.add_combatant(unit)
	
	var start_time := Time.get_ticks_msec()
	
	for i in range(1000):
		var action := {"type": GameEnums.UnitAction.MOVE, "actor": unit, "target_position": Vector2i(i % 10, i % 10)}
		if _state_machine.has_method("execute_action"):
			_state_machine.execute_action(action)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should process 1000 actions within 1 second")

# Helper Methods
func _create_test_character(char_name: String) -> Node:
	var character_instance = Character.new()
	
	# Check if Character is a Node or Resource
	if character_instance is Node:
		# Character is a Node, use as is
		var character: Node = character_instance
		
		if character.has_method("set_character_name"):
			character.set_character_name(char_name)
		
		if character.has_method("set_max_health"):
			character.set_max_health(100)
		
		if character.has_method("set_current_health"):
			character.set_current_health(100)
		
		add_child_autofree(character)
		track_test_node(character)
		return character
	elif character_instance is Resource:
		# Character is a Resource, create a Node wrapper
		var character_node = Node.new()
		character_node.set_name("CharacterWrapper_" + char_name)
		character_node.set_meta("character", character_instance)
		
		# Store character_instance in a variable that can be captured by the lambda
		var char_instance = character_instance
		
		# Define methods
		if char_instance.has_method("set_character_name"):
			char_instance.set_character_name(char_name)
		
		if char_instance.has_method("set_max_health"):
			char_instance.set_max_health(100)
		
		if char_instance.has_method("set_current_health"):
			char_instance.set_current_health(100)
		
		# Add forwarding methods to the wrapper node
		character_node.set("get_primary_weapon", Callable(char_instance, "get_primary_weapon") if char_instance.has_method("get_primary_weapon") else
			func(): return null)
		
		character_node.set("has_status", Callable(char_instance, "has_status") if char_instance.has_method("has_status") else
			func(status): return false)
		
		character_node.set("get_current_tactic", Callable(char_instance, "get_current_tactic") if char_instance.has_method("get_current_tactic") else
			func(): return GameEnums.CombatTactic.BALANCED)
		
		character_node.set("get_combat_modifiers", Callable(char_instance, "get_combat_modifiers") if char_instance.has_method("get_combat_modifiers") else
			func(): return {"attack": 0, "defense": 0})
		
		add_child_autofree(character_node)
		track_test_node(character_node)
		return character_node
	else:
		push_error("Failed to create test character")
		return null     