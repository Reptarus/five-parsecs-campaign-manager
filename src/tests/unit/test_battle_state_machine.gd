class_name TestBattleStateMachine
extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const BattleStateMachine = preload("res://src/core/battle/state/BattleStateMachine.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var battle_state_machine: BattleStateMachine
var test_character: Character

func before_each():
	battle_state_machine = BattleStateMachine.new()
	add_child_autoqfree(battle_state_machine)
	
	test_character = Character.new()
	test_character.character_name = "Test Character"
	test_character.level = 1
	test_character.status = GameEnums.CharacterStatus.HEALTHY

func after_each():
	battle_state_machine = null
	test_character = null

func test_initial_state():
	assert_eq(battle_state_machine.current_phase, GameEnums.CombatPhase.NONE,
		"Initial combat phase should be NONE")
	assert_false(battle_state_machine.is_battle_active,
		"Battle should not be active initially")

func test_battle_start():
	var signal_emitted = false
	battle_state_machine.battle_started.connect(
		func(): signal_emitted = true
	)
	
	battle_state_machine.start_battle()
	assert_true(battle_state_machine.is_battle_active,
		"Battle should be active after starting")
	assert_eq(battle_state_machine.current_phase, GameEnums.CombatPhase.SETUP,
		"Combat phase should be SETUP after starting battle")
	assert_true(signal_emitted,
		"Battle started signal should be emitted")

func test_battle_end():
	battle_state_machine.start_battle()
	
	var signal_emitted = false
	battle_state_machine.battle_ended.connect(
		func(): signal_emitted = true
	)
	
	battle_state_machine.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	assert_false(battle_state_machine.is_battle_active,
		"Battle should not be active after ending")
	assert_true(signal_emitted,
		"Battle ended signal should be emitted")

func test_phase_transitions():
	battle_state_machine.start_battle()
	
	var phase_changes = []
	battle_state_machine.phase_changed.connect(
		func(new_phase): phase_changes.append(new_phase)
	)
	
	# Test phase progression
	battle_state_machine.advance_phase()
	assert_eq(battle_state_machine.current_phase, GameEnums.CombatPhase.DEPLOYMENT,
		"Should advance to DEPLOYMENT phase")
	
	battle_state_machine.advance_phase()
	assert_eq(battle_state_machine.current_phase, GameEnums.CombatPhase.INITIATIVE,
		"Should advance to INITIATIVE phase")
	
	assert_eq(phase_changes.size(), 2,
		"Phase changed signal should be emitted for each transition")

func test_combat_resolution():
	battle_state_machine.start_battle()
	battle_state_machine.add_combatant(test_character)
	
	var signal_emitted = false
	battle_state_machine.attack_resolved.connect(
		func(attacker, target, result): signal_emitted = true
	)
	
	var target = Character.new()
	target.character_name = "Target Character"
	battle_state_machine.add_combatant(target)
	
	battle_state_machine.resolve_attack(test_character, target)
	assert_true(signal_emitted,
		"Attack resolved signal should be emitted")

func test_reaction_system():
	battle_state_machine.start_battle()
	battle_state_machine.add_combatant(test_character)
	
	var signal_emitted = false
	battle_state_machine.reaction_opportunity.connect(
		func(unit, reaction_type, source): signal_emitted = true
	)
	
	battle_state_machine.trigger_reaction(test_character, "overwatch", null)
	assert_true(signal_emitted,
		"Reaction opportunity signal should be emitted")

func test_combat_effects():
	battle_state_machine.start_battle()
	battle_state_machine.add_combatant(test_character)
	
	var signal_emitted = false
	battle_state_machine.combat_effect_triggered.connect(
		func(effect_name, source, target): signal_emitted = true
	)
	
	battle_state_machine.apply_combat_effect("suppressed", test_character, null)
	assert_true(signal_emitted,
		"Combat effect triggered signal should be emitted")

func test_state_persistence():
	battle_state_machine.start_battle()
	battle_state_machine.add_combatant(test_character)
	
	var save_data = battle_state_machine.save_state()
	assert_not_null(save_data,
		"Battle state should be saved successfully")
	
	battle_state_machine.end_battle(GameEnums.VictoryConditionType.ELIMINATION)
	battle_state_machine.load_state(save_data)
	
	assert_true(battle_state_machine.is_battle_active,
		"Battle should be active after loading state")
	assert_has(battle_state_machine.active_combatants, test_character,
		"Combatants should be restored after loading state")