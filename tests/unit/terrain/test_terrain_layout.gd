@tool
extends GameTest

# Type-safe constants with explicit typing
const TerrainLayoutNode: GDScript = preload("res://src/core/terrain/TerrainLayoutNode.gd")
const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")

# Type-safe enums
enum TerrainFeatureType {
	NONE = 0,
	COVER = 1,
	OBSTACLE = 2,
	HAZARD = 3,
	OBJECTIVE = 4,
	WALL = 5,
	SPECIAL = 6
}

enum TerrainModifier {
	NONE = 0,
	DIFFICULT_TERRAIN = 1,
	HAZARDOUS = 2,
	LINE_OF_SIGHT_BLOCKED = 3,
	COVER_BONUS = 4,
	ELEVATION_BONUS = 5
}

# Type-safe instance variables
var _terrain_layout: Node = null
var _terrain_system: Node = null
var _test_size: Vector2i = Vector2i(10, 10)

# Type-safe signal tracking
var _feature_changed_emitted: bool = false
var _last_feature_data: Dictionary = {
	"position": Vector2i() as Vector2i,
	"feature_type": TerrainFeatureType.NONE as int,
	"old_feature_type": TerrainFeatureType.NONE as int
}

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize terrain system with type safety
	_terrain_system = TerrainSystem.new()
	if not _terrain_system:
		push_error("Failed to create terrain system")
		return
	add_child_autofree(_terrain_system)
	
	# Initialize terrain layout with type safety
	_terrain_layout = TerrainLayoutNode.new(_terrain_system)
	if not _terrain_layout:
		push_error("Failed to create terrain layout")
		return
	_terrain_layout.initialize(_test_size)
	add_child_autofree(_terrain_layout)
	
	# Setup signal watching
	_connect_signals()
	
	await get_tree().process_frame

func after_each() -> void:
	_cleanup_terrain()
	await super.after_each()

# Type-safe cleanup methods
func _cleanup_terrain() -> void:
	if _signal_watcher:
		_signal_watcher.clear()
	
	_terrain_layout = null
	_terrain_system = null
	_reset_feature_data()

func _reset_feature_data() -> void:
	_feature_changed_emitted = false
	_last_feature_data = {
		"position": Vector2i() as Vector2i,
		"feature_type": TerrainFeatureType.NONE as int,
		"old_feature_type": TerrainFeatureType.NONE as int
	}

# Type-safe signal management
func _connect_signals() -> void:
	if not _terrain_system or not _terrain_layout:
		push_error("Cannot connect signals: Terrain components are null")
		return
	
	if _signal_watcher:
		_signal_watcher.watch_signals(_terrain_system)
		_signal_watcher.watch_signals(_terrain_layout)

# Type-safe signal handlers
func _on_feature_changed(position: Vector2i, feature_type: int, old_feature_type: int) -> void:
	_feature_changed_emitted = true
	_last_feature_data["position"] = position
	_last_feature_data["feature_type"] = feature_type
	_last_feature_data["old_feature_type"] = old_feature_type

# Type-safe helper methods
func _get_cell_safe(position: Vector2i) -> Dictionary:
	if not _terrain_layout or not _terrain_layout.has_method("get_cell"):
		push_error("Invalid terrain layout or missing get_cell method")
		return {}
	
	if not _terrain_layout.is_valid_position(position):
		push_error("Invalid position: %s" % str(position))
		return {}
	
	var cell: Dictionary = _terrain_layout.get_cell(position)
	if not cell:
		push_error("Failed to get cell at position: %s" % str(position))
		return {}
	
	return cell

func _place_feature_safe(position: Vector2i, feature_type: int) -> bool:
	if not _terrain_layout or not _terrain_layout.has_method("place_feature"):
		push_error("Invalid terrain layout or missing place_feature method")
		return false
	
	if not _terrain_layout.is_valid_position(position):
		push_error("Invalid position for feature placement: %s" % str(position))
		return false
	
	if feature_type < TerrainFeatureType.NONE or feature_type > TerrainFeatureType.SPECIAL:
		push_error("Invalid feature type: %d" % feature_type)
		return false
	
	return _terrain_layout.place_feature(position, feature_type)

func _verify_feature_change(position: Vector2i, feature_type: int, old_feature_type: int, message: String) -> void:
	assert_true(_feature_changed_emitted, "Feature changed signal should be emitted: %s" % message)
	assert_eq(_last_feature_data["position"], position, "Position should match: %s" % message)
	assert_eq(_last_feature_data["feature_type"], feature_type, "Feature type should match: %s" % message)
	assert_eq(_last_feature_data["old_feature_type"], old_feature_type, "Old feature type should match: %s" % message)

# Type-safe test cases
func test_terrain_layout_initialization() -> void:
	assert_not_null(_terrain_layout, "Terrain layout should be created")
	assert_not_null(_terrain_system, "Terrain system should be created")
	assert_eq(_terrain_layout.get_size(), _test_size, "Terrain size should match")
	assert_true(_terrain_layout.is_inside_tree(), "Terrain layout should be in scene tree")

func test_terrain_cell_access() -> void:
	const TEST_POS := Vector2i(5, 5)
	assert_true(_terrain_layout.is_valid_position(TEST_POS), "Position should be valid")
	
	var cell := _get_cell_safe(TEST_POS)
	assert_not_null(cell, "Should get valid cell")
	assert_eq(cell.get("terrain_type", -1), TerrainFeatureType.NONE,
		"New cell should be empty")

func test_terrain_boundaries() -> void:
	var invalid_positions: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(_test_size.x, _test_size.y),
		Vector2i(_test_size.x + 1, 0),
		Vector2i(0, _test_size.y + 1)
	]
	
	for pos in invalid_positions:
		assert_false(_terrain_layout.is_valid_position(pos),
			"Position %s should be invalid" % str(pos))

func test_get_adjacent_positions() -> void:
	const TEST_POS := Vector2i(5, 5)
	var adjacent_positions: Array = _terrain_layout.get_adjacent_positions(TEST_POS)
	
	var expected_positions: Array[Vector2i] = [
		Vector2i(4, 5), Vector2i(6, 5),
		Vector2i(5, 4), Vector2i(5, 6)
	]
	
	assert_eq(adjacent_positions.size(), 4, "Should have 4 adjacent positions")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos,
			"Should contain expected adjacent position %s" % str(pos))

func test_get_adjacent_positions_at_edge() -> void:
	const EDGE_POS := Vector2i(0, 0)
	var adjacent_positions: Array = _terrain_layout.get_adjacent_positions(EDGE_POS)
	
	var expected_positions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1)
	]
	
	assert_eq(adjacent_positions.size(), 2, "Should have 2 adjacent positions at corner")
	for pos in expected_positions:
		assert_has(adjacent_positions, pos,
			"Should contain expected adjacent position %s" % str(pos))

func test_feature_placement() -> void:
	const TEST_POS := Vector2i(3, 3)
	const OLD_TYPE := TerrainFeatureType.NONE
	
	# Test all feature types
	var feature_types: Array[int] = [
		TerrainFeatureType.COVER,
		TerrainFeatureType.OBSTACLE,
		TerrainFeatureType.HAZARD,
		TerrainFeatureType.OBJECTIVE,
		TerrainFeatureType.WALL,
		TerrainFeatureType.SPECIAL
	]
	
	for feature_type in feature_types:
		_reset_feature_data()
		assert_true(_place_feature_safe(TEST_POS, feature_type),
			"Should successfully place feature %d" % feature_type)
		
		var cell := _get_cell_safe(TEST_POS)
		assert_eq(cell.get("feature_type", -1), feature_type,
			"Feature %d should be placed correctly" % feature_type)
		
		_verify_feature_change(TEST_POS, feature_type, OLD_TYPE,
			"Feature %d placement" % feature_type)

func test_feature_placement_with_blocking() -> void:
	const TEST_POS := Vector2i(5, 5)
	const ADJACENT_POS := Vector2i(5, 6)
	const OLD_TYPE := TerrainFeatureType.NONE
	
	# Place a wall feature
	assert_true(_place_feature_safe(TEST_POS, TerrainFeatureType.WALL),
		"Should place wall feature")
	_verify_feature_change(TEST_POS, TerrainFeatureType.WALL, OLD_TYPE,
		"Wall placement")
	
	# Place a cover feature adjacent to wall
	assert_true(_place_feature_safe(ADJACENT_POS, TerrainFeatureType.COVER),
		"Should place cover feature")
	_verify_feature_change(ADJACENT_POS, TerrainFeatureType.COVER, OLD_TYPE,
		"Cover placement")
	
	# Verify adjacent positions
	var adjacent_positions: Array = _terrain_layout.get_adjacent_positions(Vector2i(5, 4))
	assert_eq(adjacent_positions.size(), 3, "Should have 3 adjacent positions")
	assert_does_not_have(adjacent_positions, TEST_POS,
		"Should not include wall position in adjacent positions")

func test_line_of_sight() -> void:
	const START_POS := Vector2i(0, 0)
	const END_POS := Vector2i(9, 9)
	const MID_POS := Vector2i(5, 5)
	const OLD_TYPE := TerrainFeatureType.NONE
	
	# Test initial line of sight
	var los: Array = _terrain_layout.get_line_of_sight(START_POS, END_POS)
	assert_not_null(los, "Should get valid line of sight")
	assert_true(los.size() > 0, "Line of sight should contain points")
	
	# Test blocking features
	var blocking_features: Array[int] = [
		TerrainFeatureType.WALL,
		TerrainFeatureType.COVER,
		TerrainFeatureType.OBSTACLE
	]
	
	for feature_type in blocking_features:
		_reset_feature_data()
		assert_true(_place_feature_safe(MID_POS, feature_type),
			"Should place blocking feature %d" % feature_type)
		
		los = _terrain_layout.get_line_of_sight(START_POS, END_POS)
		assert_true(los.has(MID_POS),
			"Line of sight should include blocking point for feature %d" % feature_type)
		assert_true(_terrain_layout.is_line_of_sight_blocked(START_POS, END_POS),
			"Line of sight should be blocked by feature %d" % feature_type)
		
		_verify_feature_change(MID_POS, feature_type, OLD_TYPE,
			"Blocking feature %d placement" % feature_type)

func test_terrain_modifiers() -> void:
	const TEST_POS := Vector2i(4, 4)
	const OLD_TYPE := TerrainFeatureType.NONE
	
	# Define modifier tests with type safety
	var modifier_tests: Dictionary = {
		TerrainFeatureType.OBSTACLE: TerrainModifier.DIFFICULT_TERRAIN,
		TerrainFeatureType.HAZARD: TerrainModifier.HAZARDOUS,
		TerrainFeatureType.WALL: TerrainModifier.LINE_OF_SIGHT_BLOCKED,
		TerrainFeatureType.COVER: TerrainModifier.COVER_BONUS,
		TerrainFeatureType.SPECIAL: TerrainModifier.ELEVATION_BONUS
	}
	
	for feature_type in modifier_tests:
		_reset_feature_data()
		assert_true(_place_feature_safe(TEST_POS, feature_type),
			"Should place feature %d" % feature_type)
		
		var modifiers: Array = _terrain_layout.get_cell_modifiers(TEST_POS)
		assert_true(modifiers.has(modifier_tests[feature_type]),
			"Feature %d should apply modifier %d" % [feature_type, modifier_tests[feature_type]])
		
		_verify_feature_change(TEST_POS, feature_type, OLD_TYPE,
			"Feature %d placement for modifier test" % feature_type)

func test_feature_removal() -> void:
	const TEST_POS := Vector2i(4, 4)
	const FEATURE_TYPE := TerrainFeatureType.WALL
	const OLD_TYPE := TerrainFeatureType.NONE
	
	# Place feature
	assert_true(_place_feature_safe(TEST_POS, FEATURE_TYPE),
		"Should place feature")
	_verify_feature_change(TEST_POS, FEATURE_TYPE, OLD_TYPE,
		"Feature placement")
	
	# Remove feature
	_reset_feature_data()
	assert_true(_place_feature_safe(TEST_POS, TerrainFeatureType.NONE),
		"Should remove feature")
	_verify_feature_change(TEST_POS, TerrainFeatureType.NONE, FEATURE_TYPE,
		"Feature removal")
	
	# Verify cell state
	var cell := _get_cell_safe(TEST_POS)
	assert_eq(cell.get("feature_type", -1), TerrainFeatureType.NONE,
		"Cell should be empty after feature removal")

func test_feature_replacement() -> void:
	const TEST_POS := Vector2i(4, 4)
	const INITIAL_TYPE := TerrainFeatureType.WALL
	const NEW_TYPE := TerrainFeatureType.COVER
	
	# Place initial feature
	assert_true(_place_feature_safe(TEST_POS, INITIAL_TYPE),
		"Should place initial feature")
	_verify_feature_change(TEST_POS, INITIAL_TYPE, TerrainFeatureType.NONE,
		"Initial feature placement")
	
	# Replace feature
	_reset_feature_data()
	assert_true(_place_feature_safe(TEST_POS, NEW_TYPE),
		"Should replace feature")
	_verify_feature_change(TEST_POS, NEW_TYPE, INITIAL_TYPE,
		"Feature replacement")
	
	# Verify cell state
	var cell := _get_cell_safe(TEST_POS)
	assert_eq(cell.get("feature_type", -1), NEW_TYPE,
		"Cell should have new feature type")