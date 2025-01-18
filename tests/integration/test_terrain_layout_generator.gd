@tool
extends "res://tests/test_base.gd"

# --- Constants ---
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainLayoutGenerator := preload("res://src/core/terrain/TerrainLayoutGenerator.gd")

# --- Variables ---
var _terrain_system: TerrainSystem
var _layout_generator: TerrainLayoutGenerator

# --- Test Lifecycle ---
func before_each() -> void:
    super.before_each()
    _terrain_system = TerrainSystem.new()
    add_child(_terrain_system)
    _terrain_system.initialize_grid(Vector2(10, 10))
    
    _layout_generator = TerrainLayoutGenerator.new(_terrain_system)
    add_child(_layout_generator)

func after_each() -> void:
    super.after_each()
    _terrain_system = null
    _layout_generator = null

# --- Tests ---
func test_open_layout_generation() -> void:
    _layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.OPEN)
    var terrain_features: Dictionary = _count_terrain_features()
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_LOW], 0, "Should have low cover")
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH], 0, "Should have high cover")
    assert_eq(terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should not have walls")

func test_dense_layout_generation() -> void:
    _layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.DENSE)
    var terrain_features: Dictionary = _count_terrain_features()
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH], 0, "Should have high cover")
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should have walls")

func test_asymmetric_layout_generation() -> void:
    _layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.ASYMMETRIC)
    var left_side: Dictionary = _count_terrain_features_in_region(Vector2.ZERO, Vector2(4, 9))
    var right_side: Dictionary = _count_terrain_features_in_region(Vector2(5, 0), Vector2(9, 9))
    assert_gt(left_side[TerrainSystem.TerrainFeatureType.COVER_HIGH], right_side[TerrainSystem.TerrainFeatureType.COVER_HIGH], "Left side should have more high cover")
    assert_gt(right_side[TerrainSystem.TerrainFeatureType.COVER_LOW], left_side[TerrainSystem.TerrainFeatureType.COVER_LOW], "Right side should have more low cover")

func test_corridor_layout_generation() -> void:
    _layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.CORRIDOR)
    var terrain_features: Dictionary = _count_terrain_features()
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should have walls")
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH], 0, "Should have high cover at choke points")

func test_scattered_layout_generation() -> void:
    _layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.SCATTERED)
    var terrain_features: Dictionary = _count_terrain_features()
    assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_LOW] +
             terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH] +
             terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should have terrain features")

func _count_terrain_features() -> Dictionary:
    var features := {}
    for feature_type in TerrainSystem.TerrainFeatureType.values():
        features[feature_type] = 0
    
    var grid_size := _terrain_system.get_grid_size()
    for x in range(int(grid_size.x)):
        for y in range(int(grid_size.y)):
            var feature_type := _terrain_system.get_terrain_type(Vector2(x, y))
            features[feature_type] += 1
    
    return features

func _count_terrain_features_in_region(start: Vector2, end: Vector2) -> Dictionary:
    var features := {}
    for feature_type in TerrainSystem.TerrainFeatureType.values():
        features[feature_type] = 0
    
    for x in range(int(start.x), int(end.x) + 1):
        for y in range(int(start.y), int(end.y) + 1):
            var feature_type := _terrain_system.get_terrain_type(Vector2(x, y))
            features[feature_type] += 1
    
    return features