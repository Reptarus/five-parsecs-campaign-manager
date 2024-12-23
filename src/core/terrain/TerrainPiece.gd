class_name TerrainPiece
extends StaticBody3D

const TerrainTypes = preload("res://src/core/battle/TerrainTypes.gd")

@export var terrain_type: TerrainTypes.Type = TerrainTypes.Type.EMPTY
@export var destructible := false
@export var current_health := 100
@export var max_health := 100

var _combat_modifiers: Dictionary = {}
var _special_effects: Dictionary = {}
var _original_position: Vector3
var _is_damaged := false
var _mesh_instance: MeshInstance3D

func _ready() -> void:
	add_to_group("terrain")
	_original_position = position
	_mesh_instance = get_node_or_null("MeshInstance3D")
	_initialize_terrain_properties()

func _initialize_terrain_properties() -> void:
	# Get terrain properties from type
	match terrain_type:
		TerrainTypes.Type.COVER_HIGH:
			_combat_modifiers = {"cover": -2}
			_special_effects = {"blocks_los": true}
		TerrainTypes.Type.COVER_LOW:
			_combat_modifiers = {"cover": -1}
			_special_effects = {"blocks_los": false}
		TerrainTypes.Type.DIFFICULT:
			_combat_modifiers = {"movement": -1}
			_special_effects = {"difficult_terrain": true}
		TerrainTypes.Type.EMPTY:
			_combat_modifiers = {}
			_special_effects = {}
		_:
			_combat_modifiers = {}
			_special_effects = {}
	
	# Set collision properties based on terrain type
	if terrain_type in [TerrainTypes.Type.WALL, TerrainTypes.Type.COVER_HIGH]:
		collision_layer = 1  # Collision layer for solid terrain
		collision_mask = 1
	else:
		collision_layer = 2  # Collision layer for passable terrain
		collision_mask = 2

func get_cover_value() -> float:
	if _is_damaged and terrain_type == TerrainTypes.Type.COVER_HIGH:
		return TerrainTypes.get_cover_value(TerrainTypes.Type.COVER_LOW)
	return TerrainTypes.get_cover_value(terrain_type)

func get_elevation() -> float:
	return TerrainTypes.get_elevation(terrain_type)

func get_movement_cost() -> float:
	if _is_damaged and TerrainTypes.blocks_movement(terrain_type):
		return TerrainTypes.get_movement_cost(TerrainTypes.Type.DIFFICULT)
	return TerrainTypes.get_movement_cost(terrain_type)

func blocks_line_of_sight() -> bool:
	if _is_damaged and terrain_type == TerrainTypes.Type.WALL:
		return false
	return TerrainTypes.blocks_line_of_sight(terrain_type)

func get_combat_modifiers() -> Dictionary:
	if _is_damaged:
		var modified = _combat_modifiers.duplicate()
		for key in modified:
			modified[key] = modified[key] * 0.5
		return modified
	return _combat_modifiers

func get_special_effects() -> Dictionary:
	return _special_effects

func can_be_destroyed() -> bool:
	return destructible

func take_damage(amount: int) -> void:
	if not destructible:
		return
		
	current_health = max(0, current_health - amount)
	_is_damaged = current_health < max_health
	
	if current_health == 0:
		_handle_destruction()
	elif _is_damaged:
		_handle_damage()

func _handle_damage() -> void:
	# Visual feedback for damage
	if _mesh_instance:
		_mesh_instance.set_instance_shader_parameter("damage_color", Color(1.0, 0.7, 0.7))
	
	# Adjust collision shape if needed
	if terrain_type == TerrainTypes.Type.WALL:
		var collision_shape = get_node_or_null("CollisionShape3D")
		if collision_shape:
			var shape = collision_shape.shape
			if shape is BoxShape3D:
				shape.size.y *= 0.5

func _handle_destruction() -> void:
	if terrain_type == TerrainTypes.Type.WALL:
		# Convert to rubble
		terrain_type = TerrainTypes.Type.DIFFICULT
		_initialize_terrain_properties()
		
		var collision_shape = get_node_or_null("CollisionShape3D")
		if collision_shape:
			var shape = collision_shape.shape
			if shape is BoxShape3D:
				shape.size.y *= 0.3
	else:
		queue_free()

func get_terrain_type() -> TerrainTypes.Type:
	return terrain_type

func is_damaged() -> bool:
	return _is_damaged

func get_original_position() -> Vector3:
	return _original_position

func repair(amount: int) -> void:
	if not _is_damaged:
		return
		
	current_health = min(max_health, current_health + amount)
	_is_damaged = current_health < max_health
	
	if not _is_damaged:
		_restore_original_state()

func _restore_original_state() -> void:
	if _mesh_instance:
		_mesh_instance.set_instance_shader_parameter("damage_color", Color(1.0, 1.0, 1.0))
	
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		var shape = collision_shape.shape
		if shape is BoxShape3D:
			shape.size = Vector3.ONE
	
	_initialize_terrain_properties()
