@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const FiveParsecsTerrainRules = preload("res://src/core/terrain/TerrainRules.gd")
const FiveParsecsTerrainEffects = preload("res://src/core/terrain/TerrainEffects.gd")
const TerrainEffectSystem := preload("res://src/core/terrain/TerrainEffectSystem.gd")

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
signal terrain_effect_applied(target: Node, effect: Dictionary)

# Properties
var terrain_map: Dictionary = {}
var terrain_effect_system: TerrainEffectSystem

func _init() -> void:
	terrain_effect_system = TerrainEffectSystem.new()
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
	
	terrain_placed.emit(position, terrain_type)
	return true

func modify_terrain(position: Vector2i, new_type: int, feature_type: int = GameEnums.TerrainFeatureType.NONE) -> bool:
	if not terrain_map.has(position):
		return false
		
	var old_type = terrain_map[position].type
	terrain_map[position].type = new_type
	terrain_map[position].feature_type = feature_type
	
	terrain_modified.emit(position, old_type, new_type)
	return true

func remove_terrain(position: Vector2i) -> bool:
	if not terrain_map.has(position):
		return false
		
	terrain_map.erase(position)
	terrain_removed.emit(position)
	
	# Clear any terrain effects at this position
	terrain_effect_system.update_terrain_state(position, TerrainType.EMPTY, GameEnums.TerrainFeatureType.NONE)
	
	return true

func get_terrain_at(position: Vector2i) -> Dictionary:
	return terrain_map.get(position, {
		"type": TerrainType.EMPTY,
		"feature_type": GameEnums.TerrainFeatureType.NONE,
		"effects": []
	})

func apply_terrain_effect(target: Node, terrain_type: int) -> void:
	var state = get_terrain_at(target.position)
	terrain_effect_system.apply_terrain_effect(target, terrain_type, state.get("feature_type", GameEnums.TerrainFeatureType.NONE))

func _is_valid_position(position: Vector2i) -> bool:
	# Add any position validation logic here
	return true

func _on_terrain_effect_applied(target: Node, effect: Dictionary) -> void:
	terrain_effect_applied.emit(target, effect)

func _on_terrain_effect_removed(target: Node, effect: Dictionary) -> void:
	# Handle effect removal if needed
	pass