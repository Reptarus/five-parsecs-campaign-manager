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

func validate_terrain_placement(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType, position: Vector2i, grid: Array) -> Dictionary:
	var validation := {
		"valid": true,
		"errors": []
	}
	
	# Check if position is within grid bounds
	if not _is_valid_grid_position(position, grid):
		validation.valid = false
		validation.errors.append("Position out of bounds")
		return validation
	
	# Check if terrain combination is valid
	if not _is_valid_terrain_combination(terrain_type, feature_type):
		validation.valid = false
		validation.errors.append("Invalid terrain combination")
	
	# Check if terrain placement follows rules
	if not _follows_placement_rules(terrain_type, feature_type, position, grid):
		validation.valid = false
		validation.errors.append("Placement rules violated")
	
	return validation

func _is_valid_grid_position(position: Vector2i, grid: Array) -> bool:
	return position.x >= 0 and position.x < grid.size() and \
		   position.y >= 0 and position.y < grid[0].size()

func _is_valid_terrain_combination(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	# Some terrain types can't have certain features
	match terrain_type:
		GlobalEnums.BattleEnvironment.SPACE_STATION:
			return feature_type != GlobalEnums.TerrainFeatureType.WATER and \
				   feature_type != GlobalEnums.TerrainFeatureType.DIFFICULT
		GlobalEnums.BattleEnvironment.SHIP_INTERIOR:
			return feature_type != GlobalEnums.TerrainFeatureType.WATER and \
				   feature_type != GlobalEnums.TerrainFeatureType.DIFFICULT
		_:
			return true

func _follows_placement_rules(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType, position: Vector2i, grid: Array) -> bool:
	# Check adjacent tiles for placement rules
	var adjacent_positions := _get_adjacent_positions(position)
	
	for adj_pos in adjacent_positions:
		if not _is_valid_grid_position(adj_pos, grid):
			continue
		
		var adj_terrain: Dictionary = grid[adj_pos.x][adj_pos.y]
		if not _is_valid_adjacent_terrain(terrain_type, feature_type, adj_terrain):
			return false
	
	return true

func _get_adjacent_positions(position: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			adjacent.append(Vector2i(position.x + dx, position.y + dy))
	return adjacent

func _is_valid_adjacent_terrain(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType, adjacent_terrain: Dictionary) -> bool:
	# Some features can't be placed next to each other
	if feature_type == GlobalEnums.TerrainFeatureType.WALL and \
	   adjacent_terrain.feature_type == GlobalEnums.TerrainFeatureType.WALL:
		return false
	
	# Water features must be connected
	if feature_type == GlobalEnums.TerrainFeatureType.WATER and \
	   adjacent_terrain.feature_type == GlobalEnums.TerrainFeatureType.WATER:
		return true
	
	return true

# Special terrain effects
func apply_terrain_effects(unit: Node, terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> void:
	var effects := get_terrain_effects(terrain_type, feature_type)
	
	for effect in effects:
		match effect:
			"damage_per_turn":
				if unit.has_method("take_damage"):
					unit.take_damage(effects[effect])
			"movement_penalty":
				if unit.has_method("apply_movement_penalty"):
					unit.apply_movement_penalty(effects[effect])
			"accuracy_bonus":
				if unit.has_method("apply_accuracy_bonus"):
					unit.apply_accuracy_bonus(effects[effect])

func get_terrain_description(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> String:
	var description := ""
	var modifiers := get_terrain_modifiers(terrain_type) + get_feature_modifiers(feature_type)
	
	# Add terrain type description
	description += _get_terrain_type_description(terrain_type)
	
	# Add feature description
	if feature_type != GlobalEnums.TerrainFeatureType.NONE:
		description += "\n" + _get_feature_type_description(feature_type)
	
	# Add modifier effects
	var effects := []
	for modifier in modifiers:
		effects.append(_get_modifier_description(modifier))
	
	if not effects.is_empty():
		description += "\nEffects:\n- " + "\n- ".join(effects)
	
	return description

func _get_terrain_type_description(terrain_type: GlobalEnums.BattleEnvironment) -> String:
	match terrain_type:
		GlobalEnums.BattleEnvironment.URBAN:
			return "Urban environment with buildings and streets"
		GlobalEnums.BattleEnvironment.WILDERNESS:
			return "Natural environment with varied terrain"
		GlobalEnums.BattleEnvironment.SPACE_STATION:
			return "Artificial space structure with corridors and chambers"
		GlobalEnums.BattleEnvironment.SHIP_INTERIOR:
			return "Interior of a spacecraft with tight corridors"
		GlobalEnums.BattleEnvironment.NONE:
			return "Standard terrain"
		_:
			return "Unknown terrain type"

func _get_feature_type_description(feature_type: GlobalEnums.TerrainFeatureType) -> String:
	match feature_type:
		GlobalEnums.TerrainFeatureType.WALL:
			return "Solid wall that blocks movement and line of sight"
		GlobalEnums.TerrainFeatureType.COVER_LOW:
			return "Low cover providing partial protection"
		GlobalEnums.TerrainFeatureType.COVER_HIGH:
			return "High cover providing significant protection"
		GlobalEnums.TerrainFeatureType.HIGH_GROUND:
			return "Elevated position providing tactical advantage"
		GlobalEnums.TerrainFeatureType.WATER:
			return "Water hazard that impedes movement"
		GlobalEnums.TerrainFeatureType.HAZARD:
			return "Dangerous area that can cause damage"
		GlobalEnums.TerrainFeatureType.DIFFICULT:
			return "Difficult terrain that slows movement"
		_:
			return "No special features"

func _get_modifier_description(modifier: GlobalEnums.TerrainModifier) -> String:
	match modifier:
		GlobalEnums.TerrainModifier.COVER_BONUS:
			return "Provides cover bonus to defense"
		GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED:
			return "Blocks line of sight"
		GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN:
			return "Reduces movement speed"
		GlobalEnums.TerrainModifier.HAZARDOUS:
			return "Causes damage to units"
		GlobalEnums.TerrainModifier.FULL_COVER:
			return "Provides full cover protection"
		GlobalEnums.TerrainModifier.PARTIAL_COVER:
			return "Provides partial cover protection"
		GlobalEnums.TerrainModifier.ELEVATION_BONUS:
			return "Provides accuracy bonus from height"
		GlobalEnums.TerrainModifier.WATER_HAZARD:
			return "Impedes movement and may cause effects"
		GlobalEnums.TerrainModifier.MOVEMENT_PENALTY:
			return "Significantly reduces movement speed"
		_:
			return "No special effects"

# Environment-specific functions
func get_environment_modifiers(environment: GlobalEnums.BattleEnvironment) -> PackedInt32Array:
	return environment_modifiers.get(environment, PackedInt32Array([]))

func apply_environment_effects(terrain_type: GlobalEnums.BattleEnvironment, feature_type: GlobalEnums.TerrainFeatureType) -> Dictionary:
	var effects = get_terrain_effects(terrain_type, feature_type)
	var env_modifiers = get_environment_modifiers(terrain_type)
	
	for modifier in env_modifiers:
		match modifier:
			GlobalEnums.TerrainModifier.COVER_BONUS:
				effects["cover_bonus"] = effects.get("cover_bonus", 0.0) + 0.25
			GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED:
				effects["blocks_los"] = true
			GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN:
				effects["movement_cost"] = effects.get("movement_cost", 1.0) * 1.5
	
	return effects