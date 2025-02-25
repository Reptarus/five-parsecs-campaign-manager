@tool
extends "res://tests/fixtures/base/game_test.gd"

## Unit tests for the MissionGenerator system
##
## Tests mission generation, validation, and customization functionality including:
## - Basic mission generation and validation
## - Integration with terrain and rival systems
## - Performance under stress conditions
## - Error handling and boundary conditions
## - State persistence and recovery
## - Signal emission verification

const MissionGenerator := preload("res://src/core/systems/MissionGenerator.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const MissionTemplate = preload("res://src/core/templates/MissionTemplate.gd")

# Test helper methods
const TEST_TIMEOUT := 1000
const STRESS_TEST_ITERATIONS := 100

var _mission_generator: MissionGenerator
var _terrain_system: TerrainSystem
var _rival_system: RivalSystem

func before_each() -> void:
	await super.before_each()
	_terrain_system = TerrainSystem.new()
	_rival_system = RivalSystem.new()
	_mission_generator = MissionGenerator.new()
	
	add_child(_terrain_system)
	add_child(_mission_generator)
	add_child(_rival_system)
	
	track_test_node(_terrain_system)
	track_test_node(_mission_generator)
	track_test_node(_rival_system)
	
	_mission_generator.set_terrain_system(_terrain_system)
	_mission_generator.set_rival_system(_rival_system)

func after_each() -> void:
	await super.after_each()
	_mission_generator = null
	_terrain_system = null
	_rival_system = null

#region Basic Generation Tests

func test_mission_generation() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(100, 300)
	template.set_title_templates(["Test Mission"])
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	assert_not_null(mission, "Mission should be generated")
	assert_eq(mission.get_mission_type(), GameEnums.MissionType.PATROL, "Mission type should match template")
	assert_true(mission.get_difficulty() >= 1 and mission.get_difficulty() <= 3, "Difficulty should be within range")
	assert_true(mission.get_rewards().credits >= 100 and mission.get_rewards().credits <= 300, "Rewards should be within range")

func test_invalid_template() -> void:
	var template = MissionTemplate.new()
	track_test_resource(template)
	var mission = _mission_generator.generate_mission(template)
	assert_null(mission, "Should not generate mission from invalid template")

#endregion

#region Performance Tests

func test_rapid_mission_generation() -> void:
	var template := create_basic_template()
	watch_signals(_mission_generator)
	
	for i in range(STRESS_TEST_ITERATIONS):
		var mission = _mission_generator.generate_mission(template)
		assert_not_null(mission, "Should generate mission in iteration %d" % i)
		track_test_resource(mission)
	
	assert_signal_emit_count(_mission_generator, "mission_generated", STRESS_TEST_ITERATIONS)

func test_concurrent_generation_performance() -> void:
	var template := create_basic_template()
	var start_time := Time.get_ticks_msec()
	
	# Generate multiple missions concurrently
	var missions = []
	for i in range(10):
		var mission = _mission_generator.generate_mission(template)
		missions.append(mission)
		track_test_resource(mission)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_lt(duration, TEST_TIMEOUT, "Mission generation should complete within timeout")
#endregion

#region State Persistence Tests

func test_mission_state_persistence() -> void:
	var template := create_basic_template()
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	# Save and reload mission state
	var saved_state = mission.serialize()
	var loaded_mission = _mission_generator.create_from_save(saved_state)
	track_test_resource(loaded_mission)
	
	assert_eq(loaded_mission.get_mission_type(), mission.get_mission_type())
	assert_eq(loaded_mission.get_difficulty(), mission.get_difficulty())
#endregion

#region Signal Verification Tests

func test_mission_generation_signals() -> void:
	var template := create_basic_template()
	watch_signals(_mission_generator)
	
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	assert_signal_emitted(_mission_generator, "generation_started")
	assert_signal_emitted(_mission_generator, "mission_generated")
	assert_signal_emitted(_mission_generator, "generation_completed")
#endregion

# Helper Methods
func create_basic_template() -> MissionTemplate:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(100, 300)
	template.set_title_templates(["Test Mission"])
	track_test_resource(template)
	return template

# Rival Integration Tests

func test_rival_involvement() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.RAID)
	template.set_difficulty_range(2, 4)
	template.set_reward_range(200, 400)
	template.set_title_templates(["Rival Test Mission"])
	track_test_resource(template)
	
	# Set up rival data
	_rival_system.add_rival({
		"id": "test_rival",
		"force_composition": ["grunt", "grunt", "elite"]
	})
	
	watch_signals(_mission_generator)
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	assert_not_null(mission.get_rival_involvement(), "Mission should have rival involvement")
	assert_eq(mission.get_rival_involvement().rival_id, "test_rival", "Rival ID should match")

# Terrain Integration Tests

func test_terrain_generation() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.DEFENSE)
	template.set_difficulty_range(2, 4)
	template.set_reward_range(200, 400)
	template.set_title_templates(["Terrain Test Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	assert_not_null(mission, "Mission should be generated")
	
	# Check if terrain features were generated
	var terrain_features = _terrain_system.get_terrain_features()
	assert_gt(terrain_features.size(), 0, "Should generate terrain features")

func test_objective_placement() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.SABOTAGE)
	template.set_difficulty_range(3, 5)
	template.set_reward_range(300, 500)
	template.set_title_templates(["Objective Test Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	assert_not_null(mission, "Mission should be generated")
	assert_gt(mission.get_objectives().size(), 0, "Should generate objectives")

# Error Condition Tests

func test_generation_with_invalid_difficulty() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(-1, 0) # Invalid range
	template.set_reward_range(100, 300)
	template.set_title_templates(["Invalid Difficulty Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	assert_null(mission, "Should not generate mission with invalid difficulty range")

func test_generation_with_invalid_rewards() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(-100, -50) # Invalid range
	template.set_title_templates(["Invalid Rewards Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	assert_null(mission, "Should not generate mission with invalid reward range")

func test_generation_with_missing_systems() -> void:
	var standalone_generator = MissionGenerator.new()
	add_child(standalone_generator)
	track_test_node(standalone_generator)
	
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(100, 300)
	template.set_title_templates(["Missing Systems Mission"])
	track_test_resource(template)
	
	var mission = standalone_generator.generate_mission(template)
	assert_null(mission, "Should not generate mission without required systems")

# Boundary Tests

func test_generation_at_difficulty_boundaries() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 1) # Minimum difficulty
	template.set_reward_range(100, 300)
	template.set_title_templates(["Boundary Test Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	assert_not_null(mission, "Should generate mission at minimum difficulty")
	assert_eq(mission.get_difficulty(), 1, "Should use minimum difficulty")
	
	template.set_difficulty_range(10, 10) # Maximum difficulty
	mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	assert_not_null(mission, "Should generate mission at maximum difficulty")
	assert_eq(mission.get_difficulty(), 10, "Should use maximum difficulty")

func test_generation_with_large_values() -> void:
	var template = MissionTemplate.new()
	template.set_mission_type(GameEnums.MissionType.PATROL)
	template.set_difficulty_range(1, 3)
	template.set_reward_range(1000000, 2000000) # Very large rewards
	template.set_title_templates(["Large Values Mission"])
	track_test_resource(template)
	
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	assert_not_null(mission, "Should generate mission with large reward values")
	assert_true(mission.get_rewards().credits >= 1000000, "Should handle large reward values")