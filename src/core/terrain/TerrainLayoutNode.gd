extends Node
const Self = preload("res://src/core/terrain/TerrainLayoutNode.gd")

const TerrainLayout = preload("res://src/core/terrain/TerrainLayout.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")

var _layout: TerrainLayout
var _terrain_system: TerrainSystem

func _init(terrain_system: TerrainSystem) -> void:
	_terrain_system = terrain_system
	_layout = TerrainLayout.new(terrain_system)

func initialize(size: Vector2i) -> void:
	_layout.initialize(size)

func get_size() -> Vector2i:
	return _layout.get_size()

func is_valid_position(pos: Vector2i) -> bool:
	return _layout.is_valid_position(pos)

func get_cell(pos: Vector2i) -> Dictionary:
	return _layout.get_cell(pos)

func get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	return _layout.get_adjacent_positions(pos)

func place_feature(pos: Vector2i, feature: int) -> void:
	_layout.place_feature(pos, feature)

func get_line_of_sight(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	return _layout.get_line_of_sight(start, end)

func is_line_of_sight_blocked(start: Vector2i, end: Vector2i) -> bool:
	return _layout.is_line_of_sight_blocked(start, end)

func get_cell_modifiers(pos: Vector2i) -> Array[int]:
	return _layout.get_cell_modifiers(pos)