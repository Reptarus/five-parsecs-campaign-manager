@tool
extends GameTest

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const ParsecsCharacter = preload("res://src/core/character/Base/Character.gd")
const BattleUnit = preload("res://src/core/battle/BattleCharacter.gd")

var _battle_state_machine: BattleStateMachine
var _battle_game_state: GameStateManager

func _ready() -> void:
	if not Engine.is_editor_hint():
		await get_tree().process_frame

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	super.before_each()
	
	# Create game state manager
	_battle_game_state = GameStateManager.new()
	var added_state := add_child_autofree(_battle_game_state)
	if not added_state or not is_instance_valid(added_state):
		push_error("Failed to add game state manager")
		return
	track_test_node(_battle_game_state)
	
	# Create battle state machine with dependencies
	_battle_state_machine = BattleStateMachine.new(_battle_game_state)
	var added_machine := add_child_autofree(_battle_state_machine)
	if not added_machine or not is_instance_valid(added_machine):
		push_error("Failed to add battle state machine")
		return
	track_test_node(_battle_state_machine)

func after_each() -> void:
	if is_instance_valid(_battle_state_machine):
		_battle_state_machine.queue_free()
	if is_instance_valid(_battle_game_state):
		_battle_game_state.queue_free()
	_battle_state_machine = null
	_battle_game_state = null
	super.after_each()

# Helper function to create test character
func _create_test_battle_character(char_name: String) -> BattleUnit:
	var character_data := ParsecsCharacter.new() as ParsecsCharacter
	
	# Set basic info
	character_data.character_name = char_name
	character_data.character_class = GameEnums.CharacterClass.SOLDIER
	character_data.origin = GameEnums.Origin.HUMAN
	character_data.background = GameEnums.Background.MILITARY
	character_data.motivation = GameEnums.Motivation.DUTY
	
	# Set stats
	character_data.level = 1
	character_data.health = 10
	character_data.max_health = 10
	character_data._reaction = 3
	character_data._combat = 3
	character_data._toughness = 3
	character_data._savvy = 3
	character_data._luck = 1
	
	# Create battle character with this data
	var battle_character := BattleUnit.new(character_data) as BattleUnit
	var added_char := add_child_autofree(battle_character)
	if not added_char or not is_instance_valid(added_char):
		push_error("Failed to add battle character")
		return null
	track_test_node(battle_character)
	return battle_character

# Battle State Tests
func test_initial_battle_state() -> void:
	# Verify initial state
	assert_not_null(_battle_state_machine, "Battle state machine should exist")
	assert_not_null(_battle_game_state, "Game state manager should exist")
	
	# Verify initial battle state
	assert_eq(_battle_state_machine.current_state, GameEnums.BattleState.SETUP,
		"Battle should start in setup state")
	assert_eq(_battle_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Combat phase should start as none")
	assert_eq(_battle_state_machine.current_round, 1,
		"Battle should start at round 1")
	assert_false(_battle_state_machine.is_battle_active,
		"Battle should not be active initially")
	
	# Create and add test characters
	var player := _create_test_battle_character("Player")
	var enemy := _create_test_battle_character("Enemy")
	
	assert_not_null(player, "Player character should be created")
	assert_not_null(enemy, "Enemy character should be created")
	
	# Verify character stats
	assert_eq(player.health, 10, "Player should have correct initial health")
	assert_eq(enemy.health, 10, "Enemy should have correct initial health")

# Battle Flow Tests
func test_battle_start_flow() -> void:
	watch_signals(_battle_state_machine)
	
	# Create test characters
	var player := _create_test_battle_character("Player")
	var enemy := _create_test_battle_character("Enemy")
	
	# Add characters to battle
	_battle_state_machine.add_character(player)
	_battle_state_machine.add_character(enemy)
	
	# Start the battle through the proper method
	_battle_state_machine.start_battle()
	
	# Wait for and assert the signals
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "battle_started",
		"Battle started signal should be emitted")
	
	# Verify battle state after start
	assert_true(_battle_state_machine.is_battle_active,
		"Battle should be active after start")
	assert_eq(_battle_state_machine.current_state, GameEnums.BattleState.ROUND,
		"Battle should be in round state after start")

func test_round_flow() -> void:
	watch_signals(_battle_state_machine)
	
	# Create and add test characters
	var player := _create_test_battle_character("Player")
	var enemy := _create_test_battle_character("Enemy")
	_battle_state_machine.add_character(player)
	_battle_state_machine.add_character(enemy)
	
	# Start battle first
	_battle_state_machine.start_battle()
	
	# Verify initial round state
	assert_eq(_battle_state_machine.current_round, 1,
		"Battle should start at round 1")

# Phase Transition Tests
func test_phase_transitions() -> void:
	watch_signals(_battle_state_machine)
	
	# Start battle first
	_battle_state_machine.start_battle()
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Test setup to deployment transition
	_battle_state_machine.transition_to_phase(GameEnums.CombatPhase.SETUP)
	await assert_async_signal(_battle_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_battle_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Should transition to setup phase")
	
	# Test deployment to initiative transition
	_battle_state_machine.transition_to_phase(GameEnums.CombatPhase.INITIATIVE)
	await assert_async_signal(_battle_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_battle_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should transition to initiative phase")
	
	# Test initiative to action transition
	_battle_state_machine.transition_to_phase(GameEnums.CombatPhase.ACTION)
	await assert_async_signal(_battle_state_machine, "phase_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "phase_changed", "Phase changed signal should be emitted")
	assert_eq(_battle_state_machine.current_phase, GameEnums.CombatPhase.ACTION,
		"Should transition to action phase")

# Unit Action Tests
func test_unit_action_flow() -> void:
	watch_signals(_battle_state_machine)
	var test_unit := _create_test_battle_character("Test Unit")
	
	# Start battle first
	_battle_state_machine.start_battle()
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Start unit action
	_battle_state_machine.start_unit_action(test_unit, GameEnums.UnitAction.MOVE)
	
	# Wait for action changed signal
	await assert_async_signal(_battle_state_machine, "unit_action_changed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "unit_action_changed", "Action changed signal should be emitted")
	
	# Complete unit action
	_battle_state_machine.complete_unit_action()
	
	# Wait for action completed signal
	await assert_async_signal(_battle_state_machine, "unit_action_completed", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "unit_action_completed", "Action completed signal should be emitted")
	
	# Verify action is marked as completed
	assert_true(_battle_state_machine.has_unit_completed_action(test_unit, GameEnums.UnitAction.MOVE),
		"Action should be marked as completed")
	
	# Verify available actions
	var available_actions := _battle_state_machine.get_available_actions(test_unit)
	assert_false(GameEnums.UnitAction.MOVE in available_actions,
		"Move action should not be available after completion")

# Battle End Tests
func test_battle_end_flow() -> void:
	watch_signals(_battle_state_machine)
	
	# Start battle first
	_battle_state_machine.start_battle()
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# End battle
	_battle_state_machine.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	
	# Wait for battle ended signal
	await assert_async_signal(_battle_state_machine, "battle_ended", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "battle_ended", "Battle ended signal should be emitted")
	assert_false(_battle_state_machine.is_battle_active, "Battle should not be active after end")

# Combat Effect Tests
func test_combat_effect_flow() -> void:
	watch_signals(_battle_state_machine)
	var test_source := _create_test_battle_character("Source")
	var test_target := _create_test_battle_character("Target")
	var test_effect := "stun"
	
	# Start battle first
	_battle_state_machine.start_battle()
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Trigger combat effect
	_battle_state_machine.trigger_combat_effect(test_effect, test_source, test_target)
	
	# Wait for effect signal
	await assert_async_signal(_battle_state_machine, "combat_effect_triggered", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "combat_effect_triggered", "Combat effect signal should be emitted")

# Reaction Tests
func test_reaction_opportunity_flow() -> void:
	watch_signals(_battle_state_machine)
	var test_unit := _create_test_battle_character("Unit")
	var test_source := _create_test_battle_character("Source")
	var test_reaction := "overwatch"
	
	# Start battle first
	_battle_state_machine.start_battle()
	await assert_async_signal(_battle_state_machine, "battle_started", SIGNAL_TIMEOUT)
	
	# Trigger reaction opportunity
	_battle_state_machine.trigger_reaction_opportunity(test_unit, test_reaction, test_source)
	
	# Wait for reaction signal
	await assert_async_signal(_battle_state_machine, "reaction_opportunity", SIGNAL_TIMEOUT)
	verify_signal_emitted(_battle_state_machine, "reaction_opportunity", "Reaction opportunity signal should be emitted")
