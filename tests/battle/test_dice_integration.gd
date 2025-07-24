@tool
extends GdUnitGameTest

## DiceSystem Integration Validation Test Suite
##
## Tests the integration between battle system and DiceSystem:
## - Battle roll integration
## - Result processing verification
## - Manual override functionality
## - History tracking validation
## - Signal flow between systems

# Test subjects
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleEventBus: GDScript = preload("res://src/core/battle/FPCM_BattleEventBus.gd")
const FPCM_DiceSystem: GDScript = preload("res://src/core/systems/DiceSystem.gd")

# Type-safe instance variables
var battle_manager: FPCM_BattleManager.new() = null
var event_bus: Node = null
var dice_system: FPCM_DiceSystem.new() = null

# Signal tracking
var dice_requests: Array[Dictionary] = []
var dice_results: Array[FPCM_DiceSystem.DiceRoll] = []
var manual_input_requests: Array[FPCM_DiceSystem.DiceRoll] = []

# Test data
var test_mission: Resource = null
var test_crew: Array[Resource] = []
var test_enemies: Array[Resource] = []

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize systems
	battle_manager = FPCM_BattleManager.new()
	track_node(battle_manager)
	
	event_bus = FPCM_BattleEventBus.new()
	add_child(event_bus)
	track_node(event_bus)
	
	dice_system = FPCM_DiceSystem.new()
	track_node(dice_system)
	
	# Connect systems
	event_bus.set_battle_manager(battle_manager)
	
	# Set up signal tracking
	_setup_signal_tracking()
	
	# Create test data
	_create_test_data()
	
	# Clear tracking arrays
	dice_requests.clear()
	dice_results.clear()
	manual_input_requests.clear()

func after_test() -> void:
	# Cleanup
	battle_manager = null
	event_bus = null
	dice_system = null
	
	dice_requests.clear()
	dice_results.clear()
	manual_input_requests.clear()
	
	super.after_test()

## BASIC DICE INTEGRATION TESTS

func test_dice_system_initialization() -> void:
	assert_that(dice_system).is_not_null()
	assert_that(dice_system.auto_roll_enabled).is_true()
	assert_that(dice_system.allow_manual_override).is_true()
	assert_that(dice_system.roll_history).is_not_null()

func test_battle_manager_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Battle manager should have dice system access
	assert_that(battle_manager.dice_system).is_not_null()

func test_dice_roll_request_from_battle() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Request dice roll through battle manager
	var result = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Test Battle Roll")
	
	assert_that(result).is_not_null()
	assert_that(dice_requests.size()).is_greater(0)
	assert_that(dice_requests[0].context).is_equal("Test Battle Roll")

## DICE PATTERN INTEGRATION TESTS

func test_five_parsecs_dice_patterns() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Test each Five Parsecs dice pattern
	var patterns = [
		FPCM_DiceSystem.DicePattern.D6,
		FPCM_DiceSystem.DicePattern.D10,
		FPCM_DiceSystem.DicePattern.D66,
		FPCM_DiceSystem.DicePattern.D100,
		FPCM_DiceSystem.DicePattern.COMBAT,
		FPCM_DiceSystem.DicePattern.REACTION
	]
	
	for pattern in patterns:
		var result = dice_system.roll_dice(pattern, "Pattern Test")
		
		assert_that(result).is_not_null()
		assert_that(result.individual_rolls.size()).is_greater(0)
		assert_that(result.total).is_greater(0)

func test_combat_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Test combat-specific dice rolls
	var combat_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.COMBAT, "Combat Resolution")
	
	assert_that(combat_roll).is_not_null()
	assert_that(combat_roll.context).is_equal("Combat Resolution")
	assert_that(combat_roll.total).is_between(1, 10) # Assuming combat is d10

func test_reaction_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Test reaction dice rolls
	var reaction_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.REACTION, "Reaction Test")
	
	assert_that(reaction_roll).is_not_null()
	assert_that(reaction_roll.context).is_equal("Reaction Test")
	assert_that(reaction_roll.total).is_between(1, 6) # Reaction should be d6

func test_injury_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Test injury table dice rolls
	var injury_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.INJURY, "Injury Table")
	
	assert_that(injury_roll).is_not_null()
	assert_that(injury_roll.context).is_equal("Injury Table")
	assert_that(injury_roll.total).is_between(1, 100) # Injury should be d100

## EVENT BUS DICE INTEGRATION TESTS

func test_dice_request_through_event_bus() -> void:
	# Test dice roll request through event bus
	event_bus.dice_roll_requested.emit(FPCM_DiceSystem.DicePattern.D6, "Event Bus Test")
	await get_tree().process_frame
	
	# Event bus should handle dice roll
	assert_that(dice_requests.size()).is_greater(0)

func test_dice_result_propagation() -> void:
	# Roll dice and check if result propagates through event bus
	var roll_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Propagation Test")
	
	assert_that(roll_result).is_not_null()
	assert_that(dice_results.size()).is_greater(0)

## MANUAL OVERRIDE TESTS

func test_manual_override_request() -> void:
	# Enable manual override mode
	dice_system.auto_roll_enabled = false
	dice_system.allow_manual_override = true
	
	# Request dice roll - should trigger manual input request
	var roll_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Manual Test", true)
	
	assert_that(manual_input_requests.size()).is_greater(0)
	assert_that(roll_result.context).is_equal("Manual Test")

func test_manual_input_processing() -> void:
	dice_system.auto_roll_enabled = false
	
	# Create manual dice roll
	var manual_roll = FPCM_DiceSystem.DiceRoll.new(1, "d6", 0, "Manual Input Test")
	manual_roll.individual_rolls = [4]
	manual_roll.total = 4
	manual_roll.is_manual = true
	
	# Process manual input (would normally come from UI)
	dice_system.dice_rolled.emit(manual_roll)
	
	assert_that(dice_results.size()).is_greater(0)
	assert_that(dice_results.back().is_manual).is_true()

func test_auto_roll_vs_manual_mode() -> void:
	# Test automatic mode
	dice_system.auto_roll_enabled = true
	var auto_roll = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Auto Test")
	
	assert_that(auto_roll.individual_rolls.size()).is_greater(0)
	assert_that(auto_roll.is_manual).is_false()
	
	# Test manual mode
	dice_system.auto_roll_enabled = false
	var manual_request = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Manual Test")
	
	# Manual request should not have rolls populated yet
	assert_that(manual_request.individual_rolls.size()).is_equal(0)

## DICE HISTORY INTEGRATION TESTS

func test_dice_history_tracking() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var initial_history_size = dice_system.roll_history.size()
	
	# Perform several dice rolls
	for i in range(5):
		battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "History Test " + str(i))
	
	assert_that(dice_system.roll_history.size()).is_equal(initial_history_size + 5)

func test_dice_history_limit() -> void:
	# Set small history limit for testing
	dice_system.max_history_size = 3
	
	# Perform more rolls than limit
	for i in range(5):
		dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Limit Test " + str(i))
	
	# History should be limited
	assert_that(dice_system.roll_history.size()).is_less_equal(3)

func test_battle_specific_dice_history() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Perform battle-related dice rolls
	battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.COMBAT, "Combat Roll 1")
	battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.REACTION, "Reaction Roll 1")
	battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.INJURY, "Injury Roll 1")
	
	# Check that battle context is preserved in history
	var battle_rolls = dice_system.roll_history.filter(func(roll): return "Roll 1" in roll.context)
	assert_that(battle_rolls.size()).is_equal(3)

## DICE ANIMATION INTEGRATION TESTS

func test_dice_animation_signals() -> void:
	var animation_started_count = 0
	var animation_completed_count = 0
	
	dice_system.dice_animation_started.connect(func(dice_count, dice_type): animation_started_count += 1)
	dice_system.dice_animation_completed.connect(func(result): animation_completed_count += 1)
	
	# Enable animations
	dice_system.show_animations = true
	
	# Roll dice
	dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Animation Test")
	
	# Should trigger animation signals
	assert_that(animation_started_count).is_greater(0)

func test_animation_disabled_mode() -> void:
	var animation_started_count = 0
	
	dice_system.dice_animation_started.connect(func(dice_count, dice_type): animation_started_count += 1)
	
	# Disable animations
	dice_system.show_animations = false
	
	# Roll dice
	dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "No Animation Test")
	
	# Should not trigger animation signals
	assert_that(animation_started_count).is_equal(0)

## BATTLE PHASE DICE INTEGRATION TESTS

func test_pre_battle_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Should be in PRE_BATTLE phase
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
	
	# Roll dice during pre-battle
	var roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Pre-Battle Setup")
	
	assert_that(roll).is_not_null()
	assert_that(roll.context).contains("Pre-Battle")

func test_tactical_battle_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	# Roll dice during tactical battle
	var combat_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.COMBAT, "Tactical Combat")
	var reaction_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.REACTION, "Tactical Reaction")
	
	assert_that(combat_roll).is_not_null()
	assert_that(reaction_roll).is_not_null()
	assert_that(combat_roll.context).contains("Tactical")
	assert_that(reaction_roll.context).contains("Tactical")

func test_battle_resolution_dice_integration() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)
	
	# Roll dice during battle resolution
	var injury_roll = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.INJURY, "Resolution Injury")
	
	assert_that(injury_roll).is_not_null()
	assert_that(injury_roll.context).contains("Resolution")

## DICE RESULT PROCESSING TESTS

func test_dice_result_validation() -> void:
	var roll = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Validation Test")
	
	# Validate roll structure
	assert_that(roll.dice_count).is_equal(1)
	assert_that(roll.dice_type).is_equal("d6")
	assert_that(roll.individual_rolls.size()).is_equal(1)
	assert_that(roll.total).is_between(1, 6)
	assert_that(roll.timestamp).is_greater(0.0)
	assert_that(roll.roll_id).is_not_empty()

func test_dice_result_display_text() -> void:
	var roll = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Display Test")
	
	var display_text = roll.get_display_text()
	var simple_text = roll.get_simple_text()
	
	assert_that(display_text).is_not_empty()
	assert_that(simple_text).is_not_empty()
	assert_that(display_text).contains("d6")
	assert_that(simple_text).contains("d6")

func test_dice_modifier_processing() -> void:
	var roll_with_modifier = dice_system.roll_custom(1, 6, 3, "Modifier Test")
	
	assert_that(roll_with_modifier.modifier).is_equal(3)
	assert_that(roll_with_modifier.total).is_greater_equal(4) # Min roll (1) + modifier (3)
	assert_that(roll_with_modifier.total).is_less_equal(9) # Max roll (6) + modifier (3)

## ERROR HANDLING TESTS

func test_dice_system_unavailable_handling() -> void:
	# Temporarily disable dice system
	battle_manager.dice_system = null
	
	# Should handle gracefully
	var result = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Error Test")
	
	assert_that(result).is_null()
	# Should emit error signal
	# Note: Would need to track battle_error signals

func test_invalid_dice_pattern_handling() -> void:
	# Test with invalid pattern (would require enum bounds checking)
	# This depends on how DicePattern enum is implemented
	
	# Try to create roll with invalid data
	var invalid_roll = FPCM_DiceSystem.DiceRoll.new(0, "", 0, "Invalid Test")
	
	# Should handle gracefully
	assert_that(invalid_roll).is_not_null()

func test_dice_roll_recovery() -> void:
	# Test recovery from failed dice roll
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Force dice system failure simulation
	var original_dice_system = battle_manager.dice_system
	battle_manager.dice_system = null
	
	# Attempt roll
	var failed_result = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Recovery Test")
	assert_that(failed_result).is_null()
	
	# Restore dice system
	battle_manager.dice_system = original_dice_system
	
	# Should work again
	var recovered_result = battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Recovery Test 2")
	assert_that(recovered_result).is_not_null()

## PERFORMANCE INTEGRATION TESTS

func test_dice_integration_performance() -> void:
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var start_time = Time.get_ticks_msec()
	
	# Perform many dice rolls rapidly
	for i in range(100):
		battle_manager.request_dice_roll(FPCM_DiceSystem.DicePattern.D6, "Performance Test " + str(i))
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	# Should handle many rolls efficiently
	assert_that(elapsed).is_less(1000.0) # Less than 1 second for 100 rolls
	print("100 dice rolls completed in %f ms" % elapsed)

func test_dice_memory_efficiency() -> void:
	var initial_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Perform many dice rolls
	for i in range(200):
		var roll = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Memory Test " + str(i))
		# Don't hold references to let GC work
		roll = null
	
	await get_tree().process_frame
	
	var final_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_increase = final_memory - initial_memory
	
	# Should not leak significant memory
	assert_that(memory_increase).is_less(100)

## HELPER METHODS

func _setup_signal_tracking() -> void:
	# Track dice requests through event bus
	event_bus.dice_roll_requested.connect(_on_dice_roll_requested)
	
	# Track dice results
	if dice_system:
		dice_system.dice_rolled.connect(_on_dice_rolled)
		dice_system.manual_input_requested.connect(_on_manual_input_requested)

func _on_dice_roll_requested(pattern: FPCM_DiceSystem.DicePattern, context: String) -> void:
	dice_requests.append({"pattern": pattern, "context": context, "timestamp": Time.get_ticks_msec()})

func _on_dice_rolled(result: FPCM_DiceSystem.DiceRoll) -> void:
	dice_results.append(result)

func _on_manual_input_requested(dice_roll: FPCM_DiceSystem.DiceRoll) -> void:
	manual_input_requests.append(dice_roll)

func _create_test_data() -> void:
	# Create test mission
	test_mission = Resource.new()
	test_mission.set_meta("name", "Dice Integration Test")
	test_mission.set_meta("type", "patrol")
	
	# Create test crew
	test_crew.clear()
	for i in range(4):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew " + str(i))
		test_crew.append(crew_member)
	
	# Create test enemies
	test_enemies.clear()
	for i in range(3):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		test_enemies.append(enemy)