@tool
extends RefCounted
class_name UnifiedTerrainSystem

## Unified Terrain System for Five Parsecs Campaign Manager
## Manages terrain generation, placement, and effects for battles

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal terrain_generated(terrain_data: Dictionary)
signal terrain_updated(position: Vector2i, terrain_type: int)

var terrain_grid: Dictionary = {}
var terrain_effects: Dictionary = {}

func _init() -> void:
	_initialize_terrain_effects()

## Initialize terrain effects database
func _initialize_terrain_effects() -> void:
	terrain_effects = {
		0: {"name": "Open", "cover": 0, "movement_cost": 1},
		1: {"name": "Light Cover", "cover": 1, "movement_cost": 1},
		2: {"name": "Heavy Cover", "cover": 2, "movement_cost": 1},
		3: {"name": "Difficult", "cover": 0, "movement_cost": 2}
	}

## Generate terrain for battlefield
func generate_terrain(size: Vector2i, density: float = 0.3) -> Dictionary:
	terrain_grid.clear()
	
	var terrain_count = int(size.x * size.y * density)
	for i in range(terrain_count):
		var pos = Vector2i(randi() % size.x, randi() % size.y)
		var terrain_type = randi() % 4
		terrain_grid[pos] = terrain_type
	
	var terrain_data = {
		"grid": terrain_grid,
		"size": size,
		"density": density
	}
	
	terrain_generated.emit(terrain_data)
	return terrain_data

## Get terrain at position
func get_terrain_at(position: Vector2i) -> int:
	return terrain_grid.get(position, 0)

## Set terrain at position
func set_terrain_at(position: Vector2i, terrain_type: int) -> void:
	terrain_grid[position] = terrain_type
	terrain_updated.emit(position, terrain_type)

## Get terrain effect data
func get_terrain_effects(terrain_type: int) -> Dictionary:
	return terrain_effects.get(terrain_type, terrain_effects[0])

## Clear all terrain
func clear_terrain() -> void:
	terrain_grid.clear()
