@tool
extends RefCounted
class_name BattlefieldDisplayManager

## Simple battlefield display manager for Five Parsecs battles
##
## Handles visual representation of the battlefield

signal battlefield_updated(grid_size: Vector2i)
signal unit_positioned(unit: Node, position: Vector2i)
signal terrain_updated(position: Vector2i, terrain_type: int)

var grid_size: Vector2i = Vector2i(24, 24)
var cell_size: Vector2 = Vector2(32, 32)
var battlefield_origin: Vector2 = Vector2.ZERO
var units: Dictionary = {}
var terrain_grid: Dictionary = {}

func _init() -> void:
	_initialize_battlefield()

func _initialize_battlefield() -> void:
	# Clear existing data
	units.clear()
	terrain_grid.clear()

	# Initialize empty terrain grid
	for x: int in range(grid_size.x):
		for y: int in range(grid_size.y):
			terrain_grid[Vector2i(x, y)] = 0 # 0 = open terrain

## Set battlefield grid size
func set_grid_size(new_size: Vector2i) -> void:
	grid_size = new_size
	_initialize_battlefield()
	battlefield_updated.emit(grid_size)

## Get world position from grid coordinates
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return battlefield_origin + Vector2(grid_pos.x * cell_size.x, grid_pos.y * cell_size.y)

## Get grid coordinates from world position
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var relative_pos = world_pos - battlefield_origin
	return Vector2i(int(relative_pos.x / cell_size.x), int(relative_pos.y / cell_size.y))

## Check if grid position is valid
func is_valid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y

## Place unit on battlefield
func place_unit(unit: Node, grid_pos: Vector2i) -> bool:
	if not is_valid_position(grid_pos):
		return false

	# Remove unit from previous position if it exists
	for _pos in units.keys():
		if units[_pos] == unit:
			units.erase(_pos)
			break

	units[grid_pos] = unit
	unit_positioned.emit(unit, grid_pos)
	return true

## Remove unit from battlefield
func remove_unit(unit: Node) -> void:
	for pos in units.keys():
		if units[pos] == unit:
			units.erase(pos)
			break

## Get unit at position
func get_unit_at_position(grid_pos: Vector2i) -> Node:
	return units.get(grid_pos, null)

## Set terrain at position
func set_terrain(grid_pos: Vector2i, terrain_type: int) -> bool:
	if not is_valid_position(grid_pos):
		return false

	terrain_grid[grid_pos] = terrain_type
	terrain_updated.emit(grid_pos, terrain_type)
	return true

## Get terrain at position
func get_terrain(grid_pos: Vector2i) -> int:
	return terrain_grid.get(grid_pos, 0)

## Check if position is occupied by unit
func is_position_occupied(grid_pos: Vector2i) -> bool:
	return units.has(grid_pos)

## Get all adjacent positions
func get_adjacent_positions(grid_pos: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	var directions = [
		Vector2i(-1, 0), Vector2i(1, 0), # Left, Right
		Vector2i(0, -1), Vector2i(0, 1), # Up, Down
		Vector2i(-1, -1), Vector2i(1, -1), # Diagonals
		Vector2i(-1, 1), Vector2i(1, 1)
	]

	for direction in directions:
		var typed_direction: Variant = direction
		var new_pos = grid_pos + direction
		if is_valid_position(new_pos):
			adjacent.append(new_pos)

	return adjacent

## Clear battlefield
func clear_battlefield() -> void:
	units.clear()
	_initialize_battlefield()
	battlefield_updated.emit(grid_size)

## Get battlefield state for saving
func get_battlefield_state() -> Dictionary:
	return {
		"grid_size": grid_size,
		"cell_size": cell_size,
		"battlefield_origin": battlefield_origin,
		"terrain_grid": terrain_grid
	}

## Load battlefield state
func load_battlefield_state(state: Dictionary) -> void:
	grid_size = state.get("grid_size", Vector2i(24, 24))
	cell_size = state.get("cell_size", Vector2(32, 32))
	battlefield_origin = state.get("battlefield_origin", Vector2.ZERO)
	terrain_grid = state.get("terrain_grid", {})
	battlefield_updated.emit(grid_size)

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