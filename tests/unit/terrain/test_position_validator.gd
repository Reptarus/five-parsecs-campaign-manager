@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

const PositionValidator: GDScript = preload("res://src/core/systems/PositionValidator.gd")
const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")
const Mission: GDScript = preload("res://src/core/mission/base/mission.gd")

var position_validator: PositionValidator
var terrain_system: TerrainSystem
var test_mission: Mission

func before_each() -> void:
	await super.before_each()
	position_validator = PositionValidator.new()
	terrain_system = TerrainSystem.new()
	test_mission = Mission.new()
	
	add_child_autofree(position_validator)
	add_child_autofree(terrain_system)
	track_test_resource(test_mission)
	
	TypeSafeMixin._call_node_method_bool(terrain_system, "initialize_terrain", [Vector2i(10, 10), 0])
	TypeSafeMixin._set_property_safe(position_validator, "terrain_system", terrain_system)

func after_each() -> void:
	await super.after_each()

func test_feature_position_validation() -> void:
	var empty_pos := Vector2(5, 5)
	assert_true(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [empty_pos, 1]),
		"Should allow feature placement on empty position")
	
	TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [empty_pos, 1])
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [empty_pos, 1]),
		"Should not allow feature placement on occupied position")
	
	var too_close_pos := Vector2(6, 5)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [too_close_pos, 1]),
		"Should not allow feature placement too close to existing feature")
	
	var edge_pos := Vector2(0, 0)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [edge_pos, 1]),
		"Should not allow feature placement at grid edge")

func test_objective_position_validation() -> void:
	TypeSafeMixin._set_property_safe(test_mission, "deployment_points", [Vector2(2, 2), Vector2(8, 8)])
	
	var valid_pos := Vector2(5, 5)
	watch_signals(position_validator)
	assert_true(TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [valid_pos, test_mission]),
		"Should allow objective placement at valid position")
	
	TypeSafeMixin._call_node_method_bool(test_mission, "add_objective", [1, valid_pos])
	var too_close_pos := Vector2(6, 5)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [too_close_pos, test_mission]),
		"Should not allow objective placement too close to existing objective")
	
	TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [Vector2(4, 4), 1])
	TypeSafeMixin._call_node_method_bool(terrain_system, "_set_terrain_feature", [Vector2(6, 6), 1])
	var blocked_pos := Vector2(5, 5)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_objective_position", [blocked_pos, test_mission]),
		"Should not allow objective placement without line of sight to deployment")

func test_deployment_position_validation() -> void:
	TypeSafeMixin._call_node_method_bool(test_mission, "add_objective", [1, Vector2(5, 5)])
	
	var valid_pos := Vector2(2, 2)
	assert_true(TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [valid_pos, test_mission]),
		"Should allow deployment at valid position")
	
	var deployment_points = TypeSafeMixin._get_property_safe(test_mission, "deployment_points", [])
	deployment_points.append(valid_pos)
	TypeSafeMixin._set_property_safe(test_mission, "deployment_points", deployment_points)
	
	var too_close_pos := Vector2(3, 2)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [too_close_pos, test_mission]),
		"Should not allow deployment too close to existing deployment point")
	
	var too_far_pos := Vector2(9, 9)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [too_far_pos, test_mission]),
		"Should not allow deployment too far from objectives")
	
	var edge_pos := Vector2(1, 1)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [edge_pos, test_mission]),
		"Should not allow deployment too close to grid edge")

func test_grid_boundary_validation() -> void:
	var outside_pos := Vector2(-1, -1)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [outside_pos, 1]),
		"Should reject position outside grid (negative)")
	
	outside_pos = Vector2(10, 10)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [outside_pos, 1]),
		"Should reject position outside grid (beyond bounds)")
	
	var boundary_pos := Vector2(0, 0)
	assert_false(TypeSafeMixin._call_node_method_bool(position_validator, "validate_deployment_position", [boundary_pos, test_mission]),
		"Should reject deployment at grid boundary")
	
	var valid_pos := Vector2(2, 2)
	assert_true(TypeSafeMixin._call_node_method_bool(position_validator, "validate_feature_position", [valid_pos, 1]),
		"Should accept position just inside valid range")