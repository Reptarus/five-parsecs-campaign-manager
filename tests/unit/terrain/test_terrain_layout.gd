@tool
extends "res://tests/fixtures/base_test.gd"

const TerrainLayoutNode := preload("res://src/core/terrain/TerrainLayoutNode.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")

var _terrain_layout: TerrainLayoutNode
var _terrain_system: TerrainSystem
var _test_size := Vector2i(10, 10)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	_terrain_system = TerrainSystem.new()
	_terrain_layout = TerrainLayoutNode.new(_terrain_system)
	_terrain_layout.initialize(_test_size)
	add_child(_terrain_system)
	add_child(_terrain_layout)
	track_test_node(_terrain_system)
	track_test_node(_terrain_layout)
	watch_signals(_terrain_system)
	watch_signals(_terrain_layout)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(_terrain_layout):
		_terrain_layout.queue_free()
		_terrain_layout = null
	if is_instance_valid(_terrain_system):
		_terrain_system.queue_free()
		_terrain_system = null

# Initialization Tests
func test_terrain_layout_initialization() -> void:
	assert_not_null(_terrain_layout, "Terrain layout should be created")
	assert_eq(_terrain_layout.get_size(), _test_size, "Terrain size should match")
	assert_true(_terrain_layout.is_inside_tree(), "Terrain layout should be in scene tree")

# Position and Cell Tests
func test_terrain_cell_access() -> void:
	var test_pos = Vector2i(5, 5)
	assert_true(_terrain_layout.is_valid_position(test_pos), "Position should be valid")
	
	var cell = _terrain_layout.get_cell(test_pos)
	assert_not_null(cell, "Should get valid cell")
	assert_eq(cell.terrain_type, TerrainSystem.TerrainFeatureType.NONE, "New cell should be empty")

func test_terrain_boundaries() -> void:
	assert_false(_terrain_layout.is_valid_position(Vector2i(-1, 0)), "Negative x should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(0, -1)), "Negative y should be invalid")
	assert_false(_terrain_layout.is_valid_position(_test_size), "Position at size should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(_test_size.x + 1, 0)), "Position beyond x should be invalid")
	assert_false(_terrain_layout.is_valid_position(Vector2i(0, _test_size.y + 1)), "Position beyond y should be invalid")

# Adjacent Position Tests
func test_get_adjacent_positions() -> void:
	var test_pos := Vector2i(5, 5)
	var adjacent_positions = _terrain_layout.get_adjacent_positions(test_pos)
	
	var expected_positions = [
		Vector2i(4, 5), Vector2i(6, 5),
		Vector2i(5, 4), Vector2i(5, 6)
	]
	
	assert_eq(adjacent_positions.size(), 4, "Should have 4 adjacent positions")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos, "Should contain expected adjacent position " + str(pos))

func test_get_adjacent_positions_at_edge() -> void:
	var edge_pos := Vector2i(0, 0)
	var adjacent_positions = _terrain_layout.get_adjacent_positions(edge_pos)
	
	var expected_positions = [
		Vector2i(1, 0), Vector2i(0, 1)
	]
	
	assert_eq(adjacent_positions.size(), 2, "Should have 2 adjacent positions at corner")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos, "Should contain expected adjacent position " + str(pos))

func test_get_adjacent_positions_with_features() -> void:
	# Set up some terrain features
	_terrain_layout.place_feature(Vector2i(5, 5), GameEnums.TerrainFeatureType.WALL)
	_terrain_layout.place_feature(Vector2i(5, 6), GameEnums.TerrainFeatureType.COVER)
	
	var test_pos := Vector2i(5, 4)
	var adjacent_positions = _terrain_layout.get_adjacent_positions(test_pos)
	
	assert_eq(adjacent_positions.size(), 3, "Should have 3 adjacent positions")
	assert_has(adjacent_positions, Vector2i(4, 4), "Should have left position")
	assert_has(adjacent_positions, Vector2i(6, 4), "Should have right position")
	assert_has(adjacent_positions, Vector2i(5, 3), "Should have up position")
	assert_does_not_have(adjacent_positions, Vector2i(5, 5), "Should not have position with wall")
	
	assert_signal_emitted(_terrain_system, "terrain_feature_changed")

# Feature Tests
func test_terrain_feature_placement() -> void:
	var test_pos = Vector2i(3, 3)
	
	# Test all terrain feature types
	var feature_types = [
		GameEnums.TerrainFeatureType.COVER,
		GameEnums.TerrainFeatureType.COVER,
		GameEnums.TerrainFeatureType.OBSTACLE,
		GameEnums.TerrainFeatureType.HAZARD,
		GameEnums.TerrainFeatureType.OBJECTIVE,
		GameEnums.TerrainFeatureType.WALL,
		GameEnums.TerrainFeatureType.SPECIAL,
		GameEnums.TerrainFeatureType.SPECIAL,
		GameEnums.TerrainFeatureType.SPECIAL
	]
	
	for feature_type in feature_types:
		_terrain_layout.place_feature(test_pos, feature_type)
		var cell = _terrain_layout.get_cell(test_pos)
		assert_eq(cell.feature, feature_type,
			"Feature %s should be placed correctly" % GameEnums.TerrainFeatureType.keys()[feature_type])
		assert_signal_emitted(_terrain_system, "terrain_feature_changed")

# Line of Sight Tests
func test_terrain_line_of_sight() -> void:
	var start = Vector2i(0, 0)
	var end = Vector2i(9, 9)
	
	var los = _terrain_layout.get_line_of_sight(start, end)
	assert_not_null(los, "Should get valid line of sight")
	assert_true(los.size() > 0, "Line of sight should contain points")
	
	# Test with each blocking feature type
	var blocking_features = [
		GameEnums.TerrainFeatureType.WALL,
		GameEnums.TerrainFeatureType.COVER,
		GameEnums.TerrainFeatureType.OBSTACLE
	]
	
	var mid_point = Vector2i(5, 5)
	for feature in blocking_features:
		_terrain_layout.place_feature(mid_point, feature)
		los = _terrain_layout.get_line_of_sight(start, end)
		assert_true(los.has(mid_point),
			"Line of sight should include blocking point for feature: %s" % GameEnums.TerrainFeatureType.keys()[feature])
		assert_true(_terrain_layout.is_line_of_sight_blocked(start, end),
			"Line of sight should be blocked by feature: %s" % GameEnums.TerrainFeatureType.keys()[feature])

# Modifier Tests
func test_terrain_modifiers() -> void:
	var test_pos = Vector2i(4, 4)
	
	# Test terrain modifiers for different feature types
	var modifier_tests = {
		GameEnums.TerrainFeatureType.OBSTACLE: GameEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GameEnums.TerrainFeatureType.HAZARD: GameEnums.TerrainModifier.HAZARDOUS,
		GameEnums.TerrainFeatureType.WALL: GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED,
		GameEnums.TerrainFeatureType.COVER: GameEnums.TerrainModifier.COVER_BONUS,
		GameEnums.TerrainFeatureType.SPECIAL: GameEnums.TerrainModifier.ELEVATION_BONUS
	}
	
	for feature in modifier_tests:
		_terrain_layout.place_feature(test_pos, feature)
		var modifiers = _terrain_layout.get_cell_modifiers(test_pos)
		assert_true(modifiers.has(modifier_tests[feature]),
			"Feature %s should apply modifier %s" % [
				GameEnums.TerrainFeatureType.keys()[feature],
				GameEnums.TerrainModifier.keys()[modifier_tests[feature]]
			])
		assert_signal_emitted(_terrain_system, "terrain_feature_changed")