@tool
extends "res://tests/fixtures/base/base_test.gd"

const TerrainLayoutGenerator = preload("res://src/core/terrain/TerrainLayoutGenerator.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")

var generator
var terrain_system
var position_validator

func before_each() -> void:
	await super.before_each()
	
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	track_test_node(terrain_system)
	terrain_system.initialize_grid(Vector2(10, 10))
	
	position_validator = PositionValidator.new()
	add_child(position_validator)
	track_test_node(position_validator)
	
	generator = TerrainLayoutGenerator.new(terrain_system)
	add_child(generator)
	track_test_node(generator)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	generator = null
	terrain_system = null
	position_validator = null

func test_initial_state() -> void:
	assert_not_null(generator, "Generator should be initialized")
	assert_not_null(terrain_system, "Terrain system should be initialized")
	assert_not_null(position_validator, "Position validator should be initialized")

func test_generate_layout() -> void:
	watch_signals(generator)
	
	generator.generate_layout(TerrainLayoutGenerator.LayoutType.OPEN)
	var grid_size = terrain_system.get_grid_size()
	assert_eq(grid_size, Vector2(10, 10), "Grid size should match")
	assert_signal_emitted(terrain_system, "terrain_modified")

func test_validate_layout() -> void:
	watch_signals(generator)
	
	generator.generate_layout(TerrainLayoutGenerator.LayoutType.OPEN)
	var grid_size = terrain_system.get_grid_size()
	assert_eq(grid_size, Vector2(10, 10), "Grid size should match")
	
	# Check that some terrain features were placed
	var has_features = false
	for x in range(10):
		for y in range(10):
			if terrain_system.get_terrain_type(Vector2(x, y)) != TerrainSystem.TerrainFeatureType.NONE:
				has_features = true
				break
		if has_features:
			break
	
	assert_true(has_features, "Layout should have terrain features")
