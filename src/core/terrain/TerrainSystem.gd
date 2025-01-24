## Handles advanced terrain mechanics and positioning for the Five Parsecs battle system
class_name FiveParsecsTerrainSystem
extends Node

const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParcecsTerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const FiveParcecsTerrainRules: GDScript = preload("res://src/core/terrain/TerrainRules.gd")

# Define TerrainFeatureType as a static enum within the class
enum TerrainFeatureType {
    NONE,
    COVER_HIGH,
    COVER_LOW,
    WALL,
    WATER,
    HAZARD,
    HIGH_GROUND,
    DIFFICULT
}

var _terrain_grid: Array = []
var _terrain_features: Array = []

signal terrain_modified(position: Vector2, feature_type: int)

func _init():
    _terrain_grid = []
    _terrain_features = []

func initialize_grid(size: Vector2) -> void:
    _terrain_grid = []
    for x in range(int(size.x)):
        var column: Array = []
        for y in range(int(size.y)):
            column.append(TerrainFeatureType.NONE)
        _terrain_grid.append(column)

func get_terrain_type(pos: Vector2) -> int:
    if not _is_valid_position(pos):
        return TerrainFeatureType.NONE
    return _terrain_grid[int(pos.x)][int(pos.y)]

func set_terrain_feature(pos: Vector2, feature_type: int) -> void:
    if _is_valid_position(pos):
        _terrain_grid[int(pos.x)][int(pos.y)] = feature_type
        terrain_modified.emit(pos, feature_type)

func get_grid_size() -> Vector2:
    if _terrain_grid.size() == 0:
        return Vector2.ZERO
    return Vector2(_terrain_grid.size(), _terrain_grid[0].size())

func _is_valid_position(pos: Vector2) -> bool:
    if _terrain_grid.size() == 0:
        return false
    return pos.x >= 0 and pos.x < _terrain_grid.size() and pos.y >= 0 and pos.y < _terrain_grid[0].size()