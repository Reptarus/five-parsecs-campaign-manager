@tool
extends GdUnitGameTest

## FPCM_BattleState Resource Integrity Test Suite
##
## Tests the battle state resource for:
## - Resource integrity validation
## - Save/load functionality 
## - State serialization/deserialization
## - Data validation methods
## - Unit tracking and position management
## - Performance under stress

# Test subject
const FPCM_BattleState: GDScript = preload("res://src/core/battle/FPCM_BattleState.gd")

# Type-safe instance variables
var battle_state: FPCM_BattleState.new() = null
var test_mission_data: Resource = null
var test_crew_members: Array[Resource] = []
var test_enemy_forces: Array[Resource] = []

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize battle state
	battle_state = FPCM_BattleState.new()
	track_node(battle_state)
	
	# Create test data
	_create_test_data()

func after_test() -> void:
	# Cleanup
	battle_state = null
	test_mission_data = null
	test_crew_members.clear()
	test_enemy_forces.clear()
	
	super.after_test()

## BASIC FUNCTIONALITY TESTS

func test_battle_state_initialization() -> void:
	assert_that(battle_state).is_not_null()
	assert_that(battle_state.battle_id).is_not_empty()
	assert_that(battle_state.battle_start_time).is_greater(0.0)
	assert_that(battle_state.current_phase).is_equal(0)
	assert_that(battle_state.current_round).is_equal(0)
	assert_that(battle_state.current_turn).is_equal(0)

func test_mission_initialization_success() -> void:
	var success: bool = battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	assert_that(success).is_true()
	assert_that(battle_state.mission_data).is_equal(test_mission_data)
	assert_that(battle_state.crew_members.size()).is_equal(3)
	assert_that(battle_state.enemy_forces.size()).is_equal(2)
	assert_that(battle_state.mission_type).is_equal("patrol")
	assert_that(battle_state.difficulty_level).is_equal(2)

func test_mission_initialization_validation() -> void:
	# Test with null mission data
	var success1: bool = battle_state.initialize_with_mission(null, test_crew_members, test_enemy_forces)
	assert_that(success1).is_false()
	assert_that(battle_state.get_validation_errors().size()).is_greater(0)
	
	# Reset validation errors
	battle_state._validation_errors.clear()
	
	# Test with empty crew
	var empty_crew: Array[Resource] = []
	var success2: bool = battle_state.initialize_with_mission(test_mission_data, empty_crew, test_enemy_forces)
	assert_that(success2).is_false()
	assert_that(battle_state.get_validation_errors().any(func(error): return error.contains("crew member"))).is_true()
	
	# Reset validation errors
	battle_state._validation_errors.clear()
	
	# Test with empty enemies
	var empty_enemies: Array[Resource] = []
	var success3: bool = battle_state.initialize_with_mission(test_mission_data, test_crew_members, empty_enemies)
	assert_that(success3).is_false()
	assert_that(battle_state.get_validation_errors().any(func(error): return error.contains("enemy"))).is_true()

## UNIT TRACKING TESTS

func test_unit_tracking_initialization() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Should have tracking for all units
	assert_that(battle_state.unit_positions.size()).is_equal(5) # 3 crew + 2 enemies
	assert_that(battle_state.unit_status.size()).is_equal(5)
	
	# All units should start undeployed
	for unit_id: String in battle_state.unit_positions:
		assert_that(battle_state.unit_positions[unit_id]).is_equal(Vector2i(-1, -1))
		assert_that(battle_state.unit_status[unit_id]["is_active"]).is_true()

func test_unit_position_updates() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var unit_ids = battle_state.unit_positions.keys()
	var test_unit_id = unit_ids[0]
	var test_position = Vector2i(5, 5)
	
	# Valid position update
	var success1: bool = battle_state.update_unit_position(test_unit_id, test_position)
	assert_that(success1).is_true()
	assert_that(battle_state.unit_positions[test_unit_id]).is_equal(test_position)
	
	# Invalid unit ID
	var success2: bool = battle_state.update_unit_position("invalid_id", Vector2i(1, 1))
	assert_that(success2).is_false()
	
	# Position conflict
	var other_unit_id = unit_ids[1]
	var success3: bool = battle_state.update_unit_position(other_unit_id, test_position)
	assert_that(success3).is_false()

func test_battlefield_bounds_validation() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	battle_state.battlefield_size = Vector2i(10, 10)
	
	var unit_ids = battle_state.unit_positions.keys()
	var test_unit_id = unit_ids[0]
	
	# Valid positions
	assert_that(battle_state.update_unit_position(test_unit_id, Vector2i(0, 0))).is_true()
	assert_that(battle_state.update_unit_position(test_unit_id, Vector2i(9, 9))).is_true()
	
	# Invalid positions (out of bounds)
	assert_that(battle_state.update_unit_position(test_unit_id, Vector2i(-1, 0))).is_false()
	assert_that(battle_state.update_unit_position(test_unit_id, Vector2i(10, 5))).is_false()
	assert_that(battle_state.update_unit_position(test_unit_id, Vector2i(5, 10))).is_false()

func test_unit_health_tracking() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var unit_ids = battle_state.unit_status.keys()
	var test_unit_id = unit_ids[0]
	var initial_health = battle_state.unit_status[test_unit_id]["health"]
	
	# Valid health update (damage)
	var success1: bool = battle_state.update_unit_health(test_unit_id, initial_health - 1, "test_damage")
	assert_that(success1).is_true()
	assert_that(battle_state.unit_status[test_unit_id]["health"]).is_equal(initial_health - 1)
	assert_that(battle_state.injuries.size()).is_equal(1)
	
	# Death (health to 0)
	var success2: bool = battle_state.update_unit_health(test_unit_id, 0, "fatal_damage")
	assert_that(success2).is_true()
	assert_that(battle_state.unit_status[test_unit_id]["health"]).is_equal(0)
	assert_that(battle_state.unit_status[test_unit_id]["is_active"]).is_false()
	assert_that(battle_state.casualties.size()).is_equal(1)

func test_health_clamping() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var unit_ids = battle_state.unit_status.keys()
	var test_unit_id = unit_ids[0]
	var max_health = battle_state.unit_status[test_unit_id]["max_health"]
	
	# Health above maximum should be clamped
	var success1: bool = battle_state.update_unit_health(test_unit_id, max_health + 10)
	assert_that(success1).is_true()
	assert_that(battle_state.unit_status[test_unit_id]["health"]).is_equal(max_health)
	
	# Negative health should be clamped to 0
	var success2: bool = battle_state.update_unit_health(test_unit_id, -5)
	assert_that(success2).is_true()
	assert_that(battle_state.unit_status[test_unit_id]["health"]).is_equal(0)

## ROUND AND TURN MANAGEMENT TESTS

func test_round_advancement() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	assert_that(battle_state.current_round).is_equal(0)
	assert_that(battle_state.current_turn).is_equal(0)
	
	battle_state.advance_round()
	
	assert_that(battle_state.current_round).is_equal(1)
	assert_that(battle_state.current_turn).is_equal(0) # Turn resets on new round

func test_turn_advancement() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	battle_state.advance_turn()
	battle_state.advance_turn()
	
	assert_that(battle_state.current_turn).is_equal(2)
	assert_that(battle_state.current_round).is_equal(0) # Round unchanged

func test_round_turn_tracking_in_events() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Advance some rounds/turns
	battle_state.advance_round()
	battle_state.advance_turn()
	battle_state.advance_turn()
	
	# Cause injury - should record current round/turn
	var unit_ids = battle_state.unit_status.keys()
	battle_state.update_unit_health(unit_ids[0], 1, "test_damage")
	
	var injury = battle_state.injuries[0]
	assert_that(injury["round"]).is_equal(1)
	assert_that(injury["turn"]).is_equal(2)

## BATTLE EVENTS TESTS

func test_battle_event_tracking() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	battle_state.add_battle_event("test_event_1")
	battle_state.add_battle_event("test_event_2", {"data": "test"})
	
	assert_that(battle_state.triggered_events.size()).is_equal(2)
	assert_that(battle_state.triggered_events).contains("test_event_1")
	assert_that(battle_state.triggered_events).contains("test_event_2")
	assert_that(battle_state.special_circumstances.size()).is_equal(1) # Only event with data

func test_duplicate_event_prevention() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	battle_state.add_battle_event("duplicate_event")
	battle_state.add_battle_event("duplicate_event")
	battle_state.add_battle_event("duplicate_event")
	
	# Should only appear once
	assert_that(battle_state.triggered_events.size()).is_equal(1)
	assert_that(battle_state.triggered_events[0]).is_equal("duplicate_event")

## CHECKPOINT SYSTEM TESTS

func test_checkpoint_creation() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Set up some state
	battle_state.advance_round()
	battle_state.advance_turn()
	var unit_ids = battle_state.unit_positions.keys()
	battle_state.update_unit_position(unit_ids[0], Vector2i(5, 5))
	
	# Create checkpoint
	battle_state.create_checkpoint("test_checkpoint")
	
	assert_that(battle_state.save_checkpoints.size()).is_equal(1)
	var checkpoint = battle_state.save_checkpoints[0]
	assert_that(checkpoint["name"]).is_equal("test_checkpoint")
	assert_that(checkpoint["round"]).is_equal(1)
	assert_that(checkpoint["turn"]).is_equal(1)

func test_checkpoint_restoration() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Create initial state
	battle_state.advance_round()
	battle_state.advance_turn()
	var unit_ids = battle_state.unit_positions.keys()
	battle_state.update_unit_position(unit_ids[0], Vector2i(3, 3))
	
	# Create checkpoint
	battle_state.create_checkpoint()
	
	# Modify state further
	battle_state.advance_round()
	battle_state.advance_turn()
	battle_state.update_unit_position(unit_ids[0], Vector2i(7, 7))
	
	# Restore checkpoint
	var success: bool = battle_state.restore_checkpoint(0)
	assert_that(success).is_true()
	assert_that(battle_state.current_round).is_equal(1)
	assert_that(battle_state.current_turn).is_equal(1)
	assert_that(battle_state.unit_positions[unit_ids[0]]).is_equal(Vector2i(3, 3))

func test_checkpoint_limit() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Create more than 10 checkpoints
	for i in range(15):
		battle_state.create_checkpoint("checkpoint_" + str(i))
	
	# Should be limited to 10
	assert_that(battle_state.save_checkpoints.size()).is_equal(10)
	
	# Should contain the latest checkpoints
	assert_that(battle_state.save_checkpoints[0]["name"]).is_equal("checkpoint_5") # First 5 should be removed
	assert_that(battle_state.save_checkpoints[-1]["name"]).is_equal("checkpoint_14")

## BATTLEFIELD STATUS TESTS

func test_battlefield_status_summary() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var status = battle_state.get_battlefield_status()
	
	assert_that(status["round"]).is_equal(0)
	assert_that(status["turn"]).is_equal(0)
	assert_that(status["active_crew"]).is_equal(3)
	assert_that(status["active_enemies"]).is_equal(2)
	assert_that(status["total_casualties"]).is_equal(0)
	assert_that(status["total_injuries"]).is_equal(0)

func test_battlefield_status_after_casualties() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Cause some casualties
	var unit_ids = battle_state.unit_status.keys()
	battle_state.update_unit_health(unit_ids[0], 0, "test") # Kill crew member
	battle_state.update_unit_health(unit_ids[3], 0, "test") # Kill enemy
	
	var status = battle_state.get_battlefield_status()
	
	assert_that(status["active_crew"]).is_equal(2) # 3 - 1 killed
	assert_that(status["active_enemies"]).is_equal(1) # 2 - 1 killed
	assert_that(status["total_casualties"]).is_equal(2)

## BATTLE COMPLETION TESTS

func test_battle_completion() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var test_loot: Array[Resource] = [Resource.new()]
	battle_state.complete_battle("victory", 500, test_loot)
	
	assert_that(battle_state.is_complete).is_true()
	assert_that(battle_state.battle_outcome).is_equal("victory")
	assert_that(battle_state.credits_earned).is_equal(500)
	assert_that(battle_state.loot_found.size()).is_equal(1)
	assert_that(battle_state.battle_end_time).is_greater(battle_state.battle_start_time)

## VALIDATION TESTS

func test_state_validation_success() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var is_valid: bool = battle_state.validate_state()
	assert_that(is_valid).is_true()
	assert_that(battle_state.get_validation_errors().size()).is_equal(0)

func test_state_validation_failures() -> void:
	# Create invalid state
	battle_state.crew_members.clear()
	battle_state.enemy_forces.clear()
	battle_state.mission_data = null
	
	var is_valid: bool = battle_state.validate_state()
	assert_that(is_valid).is_false()
	
	var errors = battle_state.get_validation_errors()
	assert_that(errors.size()).is_greater(0)
	assert_that(errors.any(func(e): return e.contains("mission data"))).is_true()
	assert_that(errors.any(func(e): return e.contains("crew members"))).is_true()
	assert_that(errors.any(func(e): return e.contains("enemy forces"))).is_true()

func test_tracking_consistency_validation() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Create inconsistent state
	battle_state.unit_positions["orphan_position"] = Vector2i(5, 5) # Position without status
	battle_state.unit_status.erase(battle_state.unit_status.keys()[0]) # Status without position
	
	var is_valid: bool = battle_state.validate_state()
	assert_that(is_valid).is_false()
	
	var errors = battle_state.get_validation_errors()
	assert_that(errors.any(func(e): return e.contains("Position without status"))).is_true()
	assert_that(errors.any(func(e): return e.contains("Status without position"))).is_true()

## SAVE/LOAD TESTS

func test_save_data_export() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Set up some state
	battle_state.advance_round()
	battle_state.complete_battle("victory", 300)
	
	var save_data: Dictionary = battle_state.export_save_data()
	
	assert_that(save_data.has("battle_id")).is_true()
	assert_that(save_data["current_round"]).is_equal(1)
	assert_that(save_data["battle_outcome"]).is_equal("victory")
	assert_that(save_data["credits_earned"]).is_equal(300)
	assert_that(save_data["is_complete"]).is_true()

func test_save_data_import() -> void:
	var save_data: Dictionary = {
		"battle_id": "test_battle_123",
		"current_round": 5,
		"current_turn": 3,
		"battle_outcome": "defeat",
		"credits_earned": 150,
		"is_complete": true,
		"unit_positions": {"test_unit": Vector2i(2, 3)},
		"unit_status": {"test_unit": {"health": 2, "is_active": false}},
		"casualties": [{"unit_id": "test_unit", "source": "test"}],
		"triggered_events": ["event1", "event2"]
	}
	
	var success: bool = battle_state.import_save_data(save_data)
	assert_that(success).is_true()
	
	assert_that(battle_state.battle_id).is_equal("test_battle_123")
	assert_that(battle_state.current_round).is_equal(5)
	assert_that(battle_state.current_turn).is_equal(3)
	assert_that(battle_state.battle_outcome).is_equal("defeat")
	assert_that(battle_state.credits_earned).is_equal(150)
	assert_that(battle_state.is_complete).is_true()

func test_save_data_roundtrip() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Set up complex state
	battle_state.advance_round()
	battle_state.advance_turn()
	var unit_ids = battle_state.unit_positions.keys()
	battle_state.update_unit_position(unit_ids[0], Vector2i(5, 5))
	battle_state.update_unit_health(unit_ids[1], 1, "test_damage")
	battle_state.add_battle_event("test_event")
	battle_state.complete_battle("victory", 400)
	
	# Export and import
	var save_data = battle_state.export_save_data()
	var new_battle_state = FPCM_BattleState.new()
	track_node(new_battle_state)
	
	var success: bool = new_battle_state.import_save_data(save_data)
	assert_that(success).is_true()
	
	# Verify all data preserved
	assert_that(new_battle_state.current_round).is_equal(battle_state.current_round)
	assert_that(new_battle_state.current_turn).is_equal(battle_state.current_turn)
	assert_that(new_battle_state.battle_outcome).is_equal(battle_state.battle_outcome)
	assert_that(new_battle_state.credits_earned).is_equal(battle_state.credits_earned)
	assert_that(new_battle_state.triggered_events.size()).is_equal(1)
	assert_that(new_battle_state.injuries.size()).is_equal(1)

## PERFORMANCE TESTS

func test_performance_large_battlefield() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	battle_state.battlefield_size = Vector2i(100, 100)
	
	var start_time: float = Time.get_ticks_msec()
	
	# Perform many position updates
	var unit_ids = battle_state.unit_positions.keys()
	for i in range(1000):
		var unit_id = unit_ids[i % unit_ids.size()]
		var pos = Vector2i(i % 100, (i / 100) % 100)
		battle_state.update_unit_position(unit_id, pos)
	
	var elapsed: float = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(1000.0) # Should complete in less than 1 second

func test_performance_validation() -> void:
	battle_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
	
	var start_time: float = Time.get_ticks_msec()
	
	# Perform many validations
	for i in range(100):
		battle_state.validate_state()
	
	var elapsed: float = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(500.0) # Should complete in less than 0.5 seconds

func test_memory_efficiency() -> void:
	var initial_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy many battle states
	for i in range(50):
		var temp_state = FPCM_BattleState.new()
		temp_state.initialize_with_mission(test_mission_data, test_crew_members, test_enemy_forces)
		temp_state.create_checkpoint()
		temp_state.complete_battle("victory", 100)
		temp_state = null
	
	# Force garbage collection
	await get_tree().process_frame
	
	var final_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_increase = final_memory - initial_memory
	
	# Should not leak significant memory
	assert_that(memory_increase).is_less(200)

## HELPER METHODS

func _create_test_data() -> void:
	# Create test mission data
	test_mission_data = Resource.new()
	test_mission_data.set_meta("mission_type", "patrol")
	test_mission_data.set_meta("difficulty", 2)
	test_mission_data.set_meta("victory_conditions", {"eliminate_enemies": true})
	
	# Create test crew members
	test_crew_members.clear()
	for i in range(3):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew Member " + str(i))
		crew_member.set_meta("health", 3)
		crew_member.set_meta("max_health", 3)
		crew_member.set_meta("equipment", [])
		test_crew_members.append(crew_member)
	
	# Create test enemy forces
	test_enemy_forces.clear()
	for i in range(2):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		enemy.set_meta("health", 2)
		enemy.set_meta("max_health", 2)
		enemy.set_meta("equipment", [])
		test_enemy_forces.append(enemy)