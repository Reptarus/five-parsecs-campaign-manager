@tool
extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules = preload("res://src/core/terrain/TerrainRules.gd")

# Signals
signal effect_applied(target_id: int, effect_type: int, strength: float)
signal effect_removed(target_id: int, effect_type: int)

# Track terrain effects on units
var _active_effects: Dictionary = {}
var _terrain_states: Dictionary = {}
var terrain_rules: TerrainRules

func _init() -> void:
	terrain_rules = TerrainRules.new()

# Apply terrain effects to a target based on terrain type and features
func apply_terrain_effect(target: Node, terrain_type: TerrainTypes.Type, feature_type: GlobalEnums.TerrainFeatureType) -> void:
	if not target:
		return

	var target_id = target.get_instance_id()
	var modifiers = _get_terrain_modifiers(terrain_type, feature_type)

	if _active_effects.has(target_id):
		# Update existing effects
		for effect_type in modifiers:
			var typed_effect_type: Variant = effect_type
			var strength = modifiers[effect_type]
			_active_effects[target_id][effect_type] = strength
			effect_applied.emit(target_id, effect_type, strength) # warning: return value discarded (intentional)
	else:
		# Create new effects
		_active_effects[target_id] = modifiers.duplicate()
		for effect_type in modifiers:
			var typed_effect_type: Variant = effect_type
			var strength = modifiers[effect_type]
			effect_applied.emit(target_id, effect_type, strength) # warning: return value discarded (intentional)

# Remove all terrain effects from a target
func remove_terrain_effects(target: Node) -> void:
	if not target:
		return

	var target_id = target.get_instance_id()
	if _active_effects.has(target_id):
		for effect_type in _active_effects[target_id]:
			effect_removed.emit(target_id, effect_type) # warning: return value discarded (intentional)
		_active_effects.erase(target_id)

# Get active effects for a target
func get_active_effects(target: Node) -> Dictionary:
	if not target:
		return {}

	var target_id = target.get_instance_id()

	return _active_effects.get(target_id, {}).duplicate()

# Update terrain state at a position
func update_terrain_state(position: Vector2i, terrain_type: TerrainTypes.Type, feature_type: GlobalEnums.TerrainFeatureType) -> void:
	var _old_state = _terrain_states.get(position, {})
	var environment = _convert_terrain_to_environment(terrain_type)
	var new_state = {
		"terrain_type": terrain_type,
		"feature_type": feature_type,
		"environment": environment,
		"movement_cost": TerrainTypes.get_movement_cost(terrain_type),
		"cover_value": TerrainTypes.get_cover_value(terrain_type),
		"blocks_los": TerrainTypes.blocks_movement(terrain_type),
		"elevation": 0,
		"special": {}
	}

	_terrain_states[position] = new_state

	# Notify rules system of terrain change
	if terrain_rules:
		terrain_rules.on_terrain_changed(position, new_state)

# Get terrain state at position
func get_terrain_state(position: Vector2i) -> Dictionary:
	return _terrain_states.get(position, {}).duplicate()

# Check if a position has a specific terrain feature
func has_terrain_feature(position: Vector2i, feature_type: GlobalEnums.TerrainFeatureType) -> bool:
	var state = _terrain_states.get(position, {})

	return state.get("feature_type", GlobalEnums.TerrainFeatureType.NONE) == feature_type

# Check if a position has a specific terrain _type
func has_terrain_type(position: Vector2i, terrain_type: TerrainTypes.Type) -> bool:
	var state = _terrain_states.get(position, {})

	return state.get("terrain_type", 0) == terrain_type

# Get movement cost for a position
func get_movement_cost(position: Vector2i) -> float:
	var state = _terrain_states.get(position, {})

	return state.get("movement_cost", 1.0)

# Check if position provides cover
func provides_cover(position: Vector2i) -> bool:
	var state = _terrain_states.get(position, {})

	return state.get("cover_value", 0) > 0

# Check if position is elevated
func is_elevated(position: Vector2i) -> bool:
	var state = _terrain_states.get(position, {})

	return state.get("elevation", 0) > 0

# Check if terrain at position is traversable
func is_traversable(position: Vector2i) -> bool:
	return get_movement_cost(position) > 0.0

# Get terrain modifiers based on type and features
func _get_terrain_modifiers(terrain_type: TerrainTypes.Type, feature_type: GlobalEnums.TerrainFeatureType) -> Dictionary:
	var modifiers: Dictionary = {}

	# Get terrain _type modifiers
	var terrain_props: Dictionary = {} # Default empty properties

	# Apply basic terrain effects

	if terrain_props.get("cover_value", 0) > 0:
		modifiers[GlobalEnums.TerrainEffectType.COVER] = terrain_props.get("cover_value", 0)

	if terrain_props.get("elevation", 0) > 0:
		modifiers[GlobalEnums.TerrainEffectType.ELEVATED] = terrain_props.get("elevation", 0)

	if "damage" in terrain_props:
		modifiers[GlobalEnums.TerrainEffectType.HAZARD] = terrain_props.get("damage", 0)

	# Apply feature modifiers
	match feature_type:
		GlobalEnums.TerrainFeatureType.RADIATION:
			modifiers[GlobalEnums.TerrainEffectType.RADIATION] = 1.0
		GlobalEnums.TerrainFeatureType.FIRE:
			modifiers[GlobalEnums.TerrainEffectType.BURNING] = 1.0
		GlobalEnums.TerrainFeatureType.ACID:
			modifiers[GlobalEnums.TerrainEffectType.ACID] = 1.0
		GlobalEnums.TerrainFeatureType.SMOKE:
			modifiers[GlobalEnums.TerrainEffectType.OBSCURED] = 1.0

	return modifiers

# Convert terrain _type to environment _type
func _convert_terrain_to_environment(terrain_type: TerrainTypes.Type) -> GlobalEnums.PlanetEnvironment:
	match terrain_type:
		TerrainTypes.Type.WALL:
			return GlobalEnums.PlanetEnvironment.URBAN
		TerrainTypes.Type.WATER:
			return GlobalEnums.PlanetEnvironment.OCEANIC
		TerrainTypes.Type.HAZARD:
			return GlobalEnums.PlanetEnvironment.VOLCANIC
		TerrainTypes.Type.FOREST:
			return GlobalEnums.PlanetEnvironment.TEMPERATE
		_:
			return GlobalEnums.PlanetEnvironment.TEMPERATE

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null