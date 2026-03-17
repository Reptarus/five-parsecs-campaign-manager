extends Node
class_name FiveParsecsBattlefield

## Five Parsecs Battlefield System - Consolidated Implementation
## Merges BaseBattlefieldGenerator + BaseBattlefieldManager functionality  
## Framework Bible compliant: Simple grid-based battlefield for Five Parsecs
## Handles terrain generation, character positioning, and tactical calculations

# Safe imports

# Battlefield signals
signal battlefield_generated(size: Vector2i, terrain_count: int)
signal character_positioned(character: Character, position: Vector2i)
signal character_moved(character: Character, from: Vector2i, to: Vector2i)
signal terrain_placed(terrain_type: String, position: Vector2i)

# Five Parsecs battlefield constants
const GRID_SIZE = Vector2i(24, 24)  # Standard 24x24 inch battlefield
const MIN_TERRAIN_PIECES = 4
const MAX_TERRAIN_PIECES = 12
const DEPLOYMENT_ZONE_DEPTH = 6  # 6 inches deployment zone

# Terrain types (Five Parsecs standard)
enum TerrainType {
	OPEN,
	COVER,        # Provides cover bonus
	DIFFICULT,    # Slows movement
	BLOCKING,     # Blocks line of sight and movement
	ELEVATED,     # Height advantage
	DANGEROUS     # Potential hazard
}

# Battlefield data
var battlefield_size: Vector2i = GRID_SIZE
var terrain_grid: Array[Array] = []
var character_positions: Dictionary = {}  # Character -> Vector2i
var deployment_zones: Dictionary = {}

# Terrain generation settings
var terrain_density: float = 0.25
var use_random_seed: bool = true

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	## Initialize empty battlefield grid
	terrain_grid.clear()
	for x in range(battlefield_size.x):
		var column: Array[TerrainType] = []
		for y in range(battlefield_size.y):
			column.append(TerrainType.OPEN)
		terrain_grid.append(column)

## Battlefield Generation - Five Parsecs Rules

func generate_battlefield(mission_data: Dictionary = {}) -> void:
	## Generate Five Parsecs battlefield with terrain and deployment zones
	
	# Clear existing battlefield
	_initialize_grid()
	character_positions.clear()
	deployment_zones.clear()
	
	# Generate terrain
	_generate_terrain(mission_data)
	
	# Setup deployment zones
	_setup_deployment_zones()
	
	var terrain_count = _count_terrain_pieces()
	battlefield_generated.emit(battlefield_size, terrain_count)

func _generate_terrain(mission_data: Dictionary) -> void:
	## Generate terrain using Five Parsecs rules
	var terrain_count = randi_range(MIN_TERRAIN_PIECES, MAX_TERRAIN_PIECES)
	var rng = RandomNumberGenerator.new()
	
	if use_random_seed:
		rng.randomize()
	
	# Place terrain pieces
	for i in range(terrain_count):
		var position = _find_valid_terrain_position(rng)
		var terrain_type = _roll_terrain_type(rng, mission_data)
		
		if position != Vector2i(-1, -1):
			_place_terrain(position, terrain_type)

func _find_valid_terrain_position(rng: RandomNumberGenerator) -> Vector2i:
	## Find valid position for terrain placement
	var attempts = 0
	var max_attempts = 50
	
	while attempts < max_attempts:
		var x = rng.randi_range(3, battlefield_size.x - 4)  # Avoid edges
		var y = rng.randi_range(3, battlefield_size.y - 4)
		var position = Vector2i(x, y)
		
		# Check if position is in deployment zones
		if _is_in_deployment_zone(position):
			attempts += 1
			continue
		
		# Check if too close to existing terrain
		if _has_nearby_terrain(position, 3):
			attempts += 1
			continue
		
		return position
	
	return Vector2i(-1, -1)  # No valid position found

func _roll_terrain_type(rng: RandomNumberGenerator, mission_data: Dictionary) -> TerrainType:
	## Roll for terrain type based on Five Parsecs rules
	var mission_type = mission_data.get("type", "standard")
	
	# Terrain distribution based on mission type
	var roll = rng.randi_range(1, 6)
	
	match mission_type:
		"urban":
			if roll <= 2:
				return TerrainType.COVER
			elif roll <= 4:
				return TerrainType.BLOCKING
			else:
				return TerrainType.ELEVATED
		"wilderness":
			if roll <= 3:
				return TerrainType.COVER
			elif roll <= 4:
				return TerrainType.DIFFICULT
			else:
				return TerrainType.ELEVATED
		_:  # Standard battlefield
			if roll <= 2:
				return TerrainType.COVER
			elif roll <= 3:
				return TerrainType.DIFFICULT
			elif roll <= 4:
				return TerrainType.BLOCKING
			elif roll <= 5:
				return TerrainType.ELEVATED
			else:
				return TerrainType.DANGEROUS

func _place_terrain(position: Vector2i, terrain_type: TerrainType) -> void:
	## Place terrain piece on battlefield
	if _is_valid_position(position):
		terrain_grid[position.x][position.y] = terrain_type
		terrain_placed.emit(TerrainType.keys()[terrain_type], position)

func _setup_deployment_zones() -> void:
	## Setup deployment zones for crew and enemies
	# Crew deploys on left side (Five Parsecs standard)
	var crew_zone: Array[Vector2i] = []
	for x in range(DEPLOYMENT_ZONE_DEPTH):
		for y in range(battlefield_size.y):
			crew_zone.append(Vector2i(x, y))
	
	# Enemies deploy on right side
	var enemy_zone: Array[Vector2i] = []
	for x in range(battlefield_size.x - DEPLOYMENT_ZONE_DEPTH, battlefield_size.x):
		for y in range(battlefield_size.y):
			enemy_zone.append(Vector2i(x, y))
	
	deployment_zones["crew"] = crew_zone
	deployment_zones["enemy"] = enemy_zone

## Character Positioning

func place_character(character: Character, position: Vector2i) -> bool:
	## Place character at specific position
	if not _is_valid_position(position):
		return false
	
	if _is_position_occupied(position):
		return false
	
	character_positions[character] = position
	character_positioned.emit(character, position)
	return true

func move_character(character: Character, new_position: Vector2i) -> bool:
	## Move character to new position
	if not character_positions.has(character):
		return false
	
	if not _is_valid_position(new_position):
		return false
	
	if _is_position_occupied(new_position):
		return false
	
	var old_position = character_positions[character]
	character_positions[character] = new_position
	character_moved.emit(character, old_position, new_position)
	return true

func get_character_position(character: Character) -> Vector2i:
	## Get character's current position
	return character_positions.get(character, Vector2i(-1, -1))

func get_character_at_position(position: Vector2i) -> Character:
	## Get character at specific position
	for character in character_positions:
		if character_positions[character] == position:
			return character
	return null

func remove_character(character: Character) -> void:
	## Remove character from battlefield
	if character_positions.has(character):
		character_positions.erase(character)

## Tactical Calculations - Five Parsecs Rules

func calculate_distance(pos1: Vector2i, pos2: Vector2i) -> float:
	## Calculate distance in inches between two positions
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return sqrt(dx * dx + dy * dy)

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	## Check if line of sight exists between positions
	var positions = _get_line_positions(from, to)
	
	for pos in positions:
		if pos == from or pos == to:
			continue
		
		if _is_blocking_terrain(pos):
			return false
	
	return true

func has_cover(position: Vector2i) -> bool:
	## Check if position provides cover
	if not _is_valid_position(position):
		return false
	
	return terrain_grid[position.x][position.y] == TerrainType.COVER

func has_height_advantage(attacker_pos: Vector2i, target_pos: Vector2i) -> bool:
	## Check if attacker has height advantage
	if not _is_valid_position(attacker_pos) or not _is_valid_position(target_pos):
		return false
	
	var attacker_terrain = terrain_grid[attacker_pos.x][attacker_pos.y]
	var target_terrain = terrain_grid[target_pos.x][target_pos.y]
	
	return attacker_terrain == TerrainType.ELEVATED and target_terrain != TerrainType.ELEVATED

func find_move_toward(from: Vector2i, to: Vector2i, max_distance: int) -> Vector2i:
	## Find valid move position toward target within movement range
	var direction = Vector2(to - from).normalized()
	var current_pos = from
	
	for i in range(max_distance):
		var next_pos = Vector2i(
			current_pos.x + int(direction.x),
			current_pos.y + int(direction.y)
		)
		
		if not _is_valid_position(next_pos):
			break
		
		if _is_position_occupied(next_pos):
			break
		
		if _is_difficult_terrain(next_pos) and i >= max_distance - 1:
			break  # Can't end move in difficult terrain with remaining movement
		
		current_pos = next_pos
	
	return current_pos

func get_deployment_zone(faction: String) -> Array[Vector2i]:
	## Get deployment zone positions for faction
	return deployment_zones.get(faction, [])

## Utility Methods

func _is_valid_position(position: Vector2i) -> bool:
	## Check if position is within battlefield bounds
	return (position.x >= 0 and position.x < battlefield_size.x and 
			position.y >= 0 and position.y < battlefield_size.y)

func _is_position_occupied(position: Vector2i) -> bool:
	## Check if position is occupied by a character
	for character_pos in character_positions.values():
		if character_pos == position:
			return true
	return false

func _is_in_deployment_zone(position: Vector2i) -> bool:
	## Check if position is in any deployment zone
	for zone in deployment_zones.values():
		if position in zone:
			return true
	return false

func _has_nearby_terrain(position: Vector2i, radius: int) -> bool:
	## Check if there's terrain within radius
	for x in range(position.x - radius, position.x + radius + 1):
		for y in range(position.y - radius, position.y + radius + 1):
			if x == position.x and y == position.y:
				continue
			
			if _is_valid_position(Vector2i(x, y)):
				if terrain_grid[x][y] != TerrainType.OPEN:
					return true
	
	return false

func _is_blocking_terrain(position: Vector2i) -> bool:
	## Check if terrain blocks line of sight
	if not _is_valid_position(position):
		return false
	
	return terrain_grid[position.x][position.y] == TerrainType.BLOCKING

func _is_difficult_terrain(position: Vector2i) -> bool:
	## Check if terrain is difficult to move through
	if not _is_valid_position(position):
		return false
	
	return terrain_grid[position.x][position.y] == TerrainType.DIFFICULT

func _count_terrain_pieces() -> int:
	## Count non-open terrain pieces
	var count = 0
	for x in range(battlefield_size.x):
		for y in range(battlefield_size.y):
			if terrain_grid[x][y] != TerrainType.OPEN:
				count += 1
	return count

func _get_line_positions(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## Get all positions along line between two points
	var positions: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy
	
	var current = from
	
	while true:
		positions.append(current)
		
		if current == to:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy
	
	return positions

## Debug and State Methods

func get_terrain_at(position: Vector2i) -> TerrainType:
	## Get terrain type at position
	if not _is_valid_position(position):
		return TerrainType.OPEN
	
	return terrain_grid[position.x][position.y]

func get_battlefield_state() -> Dictionary:
	## Get complete battlefield state for debugging/saving
	return {
		"size": battlefield_size,
		"terrain_grid": terrain_grid,
		"character_positions": character_positions,
		"deployment_zones": deployment_zones,
		"terrain_count": _count_terrain_pieces()
	}

func clear_battlefield() -> void:
	## Clear battlefield and reset to empty state
	_initialize_grid()
	character_positions.clear()
	deployment_zones.clear()

## Legacy compatibility methods

func initialize_battlefield(size: Vector2i = GRID_SIZE) -> void:
	## Legacy method for BaseBattlefieldManager compatibility
	battlefield_size = size
	generate_battlefield()

func generate_random_battlefield() -> Dictionary:
	## Legacy method for BaseBattlefieldGenerator compatibility
	generate_battlefield()
	return get_battlefield_state()