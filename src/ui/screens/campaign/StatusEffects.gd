@tool
extends Resource
class_name StatusEffect

## Status Effect system for Five Parsecs from Home
## Handles temporary and permanent character status effects

# GlobalEnums available as autoload singleton

signal effect_applied(character: Node, effect: StatusEffect)
signal effect_removed(character: Node, effect: StatusEffect)
signal effect_expired(character: Node, effect: StatusEffect)

enum EffectType {
	BUFF,
	DEBUFF,
	CONDITION,
	INJURY,
	ENHANCEMENT
}

enum EffectDuration {
	PERMANENT,
	BATTLE,
	TURN,
	CUSTOM
}

var effect_name: String = ""
var effect_type: EffectType = EffectType.CONDITION
var duration_type: EffectDuration = EffectDuration.BATTLE
var remaining_duration: int = 0
var description: String = ""
var stat_modifiers: Dictionary = {}
var special_rules: Array[String] = []

func _init() -> void:
	effect_name = "Unknown Effect"

func apply_to_character(character: Node) -> void:
	# Apply stat modifiers
	for stat in stat_modifiers:
		if character and character.has_method("modify_stat"):
			character.modify_stat(stat, stat_modifiers[stat])

	# Apply special rules
	for rule in special_rules:
		if character and character.has_method("add_special_rule"):
			character.add_special_rule(rule)

	effect_applied.emit(character, self)

func remove_from_character(character: Node) -> void:
	# Remove stat modifiers
	for stat in stat_modifiers:
		if character and character.has_method("modify_stat"):
			character.modify_stat(stat, -stat_modifiers[stat])

	# Remove special rules
	for rule in special_rules:
		if character and character.has_method("remove_special_rule"):
			character.remove_special_rule(rule)

	effect_removed.emit(character, self)

func tick_duration() -> bool:
	if duration_type == EffectDuration.CUSTOM and remaining_duration > 0:
		remaining_duration -= 1
		return remaining_duration <= 0
	return false

func is_expired() -> bool:
	return duration_type == EffectDuration.CUSTOM and remaining_duration <= 0

func set_duration(turns: int) -> void:
	duration_type = EffectDuration.CUSTOM
	remaining_duration = turns

func serialize() -> Dictionary:
	return {
		"effect_name": effect_name,
		"effect_type": effect_type,
		"duration_type": duration_type,
		"remaining_duration": remaining_duration,
		"description": description,
		"stat_modifiers": stat_modifiers,
		"special_rules": special_rules
	}

static func deserialize(data: Dictionary) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_name = data.get("effect_name", "")
	effect.effect_type = data.get("effect_type", EffectType.CONDITION)
	effect.duration_type = data.get("duration_type", EffectDuration.BATTLE)
	effect.remaining_duration = data.get("remaining_duration", 0)
	effect.description = data.get("description", "")
	effect.stat_modifiers = data.get("stat_modifiers", {})
	effect.special_rules = data.get("special_rules", [])
	return effect

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