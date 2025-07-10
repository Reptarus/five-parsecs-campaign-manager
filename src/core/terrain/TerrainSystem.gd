## Core terrain system for Five Parsecs tactical battles
class_name TerrainSystem
extends RefCounted

const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

signal terrain_modified(position: Vector2, terrain_type: TerrainTypes.Type)
signal elevation_changed(position: Vector2, elevation: int)

var _terrain_grid: Array[Array] = []
var _elevation_grid: Array[Array] = []
var grid_width: int = 20
var grid_height: int = 20

func _init(width: int = 20, height: int = 20) -> void:
	grid_width = width
	grid_height = height
	_initialize_grids()

func _initialize_grids() -> void:
	_terrain_grid.clear()
	_elevation_grid.clear()

	for x: int in range(grid_width):
		safe_call_method(_terrain_grid, "append", [[]])  # warning: return value discarded (intentional)
		safe_call_method(_elevation_grid, "append", [[]])  # warning: return value discarded (intentional)
		for y: int in range(grid_height):
			_terrain_grid[x].append(TerrainTypes.Type.OPEN)
			_elevation_grid[x].append(0)

## Set terrain type at position
func set_terrain(position: Vector2i, terrain_type: TerrainTypes.Type) -> void:
	if _is_valid_position(position):
		_terrain_grid[position.x][position.y] = terrain_type
		terrain_modified.emit(position, terrain_type)  # warning: return value discarded (intentional)

## Get terrain _type at position
func get_terrain(position: Vector2i) -> TerrainTypes.Type:
	if _is_valid_position(position):
		return _terrain_grid[position.x][position.y]
	return TerrainTypes.Type.OPEN

## Private method for compatibility
func _get_terrain_at(position: Vector2) -> TerrainTypes.Type:
	return get_terrain(Vector2i(position))

## Set elevation at position
func set_elevation(position: Vector2i, elevation: int) -> void:
	if _is_valid_position(position):
		_elevation_grid[position.x][position.y] = elevation
		elevation_changed.emit(position, elevation)

## Get elevation at position
func get_elevation(position: Vector2) -> int:
	var pos = Vector2i(position)
	if _is_valid_position(pos):
		return _elevation_grid[pos.x][pos.y]
	return 0

## Get all terrain features as dictionary
func get_terrain_features() -> Dictionary:
	var features: Dictionary = {}
	for x: int in range(grid_width):
		for y: int in range(grid_height):
			var pos = Vector2i(x, y)
			var terrain_type = _terrain_grid[x][y]
			if terrain_type != TerrainTypes.Type.OPEN:
				features[pos] = terrain_type
	return features

## Check if position is valid
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < grid_width and position.y >= 0 and position.y < grid_height

## Generate random terrain layout
func generate_terrain_layout(feature_count: int = 10) -> void:
	for i: int in range(feature_count):
		var x = randi_range(0, grid_width - 1)
		var y = randi_range(0, grid_height - 1)
		var terrain_type = randi_range(1, TerrainTypes.Type.size() - 1) as TerrainTypes.Type
		set_terrain(Vector2i(x, y), terrain_type)

## Clear all terrain

func clear_terrain() -> void:
	_initialize_grids()

## Serialize terrain data

func serialize() -> Dictionary:
	return {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"terrain_grid": _terrain_grid,
		"elevation_grid": _elevation_grid
	}

## Deserialize terrain data
func deserialize(data: Dictionary) -> void:
	grid_width = data.get("grid_width", 20)
	grid_height = data.get("grid_height", 20)
	_terrain_grid = data.get("terrain_grid", [])
	_elevation_grid = data.get("elevation_grid", [])

	if (safe_call_method(_terrain_grid, "is_empty") == true):
		_initialize_grids()

		_initialize_grids()
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null