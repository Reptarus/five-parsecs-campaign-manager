# Content from src/core/battle/PathFinder.gd
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://src/core/utils/PathFinder.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const BattlefieldManagerClass = preload("res://src/core/battle/BattlefieldManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
# Compatibility layer to handle GDScript creation
var Compatibility = load("res://addons/gut/compatibility.gd").new()

signal path_found(path: Array[Vector2])
signal path_not_found

# PathNode class definition moved outside of PathFinder to reduce caching issues
const PATH_NODE_SCRIPT = """
extends RefCounted
var position: Vector2i
var g_cost: float = 0.0 # Cost from start to this node
var h_cost: float = 0.0 # Estimated cost from this node to end
var parent = null # PathNode - can't type this properly in GDScript

func _init(pos = null) -> void:
	if pos != null:
		position = pos

func f_cost() -> float:
	return g_cost + h_cost

func equals(other) -> bool:
	if other == null:
		return false
	return position == other.position
"""

var battlefield_manager: Node # Will be cast to BattlefieldManager
var _open_set = [] # Array of PathNodes
var _closed_set = [] # Array of PathNodes
var _movement_directions := [
	Vector2i(1, 0), # Right
	Vector2i(-1, 0), # Left
	Vector2i(0, 1), # Down
	Vector2i(0, -1), # Up
	Vector2i(1, 1), # Down-Right
	Vector2i(-1, 1), # Down-Left
	Vector2i(1, -1), # Up-Right
	Vector2i(-1, -1) # Up-Left
]

var _path_node_script

func _init(battlefield: Node) -> void: # Accept Node, will be BattlefieldManager
	battlefield_manager = battlefield
	_create_path_node_script()

# Creates a script for PathNode instances
func _create_path_node_script():
	if _path_node_script != null:
		return
		
	_path_node_script = Compatibility.create_gdscript()
	
	_path_node_script.source_code = """
extends RefCounted
class_name PathNode

var position
var parent
var g_cost = 0
var h_cost = 0
var f_cost = 0

func _init(pos = Vector2.ZERO, p = null):
	position = pos
	parent = p
	_calculate_costs()
	
func _calculate_costs():
	if parent != null:
		g_cost = parent.g_cost + position.distance_to(parent.position)
	h_cost = 0 # Will be set externally by the pathfinder
	f_cost = g_cost + h_cost
"""
	_path_node_script.reload()

# Function to create a new PathNode without direct class reference
func create_path_node(pos: Vector2i) -> Variant:
	var node = _path_node_script.new(pos)
	return node

func find_path(start_pos: Vector2, end_pos: Vector2, max_movement: float) -> Array[Vector2]:
	# Convert world positions to grid positions
	var start_grid = battlefield_manager._world_to_grid(start_pos)
	var end_grid = battlefield_manager._world_to_grid(end_pos)
	
	# Reset pathfinding arrays
	_open_set.clear()
	_closed_set.clear()
	
	# Create start and end nodes
	var start_node = create_path_node(start_grid)
	var end_node = create_path_node(end_grid)
	
	# Add start node to open set
	_open_set.append(start_node)
	
	while not _open_set.is_empty():
		var current_node = _get_lowest_f_cost_node()
		
		if current_node.position == end_node.position:
			var path = _retrace_path(start_node, current_node)
			if _calculate_path_cost(path) <= max_movement:
				path_found.emit(path)
				return path
			else:
				path_not_found.emit()
				return []
		
		_open_set.erase(current_node)
		_closed_set.append(current_node)
		
		for neighbor in _get_neighbors(current_node):
			if _is_in_closed_set(neighbor):
				continue
			
			var terrain_type = battlefield_manager.terrain_map[neighbor.position.x][neighbor.position.y]
			var movement_cost = _calculate_movement_cost(current_node.position, neighbor.position, terrain_type)
			var new_cost_to_neighbor = current_node.g_cost + movement_cost
			
			if not _is_in_open_set(neighbor) or new_cost_to_neighbor < neighbor.g_cost:
				neighbor.g_cost = new_cost_to_neighbor
				neighbor.h_cost = _calculate_heuristic(neighbor.position, end_grid)
				neighbor.parent = current_node
				
				if not _is_in_open_set(neighbor):
					_open_set.append(neighbor)
	
	path_not_found.emit()
	return []

func _get_lowest_f_cost_node() -> Variant:
	var lowest_node = _open_set[0]
	for node in _open_set:
		if node.f_cost() < lowest_node.f_cost():
			lowest_node = node
	return lowest_node

func _get_neighbors(node: Variant) -> Array:
	var neighbors = []
	
	for direction in _movement_directions:
		var neighbor_pos = node.position + direction
		
		if battlefield_manager._is_valid_grid_position(neighbor_pos):
			var terrain_type = battlefield_manager.terrain_map[neighbor_pos.x][neighbor_pos.y]
			if not TerrainTypes.blocks_movement(terrain_type):
				neighbors.append(create_path_node(neighbor_pos))
	
	return neighbors

func _calculate_movement_cost(from: Vector2i, to: Vector2i, terrain_type: int) -> float:
	var base_cost = 1.0
	
	# Apply terrain movement cost
	return base_cost * TerrainTypes.get_movement_cost(terrain_type)

func _calculate_heuristic(pos: Vector2i, target: Vector2i) -> float:
	# Using octile distance for 8-directional movement
	var dx = abs(target.x - pos.x)
	var dy = abs(target.y - pos.y)
	return 1.0 * max(dx, dy) + (1.4 - 1.0) * min(dx, dy)

func _retrace_path(start_node: Variant, end_node: Variant) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current_node = end_node
	
	while current_node != start_node:
		path.append(battlefield_manager._grid_to_world(current_node.position))
		current_node = current_node.parent
	
	path.append(battlefield_manager._grid_to_world(start_node.position))
	path.reverse()
	return path

func _calculate_path_cost(path: Array[Vector2]) -> float:
	var total_cost := 0.0
	
	for i in range(1, path.size()):
		var from_grid = battlefield_manager._world_to_grid(path[i - 1])
		var to_grid = battlefield_manager._world_to_grid(path[i])
		var terrain_type = battlefield_manager.terrain_map[to_grid.x][to_grid.y]
		total_cost += _calculate_movement_cost(from_grid, to_grid, terrain_type)
	
	return total_cost

func _is_in_open_set(node: Variant) -> bool:
	for open_node in _open_set:
		if open_node.equals(node):
			return true
	return false

func _is_in_closed_set(node: Variant) -> bool:
	for closed_node in _closed_set:
		if closed_node.equals(node):
			return true
	return false