@tool
extends "res://tests/fixtures/game_test.gd"

## Performance tests for mission systems
##
## Tests performance characteristics of:
## - Mission generation and template system
## - Mission state and objective tracking
## - Mission rewards calculation
## - Mission serialization and persistence

const Mission = preload("res://src/core/systems/Mission.gd")
const MissionGenerator = preload("res://src/core/systems/MissionGenerator.gd")
const MissionTemplate = preload("res://src/core/templates/MissionTemplate.gd")

# Performance thresholds (in milliseconds)
const GENERATION_THRESHOLD := 50
const STATE_UPDATE_THRESHOLD := 10
const SERIALIZATION_THRESHOLD := 20
const BATCH_SIZE := 100

var _mission_generator: MissionGenerator
var _template: Resource

# Helper methods
func _get_template() -> MissionTemplate:
	return _template as Object

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	_mission_generator = MissionGenerator.new()
	add_child(_mission_generator)
	track_test_node(_mission_generator)
	
	_template = MissionTemplate.new()
	var mission_template := _template as Object
	if mission_template.has_method("set_mission_type"):
		mission_template.set_mission_type(GameEnums.MissionType.PATROL)
		mission_template.set_difficulty_range(1, 3)
		mission_template.set_reward_range(100, 300)
	track_test_resource(_template)

func after_each() -> void:
	await super.after_each()
	_mission_generator = null
	_template = null

# Generation Performance Tests
func test_batch_mission_generation() -> void:
	var total_time := 0
	var missions: Array[Mission] = []
	var template := _get_template()
	
	for i in range(BATCH_SIZE):
		var start_time := Time.get_ticks_msec()
		var mission = _mission_generator.generate_mission(template)
		track_test_resource(mission)
		missions.append(mission)
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, GENERATION_THRESHOLD,
		"Average mission generation time should be under %d ms" % GENERATION_THRESHOLD)

# State Update Performance Tests
func test_objective_update_performance() -> void:
	var template := _get_template()
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	# Add many objectives
	for i in range(BATCH_SIZE):
		mission.objectives.append({
			"type": GameEnums.MissionObjective.PATROL,
			"description": "Test objective %d" % i,
			"completed": false,
			"is_primary": false
		})
	
	var total_time := 0
	for i in range(BATCH_SIZE):
		var start_time := Time.get_ticks_msec()
		mission.complete_objective(i)
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, STATE_UPDATE_THRESHOLD,
		"Average objective update time should be under %d ms" % STATE_UPDATE_THRESHOLD)

# Serialization Performance Tests
func test_mission_serialization_performance() -> void:
	var template := _get_template()
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	# Add many objectives and rewards
	for i in range(BATCH_SIZE):
		mission.objectives.append({
			"type": GameEnums.MissionObjective.PATROL,
			"description": "Test objective %d" % i,
			"completed": false,
			"is_primary": false
		})
	
	var total_time := 0
	for i in range(BATCH_SIZE):
		var start_time := Time.get_ticks_msec()
		var _save_data = mission.serialize()
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, SERIALIZATION_THRESHOLD,
		"Average serialization time should be under %d ms" % SERIALIZATION_THRESHOLD)

# Memory Usage Tests
func test_mission_memory_usage() -> void:
	var template := _get_template()
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var missions: Array[Mission] = []
	
	for i in range(BATCH_SIZE):
		var mission = _mission_generator.generate_mission(template)
		track_test_resource(mission)
		missions.append(mission)
	
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_per_mission: float = (final_memory - initial_memory) / float(BATCH_SIZE)
	
	print("Memory usage per mission: %.2f KB" % (memory_per_mission / 1024.0))
	assert_lt(memory_per_mission, 1024 * 10, # 10 KB per mission
		"Memory usage per mission should be reasonable")

# Stress Tests
func test_concurrent_mission_operations() -> void:
	var template := _get_template()
	var mission = _mission_generator.generate_mission(template)
	track_test_resource(mission)
	
	var start_time := Time.get_ticks_msec()
	for i in range(BATCH_SIZE):
		# Simulate multiple operations happening in the same frame
		mission.update_progress(float(i) / BATCH_SIZE * 100.0)
		mission.calculate_rewards()
		if i % 2 == 0:
			mission.complete_objective(0)
		mission.serialize()
	
	var total_time := Time.get_ticks_msec() - start_time
	assert_lt(total_time, BATCH_SIZE * STATE_UPDATE_THRESHOLD,
		"Should handle concurrent operations efficiently")