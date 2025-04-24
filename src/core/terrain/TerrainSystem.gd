## Handles advanced terrain mechanics and positioning for the Five Parsecs battle system
@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules = preload("res://src/core/terrain/TerrainRules.gd")

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

signal terrain_modified(position: Vector2i, feature_type: int)

func _init():
    _terrain_grid = []
    _terrain_features = []

func initialize_grid(size: Vector2i) -> void:
    _terrain_grid = []
    for x in range(size.x):
        var column: Array = []
        for y in range(size.y):
            column.append(GameEnums.TerrainFeatureType.NONE)
        _terrain_grid.append(column)

func get_terrain_type(pos: Vector2i) -> int:
    if not _is_valid_position(pos):
        return GameEnums.TerrainFeatureType.NONE
    return _terrain_grid[pos.x][pos.y]

func set_terrain_feature(pos: Vector2i, feature_type: int) -> void:
    if _is_valid_position(pos):
        _terrain_grid[pos.x][pos.y] = feature_type
        terrain_modified.emit(pos, feature_type)

func get_grid_size() -> Vector2i:
    if _terrain_grid.size() == 0:
        return Vector2i.ZERO
    return Vector2i(_terrain_grid.size(), _terrain_grid[0].size())

func _is_valid_position(pos: Vector2i) -> bool:
    if _terrain_grid.size() == 0:
        return false
    return pos.x >= 0 and pos.x < _terrain_grid.size() and pos.y >= 0 and pos.y < _terrain_grid[0].size()

func is_position_empty(pos: Vector2i) -> bool:
    if not _is_valid_position(pos):
        return false
    return _terrain_grid[pos.x][pos.y] == GameEnums.TerrainFeatureType.NONE

# Add this method to provide access to the terrain layout
func get_terrain_layout():
    # If this class needs to implement terrain layout functionality,
    # we would return a layout object here
    return self