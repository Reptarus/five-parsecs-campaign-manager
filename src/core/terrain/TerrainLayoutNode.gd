extends Node
const Self = preload("res://src/core/terrain/TerrainLayoutNode.gd")

const TerrainLayout = preload("res://src/core/terrain/TerrainLayout.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")

# Signal for feature changes (matches TerrainLayout)
signal feature_changed(position, feature_type, old_feature_type)

var _layout: TerrainLayout
var _terrain_system: TerrainSystem

func _init(terrain_system: TerrainSystem) -> void:
	_terrain_system = terrain_system
	_layout = TerrainLayout.new(terrain_system)
	
	# Connect to layout signals and reconnect whenever necessary
	_connect_layout_signals()

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

func place_feature(pos: Vector2i, feature: int) -> bool:
	return _layout.place_feature(pos, feature)

func get_line_of_sight(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	return _layout.get_line_of_sight(start, end)

func is_line_of_sight_blocked(start: Vector2i, end: Vector2i) -> bool:
	return _layout.is_line_of_sight_blocked(start, end)

func get_cell_modifiers(pos: Vector2i) -> Array[int]:
	return _layout.get_cell_modifiers(pos)

# Helper method to ensure signals are connected
func _connect_layout_signals() -> void:
	if _layout:
		# Disconnect any existing connections to avoid duplicates
		if _layout.is_connected("feature_changed", _on_layout_feature_changed):
			_layout.disconnect("feature_changed", _on_layout_feature_changed)
			
		# Connect to the layout's signals
		_layout.feature_changed.connect(_on_layout_feature_changed)

# Signal handler for layout feature_changed
func _on_layout_feature_changed(pos, feature_type, old_feature_type) -> void:
	# Re-emit the signal
	feature_changed.emit(pos, feature_type, old_feature_type)
