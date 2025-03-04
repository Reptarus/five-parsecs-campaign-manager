class_name FPCM_TerrainLayout
extends Resource

const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainSystem: GDScript = preload("res://src/core/terrain/TerrainSystem.gd")

var _terrain_system: TerrainSystem

func _init(terrain_system: TerrainSystem):
    _terrain_system = terrain_system

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