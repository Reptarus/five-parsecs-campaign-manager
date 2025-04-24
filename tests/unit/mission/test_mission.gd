## Mission System Test Suite
## Tests the functionality of the mission system including generation, rewards, difficulty, 
## completion mechanics, and mission types.
##
## Covers:
## - Mission generation
## - Mission state transitions
## - Reward calculations
## - Difficulty adjustments
## - Mission types and special rules
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
var MissionScript = load("res://src/core/mission/base/Mission.gd") if ResourceLoader.exists("res://src/core/mission/base/Mission.gd") else load("res://src/core/mission/Mission.gd") if ResourceLoader.exists("res://src/core/mission/Mission.gd") else null
var MissionRewardScript = load("res://src/core/mission/base/MissionReward.gd") if ResourceLoader.exists("res://src/core/mission/base/MissionReward.gd") else load("res://src/core/mission/rewards/MissionReward.gd") if ResourceLoader.exists("res://src/core/mission/rewards/MissionReward.gd") else null
var MissionGeneratorScript = load("res://src/core/mission/generator/MissionGenerator.gd") if ResourceLoader.exists("res://src/core/mission/generator/MissionGenerator.gd") else load("res://src/core/mission/MissionGenerator.gd") if ResourceLoader.exists("res://src/core/mission/MissionGenerator.gd") else null
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Enums for tests
enum MissionType {BATTLE = 0, RECON = 1, SALVAGE = 2}
enum MissionState {AVAILABLE = 0, IN_PROGRESS = 1, COMPLETED = 2, FAILED = 3, EXPIRED = 4}

# Type-safe constants
const TEST_MISSION_NAME = "Test Mission"
const TEST_MISSION_DESC = "This is a test mission description"
const DEFAULT_DIFFICULTY = 3
const DEFAULT_REWARD_CREDITS = 1000

# Type-safe instance variables
var _mission: Resource = null
var _generator: Node = null
var _reward: Resource = null

# Helper methods
func _create_test_mission(difficulty: int = DEFAULT_DIFFICULTY) -> Resource:
	if not MissionScript:
		push_error("Mission script is null")
		return null
		
	var mission: Resource = MissionScript.new()
	if not mission:
		push_error("Failed to create mission")
		return null
	
	# Ensure resource has a valid path for Godot 4.4
	mission = Compatibility.ensure_resource_path(mission, "test_mission")
	
	# Set mission properties safely
	Compatibility.safe_call_method(mission, "set_name", [TEST_MISSION_NAME])
	Compatibility.safe_call_method(mission, "set_description", [TEST_MISSION_DESC])
	Compatibility.safe_call_method(mission, "set_difficulty", [difficulty])
	Compatibility.safe_call_method(mission, "set_mission_type", [MissionType.BATTLE])
	Compatibility.safe_call_method(mission, "set_completed", [false])
	
	# Create reward
	var reward = _create_test_reward()
	if reward:
		Compatibility.safe_call_method(mission, "set_reward", [reward])
	
	return mission

func _create_test_reward(credits: int = DEFAULT_REWARD_CREDITS) -> Resource:
	if not MissionRewardScript:
		push_error("MissionReward script is null")
		return null
		
	var reward: Resource = MissionRewardScript.new()
	if not reward:
		push_error("Failed to create reward")
		return null
	
	# Ensure resource has a valid path for Godot 4.4
	reward = Compatibility.ensure_resource_path(reward, "test_reward")
	
	# Set reward properties safely
	Compatibility.safe_call_method(reward, "set_credits", [credits])
	
	return reward

func _create_mission_generator() -> Node:
	if not MissionGeneratorScript:
		push_error("MissionGenerator script is null")
		return null
		
	var generator: Node = MissionGeneratorScript.new()
	if not generator:
		push_error("Failed to create mission generator")
		return null
	
	add_child_autofree(generator)
	track_test_node(generator)
	
	return generator

# Helper assertion methods
func assert_not_eq(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a != b, text)
	else:
		assert_true(a != b, "Expected %s != %s" % [a, b])

# Setup and teardown
func before_each() -> void:
	await super.before_each()
	
	# Create generator
	_generator = _create_mission_generator()
	
	# Create mission
	_mission = _create_test_mission()
	
	# Create reward
	_reward = _create_test_reward()
	
	watch_signals(_mission)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_mission = null
	_generator = null
	_reward = null
	await super.after_each()

# Basic functionality tests
func test_mission_properties() -> void:
	assert_not_null(_mission, "Mission should be created")
	
	var name: String = Compatibility.safe_call_method(_mission, "get_name", [], "")
	var description: String = Compatibility.safe_call_method(_mission, "get_description", [], "")
	var difficulty: int = Compatibility.safe_call_method(_mission, "get_difficulty", [], 0)
	var completed: bool = Compatibility.safe_call_method(_mission, "is_completed", [], false)
	
	assert_eq(name, TEST_MISSION_NAME, "Mission name should match")
	assert_eq(description, TEST_MISSION_DESC, "Mission description should match")
	assert_eq(difficulty, DEFAULT_DIFFICULTY, "Mission difficulty should match")
	assert_false(completed, "Mission should not be completed initially")

func test_mission_completion() -> void:
	var completed_before: bool = Compatibility.safe_call_method(_mission, "is_completed", [], false)
	assert_false(completed_before, "Mission should start incomplete")
	
	watch_signals(_mission)
	var result: bool = Compatibility.safe_call_method(_mission, "complete", [], false)
	assert_true(result, "Should complete mission successfully")
	
	var completed_after: bool = Compatibility.safe_call_method(_mission, "is_completed", [], false)
	assert_true(completed_after, "Mission should be completed after calling complete()")
	
	verify_signal_emitted(_mission, "mission_completed")

# Reward tests
func test_mission_reward() -> void:
	var reward = Compatibility.safe_call_method(_mission, "get_reward", [], null)
	assert_not_null(reward, "Mission should have a reward")
	
	var credits: int = Compatibility.safe_call_method(reward, "get_credits", [], 0)
	assert_eq(credits, DEFAULT_REWARD_CREDITS, "Reward credits should match")

func test_reward_scaling() -> void:
	var high_difficulty = 7
	var high_diff_mission = _create_test_mission(high_difficulty)
	if not high_diff_mission:
		push_error("Failed to create high difficulty mission")
		return
		
	var reward = Compatibility.safe_call_method(high_diff_mission, "get_reward", [], null)
	assert_not_null(reward, "High difficulty mission should have a reward")
	
	# Apply difficulty reward scaling if applicable - use type-safe check
	if Compatibility.safe_call_method(high_diff_mission, "has_method", ["apply_difficulty_scaling_to_reward"], false):
		Compatibility.safe_call_method(high_diff_mission, "apply_difficulty_scaling_to_reward", [])
		
		var scaled_credits: int = Compatibility.safe_call_method(reward, "get_credits", [], 0)
		assert_true(scaled_credits > DEFAULT_REWARD_CREDITS, "Higher difficulty should give higher rewards")
	else:
		# Alternative approach without scaling method
		var base_credits: int = Compatibility.safe_call_method(reward, "get_credits", [], 0)
		assert_eq(base_credits, DEFAULT_REWARD_CREDITS, "Base reward should match default")

# Generator tests
func test_mission_generation() -> void:
	if not _generator:
		push_error("Generator not created")
		return
		
	var generated_mission = Compatibility.safe_call_method(_generator, "generate_mission", [], null)
	assert_not_null(generated_mission, "Should generate a mission")
	
	# Add null check before accessing properties
	if not generated_mission:
		return
		
	var name: String = Compatibility.safe_call_method(generated_mission, "get_name", [], "")
	var description: String = Compatibility.safe_call_method(generated_mission, "get_description", [], "")
	
	assert_not_eq(name, "", "Generated mission should have a name")
	assert_not_eq(description, "", "Generated mission should have a description")
	
	var reward = Compatibility.safe_call_method(generated_mission, "get_reward", [], null)
	assert_not_null(reward, "Generated mission should have a reward")

func test_mission_type_generation() -> void:
	if not _generator:
		push_error("Generator not created")
		return
		
	# Test multiple types of missions
	var mission_types = [
		MissionType.BATTLE,
		MissionType.RECON,
		MissionType.SALVAGE
	]
	
	for mission_type in mission_types:
		var generated_mission = Compatibility.safe_call_method(_generator, "generate_mission_of_type", [mission_type], null)
		assert_not_null(generated_mission, "Should generate a mission of type %d" % mission_type)
		
		var type: int = Compatibility.safe_call_method(generated_mission, "get_mission_type", [], -1)
		assert_eq(type, mission_type, "Generated mission should have the requested type")

# Mission progression tests
func test_mission_state_transitions() -> void:
	var valid_transitions = {
		MissionState.AVAILABLE: [MissionState.IN_PROGRESS, MissionState.EXPIRED],
		MissionState.IN_PROGRESS: [MissionState.COMPLETED, MissionState.FAILED],
		MissionState.COMPLETED: [],
		MissionState.FAILED: [],
		MissionState.EXPIRED: []
	}
	
	# Test initial state
	var initial_state: int = Compatibility.safe_call_method(_mission, "get_state", [], -1)
	assert_eq(initial_state, MissionState.AVAILABLE, "Mission should start in AVAILABLE state")
	
	# Test transitions
	for from_state in valid_transitions.keys():
		# Set initial state
		Compatibility.safe_call_method(_mission, "set_state", [from_state])
		
		# Try all possible transitions
		for to_state in MissionState.values():
			if not Compatibility.safe_dict_get(valid_transitions, from_state, []).has(to_state):
				continue
				
			var result: bool = Compatibility.safe_call_method(_mission, "transition_to", [to_state], false)
			assert_true(result, "Should transition from %d to %d" % [from_state, to_state])
			
			var new_state: int = Compatibility.safe_call_method(_mission, "get_state", [], -1)
			assert_eq(new_state, to_state, "State should be updated after transition")

# Performance test
func test_generator_performance() -> void:
	if not _generator:
		push_error("Generator not created")
		return
		
	var start_time := Time.get_ticks_msec()
	var mission_count = 50
	
	for i in range(mission_count):
		var mission = Compatibility.safe_call_method(_generator, "generate_mission", [], null)
		assert_not_null(mission, "Should generate mission %d" % i)
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	# 500ms is a reasonable threshold for generating 50 missions
	assert_true(duration < 500, "Mission generation should be performant")
