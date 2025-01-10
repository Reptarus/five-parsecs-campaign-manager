extends "res://addons/gut/test.gd"

var position_validator: PositionValidator
var terrain_system: TerrainSystem
var test_mission: Mission

func before_each():
    position_validator = PositionValidator.new()
    terrain_system = TerrainSystem.new()
    test_mission = Mission.new()
    
    # Setup terrain system with a 10x10 grid
    terrain_system.initialize_terrain(Vector2i(10, 10), 0) # URBAN environment
    position_validator.terrain_system = terrain_system
    add_child(position_validator)

func after_each():
    position_validator.queue_free()
    terrain_system.queue_free()
    test_mission.queue_free()

func test_feature_position_validation():
    # Test empty position
    var empty_pos := Vector2(5, 5)
    assert_true(position_validator.validate_feature_position(empty_pos, 1),
        "Should allow feature placement on empty position")
    
    # Test occupied position
    terrain_system._set_terrain_feature(empty_pos, 1) # Place COVER_LOW
    assert_false(position_validator.validate_feature_position(empty_pos, 1),
        "Should not allow feature placement on occupied position")
    
    # Test feature spacing
    var too_close_pos := Vector2(6, 5)
    assert_false(position_validator.validate_feature_position(too_close_pos, 1),
        "Should not allow feature placement too close to existing feature")
    
    # Test edge position
    var edge_pos := Vector2(0, 0)
    assert_false(position_validator.validate_feature_position(edge_pos, 1),
        "Should not allow feature placement at grid edge")

func test_objective_position_validation():
    # Setup test mission with deployment points
    test_mission.deployment_points = [Vector2(2, 2), Vector2(8, 8)]
    
    # Test valid objective position
    var valid_pos := Vector2(5, 5)
    assert_true(position_validator.validate_objective_position(valid_pos, test_mission),
        "Should allow objective placement at valid position")
    
    # Test objective spacing
    test_mission.add_objective(1, valid_pos) # Add first objective
    var too_close_pos := Vector2(6, 5)
    assert_false(position_validator.validate_objective_position(too_close_pos, test_mission),
        "Should not allow objective placement too close to existing objective")
    
    # Test line of sight
    terrain_system._set_terrain_feature(Vector2(4, 4), 1) # Place blocking terrain
    terrain_system._set_terrain_feature(Vector2(6, 6), 1)
    var blocked_pos := Vector2(5, 5)
    assert_false(position_validator.validate_objective_position(blocked_pos, test_mission),
        "Should not allow objective placement without line of sight to deployment")

func test_deployment_position_validation():
    # Setup test mission with objectives
    test_mission.add_objective(1, Vector2(5, 5))
    
    # Test valid deployment position
    var valid_pos := Vector2(2, 2)
    assert_true(position_validator.validate_deployment_position(valid_pos, test_mission),
        "Should allow deployment at valid position")
    
    # Test deployment spacing
    test_mission.deployment_points.append(valid_pos)
    var too_close_pos := Vector2(3, 2)
    assert_false(position_validator.validate_deployment_position(too_close_pos, test_mission),
        "Should not allow deployment too close to existing deployment point")
    
    # Test objective distance
    var too_far_pos := Vector2(9, 9)
    assert_false(position_validator.validate_deployment_position(too_far_pos, test_mission),
        "Should not allow deployment too far from objectives")
    
    # Test edge distance
    var edge_pos := Vector2(1, 1)
    assert_false(position_validator.validate_deployment_position(edge_pos, test_mission),
        "Should not allow deployment too close to grid edge")

func test_grid_boundary_validation():
    # Test positions outside grid
    var outside_pos := Vector2(-1, -1)
    assert_false(position_validator.validate_feature_position(outside_pos, 1),
        "Should reject position outside grid (negative)")
    
    outside_pos = Vector2(10, 10)
    assert_false(position_validator.validate_feature_position(outside_pos, 1),
        "Should reject position outside grid (beyond bounds)")
    
    # Test positions at grid boundary
    var boundary_pos := Vector2(0, 0)
    assert_false(position_validator.validate_deployment_position(boundary_pos, test_mission),
        "Should reject deployment at grid boundary")
    
    # Test positions just inside valid range
    var valid_pos := Vector2(2, 2)
    assert_true(position_validator.validate_feature_position(valid_pos, 1),
        "Should accept position just inside valid range")