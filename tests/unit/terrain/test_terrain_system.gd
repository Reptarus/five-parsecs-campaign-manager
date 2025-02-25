@tool
extends "res://tests/fixtures/base/game_test.gd"

const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")
const TerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")

# Test variables
var terrain_system: TerrainSystem

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	track_test_node(terrain_system)

func after_each() -> void:
	await super.after_each()
	terrain_system = null

# Test Methods
func test_initialize_grid() -> void:
	var size := Vector2(10, 10)
	terrain_system.initialize_grid(size)
	assert_eq(terrain_system.get_grid_size(), size)

func test_set_and_get_terrain_type() -> void:
	var size := Vector2(10, 10)
	terrain_system.initialize_grid(size)
	var test_pos := Vector2(5, 5)
	var test_type := TerrainSystem.TerrainFeatureType.HIGH_GROUND
	
	terrain_system.set_terrain_feature(test_pos, test_type)
	assert_eq(terrain_system.get_terrain_type(test_pos), test_type)

func test_invalid_position() -> void:
	var size := Vector2(10, 10)
	terrain_system.initialize_grid(size)
	var invalid_pos := Vector2(-1, -1)
	
	assert_eq(terrain_system.get_terrain_type(invalid_pos), TerrainSystem.TerrainFeatureType.NONE)

func test_grid_size() -> void:
	assert_eq(terrain_system.get_grid_size(), Vector2.ZERO)
	
	var size := Vector2(5, 8)
	terrain_system.initialize_grid(size)
	assert_eq(terrain_system.get_grid_size(), size)

func test_terrain_effect_application() -> void:
	var target := Node2D.new()
	add_child(target)
	track_test_node(target)
	
	terrain_system.apply_terrain_effect(target, TerrainSystem.TerrainFeatureType.HIGH_GROUND)
	assert_signal_emitted(terrain_system, "effect_applied")
	
	terrain_system.remove_terrain_effect(target)
	assert_signal_emitted(terrain_system, "effect_removed")

func test_multiple_effects() -> void:
	var target1 := Node2D.new()
	var target2 := Node2D.new()
	add_child(target1)
	add_child(target2)
	track_test_node(target1)
	track_test_node(target2)
	
	terrain_system.apply_terrain_effect(target1, TerrainSystem.TerrainFeatureType.HIGH_GROUND)
	terrain_system.apply_terrain_effect(target2, TerrainSystem.TerrainFeatureType.COVER_LOW)
	
	assert_eq(terrain_system.get_active_effects().size(), 2, "Should have two active effects")
	
	terrain_system.remove_terrain_effect(target1)
	assert_eq(terrain_system.get_active_effects().size(), 1, "Should have one active effect")
	
	terrain_system.remove_terrain_effect(target2)
	assert_eq(terrain_system.get_active_effects().size(), 0, "Should have no active effects")