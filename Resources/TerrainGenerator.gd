# Resources/TerrainGenerator.gd
class_name TerrainGenerator
extends Resource

const TABLE_SIZES = {
	GlobalEnums.TerrainSize.SMALL: Vector2i(24, 24),
	GlobalEnums.TerrainSize.MEDIUM: Vector2i(30, 30),
	GlobalEnums.TerrainSize.LARGE: Vector2i(36, 36)
}

const TERRAIN_COUNTS = {
	GlobalEnums.TerrainSize.SMALL: {GlobalEnums.TerrainFeature.AREA: 2, GlobalEnums.TerrainFeature.INDIVIDUAL: 4, GlobalEnums.TerrainFeature.LINEAR: 2},
	GlobalEnums.TerrainSize.MEDIUM: {GlobalEnums.TerrainFeature.AREA: 2, GlobalEnums.TerrainFeature.INDIVIDUAL: 5, GlobalEnums.TerrainFeature.LINEAR: 4},
	GlobalEnums.TerrainSize.LARGE: {GlobalEnums.TerrainFeature.AREA: 3, GlobalEnums.TerrainFeature.INDIVIDUAL: 6, GlobalEnums.TerrainFeature.LINEAR: 3}
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func generate_terrain(table_size: GlobalEnums.TerrainSize) -> Array:
	var grid_size = TABLE_SIZES[table_size]
	var terrain_map = []
	for x in range(grid_size.x):
		terrain_map.append([])
		for y in range(grid_size.y):
			terrain_map[x].append(GlobalEnums.TerrainFeature.FIELD)
	
	place_terrain_features(terrain_map, table_size)
	return terrain_map

func place_terrain_features(terrain_map: Array, table_size: GlobalEnums.TerrainSize) -> void:
	var terrain_counts = TERRAIN_COUNTS[table_size]
	var grid_size = TABLE_SIZES[table_size]
	
	for terrain_type in [GlobalEnums.TerrainFeature.AREA, GlobalEnums.TerrainFeature.INDIVIDUAL, GlobalEnums.TerrainFeature.LINEAR]:
		var count = terrain_counts[terrain_type]
		for i in range(count):
			place_terrain(terrain_map, terrain_type, grid_size)

func place_terrain(terrain_map: Array, terrain_type: GlobalEnums.TerrainFeature, grid_size: Vector2i) -> void:
	var placed = false
	while not placed:
		var x = rng.randi() % grid_size.x
		var y = rng.randi() % grid_size.y
		if can_place_terrain(terrain_map, x, y, terrain_type, grid_size):
			terrain_map[x][y] = terrain_type
			placed = true

func can_place_terrain(terrain_map: Array, x: int, y: int, terrain_type: GlobalEnums.TerrainFeature, grid_size: Vector2i) -> bool:
	if terrain_map[x][y] != GlobalEnums.TerrainFeature.FIELD:
		return false
	
	var size = 1 if terrain_type == GlobalEnums.TerrainFeature.INDIVIDUAL else 2
	for dx in range(size):
		for dy in range(size):
			if x + dx >= grid_size.x or y + dy >= grid_size.y:
				return false
			if terrain_map[x + dx][y + dy] != GlobalEnums.TerrainFeature.FIELD:
				return false
	return true

const CELL_SIZE := Vector2i(32, 32)

func generate_features(terrain_map: Array, _mission: Mission) -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	var grid_size := Vector2i(terrain_map.size(), terrain_map[0].size())
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			match terrain_map[x][y]:
				GlobalEnums.TerrainFeature.BLOCK:
					features.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": Vector2i(2, 2) * CELL_SIZE,
						"type": "large"
					})
				GlobalEnums.TerrainFeature.INDIVIDUAL:
					features.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": Vector2i(1, 1) * CELL_SIZE,
						"type": "small"
					})
				GlobalEnums.TerrainFeature.LINEAR:
					var is_horizontal: bool = x < grid_size.x - 1 and terrain_map[x + 1][y] == GlobalEnums.TerrainFeature.LINEAR
					var length: int = 1
					if is_horizontal:
						while x + length < grid_size.x and terrain_map[x + length][y] == GlobalEnums.TerrainFeature.LINEAR:
							length += 1
					else:
						while y + length < grid_size.y and terrain_map[x][y + length] == GlobalEnums.TerrainFeature.LINEAR:
							length += 1
					features.append({
						"position": Vector2i(x, y) * CELL_SIZE,
						"size": (Vector2i(length, 1) if is_horizontal else Vector2i(1, length)) * CELL_SIZE,
						"type": "linear"
					})
	
	return features

func generate_player_positions(num_players: int, grid_size: Vector2i) -> Array[Vector2]:
	var player_positions: Array[Vector2] = []
	for _i in range(num_players):
		var position: Vector2 = Vector2(
			rng.randf_range(0, float(grid_size.x - 1)),
			rng.randf_range(0, float(grid_size.y - 1))
		) * Vector2(CELL_SIZE)
		player_positions.append(position)
	return player_positions

func generate_enemy_positions(num_enemies: int, grid_size: Vector2i) -> Array[Vector2]:
	var enemy_positions: Array[Vector2] = []
	for _i in range(num_enemies):
		var position: Vector2 = Vector2(
			rng.randf_range(0, float(grid_size.x - 1)),
			rng.randf_range(0, float(grid_size.y - 1))
		) * Vector2(CELL_SIZE)
		enemy_positions.append(position)
	return enemy_positions

func generate_battlefield(mission: Mission) -> Dictionary:
	var table_size := GlobalEnums.TerrainSize.MEDIUM  # Adjust based on mission requirements
	var terrain_map: Array = generate_terrain(table_size)
	var features: Array[Dictionary] = generate_features(terrain_map, mission)
	var player_positions: Array[Vector2] = generate_player_positions(mission.required_crew_size, TABLE_SIZES[table_size])
	var enemy_positions: Array[Vector2] = generate_enemy_positions(mission.get_enemies().size(), TABLE_SIZES[table_size])

	return {
		"terrain": terrain_map,
		"features": features,
		"player_positions": player_positions,
		"enemy_positions": enemy_positions
	}

func serialize() -> Dictionary:
	return {}

static func deserialize(_data: Dictionary) -> TerrainGenerator:
	return TerrainGenerator.new()