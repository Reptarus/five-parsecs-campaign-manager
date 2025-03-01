@tool
extends GameTest

## Edge case tests for mission system
##
## Tests boundary conditions and error handling:
## - Resource exhaustion scenarios
## - Invalid state transitions
## - Corrupted save data handling
## - Extreme value testing
## - Error recovery mechanisms

# Type-safe script references with correct paths
const MissionTemplate: GDScript = preload("res://src/core/templates/MissionTemplate.gd")

# Type-safe instance variables
var _template: Resource
var _mission: Node

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	_template = MissionTemplate.new()
	# Set template properties using type-safe method calls
	TypeSafeMixin._set_property_safe(_template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(_template, "title_templates", ["Test Mission"])
	TypeSafeMixin._set_property_safe(_template, "description_templates", ["Test Description"])
	TypeSafeMixin._set_property_safe(_template, "objective", GameEnums.MissionObjective.PATROL)
	TypeSafeMixin._set_property_safe(_template, "objective_description", "Test Objective Description")
	TypeSafeMixin._set_property_safe(_template, "reward_range", Vector2(100, 500))
	TypeSafeMixin._set_property_safe(_template, "difficulty_range", Vector2(1, 3))
	
	# Create mission object - using a Node for type safety
	_mission = Node.new()
	# Set mission properties using type-safe method calls
	TypeSafeMixin._set_property_safe(_mission, "mission_type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(_mission, "mission_name", "Test Mission")
	TypeSafeMixin._set_property_safe(_mission, "description", "Test Description")
	TypeSafeMixin._set_property_safe(_mission, "difficulty", 1)
	TypeSafeMixin._set_property_safe(_mission, "objectives", [ {"id": "test", "description": "Test", "completed": false, "is_primary": true}])
	TypeSafeMixin._set_property_safe(_mission, "rewards", {"credits": 100})
	
	track_test_resource(_template)
	add_child_autofree(_mission)

func after_each() -> void:
	await super.after_each()
	_template = null
	_mission = null

# Resource Exhaustion Tests
func test_excessive_objectives() -> void:
	# Test adding more objectives than the system can handle
	var objectives = TypeSafeMixin._get_property_safe(_mission, "objectives", [])
	for i in range(100):
		objectives.append({
			"id": "test_%d" % i,
			"description": "Test %d" % i,
			"completed": false,
			"is_primary": false
		})
	TypeSafeMixin._set_property_safe(_mission, "objectives", objectives)
	
	assert_eq(TypeSafeMixin._get_property_safe(_mission, "objectives", []).size(), 101)
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_completed", false))
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_failed", false))

func test_memory_exhaustion_recovery() -> void:
	var large_data = "x".repeat(1000000) # 1MB string
	TypeSafeMixin._set_property_safe(_mission, "description", large_data)
	TypeSafeMixin._set_property_safe(_mission, "mission_name", large_data)
	
	var description = TypeSafeMixin._get_property_safe(_mission, "description", "")
	var mission_name = TypeSafeMixin._get_property_safe(_mission, "mission_name", "")
	assert_true(description.length() > 0)
	assert_true(mission_name.length() > 0)

# Invalid State Tests
func test_invalid_state_transitions() -> void:
	TypeSafeMixin._set_property_safe(_mission, "is_completed", true)
	TypeSafeMixin._set_property_safe(_mission, "is_failed", true)
	
	# Mission should not be both completed and failed
	var is_completed = TypeSafeMixin._get_property_safe(_mission, "is_completed", false)
	var is_failed = TypeSafeMixin._get_property_safe(_mission, "is_failed", false)
	assert_true(is_completed != is_failed)

# Corrupted Data Tests
func test_corrupted_save_data() -> void:
	TypeSafeMixin._set_property_safe(_mission, "mission_id", "")
	TypeSafeMixin._set_property_safe(_mission, "mission_type", -1)
	TypeSafeMixin._set_property_safe(_mission, "difficulty", -1)
	
	var mission_id = TypeSafeMixin._get_property_safe(_mission, "mission_id", "")
	var mission_type = TypeSafeMixin._get_property_safe(_mission, "mission_type", -1)
	var difficulty = TypeSafeMixin._get_property_safe(_mission, "difficulty", -1)
	
	assert_false(mission_id.is_empty())
	assert_gt(mission_type, -1)
	assert_gt(difficulty, -1)

# Extreme Value Tests
func test_extreme_reward_values() -> void:
	TypeSafeMixin._set_property_safe(_mission, "rewards", {
		"credits": 999999999,
		"reputation": 999999999
	})
	
	var result = TypeSafeMixin._call_node_method(_mission, "calculate_final_rewards", [])
	assert_eq(result, {}) # Should return empty dict since mission not completed

	TypeSafeMixin._set_property_safe(_mission, "is_completed", true)
	result = TypeSafeMixin._call_node_method(_mission, "calculate_final_rewards", [])
	assert_gt(result.get("credits", 0), 0)
	assert_gt(result.get("reputation", 0), 0)

# Error Recovery Tests
func test_objective_error_recovery() -> void:
	TypeSafeMixin._set_property_safe(_mission, "objectives", [])
	var result = TypeSafeMixin._call_node_method(_mission, "complete_objective", [0]) # Should handle invalid index gracefully
	
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_completed", false))
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_failed", false))
	var completion_percentage = TypeSafeMixin._get_property_safe(_mission, "completion_percentage", 0.0)
	assert_eq(completion_percentage, 0.0)

func test_rapid_phase_changes() -> void:
	var phases = ["preparation", "deployment", "combat", "resolution"]
	for phase in phases:
		TypeSafeMixin._call_node_method(_mission, "change_phase", [phase])
		var current_phase = TypeSafeMixin._get_property_safe(_mission, "current_phase", "")
		assert_eq(current_phase, phase)
	
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_completed", false))
	assert_false(TypeSafeMixin._get_property_safe(_mission, "is_failed", false))