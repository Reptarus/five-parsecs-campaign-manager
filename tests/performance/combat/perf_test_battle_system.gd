@tool
extends "res://tests/fixtures/base_test.gd"

const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const CombatResolver = preload("res://src/core/battle/CombatResolver.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")

var _state_machine: BattleStateMachine
var _game_state: GameStateManager
var _combat_resolver: CombatResolver
var _battlefield_manager: BattlefieldManager

func before_each() -> void:
	await super.before_each()
	
	# Create managers
	_game_state = GameStateManager.new()
	add_child(_game_state)
	track_test_node(_game_state)
	
	_battlefield_manager = BattlefieldManager.new()
	add_child(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	_combat_resolver = CombatResolver.new()
	_combat_resolver.battlefield_manager = _battlefield_manager
	add_child(_combat_resolver)
	track_test_node(_combat_resolver)
	
	_state_machine = BattleStateMachine.new(_game_state)
	_state_machine.game_state_manager = _game_state
	add_child(_state_machine)
	track_test_node(_state_machine)

func after_each() -> void:
	await super.after_each()
	_state_machine = null
	_game_state = null
	_combat_resolver = null
	_battlefield_manager = null

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

# Helper function to create multiple test characters
func _create_test_squad(size: int) -> Array[Character]:
	var squad: Array[Character] = []
	for i in range(size):
		squad.append(_create_test_character("Unit %d" % (i + 1)))
	return squad

# Performance Tests
func test_combat_resolution_performance() -> void:
	var player_squad = _create_test_squad(5)
	var enemy_squad = _create_test_squad(5)
	
	# Add squads to combat resolver
	for unit in player_squad:
		_combat_resolver.active_combatants.append(unit)
	for unit in enemy_squad:
		_combat_resolver.active_combatants.append(unit)
	
	# Measure time for 100 combat resolutions
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var attacker = player_squad[i % 5]
		var target = enemy_squad[i % 5]
		_combat_resolver.resolve_combat(attacker, target)
	var end_time = Time.get_ticks_msec()
	
	var time_taken = end_time - start_time
	var avg_time = time_taken / 100.0
	
	print("Combat Resolution Performance:")
	print("- Total time for 100 resolutions: %d ms" % time_taken)
	print("- Average time per resolution: %.2f ms" % avg_time)
	
	# Assert reasonable performance
	assert_lt(avg_time, 5.0, "Combat resolution should take less than 5ms on average")

func test_state_transition_performance() -> void:
	var phase_changes = []
	_state_machine.phase_changed.connect(func(new_phase): phase_changes.append(new_phase))
	
	# Measure time for 1000 state transitions
	var start_time = Time.get_ticks_msec()
	for i in range(1000):
		_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.SETUP)
		_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.INITIATIVE)
		_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.ACTION)
	var end_time = Time.get_ticks_msec()
	
	var time_taken = end_time - start_time
	var avg_time = time_taken / 3000.0 # 1000 iterations * 3 transitions each
	
	print("State Transition Performance:")
	print("- Total time for 3000 transitions: %d ms" % time_taken)
	print("- Average time per transition: %.2f ms" % avg_time)
	
	# Assert reasonable performance
	assert_lt(avg_time, 1.0, "State transitions should take less than 1ms on average")

func test_battle_flow_performance() -> void:
	var player_squad = _create_test_squad(5)
	var enemy_squad = _create_test_squad(5)
	
	# Add squads to managers
	for unit in player_squad:
		_combat_resolver.active_combatants.append(unit)
	for unit in enemy_squad:
		_combat_resolver.active_combatants.append(unit)
	
	# Measure time for 10 complete battle rounds
	var start_time = Time.get_ticks_msec()
	for round in range(10):
		# Start round
		_state_machine.emit_signal("round_started", round + 1)
		
		# Process each unit's turn
		for unit in player_squad + enemy_squad:
			# Initiative phase
			_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.INITIATIVE)
			
			# Action phase
			_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.ACTION)
			_state_machine.emit_signal("unit_action_changed", GameEnums.UnitAction.MOVE)
			_state_machine.emit_signal("unit_action_completed", unit, GameEnums.UnitAction.MOVE)
			
			# Combat resolution if enemy
			if unit in enemy_squad:
				var target = player_squad[randi() % player_squad.size()]
				_combat_resolver.resolve_combat(unit, target)
		
		# End round
		_state_machine.emit_signal("round_ended", round + 1)
	var end_time = Time.get_ticks_msec()
	
	var time_taken = end_time - start_time
	var avg_time = time_taken / 10.0
	
	print("Battle Flow Performance:")
	print("- Total time for 10 rounds: %d ms" % time_taken)
	print("- Average time per round: %.2f ms" % avg_time)
	
	# Assert reasonable performance
	assert_lt(avg_time, 100.0, "Battle rounds should take less than 100ms on average")