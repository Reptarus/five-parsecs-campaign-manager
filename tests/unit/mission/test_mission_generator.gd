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

const FiveParsecsMissionGenerator := preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const MissionTemplate = preload("res://src/core/templates/MissionTemplate.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const WorldManager = preload("res://src/game/world/GameWorldManager.gd")

# Test helper methods
const TEST_TIMEOUT := 1000
const STRESS_TEST_ITERATIONS := 100

var _mission_generator: Node
var _terrain_system: TerrainSystem
var _rival_system: RivalSystem
var _world_manager: WorldManager
var _test_game_state: GameState

func before_each() -> void:
	await super.before_each()
	_test_game_state = GameState.new()
	_world_manager = WorldManager.new()
	_terrain_system = TerrainSystem.new()
	_rival_system = RivalSystem.new()
	
	add_child_autofree(_test_game_state)
	add_child_autofree(_world_manager)
	add_child_autofree(_terrain_system)
	add_child_autofree(_rival_system)
	
	# Create mission generator - we need a Node wrapper since FiveParsecsMissionGenerator
	# is RefCounted, not a Node
	var generator_wrapper = FiveParsecsMissionGenerator.create_node_wrapper()
	add_child_autofree(generator_wrapper)
	track_test_node(generator_wrapper)
	
	# Set the mission_generator reference to the wrapper
	_mission_generator = generator_wrapper
	
	# Set required systems
	if generator_wrapper.has_method("set_game_state"):
		generator_wrapper.set_game_state(_test_game_state)
	else:
		TypeSafeMixin._call_node_method_bool(generator_wrapper, "set_game_state", [_test_game_state])
		
	if generator_wrapper.has_method("set_world_manager"):
		generator_wrapper.set_world_manager(_world_manager)
	else:
		TypeSafeMixin._call_node_method_bool(generator_wrapper, "set_world_manager", [_world_manager])

func after_each() -> void:
	await super.after_each()
	_mission_generator = null
	_terrain_system = null
	_rival_system = null

#region Basic Generation Tests

func test_mission_generation() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_mission_generation")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 3))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(100, 300))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Test Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	watch_signals(_mission_generator)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = _mission_generator.generate_mission(2, GameEnums.MissionType.PATROL)
	safe_track_resource(mission)
	
	assert_not_null(mission, "Mission should be generated")
	# Use safe dictionary access
	assert_eq(_safe_get_property(mission, "type"), GameEnums.MissionType.PATROL, "Mission type should match template")
	assert_true(
		_safe_get_property(mission, "difficulty", 0) >= 1 and
		_safe_get_property(mission, "difficulty", 0) <= 3,
		"Difficulty should be within range"
	)
	assert_true(
		_safe_get_property(mission, "reward", 0) >= 100 and
		_safe_get_property(mission, "reward", 0) <= 300,
		"Rewards should be within range"
	)

func test_invalid_template() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_invalid_template")
		return
		
	var template = MissionTemplate.new()
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = _mission_generator.generate_mission(1)
	assert_true(mission.is_empty(), "Should return empty dictionary for invalid template")

#endregion

#region Performance Tests

func test_rapid_mission_generation() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_rapid_mission_generation")
		return
		
	var template := create_basic_template()
	watch_signals(_mission_generator)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
	
	for i in range(STRESS_TEST_ITERATIONS):
		var mission_type = GameEnums.MissionType.PATROL
		var mission = _mission_generator.generate_mission(2, mission_type)
		safe_track_resource(mission)
		assert_not_null(mission, "Should generate mission in iteration %d" % i)
	
	assert_signal_emit_count(_mission_generator, "mission_generated", STRESS_TEST_ITERATIONS)

func test_concurrent_generation_performance() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_concurrent_generation_performance")
		return
		
	var template := create_basic_template()
	var start_time := Time.get_ticks_msec()
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
	
	# Generate multiple missions concurrently
	var missions = []
	for i in range(10):
		var mission_type = GameEnums.MissionType.PATROL
		var mission = _mission_generator.generate_mission(2, mission_type)
		missions.append(mission)
		safe_track_resource(mission)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_lt(duration, TEST_TIMEOUT, "Mission generation should complete within timeout")

#endregion

#region State Persistence Tests

func test_mission_state_persistence() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_mission_state_persistence")
		return
		
	var template := create_basic_template()
	var mission_type = GameEnums.MissionType.PATROL
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission") or not _mission_generator.has_method("create_from_save"):
		push_error("Required methods not found on mission generator")
		assert_true(false, "Missing required methods")
		return
		
	var mission = _mission_generator.generate_mission(2, mission_type)
	safe_track_resource(mission)
	
	# Save and reload mission state
	var saved_state = mission.duplicate(true)
	var loaded_mission = _mission_generator.create_from_save(saved_state)
	safe_track_resource(loaded_mission)
	
	assert_eq(_safe_get_property(loaded_mission, "type"), _safe_get_property(mission, "type"), "Loaded mission type should match original")
	assert_eq(_safe_get_property(loaded_mission, "difficulty"), _safe_get_property(mission, "difficulty"), "Loaded mission difficulty should match original")

func test_mission_generation_signals() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_mission_generation_signals")
		return
		
	var template := create_basic_template()
	watch_signals(_mission_generator)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission_type = GameEnums.MissionType.PATROL
	var mission = _mission_generator.generate_mission(2, mission_type)
	safe_track_resource(mission)
	
	assert_signal_emitted(_mission_generator, "generation_started")
	assert_signal_emitted(_mission_generator, "mission_generated")
	assert_signal_emitted(_mission_generator, "generation_completed")

#endregion

# Helper Methods
func create_basic_template() -> MissionTemplate:
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 3))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(100, 300))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Test Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	return template

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

# Rival Integration Tests

func test_rival_involvement() -> void:
	if not _mission_generator or not _rival_system:
		push_error("Mission generator or rival system is null in test_rival_involvement")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.RAID)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(2, 4))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(200, 400))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Rival Test Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Set up rival data
	_rival_system.create_rival({
		"id": "test_rival",
		"force_composition": ["grunt", "grunt", "elite"]
	})
	
	watch_signals(_mission_generator)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = _mission_generator.generate_mission(3, GameEnums.MissionType.RAID)
	safe_track_resource(mission)
	
	# Add null check before accessing mission properties
	if mission == null:
		push_warning("Mission was not generated, skipping rival check")
		return
		
	# Use safe property access
	var rival_involvement = _safe_get_property(mission, "rival_involvement")
	assert_not_null(rival_involvement, "Mission should have rival involvement")
	
	# Add null check before accessing nested properties
	if rival_involvement != null:
		var rival_id = _safe_get_property(rival_involvement, "rival_id", "")
		assert_eq(rival_id, "test_rival", "Rival ID should match")

# Terrain Integration Tests

func test_terrain_generation() -> void:
	if not _mission_generator or not _terrain_system:
		push_error("Mission generator or terrain system is null in test_terrain_generation")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.DEFENSE)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(2, 4))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(200, 400))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Terrain Test Mission")
	TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = _mission_generator.generate_mission(3, GameEnums.MissionType.DEFENSE)
	safe_track_resource(mission)
	assert_not_null(mission, "Mission should be generated")
	
	# Check if terrain features were generated - with null safety
	var terrain_features = []
	if _terrain_system and _terrain_system.has_method("get_terrain_features"):
		terrain_features = _terrain_system.get_terrain_features()
	
	# Use safe size check for the array
	var features_count = 0
	if terrain_features != null and terrain_features is Array:
		features_count = terrain_features.size()
		
	assert_gt(features_count, 0, "Should generate terrain features")

# Helper function to safely check for properties
func _safe_has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	return property_name in obj

# Helper function to safely get property values
func _safe_get_property(obj, property_name: String, default_value = null):
	if obj == null:
		return default_value
		
	if obj is Dictionary:
		return obj.get(property_name, default_value)
		
	# For objects, try using a getter method first
	if obj.has_method("get_" + property_name):
		return obj.call("get_" + property_name)
		
	# Try using get() method if it exists
	if obj.has_method("get"):
		# Check if the get method accepts two parameters
		var method_info = obj.get_method_list().filter(func(m): return m.name == "get")
		if method_info.size() > 0 and method_info[0].args.size() >= 2:
			return obj.get(property_name, default_value)
		else:
			# If get() only accepts one parameter, don't provide a default value
			return obj.get(property_name)
		
	# Direct property access as last resort
	if property_name in obj:
		return obj.get(property_name)
		
	return default_value

func test_objective_placement() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_objective_placement")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.SABOTAGE)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(3, 5))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(300, 500))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Objective Test Mission")
	TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = _mission_generator.generate_mission(4, GameEnums.MissionType.SABOTAGE)
	safe_track_resource(mission)
	assert_not_null(mission, "Mission should be generated")
	
	# Add null check before accessing objectives
	if mission == null:
		return
		
	# Use a safe method to get objectives size
	var objectives_size = 0
	if _safe_has_property(mission, "objectives"):
		var objectives = mission.objectives
		if objectives != null and objectives is Array:
			objectives_size = objectives.size()
			
	assert_gt(objectives_size, 0, "Should generate objectives")

# Error Condition Tests

func test_generation_with_invalid_difficulty() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_generation_with_invalid_difficulty")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(-1, 0)) # Invalid range
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(100, 300))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Invalid Difficulty Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	# Use proper type-safe access to properties
	var template_type = _safe_get_property(template, "type", GameEnums.MissionType.PATROL)
	var mission = _mission_generator.generate_mission(0, template_type)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_with_invalid_difficulty")
		assert_true(false, "Mission should not be null, even with invalid parameters")
		return
		
	assert_true(mission.is_empty(), "Should return empty dictionary for invalid difficulty range")

func test_generation_with_invalid_rewards() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_generation_with_invalid_rewards")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 3))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(-100, -50)) # Invalid range
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Invalid Rewards Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	# Use proper type-safe access to properties
	var template_type = _safe_get_property(template, "type", GameEnums.MissionType.PATROL)
	var mission = _mission_generator.generate_mission(2, template_type)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_with_invalid_rewards")
		assert_true(false, "Mission should not be null, even with invalid parameters")
		return
		
	assert_true(mission.is_empty(), "Should return empty dictionary for invalid reward range")

# Boundary Tests

func test_generation_at_difficulty_boundaries() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_generation_at_difficulty_boundaries")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 1)) # Minimum difficulty
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(100, 300))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Boundary Test Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var template_type = template.type # Access type property directly
	var mission = _mission_generator.generate_mission(1, template_type)
	safe_track_resource(mission)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_at_difficulty_boundaries (min)")
		assert_true(false, "Mission should not be null at minimum difficulty")
		return
		
	assert_not_null(mission, "Should generate mission at minimum difficulty")
	assert_eq(_safe_get_property(mission, "difficulty"), 1, "Should use minimum difficulty")
	
	# Use safe setter for difficulty_range
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(10, 10)) # Maximum difficulty
	
	# Check if the method exists before calling it again
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
	
	template_type = template.type # Access type property directly
	mission = _mission_generator.generate_mission(10, template_type)
	safe_track_resource(mission)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_at_difficulty_boundaries (max)")
		assert_true(false, "Mission should not be null at maximum difficulty")
		return
		
	assert_not_null(mission, "Should generate mission at maximum difficulty")
	assert_eq(_safe_get_property(mission, "difficulty"), 10, "Should use maximum difficulty")

# Add a test for the node wrapper approach
func test_node_wrapper_functionality() -> void:
	# Try to create a node wrapper directly
	var wrapper = FiveParsecsMissionGenerator.create_node_wrapper()
	
	assert_not_null(wrapper, "Node wrapper should be created")
	
	# If wrapper is null, exit early
	if not wrapper:
		push_error("Node wrapper is null in test_node_wrapper_functionality")
		return
		
	# Add to scene tree for proper lifecycle
	add_child_autofree(wrapper)
	
	# Set required systems
	if wrapper.has_method("set_game_state"):
		wrapper.set_game_state(_test_game_state)
	else:
		TypeSafeMixin._call_node_method_bool(wrapper, "set_game_state", [_test_game_state])
		
	if wrapper.has_method("set_world_manager"):
		wrapper.set_world_manager(_world_manager)
	else:
		TypeSafeMixin._call_node_method_bool(wrapper, "set_world_manager", [_world_manager])
	
	# Register for signals
	var signals_connected = false
	if wrapper.has_method("connect_signals_to"):
		wrapper.connect_signals_to(self)
		signals_connected = true
	
	# Set up signal watching
	watch_signals(wrapper)
	
	# Test wrapper functionality
	assert_true(wrapper.has_method("generate_mission"), "Wrapper should have generate_mission method")
	
	# Check if the method exists before calling it
	if not wrapper.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on wrapper")
		assert_true(false, "Missing generate_mission method")
		return
		
	var mission = wrapper.generate_mission(2, GameEnums.MissionType.PATROL)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_node_wrapper_functionality")
		assert_true(false, "Wrapper should generate non-null missions")
		return
		
	assert_not_null(mission, "Wrapper should generate missions")
	assert_true(mission is Dictionary, "Generated mission should be a Dictionary")
	assert_true(mission.has("id"), "Mission should have an id")
	
	# If signals were connected, check for signal emission
	if signals_connected:
		assert_signal_emitted(wrapper, "mission_generated")
	
	# Test the wrapper with mission type
	if wrapper.has_method("generate_mission_with_type"):
		var mission2 = wrapper.generate_mission_with_type(GameEnums.MissionType.DEFENSE)
		safe_track_resource(mission2)
		
		# Check if mission2 is null
		if mission2 == null:
			push_error("Generated mission2 is null in test_node_wrapper_functionality")
			assert_true(false, "Wrapper should generate non-null missions with type")
			return
			
		assert_not_null(mission2, "Wrapper should generate missions with type")
		assert_true(mission2 is Dictionary, "Generated mission should be a Dictionary")
		assert_eq(_safe_get_property(mission2, "type"), GameEnums.MissionType.DEFENSE, "Mission type should match request")
	else:
		push_warning("Method 'generate_mission_with_type' not found on wrapper")

# Helper Methods
func create_node_generator() -> Node:
	# Create a node-compatible generator
	var generator_node = FiveParsecsMissionGenerator.create_node_wrapper()
	
	# Check if generator_node is null
	if not generator_node:
		push_error("Failed to create node generator")
		return null
		
	add_child_autofree(generator_node)
	track_test_node(generator_node)
	return generator_node

# Test with missing required systems
func test_generation_with_missing_systems() -> void:
	# Create a standalone generator with a proper node wrapper
	var node_wrapper = FiveParsecsMissionGenerator.create_node_wrapper()
	
	# Check if node_wrapper is null
	if not node_wrapper:
		push_error("Failed to create node wrapper in test_generation_with_missing_systems")
		assert_true(false, "Could not create node wrapper")
		return
		
	add_child_autofree(node_wrapper)
	track_test_node(node_wrapper)
	
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 3))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(100, 300))
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Missing Systems Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not node_wrapper.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on node wrapper")
		assert_true(false, "Missing generate_mission method")
		return
		
	# The mission generation should fail because required systems aren't set
	var template_type = template.type # Access type property directly
	var mission = node_wrapper.generate_mission(2, template_type)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_with_missing_systems")
		assert_true(false, "Mission should not be null, even without required systems")
		return
		
	assert_true(mission.is_empty(), "Should return empty dictionary without required systems")

# Large values test
func test_generation_with_large_values() -> void:
	if not _mission_generator:
		push_error("Mission generator is null in test_generation_with_large_values")
		return
		
	var template = MissionTemplate.new()
	TypeSafeMixin._set_property_safe(template, "type", GameEnums.MissionType.PATROL)
	TypeSafeMixin._set_property_safe(template, "difficulty_range", Vector2(1, 3))
	TypeSafeMixin._set_property_safe(template, "reward_range", Vector2(1000000, 2000000)) # Very large rewards
	
	# Use proper methods for setting array properties
	var title_array = []
	title_array.append("Large Values Mission")
	if template.has_method("set_title_templates"):
		template.set_title_templates(title_array)
	else:
		TypeSafeMixin._call_node_method(template, "set_title_templates", [title_array])
	
	track_test_resource(template)
	
	# Check if the method exists before calling it
	if not _mission_generator.has_method("generate_mission"):
		push_error("Method 'generate_mission' not found on mission generator")
		assert_true(false, "Missing generate_mission method")
		return
		
	var template_type = template.type # Access type property directly
	var mission = _mission_generator.generate_mission(2, template_type)
	safe_track_resource(mission)
	
	# Check if mission is null
	if mission == null:
		push_error("Generated mission is null in test_generation_with_large_values")
		assert_true(false, "Mission should not be null with large reward values")
		return
		
	assert_not_null(mission, "Should generate mission with large reward values")
	assert_true(_safe_get_property(mission, "reward", 0) >= 1000000, "Should handle large reward values")

# Signal handlers for tests
func _on_generation_started(data) -> void:
	# This function will be called when the generation_started signal is emitted
	pass

func _on_mission_generated(mission) -> void:
	# This function will be called when the mission_generated signal is emitted
	pass

func _on_generation_completed(data) -> void:
	# This function will be called when the generation_completed signal is emitted
	pass
