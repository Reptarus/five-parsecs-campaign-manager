class_name FiveParsecsTerrainEffectSystem
extends Node

const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsTerrainTypes: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const FiveParsecsTerrainEffects: GDScript = preload("res://src/core/terrain/TerrainEffects.gd")
const TerrainRules: GDScript = preload("res://src/core/terrain/TerrainRules.gd")

# Signals
signal effect_applied(target: Node, effect_type: String, value: float)
signal effect_removed(target: Node, effect_type: String)
signal terrain_state_changed(position: Vector2i, old_state: Dictionary, new_state: Dictionary)

# Active effects tracking
var _active_effects: Dictionary = {}
var _terrain_states: Dictionary = {}
var terrain_rules: TerrainRules

func _ready() -> void:
	terrain_rules = TerrainRules.new()

func apply_terrain_effect(target: Node, terrain_type: FiveParsecsTerrainTypes.Type, feature_type: GameEnums.TerrainFeatureType) -> void:
	if not target:
		return
	
	var environment = _convert_terrain_to_environment(terrain_type)
	var effects = terrain_rules.get_terrain_effects(environment, feature_type)
	var target_id = target.get_instance_id()
	
	if not _active_effects.has(target_id):
		_active_effects[target_id] = {}
	
	for effect_name in effects:
		var effect_value = effects[effect_name]
		_active_effects[target_id][effect_name] = effect_value
		effect_applied.emit(target, effect_name, effect_value)

func remove_terrain_effects(target: Node) -> void:
	var target_id = target.get_instance_id()
	if not _active_effects.has(target_id):
		return
	
	for effect_name in _active_effects[target_id]:
		effect_removed.emit(target, effect_name)
	
	_active_effects.erase(target_id)

func get_active_effects(target: Node) -> Dictionary:
	var target_id = target.get_instance_id()
	return _active_effects.get(target_id, {}).duplicate()

func update_terrain_state(position: Vector2i, terrain_type: FiveParsecsTerrainTypes.Type, feature_type: GameEnums.TerrainFeatureType) -> void:
	var old_state = _terrain_states.get(position, {})
	var environment = _convert_terrain_to_environment(terrain_type)
	var new_state = {
		"terrain_type": terrain_type,
		"feature_type": feature_type,
		"effects": terrain_rules.get_terrain_effects(environment, feature_type),
		"modifiers": _get_terrain_modifiers(terrain_type, feature_type)
	}
	
	_terrain_states[position] = new_state
	terrain_state_changed.emit(position, old_state, new_state)

func get_terrain_state(position: Vector2i) -> Dictionary:
	return _terrain_states.get(position, {}).duplicate()

func calculate_movement_cost(from: Vector2i, to: Vector2i) -> float:
	var from_state = get_terrain_state(from)
	var to_state = get_terrain_state(to)
	
	if from_state.is_empty() or to_state.is_empty():
		return INF
	
	var base_cost = 1.0
	var to_modifiers = to_state.get("modifiers", {})
	
	if to_modifiers.get("difficult_terrain", false):
		base_cost *= 2.0
	if to_modifiers.get("water_hazard", false):
		base_cost *= 1.5
	if to_modifiers.get("movement_penalty", false):
		base_cost *= 1.25
	
	return base_cost

func calculate_cover_value(position: Vector2i, target_position: Vector2i) -> float:
	var state = get_terrain_state(position)
	if state.is_empty():
		return 0.0
	
	var modifiers = state.get("modifiers", {})
	var base_cover = 0.0
	
	if modifiers.get("full_cover", false):
		base_cover = 0.75
	elif modifiers.get("partial_cover", false):
		base_cover = 0.5
	elif modifiers.get("cover_bonus", false):
		base_cover = 0.25
	
	# Apply directional modifiers based on target position
	var direction = Vector2(target_position - position).normalized()
	var angle_modifier = _calculate_angle_modifier(direction)
	
	return base_cover * angle_modifier

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var points = _get_line_points(from, to)
	
	for point in points:
		var state = get_terrain_state(point)
		if state.is_empty():
			continue
		
		var modifiers = state.get("modifiers", {})
		if modifiers.get("blocks_los", false):
			return false
	
	return true

func _get_terrain_modifiers(terrain_type: FiveParsecsTerrainTypes.Type, feature_type: GameEnums.TerrainFeatureType) -> Dictionary:
	var modifiers = {}
	
	# Get terrain type modifiers
	var terrain_props = FiveParsecsTerrainTypes.get_terrain_properties(terrain_type)
	modifiers["blocks_movement"] = terrain_props.get("blocks_movement", false)
	modifiers["blocks_los"] = terrain_props.get("blocks_los", false)
	modifiers["provides_cover"] = terrain_props.get("provides_cover", false)
	
	# Get feature type modifiers
	var feature_mods = terrain_rules.get_feature_modifiers(feature_type)
	for mod in feature_mods:
		match mod:
			GameEnums.TerrainModifier.DIFFICULT_TERRAIN:
				modifiers["difficult_terrain"] = true
			GameEnums.TerrainModifier.WATER_HAZARD:
				modifiers["water_hazard"] = true
			GameEnums.TerrainModifier.MOVEMENT_PENALTY:
				modifiers["movement_penalty"] = true
			GameEnums.TerrainModifier.FULL_COVER:
				modifiers["full_cover"] = true
			GameEnums.TerrainModifier.PARTIAL_COVER:
				modifiers["partial_cover"] = true
			GameEnums.TerrainModifier.COVER_BONUS:
				modifiers["cover_bonus"] = true
	
	return modifiers

func _convert_terrain_to_environment(terrain_type: FiveParsecsTerrainTypes.Type) -> GameEnums.PlanetEnvironment:
	match terrain_type:
		FiveParsecsTerrainTypes.Type.WALL:
			return GameEnums.PlanetEnvironment.URBAN
		FiveParsecsTerrainTypes.Type.WATER:
			return GameEnums.PlanetEnvironment.RAIN
		FiveParsecsTerrainTypes.Type.HAZARD:
			return GameEnums.PlanetEnvironment.HAZARDOUS
		_:
			return GameEnums.PlanetEnvironment.NONE

func _calculate_angle_modifier(direction: Vector2) -> float:
	# Calculate cover effectiveness based on angle
	# Front-on cover is most effective, angled cover less so
	var angle = abs(direction.angle())
	if angle < PI / 4: # Within 45 degrees
		return 1.0
	elif angle < PI / 2: # Within 90 degrees
		return 0.7
	else:
		return 0.5

func _get_line_points(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var n = 1 + dx + dy
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx - dy
	dx *= 2
	dy *= 2
	
	for _i in range(n):
		points.append(Vector2i(x, y))
		
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return points

func clear_states() -> void:
	_active_effects.clear()
	_terrain_states.clear()