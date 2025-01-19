@tool
extends "res://tests/fixtures/game_test.gd"

const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")

# Test variables
var terrain_system: Node # Using Node type to avoid casting issues

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
func test_terrain_effect_application() -> void:
	watch_signals(terrain_system)
	
	var target = Node2D.new()
	add_child(target)
	track_test_node(target)
	
	terrain_system.apply_terrain_effect(target, GameEnums.TerrainFeatureType.COVER_HIGH)
	assert_signal_emitted(terrain_system, "effect_applied")
	
	terrain_system.remove_terrain_effect(target)
	assert_signal_emitted(terrain_system, "effect_removed")

func test_multiple_effects() -> void:
	watch_signals(terrain_system)
	
	var target1 = Node2D.new()
	var target2 = Node2D.new()
	add_child(target1)
	add_child(target2)
	track_test_node(target1)
	track_test_node(target2)
	
	terrain_system.apply_terrain_effect(target1, GameEnums.TerrainFeatureType.COVER_HIGH)
	terrain_system.apply_terrain_effect(target2, GameEnums.TerrainFeatureType.COVER_LOW)
	
	assert_eq(terrain_system.get_active_effects().size(), 2, "Should have two active effects")
	
	terrain_system.remove_terrain_effect(target1)
	assert_eq(terrain_system.get_active_effects().size(), 1, "Should have one active effect")
	
	terrain_system.remove_terrain_effect(target2)
	assert_eq(terrain_system.get_active_effects().size(), 0, "Should have no active effects")