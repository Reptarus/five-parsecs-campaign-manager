# Content from src/core/battle/TerrainRules.gd
## TerrainRules
# Enforces Core Rules terrain mechanics and validation.
# Handles terrain placement rules, deployment zone validation, terrain-specific rules, and environment effects.
@tool
extends Resource

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

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
	GameEnums.PlanetEnvironment.VOLCANIC: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS,
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GameEnums.PlanetEnvironment.OCEANIC: PackedInt32Array([
		GameEnums.TerrainModifier.WATER_HAZARD,
		GameEnums.TerrainModifier.MOVEMENT_PENALTY
	]),
	GameEnums.PlanetEnvironment.TEMPERATE: PackedInt32Array([
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
	]),
	GameEnums.TerrainFeatureType.RADIATION: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS
	]),
	GameEnums.TerrainFeatureType.FIRE: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS
	]),
	GameEnums.TerrainFeatureType.ACID: PackedInt32Array([
		GameEnums.TerrainModifier.HAZARDOUS,
		GameEnums.TerrainModifier.WATER_HAZARD
	]),
	GameEnums.TerrainFeatureType.SMOKE: PackedInt32Array([
		GameEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
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

# Event handlers for terrain changes
signal terrain_rule_triggered(position: Vector2i, rule_type: String, data: Dictionary)

# Cached terrain states for rule checking
var _terrain_states: Dictionary = {}

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
		effects[GameEnums.TerrainEffectType.HAZARD] = 1.0
		
	if has_modifier(modifiers, GameEnums.TerrainModifier.WATER_HAZARD):
		effects[GameEnums.TerrainEffectType.HAZARD] = 0.5
		
	if has_modifier(modifiers, GameEnums.TerrainModifier.ELEVATION_BONUS):
		effects[GameEnums.TerrainEffectType.ELEVATED] = 1.0
		
	if has_modifier(modifiers, GameEnums.TerrainModifier.FULL_COVER) or has_modifier(modifiers, GameEnums.TerrainModifier.PARTIAL_COVER):
		effects[GameEnums.TerrainEffectType.COVER] = get_cover_value(terrain_type, feature_type)
	
	# Feature-specific effects
	match feature_type:
		GameEnums.TerrainFeatureType.RADIATION:
			effects[GameEnums.TerrainEffectType.RADIATION] = 1.0
		GameEnums.TerrainFeatureType.FIRE:
			effects[GameEnums.TerrainEffectType.BURNING] = 1.0
		GameEnums.TerrainFeatureType.ACID:
			effects[GameEnums.TerrainEffectType.ACID] = 1.0
		GameEnums.TerrainFeatureType.SMOKE:
			effects[GameEnums.TerrainEffectType.OBSCURED] = 1.0
	
	return effects

# Called when terrain changes at a position
func on_terrain_changed(position: Vector2i, new_state: Dictionary) -> void:
	_terrain_states[position] = new_state
	
	# Check adjacent terrain for special rules
	_check_terrain_rules(position)

# Check for special terrain interaction rules
func _check_terrain_rules(position: Vector2i) -> void:
	var current_state = _terrain_states.get(position, {})
	if current_state.is_empty():
		return
		
	# Example rule: Fire spreads to adjacent flammable terrain
	if current_state.get("feature_type") == GameEnums.TerrainFeatureType.FIRE:
		_check_fire_spread_rule(position)
	
	# Example rule: Water extinguishes fire
	if current_state.get("terrain_type") == TerrainTypes.Type.WATER:
		_check_extinguish_rule(position)

# Fire can spread to adjacent cells with certain terrain types
func _check_fire_spread_rule(position: Vector2i) -> void:
	var adjacent_positions = [
		Vector2i(position.x - 1, position.y),
		Vector2i(position.x + 1, position.y),
		Vector2i(position.x, position.y - 1),
		Vector2i(position.x, position.y + 1)
	]
	
	for adj_pos in adjacent_positions:
		var adj_state = _terrain_states.get(adj_pos, {})
		if adj_state.is_empty():
			continue
			
		# Check if adjacent terrain can catch fire
		if adj_state.get("terrain_type") == TerrainTypes.Type.FOREST:
			var data = {
				"source_position": position,
				"target_position": adj_pos,
				"probability": 0.2 # 20% chance to spread
			}
			terrain_rule_triggered.emit(adj_pos, "fire_spread", data)

# Water can extinguish fire
func _check_extinguish_rule(position: Vector2i) -> void:
	var adjacent_positions = [
		Vector2i(position.x - 1, position.y),
		Vector2i(position.x + 1, position.y),
		Vector2i(position.x, position.y - 1),
		Vector2i(position.x, position.y + 1)
	]
	
	for adj_pos in adjacent_positions:
		var adj_state = _terrain_states.get(adj_pos, {})
		if adj_state.is_empty():
			continue
			
		# Check if adjacent terrain has fire
		if adj_state.get("feature_type") == GameEnums.TerrainFeatureType.FIRE:
			var data = {
				"source_position": position,
				"target_position": adj_pos,
				"probability": 0.5 # 50% chance to extinguish
			}
			terrain_rule_triggered.emit(adj_pos, "extinguish_fire", data)
