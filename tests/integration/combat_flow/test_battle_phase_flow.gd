@tool
extends "res://tests/fixtures/base_test.gd"

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var _state_machine: BattleStateMachine
var _game_state: GameStateManager

func before_each() -> void:
	await super.before_each()
	
	# Create game state manager
	_game_state = GameStateManager.new()
	add_child(_game_state)
	track_test_node(_game_state)
	
	# Create battle state machine with dependencies
	_state_machine = BattleStateMachine.new(_game_state)
	add_child(_state_machine)
	track_test_node(_state_machine)

func after_each() -> void:
	await super.after_each()
	_state_machine = null
	_game_state = null

# Helper function to create test character
func _create_test_character(name: String) -> Character:
	var character = Character.new()
	character.from_dictionary({
		"character_name": name,
		"character_class": GameEnums.CharacterClass.SOLDIER,
		"origin": GameEnums.Origin.HUMAN,
		"background": GameEnums.Background.MILITARY,
		"motivation": GameEnums.Motivation.DUTY,
		"level": 1,
		"health": 10,
		"max_health": 10,
		"reaction": 3,
		"combat": 3,
		"toughness": 3,
		"savvy": 3,
		"luck": 1
	})
	return character

# Battle State Tests
func test_initial_battle_state() -> void:
	assert_eq(_state_machine.current_state, GameEnums.BattleState.SETUP,
		"Battle should start in setup state")
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Combat phase should start as none")
	assert_eq(_state_machine.current_round, 1,
		"Battle should start at round 1")
	assert_false(_state_machine.is_battle_active,
		"Battle should not be active initially")

# Battle Flow Tests
func test_battle_start_flow() -> void:
	var battle_started_emitted = false
	_state_machine.battle_started.connect(func(): battle_started_emitted = true)
	
	_state_machine.emit_signal("battle_started")
	
	assert_true(battle_started_emitted, "Battle started signal should be emitted")
	assert_true(_state_machine.is_battle_active, "Battle should be active")

func test_round_flow() -> void:
	var round_started_emitted = false
	var round_ended_emitted = false
	var round_number = 0
	
	_state_machine.round_started.connect(func(round):
		round_started_emitted = true
		round_number = round)
	
	_state_machine.round_ended.connect(func(round):
		round_ended_emitted = true
		assert_eq(round, round_number, "Round end should match round start"))
	
	_state_machine.emit_signal("round_started", 1)
	assert_true(round_started_emitted, "Round started signal should be emitted")
	assert_eq(round_number, 1, "Round number should be 1")
	
	_state_machine.emit_signal("round_ended", 1)
	assert_true(round_ended_emitted, "Round ended signal should be emitted")

# Phase Transition Tests
func test_phase_transitions() -> void:
	var phase_changes = []
	_state_machine.phase_changed.connect(func(new_phase): phase_changes.append(new_phase))
	
	# Test setup to deployment transition
	_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.SETUP)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Should transition to setup phase")
	
	# Test deployment to initiative transition
	_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.INITIATIVE)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should transition to initiative phase")
	
	# Test initiative to action transition
	_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.ACTION)
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should transition to action phase")
	
	# Verify phase sequence
	assert_eq(phase_changes, [
		GameEnums.CombatPhase.SETUP,
		GameEnums.CombatPhase.INITIATIVE,
		GameEnums.CombatPhase.ACTION
	], "Phase transitions should occur in correct sequence")

# Unit Action Tests
func test_unit_action_flow() -> void:
	var test_unit = _create_test_character("Test Unit")
	var action_changed_emitted = false
	var action_completed_emitted = false
	
	_state_machine.unit_action_changed.connect(func(action):
		action_changed_emitted = true
		assert_eq(action, GameEnums.UnitAction.MOVE, "Should emit correct action"))
	
	_state_machine.unit_action_completed.connect(func(unit, action):
		action_completed_emitted = true
		assert_eq(unit, test_unit, "Should emit correct unit")
		assert_eq(action, GameEnums.UnitAction.MOVE, "Should emit correct action"))
	
	_state_machine.emit_signal("unit_action_changed", GameEnums.UnitAction.MOVE)
	assert_true(action_changed_emitted, "Action changed signal should be emitted")
	
	_state_machine.emit_signal("unit_action_completed", test_unit, GameEnums.UnitAction.MOVE)
	assert_true(action_completed_emitted, "Action completed signal should be emitted")

# Battle End Tests
func test_battle_end_flow() -> void:
	var battle_ended_emitted = false
	var victory_result = false
	
	_state_machine.battle_ended.connect(func(victory):
		battle_ended_emitted = true
		victory_result = victory)
	
	_state_machine.emit_signal("battle_ended", true)
	
	assert_true(battle_ended_emitted, "Battle ended signal should be emitted")
	assert_true(victory_result, "Victory result should be true")
	assert_false(_state_machine.is_battle_active, "Battle should not be active after end")

# Combat Effect Tests
func test_combat_effect_flow() -> void:
	var effect_triggered_emitted = false
	var test_source = _create_test_character("Source")
	var test_target = _create_test_character("Target")
	var test_effect = "stun"
	
	_state_machine.combat_effect_triggered.connect(func(effect_name, source, target):
		effect_triggered_emitted = true
		assert_eq(effect_name, test_effect, "Should emit correct effect name")
		assert_eq(source, test_source, "Should emit correct source")
		assert_eq(target, test_target, "Should emit correct target"))
	
	_state_machine.emit_signal("combat_effect_triggered", test_effect, test_source, test_target)
	assert_true(effect_triggered_emitted, "Combat effect signal should be emitted")

# Reaction Tests
func test_reaction_opportunity_flow() -> void:
	var reaction_emitted = false
	var test_unit = _create_test_character("Unit")
	var test_source = _create_test_character("Source")
	var test_reaction = "overwatch"
	
	_state_machine.reaction_opportunity.connect(func(unit, reaction_type, source):
		reaction_emitted = true
		assert_eq(unit, test_unit, "Should emit correct unit")
		assert_eq(reaction_type, test_reaction, "Should emit correct reaction type")
		assert_eq(source, test_source, "Should emit correct source"))
	
	_state_machine.emit_signal("reaction_opportunity", test_unit, test_reaction, test_source)
	assert_true(reaction_emitted, "Reaction opportunity signal should be emitted")