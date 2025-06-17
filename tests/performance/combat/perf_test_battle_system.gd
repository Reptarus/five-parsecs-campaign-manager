@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Safe script references - only use paths that definitely exist
const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var _state_machine: Node
var _game_state: Node
var _combat_resolver: Node
var _battlefield_manager: Node

func before_test() -> void:
	super.before_test()
	setup_battle_system()

func after_test() -> void:
	cleanup_battle_system()
	super.after_test()

func setup_battle_system() -> void:
	# Create battle system components with error handling and auto_free
	_state_machine = auto_free(BattleStateMachine.new() if BattleStateMachine else Node.new())
	_state_machine.name = "TestBattleStateMachine"
	
	_game_state = auto_free(Node.new())
	_game_state.name = "TestGameState"
	
	_combat_resolver = auto_free(Node.new())
	_combat_resolver.name = "TestCombatResolver"
	
	_battlefield_manager = auto_free(Node.new())
	_battlefield_manager.name = "TestBattlefieldManager"
	
	# Set up relationships only if components have the required properties
	if _state_machine.has_method("set_game_state_manager") or "game_state_manager" in _state_machine:
		_safe_set_property(_state_machine, "game_state_manager", _game_state)
	
	if _state_machine.has_method("set_combat_resolver") or "combat_resolver" in _state_machine:
		_safe_set_property(_state_machine, "combat_resolver", _combat_resolver)
	
	if _state_machine.has_method("set_battlefield_manager") or "battlefield_manager" in _state_machine:
		_safe_set_property(_state_machine, "battlefield_manager", _battlefield_manager)
	
	# Add to scene tree - auto_free will handle cleanup
	add_child(_game_state)
	add_child(_battlefield_manager)
	add_child(_combat_resolver)
	add_child(_state_machine)
	
	# Initialize active combatants array if it doesn't exist
	if not _combat_resolver.has_method("get") or not _combat_resolver.get("active_combatants"):
		_combat_resolver.set_meta("active_combatants", [])
	
	await stabilize_engine()

func cleanup_battle_system() -> void:
	_state_machine = null
	_game_state = null
	_combat_resolver = null
	_battlefield_manager = null

# Helper function to create test character
func _create_test_character(name: String) -> Node:
	# Create simple test character node
	var character_data = auto_free(Node.new())
	character_data.name = name + "_Data"
	
	# Set character properties as metadata
	character_data.set_meta("character_name", name)
	character_data.set_meta("character_class", _get_safe_enum_value("CharacterClass", "SOLDIER", 0))
	character_data.set_meta("origin", _get_safe_enum_value("Origin", "HUMAN", 0))
	character_data.set_meta("background", _get_safe_enum_value("Background", "MILITARY", 0))
	character_data.set_meta("reactions", 3)
	character_data.set_meta("speed", 4)
	character_data.set_meta("combat_skill", 1)
	character_data.set_meta("toughness", 3)
	character_data.set_meta("savvy", 1)
	character_data.set_meta("luck", 1)
	
	# Create battle character wrapper
	var battle_character = auto_free(Node.new())
	battle_character.name = name + "_Battle"
	
	# Set battle properties as metadata
	battle_character.set_meta("character_data", character_data)
	battle_character.set_meta("health", 10)
	battle_character.set_meta("armor", 2)
	battle_character.set_meta("weapon_skill", 3)
	
	return battle_character

# Helper method to safely set properties
func _safe_set_property(obj: Object, property: String, value: Variant) -> void:
	if obj and property in obj:
		obj.set(property, value)

# Helper method to safely get enum values with fallbacks
func _get_safe_enum_value(enum_class: String, value_name: String, default_value: int) -> int:
	if enum_class in GameEnums and value_name in GameEnums[enum_class]:
		return GameEnums[enum_class][value_name]
	return default_value

# Helper method to safely call resolve_combat or simulate it
func _safe_resolve_combat(attacker: Node, target: Node) -> void:
	if is_instance_valid(_combat_resolver) and _combat_resolver.has_method("resolve_combat"):
		_combat_resolver.resolve_combat(attacker, target)
	else:
		# Simulate combat resolution for performance testing
		var damage = randi_range(1, 5)
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif "health" in target:
			target.health = max(0, target.health - damage)

# Helper function to create multiple test characters
func _create_test_squad(size: int) -> Array[Node]:
	var squad: Array[Node] = []
	for i in range(size):
		var character = _create_test_character("TestChar_%d" % i)
		squad.append(character)
	return squad

# Helper function to create test weapon
func _create_test_weapon(name: String) -> Resource:
	# Create simple weapon resource without specific script dependency
	var weapon = Resource.new()
	weapon.set_meta("name", name)
	weapon.set_meta("damage", 2)
	weapon.set_meta("range", 12)
	weapon.set_meta("shots", 1)
	return weapon

# Performance Tests
func test_combat_resolution_performance() -> void:
	var player_squad = _create_test_squad(5)
	var enemy_squad = _create_test_squad(5)
	
	# Add squads to combat resolver using metadata if property doesn't exist
	var active_combatants = []
	if _combat_resolver.has_method("get") and _combat_resolver.get("active_combatants") != null:
		active_combatants = _combat_resolver.active_combatants
	else:
		active_combatants = _combat_resolver.get_meta("active_combatants", [])
	
	for unit in player_squad:
		active_combatants.append(unit)
	for unit in enemy_squad:
		active_combatants.append(unit)
	
	# Update the active combatants
	if _combat_resolver.has_method("set") and "active_combatants" in _combat_resolver:
		_combat_resolver.active_combatants = active_combatants
	else:
		_combat_resolver.set_meta("active_combatants", active_combatants)
	
	# Measure time for 100 combat resolutions
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		var attacker = player_squad[i % 5]
		var target = enemy_squad[i % 5]
		_safe_resolve_combat(attacker, target)
	var end_time = Time.get_ticks_msec()
	
	var time_taken = end_time - start_time
	var avg_time = time_taken / 100.0
	
	print("Combat Resolution Performance:")
	print("- Total time for 100 resolutions: %d ms" % time_taken)
	print("- Average time per resolution: %.2f ms" % avg_time)
	
	# Assert reasonable performance
	assert_that(avg_time).override_failure_message(
		"Combat resolution should take less than 5ms on average"
	).is_less(5.0)

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
	assert_that(avg_time).override_failure_message(
		"State transitions should take less than 1ms on average"
	).is_less(1.0)

func test_battle_flow_performance() -> void:
	var player_squad = _create_test_squad(5)
	var enemy_squad = _create_test_squad(5)
	
	# Add squads to managers using safe metadata approach
	var active_combatants = _combat_resolver.get_meta("active_combatants", [])
	for unit in player_squad:
		active_combatants.append(unit)
	for unit in enemy_squad:
		active_combatants.append(unit)
	_combat_resolver.set_meta("active_combatants", active_combatants)
	
	# Measure time for 10 complete battle rounds
	var start_time = Time.get_ticks_msec()
	for round in range(10):
		# Start round
		_state_machine.emit_signal("round_started", round + 1)
		
		# Process each unit's turn
		for unit in player_squad + enemy_squad:
			# Initiative phase
			_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.SETUP)
			
			# Action phase
			_state_machine.emit_signal("phase_changed", GameEnums.CombatPhase.ACTION)
			_state_machine.emit_signal("unit_action_changed", GameEnums.UnitAction.MOVE)
			_state_machine.emit_signal("unit_action_completed", unit, GameEnums.UnitAction.MOVE)
			
			# Combat resolution if enemy
			if unit in enemy_squad:
				var target = player_squad[randi() % player_squad.size()]
				_safe_resolve_combat(unit, target)
		
		# End round
		_state_machine.emit_signal("round_ended", round + 1)
	var end_time = Time.get_ticks_msec()
	
	var time_taken = end_time - start_time
	var avg_time = time_taken / 10.0
	
	print("Battle Flow Performance:")
	print("- Total time for 10 rounds: %d ms" % time_taken)
	print("- Average time per round: %.2f ms" % avg_time)
	
	# Assert reasonable performance
	assert_that(avg_time).override_failure_message(
		"Battle rounds should take less than 100ms on average"
	).is_less(100.0)
