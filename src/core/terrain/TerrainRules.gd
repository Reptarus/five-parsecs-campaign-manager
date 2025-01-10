# Content from src/core/battle/TerrainRules.gd
## TerrainRules
# Enforces Core Rules terrain mechanics and validation.
# Handles terrain placement rules, deployment zone validation, terrain-specific rules, and environment effects.
class_name TerrainRules
extends Resource

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Terrain type modifiers
@export var terrain_modifiers: Dictionary = {
	GlobalEnums.BattleEnvironment.URBAN: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.BattleEnvironment.WILDERNESS: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GlobalEnums.TerrainModifier.COVER_BONUS
	]),
	GlobalEnums.BattleEnvironment.SPACE_STATION: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.BattleEnvironment.SHIP_INTERIOR: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.BattleEnvironment.NONE: PackedInt32Array([
		GlobalEnums.TerrainModifier.NONE
	])
}

# Feature type modifiers
@export var feature_modifiers: Dictionary = {
	GlobalEnums.TerrainFeatureType.WALL: PackedInt32Array([
		GlobalEnums.TerrainModifier.FULL_COVER,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.TerrainFeatureType.COVER_LOW: PackedInt32Array([
		GlobalEnums.TerrainModifier.PARTIAL_COVER
	]),
	GlobalEnums.TerrainFeatureType.COVER_HIGH: PackedInt32Array([
		GlobalEnums.TerrainModifier.FULL_COVER
	]),
	GlobalEnums.TerrainFeatureType.HIGH_GROUND: PackedInt32Array([
		GlobalEnums.TerrainModifier.ELEVATION_BONUS
	]),
	GlobalEnums.TerrainFeatureType.WATER: PackedInt32Array([
		GlobalEnums.TerrainModifier.WATER_HAZARD,
		GlobalEnums.TerrainModifier.MOVEMENT_PENALTY
	]),
	GlobalEnums.TerrainFeatureType.HAZARD: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS
	]),
	GlobalEnums.TerrainFeatureType.DIFFICULT: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN
	])
}

# Environment type modifiers
@export var environment_modifiers: Dictionary = {
	GlobalEnums.BattleEnvironment.URBAN: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.BattleEnvironment.WILDERNESS: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GlobalEnums.TerrainModifier.COVER_BONUS
	]),
	GlobalEnums.BattleEnvironment.SPACE_STATION: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.BattleEnvironment.SHIP_INTERIOR: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	])
}

func get_terrain_modifiers(terrain_type: GlobalEnums.BattleEnvironment) -> PackedInt32Array:
	return terrain_modifiers.get(terrain_type, PackedInt32Array([GlobalEnums.TerrainModifier.NONE]))

func get_feature_modifiers(feature_type: GlobalEnums.TerrainFeatureType) -> PackedInt32Array:
	return feature_modifiers.get(feature_type, PackedInt32Array([GlobalEnums.TerrainModifier.NONE]))

func has_modifier(modifiers: PackedInt32Array, modifier: GlobalEnums.TerrainModifier) -> bool:
	return modifier in modifiers

func get_movement_cost(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var base_cost := 1.0
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN):
		base_cost *= 2.0
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.WATER_HAZARD):
		base_cost *= 1.5
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.MOVEMENT_PENALTY):
		base_cost *= 1.25
		
	return base_cost

func get_cover_value(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.FULL_COVER):
		return 0.75
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.PARTIAL_COVER):
		return 0.5
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.COVER_BONUS):
		return 0.25
		
	return 0.0

func blocks_line_of_sight(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED)

func is_hazardous(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GlobalEnums.TerrainModifier.HAZARDOUS)

func get_elevation_bonus(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.ELEVATION_BONUS):
		return 1.0
	return 0.0

func get_terrain_effects(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> Dictionary:
	var effects := {}
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.HAZARDOUS):
		effects["damage_per_turn"] = 1
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.WATER_HAZARD):
		effects["movement_penalty"] = 0.5
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.ELEVATION_BONUS):
		effects["accuracy_bonus"] = 0.15
	
	return effects