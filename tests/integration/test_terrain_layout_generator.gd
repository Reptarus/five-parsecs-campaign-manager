@tool
extends "res://tests/fixtures/game_test.gd"

const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainLayoutGenerator := preload("res://src/core/terrain/TerrainLayoutGenerator.gd")

# Test variables
var terrain_system: Node # Using Node type since TerrainSystem extends Node
var layout_generator: Node # Using Node type since TerrainLayoutGenerator extends Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	track_test_node(terrain_system)
	terrain_system.initialize_grid(Vector2(10, 10))
	
	layout_generator = TerrainLayoutGenerator.new(terrain_system)
	add_child(layout_generator)
	track_test_node(layout_generator)
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	terrain_system = null
	layout_generator = null

# Helper Methods
func _count_terrain_features() -> Dictionary:
	var features = {
		TerrainSystem.TerrainFeatureType.COVER_LOW: 0,
		TerrainSystem.TerrainFeatureType.COVER_HIGH: 0,
		TerrainSystem.TerrainFeatureType.WALL: 0
	}
	
	for x in range(10):
		for y in range(10):
			var pos = Vector2(x, y)
			var feature = terrain_system.get_terrain_feature(pos)
			if feature in features:
				features[feature] += 1
	
	return features

func _count_terrain_features_in_region(start: Vector2, end: Vector2) -> Dictionary:
	var features = {
		TerrainSystem.TerrainFeatureType.COVER_LOW: 0,
		TerrainSystem.TerrainFeatureType.COVER_HIGH: 0,
		TerrainSystem.TerrainFeatureType.WALL: 0
	}
	
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			var pos = Vector2(x, y)
			var feature = terrain_system.get_terrain_feature(pos)
			if feature in features:
				features[feature] += 1
	
	return features

# Test Methods
func test_initial_state() -> void:
	assert_not_null(terrain_system, "Terrain system should be initialized")
	assert_not_null(layout_generator, "Layout generator should be initialized")
	assert_eq(terrain_system.get_grid_size(), Vector2(10, 10), "Grid should be initialized to correct size")

func test_open_layout() -> void:
	watch_signals(layout_generator)
	
	layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.OPEN)
	var terrain_features = _count_terrain_features()
	assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_LOW], 0, "Should have low cover")
	assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH], 0, "Should have high cover")
	assert_eq(terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should not have walls")
	assert_signal_emitted(layout_generator, "layout_generated")

func test_dense_layout() -> void:
	watch_signals(layout_generator)
	
	layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.DENSE)
	var terrain_features = _count_terrain_features()
	assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.COVER_HIGH], 0, "Should have high cover")
	assert_gt(terrain_features[TerrainSystem.TerrainFeatureType.WALL], 0, "Should have walls")
	assert_signal_emitted(layout_generator, "layout_generated")

func test_asymmetric_layout() -> void:
	watch_signals(layout_generator)
	
	layout_generator.generate_layout(TerrainLayoutGenerator.LayoutType.ASYMMETRIC)
	var left_side = _count_terrain_features_in_region(Vector2.ZERO, Vector2(4, 9))
	var right_side = _count_terrain_features_in_region(Vector2(5, 0), Vector2(9, 9))
	assert_gt(left_side[TerrainSystem.TerrainFeatureType.COVER_HIGH], right_side[TerrainSystem.TerrainFeatureType.COVER_HIGH], "Left side should have more high cover")
	assert_gt(right_side[TerrainSystem.TerrainFeatureType.COVER_LOW], left_side[TerrainSystem.TerrainFeatureType.COVER_LOW], "Right side should have more low cover")
	assert_signal_emitted(layout_generator, "layout_generated")