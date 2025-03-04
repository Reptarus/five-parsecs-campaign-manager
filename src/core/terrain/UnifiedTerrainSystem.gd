@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules = preload("res://src/core/terrain/TerrainRules.gd")
const TerrainEffectSystem = preload("res://src/core/terrain/TerrainEffectSystem.gd")

# Define terrain type enum locally if not found in TerrainTypes.gd
enum TerrainType {
	EMPTY = 0,
	GRASS = 1,
	DIRT = 2,
	ROCK = 3,
	WATER = 4,
	SAND = 5,
	SNOW = 6,
	URBAN = 7
}

# Signals
signal terrain_placed(position: Vector2i, terrain_type: int)
signal terrain_modified(position: Vector2i, old_type: int, new_type: int)
signal terrain_removed(position: Vector2i)
signal terrain_effect_applied(target_id: int, effect_type: int, strength: float)
signal terrain_effect_removed(target_id: int, effect_type: int)

# Properties
var terrain_map: Dictionary = {}
var terrain_effect_system: TerrainEffectSystem
var terrain_rules: TerrainRules

func _init() -> void:
	terrain_effect_system = TerrainEffectSystem.new()
	terrain_rules = TerrainRules.new()
	add_child(terrain_effect_system)

func _ready() -> void:
	terrain_effect_system.connect("effect_applied", _on_terrain_effect_applied)
	terrain_effect_system.connect("effect_removed", _on_terrain_effect_removed)

func place_terrain(position: Vector2i, terrain_type: int, feature_type: int = GameEnums.TerrainFeatureType.NONE) -> bool:
	if not _is_valid_position(position):
		return false
		
	if terrain_map.has(position):
		return false
		
	terrain_map[position] = {
		"type": terrain_type,
		"feature_type": feature_type,
		"effects": []
	}
	
	# Update terrain state in effect system
	terrain_effect_system.update_terrain_state(position, terrain_type, feature_type)
	
	terrain_placed.emit(position, terrain_type)
	return true

func modify_terrain(position: Vector2i, new_type: int, feature_type: int = GameEnums.TerrainFeatureType.NONE) -> bool:
	if not terrain_map.has(position):
		return false
		
	var old_type = terrain_map[position].type
	terrain_map[position].type = new_type
	terrain_map[position].feature_type = feature_type
	
	# Update terrain state in effect system
	terrain_effect_system.update_terrain_state(position, new_type, feature_type)
	
	terrain_modified.emit(position, old_type, new_type)
	return true

func remove_terrain(position: Vector2i) -> bool:
	if not terrain_map.has(position):
		return false
		
	terrain_map.erase(position)
	terrain_removed.emit(position)
	
	# Clear any terrain effects at this position
	terrain_effect_system.update_terrain_state(position, TerrainTypes.Type.EMPTY, GameEnums.TerrainFeatureType.NONE)
	
	return true

func get_terrain_at(position: Vector2i) -> Dictionary:
	return terrain_map.get(position, {
		"type": TerrainTypes.Type.EMPTY,
		"feature_type": GameEnums.TerrainFeatureType.NONE,
		"effects": []
	})

func apply_terrain_effect_to_unit(target: Node, position: Vector2i) -> void:
	var state = get_terrain_at(position)
	terrain_effect_system.apply_terrain_effect(target, state.get("type", TerrainTypes.Type.EMPTY), state.get("feature_type", GameEnums.TerrainFeatureType.NONE))

func remove_terrain_effects_from_unit(target: Node) -> void:
	terrain_effect_system.remove_terrain_effects(target)

func get_movement_cost(position: Vector2i) -> float:
	return terrain_effect_system.get_movement_cost(position)

func provides_cover(position: Vector2i) -> bool:
	return terrain_effect_system.provides_cover(position)

func is_traversable(position: Vector2i) -> bool:
	return terrain_effect_system.is_traversable(position)

func is_elevated(position: Vector2i) -> bool:
	return terrain_effect_system.is_elevated(position)

func is_position_empty(position: Vector2i) -> bool:
	return not terrain_map.has(position)

func set_terrain_feature(position: Vector2i, feature_type: int) -> bool:
	if not terrain_map.has(position):
		# Create new terrain with the feature
		return place_terrain(position, TerrainTypes.Type.EMPTY, feature_type)
	else:
		# Modify existing terrain to add the feature
		var current_type = terrain_map[position].type
		return modify_terrain(position, current_type, feature_type)

func get_grid_size() -> Vector2:
	# Default grid size or based on some property
	return Vector2(20, 20)

func _is_valid_position(position: Vector2i) -> bool:
	var grid_size = get_grid_size()
	return position.x >= 0 and position.y >= 0 and position.x < grid_size.x and position.y < grid_size.y

func _on_terrain_effect_applied(target_id: int, effect_type: int, strength: float) -> void:
	terrain_effect_applied.emit(target_id, effect_type, strength)

func _on_terrain_effect_removed(target_id: int, effect_type: int) -> void:
	terrain_effect_removed.emit(target_id, effect_type)

func clear_all() -> void:
	terrain_map.clear()
	terrain_effect_system._terrain_states.clear()
	terrain_effect_system._active_effects.clear()