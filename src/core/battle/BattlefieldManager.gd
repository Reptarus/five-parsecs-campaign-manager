@tool
class_name BattlefieldManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

## Signals
signal terrain_updated(position: Vector2, terrain_type: int)
signal cover_updated(position: Vector2, cover_value: int)
signal battlefield_generated(width: int, height: int)
signal battlefield_reset
signal deployment_zone_generated(team: int, positions: Array[Vector2])

## Battlefield properties
var battlefield_width: int = 20
var battlefield_height: int = 20
var grid_size: float = 64.0

## Maps for terrain, cover and other battlefield properties
var terrain_map: Array = []
var cover_map: Array = []
var elevation_map: Array = []
var deployment_zones: Dictionary = {}

## Game objects references
var combat_manager: Node
var pathfinder: Node

## Initialize the battlefield
func _init() -> void:
	_setup_battlefield()

## Setup the battlefield grid
func _setup_battlefield() -> void:
	terrain_map = []
	cover_map = []
	elevation_map = []
	
	for x in range(battlefield_width):
		terrain_map.append([])
		cover_map.append([])
		elevation_map.append([])
		
		for y in range(battlefield_height):
			terrain_map[x].append(TerrainTypes.Type.EMPTY)
			cover_map[x].append(0)
			elevation_map[x].append(0)

## Reset the battlefield to default state
func reset_battlefield() -> void:
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			terrain_map[x][y] = TerrainTypes.Type.EMPTY
			cover_map[x][y] = 0
			elevation_map[x][y] = 0
	
	deployment_zones.clear()
	battlefield_reset.emit()

## Generate terrain based on mission parameters
func generate_terrain(terrain_type: String, density: float = 0.3) -> void:
	reset_battlefield()
	
	match terrain_type:
		"standard":
			_generate_standard_terrain(density)
		"desert":
			_generate_desert_terrain(density)
		"urban":
			_generate_urban_terrain(density)
		"forest":
			_generate_forest_terrain(density)
		"space_station":
			_generate_space_station_terrain(density)
		_:
			_generate_standard_terrain(density)
	
	battlefield_generated.emit(battlefield_width, battlefield_height)

## Generate deployment zones for different teams
func generate_deployment_zones(num_teams: int = 2) -> void:
	deployment_zones.clear()
	
	match num_teams:
		1:
			# Single team deployment (e.g., for scenario missions)
			var positions = _generate_deployment_area(
				Vector2i(battlefield_width / 2, battlefield_height / 2),
				battlefield_width / 4,
				battlefield_height / 4
			)
			deployment_zones[1] = positions
			deployment_zone_generated.emit(1, positions)
		
		2:
			# Two teams - opposite sides
			var team1_positions = _generate_deployment_area(
				Vector2i(battlefield_width / 6, battlefield_height / 2),
				battlefield_width / 6,
				battlefield_height / 3
			)
			
			var team2_positions = _generate_deployment_area(
				Vector2i(5 * battlefield_width / 6, battlefield_height / 2),
				battlefield_width / 6,
				battlefield_height / 3
			)
			
			deployment_zones[1] = team1_positions
			deployment_zones[2] = team2_positions
			
			deployment_zone_generated.emit(1, team1_positions)
			deployment_zone_generated.emit(2, team2_positions)
		
		3, 4:
			# For 3-4 teams, use corners
			var positions_per_quadrant = []
			
			# Top-left
			positions_per_quadrant.append(_generate_deployment_area(
				Vector2i(battlefield_width / 6, battlefield_height / 6),
				battlefield_width / 6,
				battlefield_height / 6
			))
			
			# Top-right
			positions_per_quadrant.append(_generate_deployment_area(
				Vector2i(5 * battlefield_width / 6, battlefield_height / 6),
				battlefield_width / 6,
				battlefield_height / 6
			))
			
			# Bottom-left
			positions_per_quadrant.append(_generate_deployment_area(
				Vector2i(battlefield_width / 6, 5 * battlefield_height / 6),
				battlefield_width / 6,
				battlefield_height / 6
			))
			
			# Bottom-right
			positions_per_quadrant.append(_generate_deployment_area(
				Vector2i(5 * battlefield_width / 6, 5 * battlefield_height / 6),
				battlefield_width / 6,
				battlefield_height / 6
			))
			
			for i in range(num_teams):
				deployment_zones[i + 1] = positions_per_quadrant[i]
				deployment_zone_generated.emit(i + 1, positions_per_quadrant[i])

## Get terrain type at specific position
func get_terrain_type(position: Vector2) -> int:
	var grid_pos = _world_to_grid(position)
	
	if _is_valid_grid_position(grid_pos):
		return terrain_map[grid_pos.x][grid_pos.y]
	
	return TerrainTypes.Type.EMPTY

## Set terrain type at specific position
func set_terrain_type(position: Vector2, terrain_type: int) -> void:
	var grid_pos = _world_to_grid(position)
	
	if _is_valid_grid_position(grid_pos):
		terrain_map[grid_pos.x][grid_pos.y] = terrain_type
		terrain_updated.emit(position, terrain_type)

## Get cover value at specific position
func get_cover_value(position: Vector2) -> int:
	var grid_pos = _world_to_grid(position)
	
	if _is_valid_grid_position(grid_pos):
		return cover_map[grid_pos.x][grid_pos.y]
	
	return 0

## Set cover value at specific position
func set_cover_value(position: Vector2, cover_value: int) -> void:
	var grid_pos = _world_to_grid(position)
	
	if _is_valid_grid_position(grid_pos):
		cover_map[grid_pos.x][grid_pos.y] = cover_value
		cover_updated.emit(position, cover_value)

## Check if a position is valid on the battlefield
func is_valid_position(position: Vector2) -> bool:
	var grid_pos = _world_to_grid(position)
	return _is_valid_grid_position(grid_pos)

## Check if a position has cover
func position_has_cover(position: Vector2) -> bool:
	return get_cover_value(position) > 0

## Convert from world position to grid position
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / grid_size),
		int(world_pos.y / grid_size)
	)

## Convert from grid position to world position
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(grid_pos.x + 0.5) * grid_size,
		(grid_pos.y + 0.5) * grid_size
	)

## Check if a grid position is valid
func _is_valid_grid_position(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0 and
		grid_pos.x < battlefield_width and
		grid_pos.y >= 0 and
		grid_pos.y < battlefield_height
	)

## Generate a standard mixed terrain
func _generate_standard_terrain(density: float) -> void:
	# Start with all open terrain
	reset_battlefield()
	
	# Add some difficult terrain
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if randf() < density * 0.7:
				if randf() < 0.7:
					terrain_map[x][y] = TerrainTypes.Type.DIFFICULT
				else:
					terrain_map[x][y] = TerrainTypes.Type.OBSTACLE
	
	# Add some light and medium cover
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if randf() < density:
				var cover_type = randi() % 3 + 1 # 1-3 cover value
				cover_map[x][y] = cover_type

## Generate desert terrain
func _generate_desert_terrain(density: float) -> void:
	# Start with all open terrain
	reset_battlefield()
	
	# Add scattered rocks and dunes
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if randf() < density * 0.5:
				if randf() < 0.8:
					terrain_map[x][y] = TerrainTypes.Type.DIFFICULT
				else:
					terrain_map[x][y] = TerrainTypes.Type.OBSTACLE
	
	# Add some cover from rocks and debris
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if randf() < density * 0.3:
				var cover_type = randi() % 2 + 1 # 1-2 cover value
				cover_map[x][y] = cover_type

## Generate urban terrain
func _generate_urban_terrain(density: float) -> void:
	# Start with all open terrain
	reset_battlefield()
	
	# Add buildings and rubble
	for x in range(2, battlefield_width - 2, 3):
		for y in range(2, battlefield_height - 2, 3):
			if randf() < density * 1.2:
				# Create building footprint
				var building_width = randi() % 3 + 2
				var building_height = randi() % 3 + 2
				
				for bx in range(building_width):
					for by in range(building_height):
						var tx = x + bx
						var ty = y + by
						
						if tx < battlefield_width and ty < battlefield_height:
							if randf() < 0.9:
								terrain_map[tx][ty] = TerrainTypes.Type.OBSTACLE
							else:
								terrain_map[tx][ty] = TerrainTypes.Type.OBSTACLE
							
							# Add heavy cover around buildings
							cover_map[tx][ty] = 3
	
	# Add streets and alleys
	for x in range(0, battlefield_width, 3):
		for y in range(battlefield_height):
			if terrain_map[x][y] != TerrainTypes.Type.EMPTY:
				terrain_map[x][y] = TerrainTypes.Type.EMPTY
	
	for y in range(0, battlefield_height, 3):
		for x in range(battlefield_width):
			if terrain_map[x][y] != TerrainTypes.Type.EMPTY:
				terrain_map[x][y] = TerrainTypes.Type.EMPTY

## Generate forest terrain
func _generate_forest_terrain(density: float) -> void:
	# Start with difficult terrain (underbrush)
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			terrain_map[x][y] = TerrainTypes.Type.DIFFICULT
	
	# Add trees and dense foliage
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if randf() < density:
				terrain_map[x][y] = TerrainTypes.Type.OBSTACLE
				cover_map[x][y] = 2
			elif randf() < density * 1.5:
				cover_map[x][y] = 1
	
	# Add some clearings
	for i in range(randi() % 4 + 2):
		var center_x = randi() % battlefield_width
		var center_y = randi() % battlefield_height
		var radius = randi() % 4 + 2
		
		for x in range(center_x - radius, center_x + radius):
			for y in range(center_y - radius, center_y + radius):
				if x >= 0 and x < battlefield_width and y >= 0 and y < battlefield_height:
					if Vector2(center_x, center_y).distance_to(Vector2(x, y)) < radius:
						terrain_map[x][y] = TerrainTypes.Type.EMPTY
						cover_map[x][y] = 0

## Generate space station terrain
func _generate_space_station_terrain(density: float) -> void:
	# Start with all impassable (space voids)
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			terrain_map[x][y] = TerrainTypes.Type.OBSTACLE
	
	# Create rooms and corridors
	var visited = []
	for i in range(battlefield_width):
		visited.append([])
		for j in range(battlefield_height):
			visited[i].append(false)
	
	# Start with a central room
	var center_x = battlefield_width / 2
	var center_y = battlefield_height / 2
	var room_size_x = randi() % 3 + 4
	var room_size_y = randi() % 3 + 4
	
	for x in range(center_x - room_size_x / 2, center_x + room_size_x / 2):
		for y in range(center_y - room_size_y / 2, center_y + room_size_y / 2):
			if x >= 0 and x < battlefield_width and y >= 0 and y < battlefield_height:
				terrain_map[x][y] = TerrainTypes.Type.EMPTY
				visited[x][y] = true
	
	# Add more rooms
	var num_rooms = randi() % 6 + 8
	var rooms = [[center_x, center_y, room_size_x, room_size_y]]
	
	for i in range(num_rooms):
		var parent_room = rooms[randi() % rooms.size()]
		var connection_point_x
		var connection_point_y
		
		# Determine connection point on parent room
		var side = randi() % 4 # 0: top, 1: right, 2: bottom, 3: left
		match side:
			0: # Top
				connection_point_x = parent_room[0] + randi() % parent_room[2] - parent_room[2] / 2
				connection_point_y = parent_room[1] - parent_room[3] / 2
			1: # Right
				connection_point_x = parent_room[0] + parent_room[2] / 2
				connection_point_y = parent_room[1] + randi() % parent_room[3] - parent_room[3] / 2
			2: # Bottom
				connection_point_x = parent_room[0] + randi() % parent_room[2] - parent_room[2] / 2
				connection_point_y = parent_room[1] + parent_room[3] / 2
			3: # Left
				connection_point_x = parent_room[0] - parent_room[2] / 2
				connection_point_y = parent_room[1] + randi() % parent_room[3] - parent_room[3] / 2
		
		# Create new room
		var new_room_size_x = randi() % 3 + 3
		var new_room_size_y = randi() % 3 + 3
		var new_room_x: int
		var new_room_y: int
		
		match side:
			0: # Top
				new_room_x = connection_point_x
				new_room_y = connection_point_y - new_room_size_y / 2 - 1
			1: # Right
				new_room_x = connection_point_x + new_room_size_x / 2 + 1
				new_room_y = connection_point_y
			2: # Bottom
				new_room_x = connection_point_x
				new_room_y = connection_point_y + new_room_size_y / 2 + 1
			3: # Left
				new_room_x = connection_point_x - new_room_size_x / 2 - 1
				new_room_y = connection_point_y
		
		# Draw the new room
		for x in range(new_room_x - new_room_size_x / 2, new_room_x + new_room_size_x / 2):
			for y in range(new_room_y - new_room_size_y / 2, new_room_y + new_room_size_y / 2):
				if x >= 0 and x < battlefield_width and y >= 0 and y < battlefield_height:
					terrain_map[x][y] = TerrainTypes.Type.EMPTY
					
					# Add some cover in rooms
					if randf() < density:
						cover_map[x][y] = 1
		
		# Draw the corridor between rooms
		var corridor_x = connection_point_x
		var corridor_y = connection_point_y
		
		match side:
			0: # Top
				for y in range(corridor_y, new_room_y + new_room_size_y / 2 + 1):
					if y >= 0 and y < battlefield_height:
						terrain_map[corridor_x][y] = TerrainTypes.Type.EMPTY
			1: # Right
				for x in range(corridor_x, new_room_x - new_room_size_x / 2 - 1, -1):
					if x >= 0 and x < battlefield_width:
						terrain_map[x][corridor_y] = TerrainTypes.Type.EMPTY
			2: # Bottom
				for y in range(corridor_y, new_room_y - new_room_size_y / 2 - 1, -1):
					if y >= 0 and y < battlefield_height:
						terrain_map[corridor_x][y] = TerrainTypes.Type.EMPTY
			3: # Left
				for x in range(corridor_x, new_room_x + new_room_size_x / 2 + 1):
					if x >= 0 and x < battlefield_width:
						terrain_map[x][corridor_y] = TerrainTypes.Type.EMPTY
		
		# Add to list of rooms
		rooms.append([new_room_x, new_room_y, new_room_size_x, new_room_size_y])
	
	# Add obstacles and cover
	for x in range(battlefield_width):
		for y in range(battlefield_height):
			if terrain_map[x][y] == TerrainTypes.Type.EMPTY:
				if randf() < density * 0.4:
					terrain_map[x][y] = TerrainTypes.Type.OBSTACLE
					cover_map[x][y] = 2
				elif randf() < density * 0.7:
					cover_map[x][y] = 1

## Generate a deployment area around a center point
func _generate_deployment_area(center: Vector2i, width: int, height: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	for x in range(center.x - width, center.x + width):
		for y in range(center.y - height, center.y + height):
			if _is_valid_grid_position(Vector2i(x, y)):
				var terrain_type = terrain_map[x][y]
				if not TerrainTypes.blocks_movement(terrain_type):
					positions.append(_grid_to_world(Vector2i(x, y)))
	
	return positions

## Clear all deployment zones
func _clear_deployment_zones() -> void:
	deployment_zones.clear()