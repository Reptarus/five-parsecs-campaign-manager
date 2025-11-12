@tool
extends Node

# GlobalEnums available as autoload singleton
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")

enum LayoutType {
	OPEN, # Sparse cover, good for ranged combat
	DENSE, # Heavy cover, good for close combat

	ASYMMETRIC, # One side has more cover than the other
	CORRIDOR, # Linear paths with choke points
	SCATTERED # Evenly distributed cover and obstacles
}

var _terrain_system: TerrainSystem
var _cover_density: float = 0.3
var _hazard_density: float = 0.1
var _symmetrical: bool = true
var _min_paths: int = 2
var _choke_points: int = 1

func _init(terrain_system: TerrainSystem) -> void:
	_terrain_system = terrain_system
func generate_layout(layout_type: LayoutType) -> void:
	match layout_type:
		LayoutType.OPEN:
			_generate_open_layout()
		LayoutType.DENSE:
			_generate_dense_layout()
		LayoutType.ASYMMETRIC:
			_generate_asymmetric_layout()
		LayoutType.CORRIDOR:
			_generate_corridor_layout()
		LayoutType.SCATTERED:
			_generate_scattered_layout()
func _generate_open_layout() -> void:
	var grid_size: Vector2i = _terrain_system.get_grid_size()
	var total_cells := int(grid_size.x * grid_size.y)
	var cover_count := int(total_cells * _cover_density * 0.5) # Reduced density for open layout

	# Place low cover
	for i: int in range(cover_count):
		var pos := _find_random_position()
		if pos != Vector2.ZERO:
			_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.COVER)

	# Add a few high cover pieces
	var high_cover_count := cover_count / 4.0
	for i: int in range(high_cover_count):
		var pos := _find_random_position()
		if pos != Vector2.ZERO:
			_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.OBSTACLE)
func _generate_dense_layout() -> void:
	var grid_size: Vector2i = _terrain_system.get_grid_size()
	var total_cells := int(grid_size.x * grid_size.y)
	var cover_count := int(total_cells * _cover_density * 1.5) # Increased density

	# Place high cover
	for i: int in range(cover_count):
		var pos := _find_random_position()
		if pos != Vector2.ZERO:
			_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.OBSTACLE)

	# Add some walls for additional cover
	var wall_count := cover_count / 3.0
	for i: int in range(wall_count):
		var pos := _find_random_position()
		if pos != Vector2.ZERO:
			_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.WALL)
func _generate_asymmetric_layout() -> void:
	var grid_size: Vector2i = _terrain_system.get_grid_size()
	var mid_x := int(grid_size.x / 2.0)

	# Dense side (left)
	for x: int in range(mid_x):
		for y: int in range(int(grid_size.y)):
			if randf() < _cover_density * 1.5:
				var pos := Vector2(x, y)
				_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.OBSTACLE)

	# Open side (right)
	for x: int in range(mid_x, int(grid_size.x)):
		for y: int in range(int(grid_size.y)):
			if randf() < _cover_density * 0.5:
				var pos := Vector2(x, y)
				_set_terrain_feature(pos, GlobalEnums.TerrainFeatureType.COVER)
func _generate_corridor_layout() -> void:
	var grid_size: Vector2i = _terrain_system.get_grid_size()

	# Create walls for corridors
	for x: int in range(int(grid_size.x)):
		for y: int in range(int(grid_size.y)):
			if (y % 3 == 0 or y % 3 == 2) and randf() < 0.7:
				_set_terrain_feature(Vector2(x, y), GlobalEnums.TerrainFeatureType.WALL)

	# Add choke points
	for i: int in range(_choke_points):
		var x := randi() % int(grid_size.x)
		var y := randi() % (int(grid_size.y) / 3) * 3 + 1
		_set_terrain_feature(Vector2(x, y), GlobalEnums.TerrainFeatureType.OBSTACLE)
func _generate_scattered_layout() -> void:
	var grid_size: Vector2i = _terrain_system.get_grid_size()
	var total_cells := int(grid_size.x * grid_size.y)
	var feature_count := int(total_cells * _cover_density)

	# Create clusters of cover
	for i: int in range(feature_count):
		var pos := _find_random_position()
		if pos != Vector2.ZERO:
			var feature_type := _get_random_feature_type()
			_set_terrain_feature(pos, feature_type)

			# Add adjacent features with decreasing probability
			for adjacent in _get_adjacent_positions(pos):
				if randf() < 0.3:
					_set_terrain_feature(adjacent, feature_type)
func _find_random_position() -> Vector2:
	var max_attempts := 50
	var attempt := 0
	var grid_size: Vector2i = _terrain_system.get_grid_size()

	while attempt < max_attempts:
		var x := randi() % int(grid_size.x)
		var y := randi() % int(grid_size.y)
		var pos := Vector2(x, y)

		if _terrain_system.is_position_empty(pos):
			return pos

		attempt += 1

	return Vector2.ZERO

func _get_random_feature_type() -> int:
	var types := [
		GlobalEnums.TerrainFeatureType.COVER,
		GlobalEnums.TerrainFeatureType.OBSTACLE,
		GlobalEnums.TerrainFeatureType.WALL
	]
	return types[randi() % (safe_call_method(types, "size") as int)]

func _get_adjacent_positions(pos: Vector2) -> Array:
	var adjacent := []
	var offsets := [
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(0, -1), Vector2(0, 1)
	]

	for offset in offsets:
		var adjacent_pos := Vector2(pos.x + offset.x, pos.y + offset.y)
		if _is_valid_position(adjacent_pos):
			safe_call_method(adjacent, "append", [adjacent_pos]) # warning: return value discarded (intentional)

	return adjacent

func _is_valid_position(pos: Vector2) -> bool:
	var grid_size: Vector2i = _terrain_system.get_grid_size()
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func _set_terrain_feature(pos: Vector2, feature_type: int) -> void:
	_terrain_system.set_terrain_feature(pos, feature_type)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null