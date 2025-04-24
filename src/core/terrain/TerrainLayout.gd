extends Resource

const Self = preload("res://src/core/terrain/TerrainLayout.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")

# Signal for feature changes
signal feature_changed(position, feature_type, old_feature_type)

var _terrain_system: TerrainSystem
var _grid_size: Vector2i
var _cells: Dictionary = {}

func _init(terrain_system: TerrainSystem):
	_terrain_system = terrain_system

# Public API

func initialize(size: Vector2i) -> void:
	_grid_size = size
	_cells.clear()
	# Initialize empty cells
	for x in range(size.x):
		for y in range(size.y):
			var pos = Vector2i(x, y)
			_cells[pos] = {
				"terrain_type": 0,
				"feature_type": 0,
				"modifiers": []
			}

func get_size() -> Vector2i:
	return _grid_size

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _grid_size.x and pos.y >= 0 and pos.y < _grid_size.y

func get_cell(pos: Vector2i) -> Dictionary:
	if not is_valid_position(pos):
		return {}
	return _cells.get(pos, {})

func get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	var offsets := [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1)
	]
	
	for offset in offsets:
		var adjacent_pos = pos + offset
		if is_valid_position(adjacent_pos):
			adjacent.append(adjacent_pos)
	
	return adjacent

func place_feature(pos: Vector2i, feature: int) -> bool:
	if not is_valid_position(pos):
		return false
	
	if pos in _cells:
		var old_feature = _cells[pos].get("feature_type", 0)
		_cells[pos]["feature_type"] = feature
		# Update cell modifiers based on feature type
		_update_cell_modifiers(pos, feature)
		# Emit signal with the feature change
		feature_changed.emit(pos, feature, old_feature)
		return true
	else:
		_cells[pos] = {
			"terrain_type": 0,
			"feature_type": feature,
			"modifiers": []
		}
		_update_cell_modifiers(pos, feature)
		# Emit signal with the feature change (old feature is 0)
		feature_changed.emit(pos, feature, 0)
		return true
	
	return false

func get_line_of_sight(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	
	# Check for valid start and end positions
	if not is_valid_position(start) or not is_valid_position(end):
		return line
	
	# Simple Bresenham's line algorithm implementation
	var dx = abs(end.x - start.x)
	var dy = abs(end.y - start.y)
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var err = dx - dy
	
	var x = start.x
	var y = start.y
	
	while true:
		var pos = Vector2i(x, y)
		line.append(pos)
		
		if x == end.x and y == end.y:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
			
		# Safety check to prevent infinite loops
		if not is_valid_position(Vector2i(x, y)):
			break
	
	return line

func is_line_of_sight_blocked(start: Vector2i, end: Vector2i) -> bool:
	var line = get_line_of_sight(start, end)
	
	# Check for obstacles along the line of sight
	for pos in line:
		if pos == start or pos == end:
			continue
			
		var cell = get_cell(pos)
		var feature_type = cell.get("feature_type", 0)
		
		# Check if this feature blocks line of sight
		if _does_feature_block_los(feature_type):
			return true
	
	return false

func get_cell_modifiers(pos: Vector2i) -> Array[int]:
	if not is_valid_position(pos):
		return []
	
	var cell = get_cell(pos)
	var modifiers = cell.get("modifiers", [])
	
	# Convert to properly typed Array[int]
	var typed_modifiers: Array[int] = []
	for modifier in modifiers:
		typed_modifiers.append(modifier)
	
	return typed_modifiers

# Helper functions

func _update_cell_modifiers(pos: Vector2i, feature_type: int) -> void:
	if not pos in _cells:
		return
		
	# Reset modifiers
	_cells[pos]["modifiers"] = []
	
	# Apply modifiers based on feature type
	match feature_type:
		1: # COVER
			_cells[pos]["modifiers"].append(4) # COVER_BONUS
		2: # OBSTACLE
			_cells[pos]["modifiers"].append(1) # DIFFICULT_TERRAIN
		3: # HAZARD
			_cells[pos]["modifiers"].append(2) # HAZARDOUS
		5: # WALL
			_cells[pos]["modifiers"].append(3) # LINE_OF_SIGHT_BLOCKED
		6: # SPECIAL
			_cells[pos]["modifiers"].append(5) # ELEVATION_BONUS

func _does_feature_block_los(feature_type: int) -> bool:
	# Features that block line of sight
	return feature_type in [2, 5, 1] # OBSTACLE (2), WALL (5), COVER (1)

# Private implementation

func _get_adjacent_positions(pos: Vector2, terrain_system: TerrainSystem) -> Array[Vector2]:
	var adjacent: Array[Vector2] = []
	var offsets := [
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(0, -1), Vector2(0, 1)
	]
	
	for offset in offsets:
		var adjacent_pos: Vector2 = pos + offset
		if _is_valid_position(adjacent_pos, terrain_system):
			adjacent.append(adjacent_pos)
	
	return adjacent

func _is_valid_position(pos: Vector2, terrain_system: TerrainSystem) -> bool:
	var grid_size: Vector2 = terrain_system.get_grid_size()
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y
