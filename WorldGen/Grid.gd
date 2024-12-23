@tool
extends Node2D
class_name Grid

signal tile_added(tile: Tile, position: Vector2i)
signal tile_removed(position: Vector2i)

## Grid cell size in pixels
@export var cell_size: int = 1:
	set(value):
		cell_size = value
		_update_display()

## Empty tile reference
@export var empty_tile: Tile

## Dictionary storing grid tiles
var grid: Dictionary = {}

func _ready() -> void:
	if not empty_tile:
		push_warning("Grid: No empty tile set")

func get_tile(pos: Vector2i) -> Tile:
	return grid.get(pos, empty_tile)

func add_tile(tile: Tile, pos: Vector2i) -> bool:
	if not tile:
		push_error("Grid: Cannot add null tile")
		return false
		
	if grid.has(pos):
		return false
		
	# Handle multi-cell tiles
	var occupied_cells: Array[Vector2i] = []
	var scale_value: int = tile.scale if tile.scale is int else 1
	var tile_scale := Vector2i(scale_value, scale_value)
	
	for i in tile_scale.x:
		for j in tile_scale.y:
			var check_pos := pos + Vector2i(i, j)
			if grid.has(check_pos):
				return false
			occupied_cells.append(check_pos)
	
	# Add tile to all occupied cells
	for cell_pos in occupied_cells:
		grid[cell_pos] = tile
	
	emit_signal("tile_added", tile, pos)
	_update_display()
	return true

func remove_tile(pos: Vector2i) -> bool:
	if not grid.has(pos):
		return false
		
	var tile: Tile = grid[pos]
	var cells_to_remove: Array[Vector2i] = []
	var scale_value: int = tile.scale if tile.scale is int else 1
	var tile_scale := Vector2i(scale_value, scale_value)
	
	# Find all cells occupied by this tile
	for i in tile_scale.x:
		for j in tile_scale.y:
			var check_pos := pos + Vector2i(i, j)
			if grid.get(check_pos) == tile:
				cells_to_remove.append(check_pos)
	
	# Remove tile from all cells
	for cell_pos in cells_to_remove:
		grid.erase(cell_pos)
	
	emit_signal("tile_removed", pos)
	_update_display()
	return true

func clear() -> void:
	grid.clear()
	_update_display()

func get_used_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pos in grid:
		cells.append(pos)
	return cells

func get_used_rect() -> Rect2i:
	if grid.is_empty():
		return Rect2i()
		
	var min_pos := Vector2i(INF, INF)
	var max_pos := Vector2i(-INF, -INF)
	
	for pos in grid:
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)
	
	return Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / cell_size)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos * cell_size)

func _update_display() -> void:
	queue_redraw()
	
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw grid lines
		var rect := get_used_rect()
		var grid_dimensions := rect.size
		
		for x in range(grid_dimensions.x + 1):
			var start := grid_to_world(rect.position + Vector2i(x, 0))
			var end := grid_to_world(rect.position + Vector2i(x, grid_dimensions.y))
			draw_line(start, end, Color.WHITE, 1.0)
			
		for y in range(grid_dimensions.y + 1):
			var start := grid_to_world(rect.position + Vector2i(0, y))
			var end := grid_to_world(rect.position + Vector2i(grid_dimensions.x, y))
			draw_line(start, end, Color.WHITE, 1.0)
			
		# Draw tiles
		for pos in grid:
			var tile: Tile = grid[pos]
			if tile and tile.scene:
				var world_pos := grid_to_world(pos)
				var scale_value: int = tile.scale if tile.scale is int else 1
				var tile_scale := Vector2i(scale_value, scale_value)
				var tile_size := Vector2(tile_scale) * cell_size
				draw_rect(Rect2(world_pos, tile_size), Color(1, 1, 1, 0.2))
