@tool
extends GutTest

## Performance tests for mission systems
##
## Tests performance characteristics of:
## - Mission generation and template system
## - Mission state and objective tracking
## - Mission rewards calculation
## - Mission serialization and persistence

const MissionScript: GDScript = preload("res://src/core/systems/Mission.gd")
const MissionGeneratorScript: GDScript = preload("res://src/core/systems/MissionGenerator.gd")
const MissionTemplateScript: GDScript = preload("res://src/core/templates/MissionTemplate.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")

# Performance thresholds (in milliseconds)
const GENERATION_THRESHOLD: int = 50
const STATE_UPDATE_THRESHOLD: int = 10
const SERIALIZATION_THRESHOLD: int = 20
const BATCH_SIZE: int = 100

# Test variables with explicit types
var _mission_generator: Node = null
var _template: Resource = null

# Helper methods
func _get_template() -> Resource:
	return _template

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	_mission_generator = TypeSafeMixin._safe_cast_to_node(MissionGeneratorScript.new(), "MissionGenerator")
	if not _mission_generator:
		push_error("Failed to create mission generator")
		return
	
	add_child(_mission_generator)
	
	_template = TypeSafeMixin._safe_cast_to_resource(MissionTemplateScript.new(), "MissionTemplate")
	if not _template:
		push_error("Failed to create mission template")
		return
		
	var template: Resource = _get_template()
	TypeSafeMixin._safe_method_call_bool(template, "set_mission_type", [GameEnums.MissionType.PATROL])
	TypeSafeMixin._safe_method_call_bool(template, "set_difficulty_range", [1, 3])
	TypeSafeMixin._safe_method_call_bool(template, "set_reward_range", [100, 300])

func after_each() -> void:
	await super.after_each()
	
	if is_instance_valid(_mission_generator):
		remove_child(_mission_generator)
		_mission_generator.queue_free()
	
	_mission_generator = null
	_template = null

# Generation Performance Tests
func test_batch_mission_generation() -> void:
	var total_time: int = 0
	var missions: Array[Resource] = []
	var template: Resource = _get_template()
	
	for i in range(BATCH_SIZE):
		var start_time: int = Time.get_ticks_msec()
		var mission: Resource = TypeSafeMixin._safe_method_call_resource(_mission_generator, "generate_mission", [template])
		if not mission:
			push_error("Failed to generate mission %d" % i)
			continue
			
		missions.append(mission)
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, GENERATION_THRESHOLD,
		"Average mission generation time should be under %d ms" % GENERATION_THRESHOLD)

# State Update Performance Tests
func test_objective_update_performance() -> void:
	var template: Resource = _get_template()
	var mission: Resource = TypeSafeMixin._safe_method_call_resource(_mission_generator, "generate_mission", [template])
	if not mission:
		push_error("Failed to generate mission")
		return
		
	# Add many objectives
	var objectives: Array = []
	for i in range(BATCH_SIZE):
		objectives.append({
			"type": GameEnums.MissionObjective.PATROL,
			"description": "Test objective %d" % i,
			"completed": false,
			"is_primary": false
		})
	
	TypeSafeMixin._safe_method_call_bool(mission, "set", ["objectives", objectives])
	
	var total_time: int = 0
	for i in range(BATCH_SIZE):
		var start_time: int = Time.get_ticks_msec()
		TypeSafeMixin._safe_method_call_bool(mission, "complete_objective", [i])
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, STATE_UPDATE_THRESHOLD,
		"Average objective update time should be under %d ms" % STATE_UPDATE_THRESHOLD)

# Serialization Performance Tests
func test_mission_serialization_performance() -> void:
	var template: Resource = _get_template()
	var mission: Resource = TypeSafeMixin._safe_method_call_resource(_mission_generator, "generate_mission", [template])
	if not mission:
		push_error("Failed to generate mission")
		return
		
	# Add many objectives and rewards
	var objectives: Array = []
	for i in range(BATCH_SIZE):
		objectives.append({
			"type": GameEnums.MissionObjective.PATROL,
			"description": "Test objective %d" % i,
			"completed": false,
			"is_primary": false
		})
	
	TypeSafeMixin._safe_method_call_bool(mission, "set", ["objectives", objectives])
	
	var total_time: int = 0
	for i in range(BATCH_SIZE):
		var start_time: int = Time.get_ticks_msec()
		var _save_data: Dictionary = TypeSafeMixin._safe_method_call_dict(mission, "serialize")
		total_time += Time.get_ticks_msec() - start_time
	
	var average_time: float = total_time / float(BATCH_SIZE)
	assert_lt(average_time, SERIALIZATION_THRESHOLD,
		"Average serialization time should be under %d ms" % SERIALIZATION_THRESHOLD)

# Memory Usage Tests
func test_mission_memory_usage() -> void:
	var template: Resource = _get_template()
	var initial_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var missions: Array[Resource] = []
	
	for i in range(BATCH_SIZE):
		var mission: Resource = TypeSafeMixin._safe_method_call_resource(_mission_generator, "generate_mission", [template])
		if not mission:
			push_error("Failed to generate mission %d" % i)
			continue
			
		missions.append(mission)
	
	var final_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_per_mission: float = (final_memory - initial_memory) / float(BATCH_SIZE)
	
	print("Memory usage per mission: %.2f KB" % (memory_per_mission / 1024.0))
	assert_lt(memory_per_mission, 1024 * 10, # 10 KB per mission
		"Memory usage per mission should be reasonable")

# Stress Tests
func test_concurrent_mission_operations() -> void:
	var template: Resource = _get_template()
	var mission: Resource = TypeSafeMixin._safe_method_call_resource(_mission_generator, "generate_mission", [template])
	if not mission:
		push_error("Failed to generate mission")
		return
		
	var start_time: int = Time.get_ticks_msec()
	for i in range(BATCH_SIZE):
		# Simulate multiple operations happening in the same frame
		TypeSafeMixin._safe_method_call_bool(mission, "update_progress", [float(i) / BATCH_SIZE * 100.0])
		TypeSafeMixin._safe_method_call_bool(mission, "calculate_rewards")
		if i % 2 == 0:
			TypeSafeMixin._safe_method_call_bool(mission, "complete_objective", [0])
		TypeSafeMixin._safe_method_call_bool(mission, "serialize")
	
	var total_time: int = Time.get_ticks_msec() - start_time
	assert_lt(total_time, BATCH_SIZE * STATE_UPDATE_THRESHOLD,
		"Should handle concurrent operations efficiently")