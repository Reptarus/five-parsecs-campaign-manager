class_name TerrainGenerator
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

const TABLE_SIZES = {
	GlobalEnums.TerrainType.URBAN: Vector2i(24, 24),
	GlobalEnums.TerrainType.WILDERNESS: Vector2i(30, 30),
	GlobalEnums.TerrainType.SPACE_STATION: Vector2i(36, 36)
}

const TERRAIN_COUNTS = {
	GlobalEnums.TerrainType.URBAN: {GlobalEnums.TerrainFeature.AREA: 2, GlobalEnums.TerrainFeature.INDIVIDUAL: 4, GlobalEnums.TerrainFeature.LINEAR: 2},
	GlobalEnums.TerrainType.WILDERNESS: {GlobalEnums.TerrainFeature.AREA: 2, GlobalEnums.TerrainFeature.INDIVIDUAL: 5, GlobalEnums.TerrainFeature.LINEAR: 4},
	GlobalEnums.TerrainType.SPACE_STATION: {GlobalEnums.TerrainFeature.AREA: 3, GlobalEnums.TerrainFeature.INDIVIDUAL: 6, GlobalEnums.TerrainFeature.LINEAR: 3}
}

var rng = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func generate_terrain_map(terrain_type: GlobalEnums.TerrainType) -> Array:
	var grid_size = TABLE_SIZES[terrain_type]
	var terrain_map = []
	
	# Initialize empty terrain map
	for x in range(grid_size.x):
		terrain_map.append([])
		for y in range(grid_size.y):
			terrain_map[x].append(GlobalEnums.TerrainFeature.FIELD)
	
	# Place terrain features according to terrain type
	var terrain_counts = TERRAIN_COUNTS[terrain_type]
	for terrain_feature in terrain_counts:
		var count = terrain_counts[terrain_feature]
		for i in range(count):
			place_terrain(terrain_map, terrain_feature, grid_size, terrain_type)
	
	return terrain_map

func place_terrain(terrain_map: Array, terrain_feature: GlobalEnums.TerrainFeature, grid_size: Vector2i, _terrain_type: GlobalEnums.TerrainType) -> void:
	var placed = false
	while not placed:
		var x = rng.randi() % grid_size.x
		var y = rng.randi() % grid_size.y
		
		if can_place_terrain(terrain_map, x, y, terrain_feature, grid_size):
			terrain_map[x][y] = terrain_feature
			placed = true

func can_place_terrain(terrain_map: Array, x: int, y: int, terrain_type: GlobalEnums.TerrainFeature, grid_size: Vector2i) -> bool:
	if terrain_map[x][y] != GlobalEnums.TerrainFeature.FIELD:
		return false
		
	# Add additional placement rules based on terrain type
	match terrain_type:
		GlobalEnums.TerrainFeature.AREA:
			return _check_area_placement(terrain_map, x, y, grid_size)
		GlobalEnums.TerrainFeature.LINEAR:
			return _check_linear_placement(terrain_map, x, y, grid_size)
		GlobalEnums.TerrainFeature.INDIVIDUAL:
			return true
		_:
			return false

func _check_area_placement(terrain_map: Array, x: int, y: int, grid_size: Vector2i) -> bool:
	# Check if we can place a 2x2 area
	if x + 1 >= grid_size.x or y + 1 >= grid_size.y:
		return false
		
	for i in range(2):
		for j in range(2):
			if terrain_map[x + i][y + j] != GlobalEnums.TerrainFeature.FIELD:
				return false
	
	return true

func _check_linear_placement(terrain_map: Array, x: int, y: int, grid_size: Vector2i) -> bool:
	# Check if we can place a linear feature (3 tiles in a line)
	if x + 2 >= grid_size.x:
		return false
		
	for i in range(3):
		if terrain_map[x + i][y] != GlobalEnums.TerrainFeature.FIELD:
			return false
	
	return true
