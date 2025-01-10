## UnifiedTerrainSystem
## Manages terrain generation, validation, and interaction for the Five Parsecs battle system.
class_name UnifiedTerrainSystem
extends Node2D

const TerrainTypes = preload("res://src/core/battle/TerrainTypes.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals
signal terrain_updated(position: Vector2i, terrain_type: int)
signal terrain_effect_applied(target: Node, effect: String)
signal terrain_state_changed(position: Vector2i, state: Dictionary)

# Core components
@onready var terrain_factory: TerrainFactory = $TerrainFactory
@onready var terrain_effect_system: TerrainEffectSystem = $TerrainEffectSystem
@onready var terrain_container: Node3D = $TerrainContainer

# Terrain generation parameters
var grid_size: Vector2i = Vector2i(24, 24) # Standard battlefield size in grid squares
var cell_size: Vector2i = Vector2i(32, 32) # Size of each grid cell in pixels

# Terrain state tracking
var terrain_map: Array[Array] = []
var terrain_pieces: Dictionary = {} # Grid position to TerrainPiece mapping
var initialized: bool = false

func _ready() -> void:
	add_to_group("terrain_system")
	_initialize_components()
	initialize_terrain_system()

func _initialize_components() -> void:
	if not terrain_factory:
		terrain_factory = TerrainFactory.new()
		add_child(terrain_factory)
	
	if not terrain_effect_system:
		terrain_effect_system = TerrainEffectSystem.new()
		add_child(terrain_effect_system)
	
	if not terrain_container:
		terrain_container = Node3D.new()
		terrain_container.name = "TerrainContainer"
		add_child(terrain_container)
	
	# Connect signals
	terrain_factory.terrain_created.connect(_on_terrain_created)
	terrain_factory.terrain_modified.connect(_on_terrain_modified)
	terrain_factory.terrain_removed.connect(_on_terrain_removed)
	
	terrain_effect_system.effect_applied.connect(_on_effect_applied)
	terrain_effect_system.terrain_state_changed.connect(_on_terrain_state_changed)

func initialize_terrain_system() -> void:
	if initialized:
		return
	
	# Initialize the terrain map
	terrain_map.clear()
	for x in range(grid_size.x):
		terrain_map.append([])
		terrain_map[x].resize(grid_size.y)
		for y in range(grid_size.y):
			terrain_map[x][y] = TerrainTypes.Type.EMPTY
	
	initialized = true

func place_terrain(position: Vector2i, terrain_type: int, feature_type: GlobalEnums.TerrainFeatureType = GlobalEnums.TerrainFeatureType.NONE) -> bool:
	if not initialized or not is_position_valid(position):
		return false
	
	var world_position = grid_to_world(position)
	var terrain_piece = terrain_factory.create_terrain_piece(
		terrain_type,
		Vector3(world_position.x, 0, world_position.y)
	)
	
	if not terrain_piece:
		return false
	
	# Update terrain state
	terrain_map[position.x][position.y] = terrain_type
	terrain_pieces[position] = terrain_piece
	terrain_container.add_child(terrain_piece)
	
	# Update terrain effects
	terrain_effect_system.update_terrain_state(position, terrain_type, feature_type)
	
	terrain_updated.emit(position, terrain_type)
	return true

func modify_terrain(position: Vector2i, new_type: int, feature_type: GlobalEnums.TerrainFeatureType = GlobalEnums.TerrainFeatureType.NONE) -> bool:
	if not initialized or not is_position_valid(position):
		return false
	
	var terrain_piece = terrain_pieces.get(position)
	if not terrain_piece:
		return false
	
	if terrain_factory.modify_terrain_piece(terrain_piece, new_type):
		terrain_map[position.x][position.y] = new_type
		terrain_effect_system.update_terrain_state(position, new_type, feature_type)
		terrain_updated.emit(position, new_type)
		return true
	
	return false

func remove_terrain(position: Vector2i) -> void:
	if not initialized or not is_position_valid(position):
		return
	
	var terrain_piece = terrain_pieces.get(position)
	if terrain_piece:
		terrain_factory.remove_terrain_piece(terrain_piece)
		terrain_pieces.erase(position)
		terrain_map[position.x][position.y] = TerrainTypes.Type.EMPTY
		terrain_effect_system.update_terrain_state(position, TerrainTypes.Type.EMPTY, GlobalEnums.TerrainFeatureType.NONE)
		terrain_updated.emit(position, TerrainTypes.Type.EMPTY)

func get_terrain_at_position(position: Vector2i) -> int:
	if not initialized or not is_position_valid(position):
		return TerrainTypes.Type.INVALID
	return terrain_map[position.x][position.y]

func get_terrain_state(position: Vector2i) -> Dictionary:
	return terrain_effect_system.get_terrain_state(position)

func apply_terrain_effects(target: Node, position: Vector2i) -> void:
	if not initialized or not is_position_valid(position):
		return
	
	var terrain_type = get_terrain_at_position(position)
	var state = get_terrain_state(position)
	terrain_effect_system.apply_terrain_effect(target, terrain_type, state.get("feature_type", GlobalEnums.TerrainFeatureType.NONE))

func remove_terrain_effects(target: Node) -> void:
	terrain_effect_system.remove_terrain_effects(target)

func get_movement_cost(from: Vector2i, to: Vector2i) -> float:
	return terrain_effect_system.calculate_movement_cost(from, to)

func get_cover_value(position: Vector2i, target_position: Vector2i) -> float:
	return terrain_effect_system.calculate_cover_value(position, target_position)

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	return terrain_effect_system.has_line_of_sight(from, to)

func clear_terrain() -> void:
	if not initialized:
		return
	
	for piece in terrain_pieces.values():
		terrain_factory.remove_terrain_piece(piece)
	
	terrain_pieces.clear()
	initialize_terrain_system()
	terrain_effect_system.clear_states()

func is_position_valid(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < grid_size.x and position.y >= 0 and position.y < grid_size.y

func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(
		grid_position.x * cell_size.x + cell_size.x / 2,
		grid_position.y * cell_size.y + cell_size.y / 2
	)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / cell_size.x),
		int(world_position.y / cell_size.y)
	)

# Signal handlers
func _on_terrain_created(piece: Node3D, type: int) -> void:
	# Additional setup if needed
	pass

func _on_terrain_modified(piece: Node3D, old_type: int, new_type: int) -> void:
	# Handle terrain modification effects
	pass

func _on_terrain_removed(piece: Node3D) -> void:
	# Cleanup if needed
	pass

func _on_effect_applied(target: Node, effect_type: String, _value: float) -> void:
	terrain_effect_applied.emit(target, effect_type)

func _on_terrain_state_changed(position: Vector2i, state: Dictionary) -> void:
	terrain_state_changed.emit(position, state)