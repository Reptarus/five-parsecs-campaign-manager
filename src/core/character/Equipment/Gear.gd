extends Equipment
class_name Gear

@export var uses_remaining: int = 1
@export var max_uses: int = 1
@export var is_consumable: bool = true
@export var effects: Array[Dictionary] = []

func _init() -> void:
	item_type = GlobalEnums.ItemType.GEAR

func can_be_used() -> bool:
	return uses_remaining > 0

func use(character: Resource) -> void:
	if can_be_used():
		_apply_effects(character)
		if is_consumable:
			uses_remaining -= 1

func _apply_effects(character: Resource) -> void:
	for effect in effects:
		match effect.type:
			"heal":
				character.heal(effect.value)
			"buff":
				character.add_combat_modifier(effect.modifier)
			"damage":
				character.take_damage(effect.value)
			"status":
				character.status = effect.value

func get_display_name() -> String:
	var name_str := super.get_display_name()
	if is_consumable and max_uses > 1:
		name_str += " (%d/%d)" % [uses_remaining, max_uses]
	return name_str

func get_description() -> String:
	var desc := super.get_description()
	if is_consumable:
		desc += "\n\nUses: %d/%d" % [uses_remaining, max_uses]
	desc += "\n\nEffects:"
	for effect in effects:
		desc += "\n- %s: %s" % [effect.type, effect.value]
	return desc
