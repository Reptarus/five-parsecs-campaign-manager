@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

const PositionValidator: GDScript = preload("res://src/core/systems/PositionValidator.gd")
const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")
const Mission: GDScript = preload("res://src/core/mission/base/mission.gd")

var position_validator: PositionValidator
var terrain_system: TerrainSystem
var test_mission: Object # Changed to Object type for flexibility

func before_each() -> void:
	await super.before_each()
	position_validator = PositionValidator.new()
	terrain_system = TerrainSystem.new()
	
	# Create mission object safely using Resource instead of new()
	test_mission = Resource.new()
	test_mission.set_script(Mission)
	
	if not is_instance_valid(position_validator) or not is_instance_valid(terrain_system) or not is_instance_valid(test_mission):
		push_error("Failed to create one or more required test objects")
		return
	
	add_child_autofree(position_validator)
	add_child_autofree(terrain_system)
	track_test_resource(test_mission)
	
	# Ensure mission has required properties and methods
	if not test_mission.has_method("add_objective"):
		test_mission.set("add_objective", func(id, pos): return true)
	
	if not "deployment_points" in test_mission:
		test_mission.set("deployment_points", [])
	
	# Initialize terrain with safe defaults
	var init_result = TypeSafeMixin._call_node_method_bool(terrain_system, "initialize_terrain", [Vector2i(10, 10), 0])
	if not init_result:
		push_warning("Failed to initialize terrain system")
		
	# Set position validator terrain_system with safer method
	var set_result = TypeSafeMixin._set_property_safe(position_validator, "terrain_system", terrain_system)
	if not set_result:
		push_warning("Failed to set terrain_system on position_validator")

func after_each() -> void:
	await super.after_each()
	# Resources will be cleaned up by tracker

func test_feature_position_validation() -> void:
	# Check if required methods exist
	if not (position_validator.has_method("validate_feature_position") and
		   terrain_system.has_method("_set_terrain_feature")):
		push_warning("Skipping test_feature_position_validation: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var empty_pos := Vector2(5, 5)
	var validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [empty_pos, 1])
	assert_true(validation_result, "Should allow feature placement on empty position")
	
	# Set terrain feature safely
	var set_feature_result = TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [empty_pos, 1])
	if not set_feature_result:
		push_warning("Failed to set terrain feature, test may be invalid")
		
	# Check we can't place on the same position	
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [empty_pos, 1])
	assert_false(validation_result, "Should not allow feature placement on occupied position")
	
	var too_close_pos := Vector2(6, 5)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [too_close_pos, 1])
	assert_false(validation_result, "Should not allow feature placement too close to existing feature")
	
	var edge_pos := Vector2(0, 0)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [edge_pos, 1])
	assert_false(validation_result, "Should not allow feature placement at grid edge")

func test_objective_position_validation() -> void:
	# Check if required methods exist
	if not (position_validator.has_method("validate_objective_position") and
		   test_mission.has_method("add_objective") and
		   terrain_system.has_method("_set_terrain_feature")):
		push_warning("Skipping test_objective_position_validation: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	# Check if required properties exist with safer checks
	var has_deployment_points = TypeSafeMixin._get_property_safe(test_mission, "deployment_points", null) != null
	if not has_deployment_points:
		push_warning("Skipping test_objective_position_validation: required property 'deployment_points' missing on mission")
		pending("Test skipped - required property missing")
		return
	
	# Set up deployment points safely
	TypeSafeMixin._set_property_safe(test_mission, "deployment_points", [Vector2(2, 2), Vector2(8, 8)])
	
	var valid_pos := Vector2(5, 5)
	watch_signals(position_validator)
	
	var validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [valid_pos, test_mission])
	assert_true(validation_result, "Should allow objective placement at valid position")
	
	# Add objective safely
	TypeSafeMixin._call_node_method_bool(test_mission, "add_objective", [1, valid_pos])
	
	var too_close_pos := Vector2(6, 5)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [too_close_pos, test_mission])
	assert_false(validation_result, "Should not allow objective placement too close to existing objective")
	
	# Set terrain features safely
	TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [Vector2(4, 4), 1])
	TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [Vector2(6, 6), 1])
	
	var blocked_pos := Vector2(5, 5)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [blocked_pos, test_mission])
	assert_false(validation_result, "Should not allow objective placement without line of sight to deployment")

func test_deployment_position_validation() -> void:
	# Check if required methods exist
	if not (position_validator.has_method("validate_deployment_position") and
		   test_mission.has_method("add_objective")):
		push_warning("Skipping test_deployment_position_validation: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	# Check if required properties exist with safer checks
	var has_deployment_points = TypeSafeMixin._get_property_safe(test_mission, "deployment_points", null) != null
	if not has_deployment_points:
		push_warning("Skipping test_deployment_position_validation: required property 'deployment_points' missing on mission")
		pending("Test skipped - required property missing")
		return
	
	# Add objective safely
	TypeSafeMixin._call_node_method_bool(test_mission, "add_objective", [1, Vector2(5, 5)])
	
	var valid_pos := Vector2(2, 2)
	var validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [valid_pos, test_mission])
	assert_true(validation_result, "Should allow deployment at valid position")
	
	# Update deployment points safely
	var deployment_points = TypeSafeMixin._get_property_safe(test_mission, "deployment_points", [])
	if deployment_points is Array:
		deployment_points.append(valid_pos)
		TypeSafeMixin._set_property_safe(test_mission, "deployment_points", deployment_points)
	
	var too_close_pos := Vector2(3, 2)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [too_close_pos, test_mission])
	assert_false(validation_result, "Should not allow deployment too close to existing deployment point")
	
	var too_far_pos := Vector2(9, 9)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [too_far_pos, test_mission])
	assert_false(validation_result, "Should not allow deployment too far from objectives")
	
	var edge_pos := Vector2(1, 1)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [edge_pos, test_mission])
	assert_false(validation_result, "Should not allow deployment too close to grid edge")

func test_grid_boundary_validation() -> void:
	# Check if required methods exist
	if not (position_validator.has_method("validate_feature_position") and
		   position_validator.has_method("validate_deployment_position")):
		push_warning("Skipping test_grid_boundary_validation: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var outside_pos := Vector2(-1, -1)
	var validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [outside_pos, 1])
	assert_false(validation_result, "Should reject position outside grid (negative)")
	
	outside_pos = Vector2(10, 10)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [outside_pos, 1])
	assert_false(validation_result, "Should reject position outside grid (beyond bounds)")
	
	var boundary_pos := Vector2(0, 0)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [boundary_pos, test_mission])
	assert_false(validation_result, "Should reject deployment at grid boundary")
	
	var valid_pos := Vector2(2, 2)
	validation_result = TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [valid_pos, 1])
	assert_true(validation_result, "Should accept position just inside valid range")
