# Content from src/core/battle/TerrainRules.gd
## TerrainRules
# Enforces Core Rules terrain mechanics and validation.
# Handles terrain placement rules, deployment zone validation, terrain-specific rules, and environment effects.
@tool
extends Resource

const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")

# Terrain type modifiers
@export var terrain_modifiers: Dictionary = {
	GameEnums.PlanetEnvironment.URBAN: PackedInt32Array([
		GameEnums.TerrainModifier.COVER_BONUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.PlanetEnvironment.FOREST: PackedInt32Array([
		GameEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GameEnums.TerrainModifier.COVER_BONUS
	]),
	GameEnums.PlanetEnvironment.HAZARDOUS: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.PlanetEnvironment.RAIN: PackedInt32Array([
		GameEnums.TerrainModifier.WATER_HAZARD,
		GameEnums.TerrainModifier.MOVEMENT_PENALTY
	]),
	GameEnums.PlanetEnvironment.NONE: PackedInt32Array([
		GameEnums.TerrainModifier.NONE
	])
}

# Feature type modifiers
@export var feature_modifiers: Dictionary = {
	GameEnums.TerrainFeatureType.WALL: PackedInt32Array([
		GameEnums.TerrainModifier.FULL_COVER,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.TerrainFeatureType.COVER: PackedInt32Array([
		GameEnums.TerrainModifier.PARTIAL_COVER
	]),
	GameEnums.TerrainFeatureType.OBSTACLE: PackedInt32Array([
		GameEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GameEnums.TerrainModifier.ELEVATION_BONUS
	]),
	GameEnums.TerrainFeatureType.HAZARD: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS,
		GameEnums.TerrainModifier.WATER_HAZARD,
		GameEnums.TerrainModifier.MOVEMENT_PENALTY
	])
}

# Environment type modifiers
@export var environment_modifiers: Dictionary = {
	GameEnums.PlanetEnvironment.URBAN: PackedInt32Array([
		GameEnums.TerrainModifier.COVER_BONUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.PlanetEnvironment.FOREST: PackedInt32Array([
		GameEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GameEnums.TerrainModifier.COVER_BONUS
	]),
	GameEnums.PlanetEnvironment.HAZARDOUS: PackedInt32Array([
		GameEnums.TerrainModifier.COVER_BONUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.PlanetEnvironment.RAIN: PackedInt32Array([
		GameEnums.TerrainModifier.COVER_BONUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	])
}

func get_terrain_modifiers(terrain_type: GameEnums.PlanetEnvironment) -> PackedInt32Array:
	return terrain_modifiers.get(terrain_type, PackedInt32Array([GameEnums.TerrainModifier.NONE]))

func get_feature_modifiers(feature_type: GameEnums.TerrainFeatureType) -> PackedInt32Array:
	return feature_modifiers.get(feature_type, PackedInt32Array([GameEnums.TerrainModifier.NONE]))

func has_modifier(modifiers: PackedInt32Array, modifier: GameEnums.TerrainModifier) -> bool:
	return modifier in modifiers

func get_movement_cost(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> float:
	var base_cost := 1.0
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GameEnums.TerrainModifier.DIFFICULT_TERRAIN):
		base_cost *= 2.0
	if has_modifier(modifiers, GameEnums.TerrainModifier.WATER_HAZARD):
		base_cost *= 1.5
	if has_modifier(modifiers, GameEnums.TerrainModifier.MOVEMENT_PENALTY):
		base_cost *= 1.25
		
	return base_cost

func get_cover_value(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GameEnums.TerrainModifier.FULL_COVER):
		return 0.75
	if has_modifier(modifiers, GameEnums.TerrainModifier.PARTIAL_COVER):
		return 0.5
	if has_modifier(modifiers, GameEnums.TerrainModifier.COVER_BONUS):
		return 0.25
		
	return 0.0

func blocks_line_of_sight(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED)

func is_hazardous(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GameEnums.TerrainModifier.HAZARDOUS)

func get_elevation_bonus(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	if has_modifier(modifiers, GameEnums.TerrainModifier.ELEVATION_BONUS):
		return 1.0
	return 0.0

func get_terrain_effects(terrain_type: GameEnums.PlanetEnvironment, feature_type: GameEnums.TerrainFeatureType) -> Dictionary:
	var effects := {}
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	if has_modifier(modifiers, GameEnums.TerrainModifier.HAZARDOUS):
		effects["damage_per_turn"] = 1
	if has_modifier(modifiers, GameEnums.TerrainModifier.WATER_HAZARD):
		effects["movement_penalty"] = 0.5
	if has_modifier(modifiers, GameEnums.TerrainModifier.ELEVATION_BONUS):
		effects["accuracy_bonus"] = 0.15
	
	return effects