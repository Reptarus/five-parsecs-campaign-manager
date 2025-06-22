@tool
extends RefCounted
class_name TerrainEffects

## Terrain effects system for Five Parsecs tactical battles
##
## Manages dynamic effects on terrain tiles

signal effect_applied(position: Vector2, effect_type: EffectType)
signal effect_removed(position: Vector2, effect_type: EffectType)

enum EffectType {
	NONE,
	FIRE,
	SMOKE,
	RADIATION,
	TOXIC_GAS,
	ENERGY_FIELD,
	DEBRIS
}

var active_effects: Dictionary = {}

func _init() -> void:
	pass

## Apply effect to a position

func apply_effect(position: Vector2, effect_type: EffectType, duration: int = 1) -> void:
	if not active_effects.has(position):
		active_effects[position] = {}
	
	active_effects[position][effect_type] = {
		"duration": duration,
		"applied_turn": 0
	}
	
	effect_applied.emit(position, effect_type) # warning: return value discarded (intentional)

## Remove effect from position
func remove_effect(position: Vector2, effect_type: EffectType) -> void:
	if active_effects.has(position) and active_effects[position].has(effect_type):
		active_effects[position].erase(effect_type)
		if active_effects[position].is_empty():
			active_effects.erase(position)
		effect_removed.emit(position, effect_type) # warning: return value discarded (intentional)

## Get active effects at position
func get_active_effects(position: Vector2) -> Array[EffectType]:
	var effects: Array[EffectType] = []
	if active_effects.has(position):
		for effect_type in active_effects[position].keys():
			effects.append(effect_type) # warning: return value discarded (intentional)
	return effects

## Get effect duration
func get_effect_duration(position: Vector2, effect_type: EffectType) -> int:
	if active_effects.has(position) and active_effects[position].has(effect_type):
		return active_effects[position][effect_type]["duration"]
	return 0

## Get movement penalty at position
func get_movement_penalty(position: Vector2) -> float:
	var penalty: float = 0.0
	var effects = get_active_effects(position)
	
	for effect in effects:
		match effect:
			EffectType.DEBRIS: penalty += 0.5
			EffectType.TOXIC_GAS: penalty += 0.3
			EffectType.SMOKE: penalty += 0.2
			_: pass
	
	return penalty

## Get visibility penalty at position
func get_visibility_penalty(position: Vector2) -> float:
	var penalty: float = 0.0
	var effects = get_active_effects(position)
	
	for effect in effects:
		match effect:
			EffectType.SMOKE: penalty += 0.5
			EffectType.TOXIC_GAS: penalty += 0.3
			_: pass
	
	return penalty

## Get combat modifier at position
func get_combat_modifier(position: Vector2) -> int:
	var modifier: int = 0
	var effects = get_active_effects(position)
	
	for effect in effects:
		match effect:
			EffectType.FIRE: modifier -= 1
			EffectType.RADIATION: modifier -= 2
			EffectType.ENERGY_FIELD: modifier -= 1
			_: pass
	
	return modifier

## Process turn-based effect decay
func process_turn() -> void:
	var positions_to_remove: Array[Vector2] = []
	
	for position in active_effects.keys():
		var effects_to_remove: Array[EffectType] = []
		
		for effect_type in active_effects[position].keys():
			var effect_data = active_effects[position][effect_type]
			effect_data["duration"] -= 1
			
			if effect_data["duration"] <= 0:
				effects_to_remove.append(effect_type) # warning: return value discarded (intentional)
		
		for effect_type in effects_to_remove:
			remove_effect(position, effect_type)
		
		if active_effects[position].is_empty():
			positions_to_remove.append(position) # warning: return value discarded (intentional)
	
	for position in positions_to_remove:
		active_effects.erase(position)

## Clear all effects
func clear_all_effects() -> void:
	active_effects.clear()

## Serialize effects data

func serialize() -> Dictionary:
	var serialized_effects: Dictionary = {}
	for pos in active_effects:
		var key: String = "%d,%d" % [pos.x, pos.y]
		serialized_effects[key] = active_effects[pos]
	
	return {
		"active_effects": serialized_effects
	}

## Deserialize effects data
func deserialize(data: Dictionary) -> void:
	active_effects.clear()
	
	if data.has("active_effects"):
		for key in data.active_effects:
			var coords = key.split(",")
			if coords.size() == 2:
				var pos = Vector2(int(coords[0]), int(coords[1]))
				active_effects[pos] = data.active_effects[key]

				active_effects[pos] = data.active_effects[key]