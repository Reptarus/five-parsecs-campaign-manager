@tool
extends "res://tests/test_base.gd"

const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainLayout := preload("res://src/core/terrain/TerrainLayout.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var terrain_system: Node
var terrain_layout: Node

func before_each() -> void:
	super.before_each()
	terrain_system = TerrainSystem.new()
	terrain_system.initialize_grid(Vector2(10, 10))
	terrain_layout = TerrainLayout.new(terrain_system)
	add_child(terrain_system)
	add_child(terrain_layout)

func after_each() -> void:
	super.after_each()
	terrain_system = null
	terrain_layout = null

func test_get_adjacent_positions() -> void:
	var test_pos := Vector2(5, 5)
	var adjacent_positions: Array[Vector2] = terrain_layout._get_adjacent_positions(test_pos, terrain_system)
	
	var expected_positions := [
		Vector2(4, 5), Vector2(6, 5),
		Vector2(5, 4), Vector2(5, 6)
	]
	
	assert_eq(adjacent_positions.size(), 4, "Should have 4 adjacent positions")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos, "Should contain expected adjacent position " + str(pos))

func test_get_adjacent_positions_at_edge() -> void:
	var edge_pos := Vector2(0, 0)
	var adjacent_positions: Array[Vector2] = terrain_layout._get_adjacent_positions(edge_pos, terrain_system)
	
	var expected_positions := [
		Vector2(1, 0), Vector2(0, 1)
	]
	
	assert_eq(adjacent_positions.size(), 2, "Should have 2 adjacent positions at corner")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos, "Should contain expected adjacent position " + str(pos))

func test_is_valid_position() -> void:
	# Test valid positions
	assert_true(terrain_layout._is_valid_position(Vector2(0, 0), terrain_system), "Origin should be valid")
	assert_true(terrain_layout._is_valid_position(Vector2(5, 5), terrain_system), "Center should be valid")
	assert_true(terrain_layout._is_valid_position(Vector2(9, 9), terrain_system), "Far corner should be valid")
	
	# Test invalid positions
	assert_false(terrain_layout._is_valid_position(Vector2(-1, 0), terrain_system), "Negative x should be invalid")
	assert_false(terrain_layout._is_valid_position(Vector2(0, -1), terrain_system), "Negative y should be invalid")
	assert_false(terrain_layout._is_valid_position(Vector2(10, 0), terrain_system), "Out of bounds x should be invalid")
	assert_false(terrain_layout._is_valid_position(Vector2(0, 10), terrain_system), "Out of bounds y should be invalid")

func test_get_adjacent_positions_with_features() -> void:
	# Set up some terrain features
	terrain_system.set_terrain_feature(Vector2(5, 5), GameEnums.TerrainFeatureType.WALL)
	terrain_system.set_terrain_feature(Vector2(5, 6), GameEnums.TerrainFeatureType.COVER_HIGH)
	
	var test_pos := Vector2(5, 4)
	var adjacent_positions: Array[Vector2] = terrain_layout._get_adjacent_positions(test_pos, terrain_system)
	
	assert_eq(adjacent_positions.size(), 3, "Should have 3 adjacent positions")
	assert_has(adjacent_positions, Vector2(4, 4), "Should have left position")
	assert_has(adjacent_positions, Vector2(6, 4), "Should have right position")
	assert_has(adjacent_positions, Vector2(5, 3), "Should have up position")
	assert_does_not_have(adjacent_positions, Vector2(5, 5), "Should not have position with wall")