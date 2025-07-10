# Content from src/core/battle/TerrainRules.gd
## TerrainRules
# Enforces Core Rules terrain mechanics and validation.
# Handles terrain placement rules, deployment zone validation, terrain-specific rules, and environment effects.
@tool
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

# Terrain type modifiers
@export var terrain_modifiers: Dictionary = {
	GlobalEnums.PlanetEnvironment.URBAN: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.PlanetEnvironment.FOREST: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GlobalEnums.TerrainModifier.COVER_BONUS
	]),
	GlobalEnums.PlanetEnvironment.VOLCANIC: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.PlanetEnvironment.OCEANIC: PackedInt32Array([
		GlobalEnums.TerrainModifier.WATER_HAZARD,
		GlobalEnums.TerrainModifier.MOVEMENT_PENALTY
	]),
	GlobalEnums.PlanetEnvironment.TEMPERATE: PackedInt32Array([
		GlobalEnums.TerrainModifier.NONE
	])
}

# Feature type modifiers
@export var feature_modifiers: Dictionary = {
	GlobalEnums.TerrainFeatureType.WALL: PackedInt32Array([
		GlobalEnums.TerrainModifier.FULL_COVER,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.TerrainFeatureType.COVER: PackedInt32Array([
		GlobalEnums.TerrainModifier.PARTIAL_COVER
	]),
	GlobalEnums.TerrainFeatureType.OBSTACLE: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GlobalEnums.TerrainModifier.ELEVATION_BONUS
	]),
	GlobalEnums.TerrainFeatureType.HAZARD: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS,
		GlobalEnums.TerrainModifier.WATER_HAZARD,
		GlobalEnums.TerrainModifier.MOVEMENT_PENALTY
	]),
	GlobalEnums.TerrainFeatureType.RADIATION: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS
	]),
	GlobalEnums.TerrainFeatureType.FIRE: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS
	]),
	GlobalEnums.TerrainFeatureType.ACID: PackedInt32Array([
		GlobalEnums.TerrainModifier.HAZARDOUS,
		GlobalEnums.TerrainModifier.WATER_HAZARD
	]),
	GlobalEnums.TerrainFeatureType.SMOKE: PackedInt32Array([
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	])
}

# Environment type modifiers
@export var environment_modifiers: Dictionary = {
	GlobalEnums.PlanetEnvironment.URBAN: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.PlanetEnvironment.FOREST: PackedInt32Array([
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN,
		GlobalEnums.TerrainModifier.COVER_BONUS
	]),
	GlobalEnums.PlanetEnvironment.HAZARDOUS: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	]),
	GlobalEnums.PlanetEnvironment.RAIN: PackedInt32Array([
		GlobalEnums.TerrainModifier.COVER_BONUS,
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
	])
}

# Event handlers for terrain changes
signal terrain_rule_triggered(position: Vector2i, rule_type: String, data: Dictionary)

# Cached terrain states for rule checking
var _terrain_states: Dictionary = {}

func get_terrain_modifiers(terrain_type: GlobalEnums.PlanetEnvironment) -> PackedInt32Array:

	return terrain_modifiers.get(terrain_type, PackedInt32Array([GlobalEnums.TerrainModifier.NONE]))

func get_feature_modifiers(feature_type: GlobalEnums.TerrainFeatureType) -> PackedInt32Array:

	return feature_modifiers.get(feature_type, PackedInt32Array([GlobalEnums.TerrainModifier.NONE]))

func has_modifier(modifiers: PackedInt32Array, modifier: GlobalEnums.TerrainModifier) -> bool:
	return modifier in modifiers

func get_movement_cost(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var base_cost := 1.0
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN):
		base_cost *= 2.0
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.WATER_HAZARD):
		base_cost *= 1.5
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.MOVEMENT_PENALTY):
		base_cost *= 1.25

	return base_cost

func get_cover_value(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.FULL_COVER):
		return 0.75
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.PARTIAL_COVER):
		return 0.5
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.COVER_BONUS):
		return 0.25

	return 0.0

func blocks_line_of_sight(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED)

func is_hazardous(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	return has_modifier(modifiers, GlobalEnums.TerrainModifier.HAZARDOUS)

func get_elevation_bonus(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> float:
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	if has_modifier(modifiers, GlobalEnums.TerrainModifier.ELEVATION_BONUS):
		return 1.0
	return 0.0

func get_terrain_effects(terrain_type: GlobalEnums.PlanetEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> Dictionary:
	var effects := {}
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.HAZARDOUS):
		effects[GlobalEnums.TerrainEffectType.HAZARD] = 1.0

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.WATER_HAZARD):
		effects[GlobalEnums.TerrainEffectType.HAZARD] = 0.5

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.ELEVATION_BONUS):
		effects[GlobalEnums.TerrainEffectType.ELEVATED] = 1.0

	if has_modifier(modifiers, GlobalEnums.TerrainModifier.FULL_COVER) or has_modifier(modifiers, GlobalEnums.TerrainModifier.PARTIAL_COVER):
		effects[GlobalEnums.TerrainEffectType.COVER] = get_cover_value(terrain_type, feature_type)

	# Feature-specific effects
	match feature_type:
		GlobalEnums.TerrainFeatureType.RADIATION:
			effects[GlobalEnums.TerrainEffectType.RADIATION] = 1.0
		GlobalEnums.TerrainFeatureType.FIRE:
			effects[GlobalEnums.TerrainEffectType.BURNING] = 1.0
		GlobalEnums.TerrainFeatureType.ACID:
			effects[GlobalEnums.TerrainEffectType.ACID] = 1.0
		GlobalEnums.TerrainFeatureType.SMOKE:
			effects[GlobalEnums.TerrainEffectType.OBSCURED] = 1.0

	return effects

# Called when terrain changes at a position
func on_terrain_changed(position: Vector2i, new_state: Dictionary) -> void:
	_terrain_states[position] = new_state

	# Check adjacent terrain for special rules
	_check_terrain_rules(position)

# Check for special terrain interaction rules
func _check_terrain_rules(position: Vector2i) -> void:

	var current_state = _terrain_states.get(position, {})
	if (safe_call_method(current_state, "is_empty") == true):
		return

	# Example rule: Fire spreads to adjacent flammable terrain

	if current_state.get("feature_type", null) == GlobalEnums.TerrainFeatureType.FIRE:
		_check_fire_spread_rule(position)

	# Example rule: Water extinguishes fire

	if current_state.get("terrain_type", null) == TerrainTypes.Type.WATER:
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
		if (safe_call_method(adj_state, "is_empty") == true):
			continue

		# Check if adjacent terrain can catch fire

		if adj_state.get("terrain_type", null) == TerrainTypes.Type.FOREST:
			var data: Dictionary = {
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
		if (safe_call_method(adj_state, "is_empty") == true):
			continue

		# Check if adjacent terrain has fire

		if adj_state.get("feature_type", null) == GlobalEnums.TerrainFeatureType.FIRE:
			var data: Dictionary = {
				"source_position": position,
				"target_position": adj_pos,
				"probability": 0.5 # 50% chance to extinguish
			}
			terrain_rule_triggered.emit(adj_pos, "extinguish_fire", data)  # warning: return value discarded (intentional)

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return default_value
	if obj is Object and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null