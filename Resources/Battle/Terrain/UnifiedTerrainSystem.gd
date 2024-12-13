## UnifiedTerrainSystem
## Manages terrain generation, validation, and interaction for the Five Parsecs battle system.
class_name UnifiedTerrainSystem
extends Node2D

# Constants for terrain types
const TERRAIN_TYPES = {
	"OPEN": 0,
	"COVER": 1,
	"DIFFICULT": 2,
	"IMPASSABLE": 3,
	"HIGH_GROUND": 4,
	"LINEAR": 5,
	"INDIVIDUAL": 6,
	"AREA": 7,
	"FIELD": 8,
	"BLOCK": 9,
	"INTERIOR": 10
}

# Terrain generation parameters
var grid_size: Vector2i = Vector2i(24, 24)  # Standard battlefield size in grid squares
var cell_size: Vector2i = Vector2i(32, 32)  # Size of each grid cell in pixels

# Reference to terrain pieces and map
var terrain_map: Array = []
var terrain_pieces: Array = []
var initialized: bool = false

func _ready() -> void:
	initialize_terrain_system()

func initialize_terrain_system() -> void:
	if initialized:
		return
		
	# Initialize the terrain map
	terrain_map.clear()
	for x in range(grid_size.x):
		var row = []
		for y in range(grid_size.y):
			row.append(TERRAIN_TYPES.OPEN)
		terrain_map.append(row)
	
	initialized = true

func get_terrain_at_position(pos: Vector2i) -> int:
	if not initialized:
		push_error("Terrain system not initialized")
		return TERRAIN_TYPES.OPEN
		
	if not is_position_valid(pos):
		return TERRAIN_TYPES.IMPASSABLE
		
	return terrain_map[pos.x][pos.y]

func is_position_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func set_terrain_at_position(pos: Vector2i, terrain_type: int) -> void:
	if not initialized:
		push_error("Terrain system not initialized")
		return
		
	if not is_position_valid(pos):
		return
		
	terrain_map[pos.x][pos.y] = terrain_type

func clear_terrain() -> void:
	if not initialized:
		push_error("Terrain system not initialized")
		return
		
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			terrain_map[x][y] = TERRAIN_TYPES.OPEN
	
	# Clear terrain pieces
	for piece in terrain_pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	terrain_pieces.clear()

func get_grid_position(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / cell_size.x),
		int(world_position.y / cell_size.y)
	)

func get_world_position(grid_position: Vector2i) -> Vector2:
	return Vector2(
		grid_position.x * cell_size.x + cell_size.x / 2,
		grid_position.y * cell_size.y + cell_size.y / 2
	)

func blocks_movement(pos: Vector2i) -> bool:
	var terrain_type = get_terrain_at_position(pos)
	return terrain_type == TERRAIN_TYPES.IMPASSABLE or terrain_type == TERRAIN_TYPES.BLOCK

func provides_cover(pos: Vector2i) -> bool:
	var terrain_type = get_terrain_at_position(pos)
	return terrain_type == TERRAIN_TYPES.COVER or terrain_type == TERRAIN_TYPES.AREA or terrain_type == TERRAIN_TYPES.BLOCK

func is_difficult_terrain(pos: Vector2i) -> bool:
	var terrain_type = get_terrain_at_position(pos)
	return terrain_type == TERRAIN_TYPES.DIFFICULT

func get_combat_modifiers(pos: Vector2i) -> Dictionary:
	var terrain_type = get_terrain_at_position(pos)
	var modifiers = {
		"cover_bonus": 0,
		"movement_penalty": 0,
		"height_advantage": 0
	}
	
	if provides_cover(pos):
		modifiers.cover_bonus = 1
	
	if is_difficult_terrain(pos):
		modifiers.movement_penalty = 1
	
	if terrain_type == TERRAIN_TYPES.HIGH_GROUND:
		modifiers.height_advantage = 1
		
	return modifiers

func get_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_position_valid(from_pos) or not is_position_valid(to_pos):
		return false
		
	# Use Bresenham's line algorithm for line of sight
	var x0 = from_pos.x
	var y0 = from_pos.y
	var x1 = to_pos.x
	var y1 = to_pos.y
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var x = x0
	var y = y0
	var n = 1 + dx + dy
	var x_inc = 1 if x1 > x0 else -1
	var y_inc = 1 if y1 > y0 else -1
	var error = dx - dy
	dx *= 2
	dy *= 2
	
	while n > 0:
		if x != x0 or y != y0:  # Don't check starting position
			var terrain_type = get_terrain_at_position(Vector2i(x, y))
			if terrain_type == TERRAIN_TYPES.BLOCK or terrain_type == TERRAIN_TYPES.IMPASSABLE:
				return false
		
		if error > 0:
			x += x_inc
			error -= dy
		elif error < 0:
			y += y_inc
			error += dx
		else:
			# Check both adjacent cells for corner cases
			x += x_inc
			error -= dy
			y += y_inc
			error += dx
			n -= 1
		
		n -= 1
	
	return true

func _to_string() -> String:
	var output = ""
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			output += str(terrain_map[x][y]) + " "
		output += "\n"
	return output