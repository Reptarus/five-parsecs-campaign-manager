@tool
extends "res://tests/fixtures/base/game_test.gd"

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
	
	# Set template properties using type-safe method calls - avoid direct array assignment
	if _template.has_method("set_type"):
		_template.set_type(GameEnums.MissionType.PATROL)
	else:
		TypeSafeMixin._set_property_safe(_template, "type", GameEnums.MissionType.PATROL)
	
	# Use proper methods for setting array properties to avoid type conflicts
	var title_array = []
	title_array.append("Test Mission")
	TypeSafeMixin._call_node_method(_template, "set_title_templates", [title_array])
	
	var desc_array = []
	desc_array.append("Test Description")
	TypeSafeMixin._call_node_method(_template, "set_description_templates", [desc_array])
	
	# Set remaining properties safely
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
	
	safe_track_resource(_template)
	add_child_autofree(_mission)

func after_each() -> void:
	await super.after_each()
	_template = null
	_mission = null

# Helper method to safely track resources or dictionaries
func safe_track_resource(obj) -> void:
	if obj is Resource:
		track_test_resource(obj)
	elif obj is Dictionary:
		# For dictionaries, we don't need to track them as they're not Resources
		# but we can print a helpful debug message
		print("Note: Dictionary passed to safe_track_resource, no tracking needed")
	else:
		push_warning("Object is neither Resource nor Dictionary, cannot track: %s" % obj)

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
	if result == null:
		result = {}
	assert_eq(result, {}) # Should return empty dict since mission not completed

	TypeSafeMixin._set_property_safe(_mission, "is_completed", true)
	result = TypeSafeMixin._call_node_method(_mission, "calculate_final_rewards", [])
	if result == null:
		result = {}
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

# Helper function to safely verify signal emission sequence
func verify_signal_sequence(received_signals: Array, expected_signals: Array, strict_order: bool = true) -> bool:
	# Check if we have any signals to verify
	if expected_signals.is_empty():
		push_warning("Expected signal list is empty")
		return false
		
	# 1. Count Check - Make sure we have enough signals
	if received_signals.size() < expected_signals.size():
		push_error("Not enough signals received. Expected %d but got %d" % [expected_signals.size(), received_signals.size()])
		print("Expected signals: ", expected_signals)
		print("Received signals: ", received_signals)
		return false
		
	# 2. Presence Check - Make sure all expected signals are present
	var missing_signals = []
	for expected in expected_signals:
		if not expected in received_signals:
			missing_signals.append(expected)
			
	if not missing_signals.is_empty():
		push_error("Missing expected signals: %s" % missing_signals)
		print("Expected signals: ", expected_signals)
		print("Received signals: ", received_signals)
		return false
		
	# 3. Order Check - If strict order is required, verify sequence
	if strict_order:
		var last_index = -1
		for expected in expected_signals:
			var current_index = received_signals.find(expected)
			if current_index < last_index:
				push_error("Signal '%s' received out of order" % expected)
				print("Expected signals order: ", expected_signals)
				print("Received signals: ", received_signals)
				return false
			last_index = current_index
	
	# All checks passed
	return true

# Add a test to verify the signal sequence helper
func test_signal_sequence_validation() -> void:
	# Create a node with signals
	var signal_node = Node.new()
	add_child_autofree(signal_node)
	
	# Setup some test signals
	var received_signals = []
	signal_node.add_user_signal("signal_1")
	signal_node.add_user_signal("signal_2")
	signal_node.add_user_signal("signal_3")
	
	# Connect to the signals
	signal_node.connect("signal_1", func(): received_signals.append("signal_1"))
	signal_node.connect("signal_2", func(): received_signals.append("signal_2"))
	signal_node.connect("signal_3", func(): received_signals.append("signal_3"))
	
	# Emit signals in expected order
	signal_node.emit_signal("signal_1")
	signal_node.emit_signal("signal_2")
	signal_node.emit_signal("signal_3")
	
	# Test validation
	var expected_signals = ["signal_1", "signal_2", "signal_3"]
	assert_true(verify_signal_sequence(received_signals, expected_signals),
		"Should validate correct signal sequence")
	
	# Test with non-strict ordering
	var out_of_order = ["signal_2", "signal_1", "signal_3"]
	assert_false(verify_signal_sequence(received_signals, out_of_order),
		"Should fail with incorrect strict ordering")
	assert_true(verify_signal_sequence(received_signals, out_of_order, false),
		"Should pass with non-strict ordering")
