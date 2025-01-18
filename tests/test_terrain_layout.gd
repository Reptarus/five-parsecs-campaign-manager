@tool
extends "res://tests/test_base.gd"

const TerrainLayout = preload("res://src/core/terrain/TerrainLayout.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")

var _terrain_layout: TerrainLayout
var _test_size := Vector2i(10, 10)
var _terrain_system: TerrainSystem

func before_each() -> void:
	await super.before_each()
	_terrain_system = TerrainSystem.new()
	_terrain_layout = TerrainLayout.new(_terrain_system)
	_terrain_layout.initialize(_test_size)
	track_test_node(_terrain_layout)

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(_terrain_layout):
		_terrain_layout.queue_free()
		_terrain_layout = null
	if is_instance_valid(_terrain_system):
		_terrain_system.queue_free()
		_terrain_system = null

func test_terrain_layout_initialization() -> void:
	assert_not_null(_terrain_layout, "Terrain layout should be created")
	assert_eq(_terrain_layout.get_size(), _test_size, "Terrain size should match")
	assert_true(_terrain_layout.is_inside_tree(), "Terrain layout should be in scene tree")

func test_terrain_cell_access() -> void:
	var test_pos = Vector2i(5, 5)
	assert_true(_terrain_layout.is_valid_position(test_pos), "Position should be valid")
	
	var cell = _terrain_layout.get_cell(test_pos)
	assert_not_null(cell, "Should get valid cell")
	assert_eq(cell.terrain_type, TerrainSystem.TerrainFeatureType.NONE, "New cell should be empty")

func test_terrain_feature_placement() -> void:
	var test_pos = Vector2i(3, 3)
	var feature_type = TerrainSystem.TerrainFeatureType.COVER_HIGH
	
	_terrain_layout.place_feature(test_pos, feature_type)
	var cell = _terrain_layout.get_cell(test_pos)
	assert_eq(cell.feature, feature_type, "Feature should be placed correctly")

func test_terrain_boundaries() -> void:
	assert_false(_terrain_layout.is_valid_position(Vector2i(-1, 0)), "Negative x should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(0, -1)), "Negative y should be invalid")
	assert_false(_terrain_layout.is_valid_position(_test_size), "Position at size should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(_test_size.x + 1, 0)), "Position beyond x should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(0, _test_size.y + 1)), "Position beyond y should be invalid")

func test_terrain_neighbors() -> void:
	var center = Vector2i(5, 5)
	var neighbors = _terrain_layout.get_neighbors(center)
	assert_eq(neighbors.size(), 8, "Should have 8 neighbors for center position")
	
	var corner = Vector2i(0, 0)
	neighbors = _terrain_layout.get_neighbors(corner)
	assert_eq(neighbors.size(), 3, "Corner should have 3 neighbors")

func test_terrain_line_of_sight() -> void:
	var start = Vector2i(0, 0)
	var end = Vector2i(9, 9)
	
	var los = _terrain_layout.get_line_of_sight(start, end)
	assert_not_null(los, "Should get valid line of sight")
	assert_true(los.size() > 0, "Line of sight should contain points")
	
	# Test with blocking feature
	var mid_point = Vector2i(5, 5)
	_terrain_layout.place_feature(mid_point, TerrainSystem.TerrainFeatureType.WALL)
	los = _terrain_layout.get_line_of_sight(start, end)
	assert_true(los.has(mid_point), "Line of sight should include blocking point")
	assert_true(_terrain_layout.is_line_of_sight_blocked(start, end), "Line of sight should be blocked")