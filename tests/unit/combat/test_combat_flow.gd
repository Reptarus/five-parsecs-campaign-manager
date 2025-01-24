@tool
extends "res://tests/fixtures/base_test.gd"

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var _state_machine: BattleStateMachine
var _game_state: GameStateManager

func before_each() -> void:
	await super.before_each()
	_game_state = GameStateManager.new()
	add_child(_game_state)
	track_test_node(_game_state)
	
	_state_machine = BattleStateMachine.new(_game_state)
	add_child(_state_machine)
	track_test_node(_state_machine)

func after_each() -> void:
	await super.after_each()
	_state_machine = null
	_game_state = null

func test_battle_phase_transitions() -> void:
	# Test initial state
	assert_eq(_state_machine.current_phase, GameEnums.BattlePhase.NONE)
	
	# Start battle
	_state_machine.start_battle()
	assert_eq(_state_machine.current_phase, GameEnums.BattlePhase.SETUP)
	
	# Move through phases
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.BattlePhase.DEPLOYMENT)
	
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.BattlePhase.INITIATIVE)
	
	_state_machine.advance_phase()
	assert_eq(_state_machine.current_phase, GameEnums.BattlePhase.ACTIVATION)

func test_combat_actions() -> void:
	# Setup test characters
	var attacker = _create_test_character("Attacker")
	var defender = _create_test_character("Defender")
	
	_state_machine.start_battle()
	_state_machine.add_combatant(attacker)
	_state_machine.add_combatant(defender)
	
	# Move to activation phase
	while _state_machine.current_phase != GameEnums.BattlePhase.ACTIVATION:
		_state_machine.advance_phase()
	
	# Test attack action
	var attack_result = _state_machine.execute_action({
		"type": GameEnums.UnitAction.ATTACK,
		"actor": attacker,
		"target": defender,
		"weapon": attacker.get_primary_weapon()
	})
	
	assert_not_null(attack_result)
	assert_true(attack_result.has("hit"))
	assert_true(attack_result.has("damage"))

func test_reaction_system() -> void:
	var active_unit = _create_test_character("Active")
	var overwatch_unit = _create_test_character("Overwatch")
	
	_state_machine.start_battle()
	_state_machine.add_combatant(active_unit)
	_state_machine.add_combatant(overwatch_unit)
	
	# Setup overwatch
	_state_machine.execute_action({
		"type": GameEnums.UnitAction.OVERWATCH,
		"actor": overwatch_unit,
		"weapon": overwatch_unit.get_primary_weapon()
	})
	
	# Test movement triggering overwatch
	var move_result = _state_machine.execute_action({
		"type": GameEnums.UnitAction.MOVE,
		"actor": active_unit,
		"target_position": Vector2i(5, 5)
	})
	
	assert_true(move_result.has("reactions"))
	assert_true(move_result.reactions.size() > 0)

func test_combat_status_effects() -> void:
	var unit = _create_test_character("TestUnit")
	
	_state_machine.start_battle()
	_state_machine.add_combatant(unit)
	
	# Apply suppression
	_state_machine.apply_status_effect(unit, GameEnums.CombatStatus.SUPPRESSED)
	assert_true(unit.has_status(GameEnums.CombatStatus.SUPPRESSED))
	
	# Test status effect removal
	_state_machine.remove_status_effect(unit, GameEnums.CombatStatus.SUPPRESSED)
	assert_false(unit.has_status(GameEnums.CombatStatus.SUPPRESSED))

func test_combat_tactics() -> void:
	var unit = _create_test_character("TacticalUnit")
	
	_state_machine.start_battle()
	_state_machine.add_combatant(unit)
	
	# Test different tactical stances
	var tactics = [
		GameEnums.CombatTactic.AGGRESSIVE,
		GameEnums.CombatTactic.DEFENSIVE,
		GameEnums.CombatTactic.BALANCED
	]
	
	for tactic in tactics:
		_state_machine.set_unit_tactic(unit, tactic)
		assert_eq(unit.get_current_tactic(), tactic)
		
		# Verify combat modifiers
		var modifiers = unit.get_combat_modifiers()
		match tactic:
			GameEnums.CombatTactic.AGGRESSIVE:
				assert_true(modifiers.attack > 0)
				assert_true(modifiers.defense < 0)
			GameEnums.CombatTactic.DEFENSIVE:
				assert_true(modifiers.attack < 0)
				assert_true(modifiers.defense > 0)
			GameEnums.CombatTactic.BALANCED:
				assert_eq(modifiers.attack, 0)
				assert_eq(modifiers.defense, 0)

# Helper function to create test characters
func _create_test_character(char_name: String) -> Character:
	var character = Character.new()
	character.character_name = char_name
	character.max_health = 100
	character.current_health = 100
	add_child(character)
	track_test_node(character)
	return character