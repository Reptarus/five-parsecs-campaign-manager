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

func generate_features() -> void:
	# Implement feature generation logic
	pass

func generate_cover() -> void:
	# Implement cover generation logic
	pass

func generate_loot() -> void:
	# Implement loot generation logic
	pass

func generate_enemies() -> void:
	# Implement enemy generation logic
	pass

func generate_npcs() -> void:
	# Implement NPC generation logic
	pass

func serialize() -> Dictionary:
	return {}

static func deserialize(_data: Dictionary) -> TerrainGenerator:
	return TerrainGenerator.new()