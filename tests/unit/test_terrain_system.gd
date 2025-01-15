extends "res://addons/gut/test.gd"

const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")

var _terrain_system: TerrainSystem

func before_each():
    _terrain_system = TerrainSystem.new()
    _terrain_system.initialize_grid(Vector2(10, 10))

func test_grid_initialization():
    var grid_size := _terrain_system.get_grid_size()
    assert_eq(grid_size, Vector2(10, 10), "Grid size should be 10x10")
    
    for x in range(10):
        for y in range(10):
            var terrain_type := _terrain_system.get_terrain_type(Vector2(x, y))
            assert_eq(terrain_type, TerrainSystem.TerrainFeatureType.NONE, "Grid should be initialized with NONE")

func test_set_terrain_feature():
    var test_pos := Vector2(5, 5)
    _terrain_system.set_terrain_feature(test_pos, TerrainSystem.TerrainFeatureType.WALL)
    var terrain_type := _terrain_system.get_terrain_type(test_pos)
    assert_eq(terrain_type, TerrainSystem.TerrainFeatureType.WALL, "Terrain feature should be set to WALL")

func test_invalid_position():
    var invalid_pos := Vector2(-1, -1)
    var terrain_type := _terrain_system.get_terrain_type(invalid_pos)
    assert_eq(terrain_type, TerrainSystem.TerrainFeatureType.NONE, "Invalid position should return NONE")
    
    invalid_pos = Vector2(10, 10)
    terrain_type = _terrain_system.get_terrain_type(invalid_pos)
    assert_eq(terrain_type, TerrainSystem.TerrainFeatureType.NONE, "Out of bounds position should return NONE")

func test_terrain_modified_signal():
    watch_signals(_terrain_system)
    var test_pos := Vector2(3, 3)
    _terrain_system.set_terrain_feature(test_pos, TerrainSystem.TerrainFeatureType.COVER_HIGH)
    assert_signal_emitted_with_parameters(_terrain_system, "terrain_modified", [test_pos, TerrainSystem.TerrainFeatureType.COVER_HIGH])

func test_multiple_terrain_features():
    var positions := [Vector2(1, 1), Vector2(3, 3), Vector2(5, 5)]
    var features := [
        TerrainSystem.TerrainFeatureType.WALL,
        TerrainSystem.TerrainFeatureType.COVER_LOW,
        TerrainSystem.TerrainFeatureType.COVER_HIGH
    ]
    
    for i in range(positions.size()):
        _terrain_system.set_terrain_feature(positions[i], features[i])
    
    for i in range(positions.size()):
        var terrain_type := _terrain_system.get_terrain_type(positions[i])
        assert_eq(terrain_type, features[i], "Terrain feature should match set feature")

func test_grid_boundaries():
    var grid_size := _terrain_system.get_grid_size()
    assert_eq(grid_size.x, 10, "Grid width should be 10")
    assert_eq(grid_size.y, 10, "Grid height should be 10")
    
    # Test corners
    var corners := [
        Vector2(0, 0),
        Vector2(0, grid_size.y - 1),
        Vector2(grid_size.x - 1, 0),
        Vector2(grid_size.x - 1, grid_size.y - 1)
    ]
    
    for corner in corners:
        _terrain_system.set_terrain_feature(corner, TerrainSystem.TerrainFeatureType.WALL)
        var terrain_type := _terrain_system.get_terrain_type(corner)
        assert_eq(terrain_type, TerrainSystem.TerrainFeatureType.WALL, "Corner should be set to WALL")