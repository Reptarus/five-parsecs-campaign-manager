@tool
extends "res://tests/fixtures/base_test.gd"

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var _state_machine: BattleStateMachine
var _game_state: GameStateManager

func _do_ready_stuff() -> void:
	super._do_ready_stuff()

func before_each() -> void:
	await super.before_each()
	
	# Create game state manager
	_game_state = GameStateManager.new()
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Create battle state machine with dependencies
	_state_machine = BattleStateMachine.new(_game_state)
	add_child_autofree(_state_machine)
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
	track_test_node(character)
	return character

# Battle State Tests
func test_initial_battle_state() -> void:
	gut.p("Testing initial battle state...")
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
	gut.p("Testing battle start flow...")
	watch_signals(_state_machine)
	
	# Start the battle through the proper method
	_state_machine.start_battle()
	
	# Wait for and assert the signals
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "battle_started", "Battle started signal should be emitted")
	assert_true(_state_machine.is_battle_active, "Battle should be active")

func test_round_flow() -> void:
	gut.p("Testing round flow...")
	watch_signals(_state_machine)
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Start round
	_state_machine.start_round()
	
	# Wait for round started signal
	var round_data = await wait_for_signal(_state_machine, "round_started", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "round_started", "Round started signal should be emitted")
	assert_eq(round_data[0], 1, "Round number should be 1")
	
	# End round
	_state_machine.end_round()
	
	# Wait for round ended signal
	var end_data = await wait_for_signal(_state_machine, "round_ended", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "round_ended", "Round ended signal should be emitted")
	assert_eq(end_data[0], 1, "Round end should match round start")

# Phase Transition Tests
func test_phase_transitions() -> void:
	gut.p("Testing phase transitions...")
	watch_signals(_state_machine)
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Test setup to deployment transition
	_state_machine.transition_to_phase(GameEnums.CombatPhase.SETUP)
	await wait_for_signal(_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Should transition to setup phase")
	
	# Test deployment to initiative transition
	_state_machine.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
	await wait_for_signal(_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should transition to initiative phase")
	
	# Test initiative to action transition
	_state_machine.transition_to_phase(GameEnums.CombatPhase.ACTION)
	await wait_for_signal(_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should transition to action phase")

# Unit Action Tests
func test_unit_action_flow() -> void:
	gut.p("Testing unit action flow...")
	watch_signals(_state_machine)
	var test_unit = _create_test_character("Test Unit")
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Start unit action
	_state_machine.start_unit_action(test_unit, GameEnums.UnitAction.MOVE)
	
	# Wait for action changed signal
	var action_data = await wait_for_signal(_state_machine, "unit_action_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "unit_action_changed", "Action changed signal should be emitted")
	assert_eq(action_data[0], GameEnums.UnitAction.MOVE, "Should emit correct action")
	
	# Complete unit action
	_state_machine.complete_unit_action()
	
	# Wait for action completed signal
	var completion_data = await wait_for_signal(_state_machine, "unit_action_completed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "unit_action_completed", "Action completed signal should be emitted")
	assert_eq(completion_data[0], test_unit, "Should emit correct unit")
	assert_eq(completion_data[1], GameEnums.UnitAction.MOVE, "Should emit correct action")
	
	# Verify action is marked as completed
	assert_true(_state_machine.has_unit_completed_action(test_unit, GameEnums.UnitAction.MOVE),
		"Action should be marked as completed")
	
	# Verify available actions
	var available_actions = _state_machine.get_available_actions(test_unit)
	assert_false(GameEnums.UnitAction.MOVE in available_actions,
		"Move action should not be available after completion")

# Battle End Tests
func test_battle_end_flow() -> void:
	gut.p("Testing battle end flow...")
	watch_signals(_state_machine)
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# End battle
	_state_machine.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	
	# Wait for battle ended signal
	var end_data = await wait_for_signal(_state_machine, "battle_ended", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "battle_ended", "Battle ended signal should be emitted")
	assert_true(end_data[0], "Victory result should be true")
	assert_false(_state_machine.is_battle_active, "Battle should not be active after end")

# Combat Effect Tests
func test_combat_effect_flow() -> void:
	gut.p("Testing combat effect flow...")
	watch_signals(_state_machine)
	var test_source = _create_test_character("Source")
	var test_target = _create_test_character("Target")
	var test_effect = "stun"
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Trigger combat effect
	_state_machine.trigger_combat_effect(test_effect, test_source, test_target)
	
	# Wait for effect signal
	var effect_data = await wait_for_signal(_state_machine, "combat_effect_triggered", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "combat_effect_triggered", "Combat effect signal should be emitted")
	assert_eq(effect_data[0], test_effect, "Should emit correct effect name")
	assert_eq(effect_data[1], test_source, "Should emit correct source")
	assert_eq(effect_data[2], test_target, "Should emit correct target")

# Reaction Tests
func test_reaction_opportunity_flow() -> void:
	gut.p("Testing reaction opportunity flow...")
	watch_signals(_state_machine)
	var test_unit = _create_test_character("Unit")
	var test_source = _create_test_character("Source")
	var test_reaction = "overwatch"
	
	# Start battle first
	_state_machine.start_battle()
	await wait_for_signal(_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Trigger reaction opportunity
	_state_machine.trigger_reaction_opportunity(test_unit, test_reaction, test_source)
	
	# Wait for reaction signal
	var reaction_data = await wait_for_signal(_state_machine, "reaction_opportunity", SIGNAL_TIMEOUT)
	verify_signal_emitted(_state_machine, "reaction_opportunity", "Reaction opportunity signal should be emitted")
	assert_eq(reaction_data[0], test_unit, "Should emit correct unit")
	assert_eq(reaction_data[1], test_reaction, "Should emit correct reaction type")
	assert_eq(reaction_data[2], test_source, "Should emit correct source")