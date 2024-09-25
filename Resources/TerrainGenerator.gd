# Resources/TerrainGenerator.gd
class_name TerrainGenerator
extends Resource

enum TerrainType { NONE, LARGE, SMALL, LINEAR }

const TABLE_SIZES = {
    "2x2": Vector2i(24, 24),
    "2.5x2.5": Vector2i(30, 30),
    "3x3": Vector2i(36, 36)
}

const TERRAIN_COUNTS = {
    "2x2": {"LARGE": 2, "SMALL": 4, "LINEAR": 2},
    "2.5x2.5": {"LARGE": 2, "SMALL": 5, "LINEAR": 4},
    "3x3": {"LARGE": 3, "SMALL": 6, "LINEAR": 3}
}

func generate_terrain(grid_size: Vector2i) -> Array:
    var terrain_map = []
    for x in range(grid_size.x):
        terrain_map.append([])
        for y in range(grid_size.y):
            terrain_map[x].append(TerrainType.NONE)
    
    place_terrain_features(terrain_map, grid_size)
    return terrain_map

func place_terrain_features(terrain_map: Array, grid_size: Vector2i):
    var terrain_counts = TERRAIN_COUNTS["2x2"]  # You might want to adjust this based on grid_size
    
    for terrain_type in [TerrainType.LARGE, TerrainType.SMALL, TerrainType.LINEAR]:
        var count = terrain_counts[TerrainType.keys()[terrain_type]]
        for i in range(count):
            place_terrain(terrain_map, terrain_type, grid_size)

func place_terrain(terrain_map: Array, terrain_type: TerrainType, grid_size: Vector2i):
    var placed = false
    while not placed:
        var x = randi() % grid_size.x
        var y = randi() % grid_size.y
        if can_place_terrain(terrain_map, x, y, terrain_type, grid_size):
            terrain_map[x][y] = terrain_type
            placed = true

func can_place_terrain(terrain_map: Array, x: int, y: int, terrain_type: TerrainType, grid_size: Vector2i) -> bool:
    if terrain_map[x][y] != TerrainType.NONE:
        return false
    
    var size = 1 if terrain_type == TerrainType.SMALL else 2
    for dx in range(size):
        for dy in range(size):
            if x + dx >= grid_size.x or y + dy >= grid_size.y:
                return false
            if terrain_map[x + dx][y + dy] != TerrainType.NONE:
                return false
    return true