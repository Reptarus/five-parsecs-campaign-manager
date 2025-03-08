extends Node

const Self = preload("res://src/core/terrain/TerrainFactory.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainPiece: GDScript = preload("res://src/core/terrain/TerrainPiece.gd")
const TerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules: GDScript = preload("res://src/core/terrain/TerrainRules.gd")

# Scene paths for terrain pieces
const TERRAIN_SCENES := {
	"base": "res://src/core/terrain/pieces/TerrainBase.tscn",
	"linear": "res://src/core/terrain/pieces/LinearFeatures.tscn",
	"small": "res://src/core/terrain/pieces/SmallTerrain.tscn",
	"large": "res://src/core/terrain/pieces/LargeTerrain.tscn",
	"garrison": "res://src/core/terrain/pieces/GarrisonFeature.tscn",
	"elevated": "res://src/core/terrain/pieces/ElevatedTerrain.tscn",
	"climbable": "res://src/core/terrain/pieces/ClimbableTerrain.tscn",
	"dangerous": "res://src/core/terrain/pieces/DangerousTerrain.tscn"
}

# Signals
signal terrain_created(piece: Node3D, type: int)
signal terrain_modified(piece: Node3D, old_type: int, new_type: int)
signal terrain_removed(piece: Node3D)

# Cache for loaded scenes
var _scene_cache: Dictionary = {}

func _ready() -> void:
	_preload_scenes()

func _preload_scenes() -> void:
	for key in TERRAIN_SCENES:
		var scene = load(TERRAIN_SCENES[key])
		if scene:
			_scene_cache[key] = scene

func create_terrain_piece(terrain_type: TerrainTypes.Type, position: Vector3, rotation: float = 0.0) -> Node3D:
	var base_scene = _get_base_scene_for_type(terrain_type)
	if not base_scene:
		push_error("TerrainFactory: Failed to get base scene for type " + str(terrain_type))
		return null
	
	var terrain_piece = base_scene.instantiate()
	if not terrain_piece:
		push_error("TerrainFactory: Failed to instantiate terrain piece")
		return null
	
	_configure_terrain_piece(terrain_piece, terrain_type, position, rotation)
	terrain_created.emit(terrain_piece, terrain_type)
	
	return terrain_piece

func modify_terrain_piece(piece: Node3D, new_type: TerrainTypes.Type) -> bool:
	if not piece or not piece.has_method("set_terrain_type"):
		return false
	
	var old_type = piece.get_terrain_type()
	piece.set_terrain_type(new_type)
	_update_terrain_properties(piece, new_type)
	
	terrain_modified.emit(piece, old_type, new_type)
	return true

func remove_terrain_piece(piece: Node3D) -> void:
	if piece:
		terrain_removed.emit(piece)
		piece.queue_free()

func _get_base_scene_for_type(terrain_type: TerrainTypes.Type) -> PackedScene:
	match terrain_type:
		TerrainTypes.Type.COVER_LOW, TerrainTypes.Type.COVER_HIGH:
			return _scene_cache.get("small", _scene_cache.get("base"))
		TerrainTypes.Type.WALL:
			return _scene_cache.get("large", _scene_cache.get("base"))
		TerrainTypes.Type.WATER, TerrainTypes.Type.HAZARD:
			return _scene_cache.get("dangerous", _scene_cache.get("base"))
		TerrainTypes.Type.DIFFICULT:
			return _scene_cache.get("climbable", _scene_cache.get("base"))
		_:
			return _scene_cache.get("base")

func _configure_terrain_piece(piece: Node3D, type: TerrainTypes.Type, position: Vector3, rotation: float) -> void:
	piece.position = position
	piece.rotation.y = rotation
	
	if piece.has_method("set_terrain_type"):
		piece.set_terrain_type(type)
	
	_update_terrain_properties(piece, type)

func _update_terrain_properties(piece: Node3D, type: TerrainTypes.Type) -> void:
	var properties = TerrainTypes.get_terrain_properties(type)
	
	# Update collision properties
	if properties.get("blocks_movement", false):
		piece.collision_layer = 1 # Solid terrain layer
		piece.collision_mask = 1
	else:
		piece.collision_layer = 2 # Passable terrain layer
		piece.collision_mask = 2
	
	# Update visual properties (assuming MeshInstance3D is present)
	var mesh_instance = piece.get_node_or_null("MeshInstance3D")
	if mesh_instance:
		_update_mesh_properties(mesh_instance, type)

func _update_mesh_properties(mesh_instance: MeshInstance3D, type: TerrainTypes.Type) -> void:
	# Update mesh appearance based on terrain type
	# This would be expanded based on your visual requirements
	var material = StandardMaterial3D.new()
	
	match type:
		TerrainTypes.Type.COVER_LOW:
			material.albedo_color = Color(0.5, 0.5, 0.5)
		TerrainTypes.Type.COVER_HIGH:
			material.albedo_color = Color(0.3, 0.3, 0.3)
		TerrainTypes.Type.WALL:
			material.albedo_color = Color(0.2, 0.2, 0.2)
		TerrainTypes.Type.WATER:
			material.albedo_color = Color(0, 0.5, 1.0, 0.7)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		TerrainTypes.Type.HAZARD:
			material.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
		TerrainTypes.Type.DIFFICULT:
			material.albedo_color = Color(0.6, 0.4, 0.2)
		_:
			material.albedo_color = Color(0.8, 0.8, 0.8)
	
	mesh_instance.material_override = material