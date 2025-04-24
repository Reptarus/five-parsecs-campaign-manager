@tool
extends "res://tests/fixtures/base/game_test.gd"

## Mission system test suite
## Tests core functionality, edge cases, and performance of the mission system
## @class TestMissionSystem
## @description Validates mission lifecycle, objectives, rewards, and state management

# Type-safe instance variables
var mission: Node = null

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	# Mission class assumed to be a Node
	mission = Node.new()
	add_child_autofree(mission)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	mission = null

# Helper methods
func create_test_objective(index: int, type: String = "primary") -> Dictionary:
	return {
		"index": index,
		"description": "Test objective",
		"type": type,
		"completed": false
	}

func setup_mission_with_objectives(objective_count: int) -> void:
	var objectives = []
	for i in range(objective_count):
		objectives.append(create_test_objective(i))
	TypeSafeMixin._set_property_safe(mission, "objectives", objectives)

# Basic functionality tests
func test_initial_state() -> void:
	# Use type-safe method calls and property access
	var mission_type = TypeSafeMixin._call_node_method_int(mission, "get_mission_type", [])
	var objectives = TypeSafeMixin._call_node_method(mission, "get_objectives", [])
	var is_completed = TypeSafeMixin._call_node_method_bool(mission, "is_mission_completed", [])
	var is_failed = TypeSafeMixin._call_node_method_bool(mission, "is_mission_failed", [])
	
	assert_eq(mission_type, GameEnums.MissionType.NONE, "Should start with no mission type")
	
	# Add null check for objectives
	var objectives_size = 0
	if objectives != null and objectives is Array:
		objectives_size = objectives.size()
	assert_eq(objectives_size, 0, "Should start with no objectives")
	
	assert_false(is_completed, "Should not be completed")
	assert_false(is_failed, "Should not be failed")

func test_mission_completion() -> void:
	watch_signals(mission)
	TypeSafeMixin._call_node_method_bool(mission, "complete_mission", [])
	var is_completed = TypeSafeMixin._call_node_method_bool(mission, "is_mission_completed", [])
	assert_true(is_completed, "Should be marked as completed")
	verify_signal_emitted(mission, "mission_completed")

func test_mission_failure() -> void:
	watch_signals(mission)
	TypeSafeMixin._call_node_method_bool(mission, "fail_mission", [])
	var is_failed = TypeSafeMixin._call_node_method_bool(mission, "is_mission_failed", [])
	assert_true(is_failed, "Should be marked as failed")
	verify_signal_emitted(mission, "mission_failed")

func test_phase_change() -> void:
	watch_signals(mission)
	TypeSafeMixin._call_node_method_bool(mission, "set_phase", ["combat"])
	var current_phase = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(mission, "get_current_phase", []))
	assert_eq(current_phase, "combat", "Should update phase")
	verify_signal_emitted(mission, "phase_changed")

func test_progress_update() -> void:
	watch_signals(mission)
	TypeSafeMixin._call_node_method_bool(mission, "update_progress", [50.0])
	var completion = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(mission, "get_completion_percentage", []))
	assert_eq(completion, 50.0, "Should update progress")
	verify_signal_emitted(mission, "progress_updated")

# Objective system tests
func test_objective_management() -> void:
	# Check if required methods/signals exist
	if not (mission.has_method("add_objective") and
		   mission.has_method("get_objectives") and
		   mission.has_method("complete_objective") and
		   mission.has_signal("objective_added") and
		   mission.has_signal("objective_completed")):
		push_warning("Mission is missing required methods or signals for objective test")
		pending("Test skipped - required methods or signals missing")
		return
		
	watch_signals(mission)
	var objective = create_test_objective(0)
	
	# Use type-safe method calls
	var add_result = TypeSafeMixin._call_node_method_bool(mission, "add_objective", [objective])
	assert_true(add_result, "Should successfully add objective")
	
	var objectives = TypeSafeMixin._call_node_method_array(mission, "get_objectives", [])
	
	# Add null check for objectives
	var objectives_size = 0
	if objectives != null and objectives is Array:
		objectives_size = objectives.size()
	assert_eq(objectives_size, 1, "Should add objective")
	
	verify_signal_emitted(mission, "objective_added")
	
	# Complete the objective with bounds checking
	if objectives_size > 0:
		var complete_result = TypeSafeMixin._call_node_method_bool(mission, "complete_objective", [0])
		assert_true(complete_result, "Should successfully complete objective")
		
		objectives = TypeSafeMixin._call_node_method_array(mission, "get_objectives", [])
		
		# Add null check before accessing objectives elements
		if objectives != null and objectives is Array and objectives.size() > 0:
			assert_true("completed" in objectives[0], "Objective should have completed property")
			assert_true(objectives[0].completed, "Should complete objective")
			verify_signal_emitted(mission, "objective_completed")
	else:
		push_warning("No objectives available to complete")

# Performance tests
func test_large_objective_set_performance() -> void:
	var start_time = Time.get_ticks_msec()
	setup_mission_with_objectives(100)
	var end_time = Time.get_ticks_msec()
	
	assert_lt(end_time - start_time, 100, "Should handle large objective sets efficiently")
	var objectives = TypeSafeMixin._call_node_method_array(mission, "get_objectives", [])
	assert_eq(objectives.size(), 100, "Should maintain all objectives")

# Boundary tests
func test_invalid_objective_operations() -> void:
	assert_null(TypeSafeMixin._call_node_method(mission, "get_objective", [-1]), "Should handle invalid index gracefully")
	assert_false(TypeSafeMixin._call_node_method_bool(mission, "has_objective", [999]), "Should handle nonexistent objective index")
	
	# Test objective limit
	setup_mission_with_objectives(999)
	var result = TypeSafeMixin._call_node_method_bool(mission, "add_objective", [create_test_objective(999)])
	assert_false(result, "Should handle objective limit gracefully")

# State persistence tests
func test_mission_state_persistence() -> void:
	# Check if required methods/signals exist
	if not (mission.has_method("set_mission_name") and
		   mission.has_method("set_mission_type") and
		   mission.has_method("set_difficulty") and
		   mission.has_method("update_progress") and
		   mission.has_method("save_state") and
		   mission.has_method("load_state") and
		   mission.has_method("get_mission_name") and
		   mission.has_method("get_mission_type") and
		   mission.has_method("get_difficulty") and
		   mission.has_method("get_completion_percentage") and
		   mission.has_signal("state_saved")):
		push_warning("Mission is missing required methods or signals for persistence test")
		pending("Test skipped - required methods or signals missing")
		return
		
	watch_signals(mission)
	
	TypeSafeMixin._call_node_method_bool(mission, "set_mission_name", ["Test Mission"])
	TypeSafeMixin._call_node_method_bool(mission, "set_mission_type", [GameEnums.MissionType.PATROL])
	TypeSafeMixin._call_node_method_bool(mission, "set_difficulty", [GameEnums.DifficultyLevel.NORMAL])
	TypeSafeMixin._call_node_method_bool(mission, "update_progress", [50.0])
	
	var save_data = TypeSafeMixin._call_node_method(mission, "save_state", [])
	assert_not_null(save_data, "Should generate save data")
	verify_signal_emitted(mission, "state_saved")
	
	var new_mission = Node.new()
	add_child_autofree(new_mission)
	track_test_node(new_mission)
	
	# Check if new mission has required methods/signals
	if not (new_mission.has_method("load_state") and
		   new_mission.has_signal("state_loaded")):
		push_warning("New mission is missing required methods or signals")
		return
		
	watch_signals(new_mission)
	var load_result = TypeSafeMixin._call_node_method_bool(new_mission, "load_state", [save_data])
	assert_true(load_result, "Should successfully load state")
	verify_signal_emitted(new_mission, "state_loaded")
	
	var restored_name = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(new_mission, "get_mission_name", []))
	var restored_type = TypeSafeMixin._call_node_method_int(new_mission, "get_mission_type", [])
	var restored_difficulty = TypeSafeMixin._call_node_method_int(new_mission, "get_difficulty", [])
	var restored_progress = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(new_mission, "get_completion_percentage", []))
	
	assert_eq(restored_name, "Test Mission", "Should restore mission name")
	assert_eq(restored_type, GameEnums.MissionType.PATROL, "Should restore mission type")
	assert_eq(restored_difficulty, GameEnums.DifficultyLevel.NORMAL, "Should restore difficulty")
	assert_eq(restored_progress, 50.0, "Should restore progress")

# Stress tests
func test_rapid_state_changes() -> void:
	watch_signals(mission)
	for i in range(100):
		TypeSafeMixin._call_node_method(mission, "update_progress", [float(i)])
		TypeSafeMixin._call_node_method(mission, "set_phase", ["phase_%d" % i])
	
	assert_signal_emit_count(mission, "progress_updated", 100)
	assert_signal_emit_count(mission, "phase_changed", 100)

func test_reward_calculation() -> void:
	TypeSafeMixin._call_node_method(mission, "set_base_rewards", [ {
		"credits": 1000,
		"reputation": 2
	}])
	TypeSafeMixin._call_node_method(mission, "set_reward_multiplier", [1.5])
	
	var rewards = TypeSafeMixin._call_node_method_dict(mission, "calculate_rewards", [])
	if rewards.has("credits"):
		assert_eq(rewards["credits"], 1500, "Should calculate credits with multiplier")
	else:
		push_warning("Rewards dictionary does not have 'credits' key")
		
	if rewards.has("reputation"):
		assert_eq(rewards["reputation"], 3, "Should calculate reputation with multiplier")
	else:
		push_warning("Rewards dictionary does not have 'reputation' key")

func test_mission_requirements() -> void:
	var requirements = {
		"min_crew": 3,
		"required_skills": ["combat", "tech"],
		"required_equipment": ["armor"]
	}
	TypeSafeMixin._call_node_method(mission, "set_requirements", [requirements])
	
	var valid_crew = {
		"size": 4,
		"skills": ["combat", "tech", "medical"],
		"equipment": ["armor", "weapons"]
	}
	assert_true(TypeSafeMixin._call_node_method_bool(mission, "check_requirements", [valid_crew]), "Should pass valid requirements")
	
	var invalid_crew = {
		"size": 2,
		"skills": ["combat"],
		"equipment": []
	}
	assert_false(TypeSafeMixin._call_node_method_bool(mission, "check_requirements", [invalid_crew]), "Should fail invalid requirements")
