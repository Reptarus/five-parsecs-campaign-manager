class_name Equipment
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var item_name: String = ""
@export var description: String = ""
@export var item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.NONE
@export var rarity: GlobalEnums.ItemRarity = GlobalEnums.ItemRarity.COMMON
@export var cost: int = 0
@export var weight: float = 1.0
@export var modifiers: Dictionary = {}

func can_be_equipped_by(character: Resource) -> bool:
	# Base equipment has no restrictions
	return true

func apply_modifiers(character: Resource) -> void:
	# Base equipment applies no modifiers
	pass

func remove_modifiers(character: Resource) -> void:
	# Base equipment removes no modifiers
	pass

func get_stat_modifiers() -> Dictionary:
	return modifiers.duplicate()

func get_display_name() -> String:
	return "%s (%s)" % [item_name, GlobalEnums.ItemRarity.keys()[rarity]]

func get_description() -> String:
	var desc := description + "\n\nModifiers:"
	for stat in modifiers:
		desc += "\n%s: %s" % [stat, modifiers[stat]]
	return desc
