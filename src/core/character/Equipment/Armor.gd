class_name Armor
extends Equipment

const Equipment := preload("res://src/core/character/Equipment/Equipment.gd")

@export var armor_type: GlobalEnums.ArmorType = GlobalEnums.ArmorType.NONE
@export var armor_value: int = 0
@export var movement_penalty: float = 0.0
@export var special_properties: Array[String] = []

func _init() -> void:
	item_type = GlobalEnums.ItemType.ARMOR

func can_be_equipped_by(character: Resource) -> bool:
	# Check if character meets armor requirements
	# For example, powered armor might require special training
	match armor_type:
		GlobalEnums.ArmorType.POWERED:
			return character.character_class == GlobalEnums.CharacterClass.TECH
		_:
			return true

func apply_modifiers(character: Resource) -> void:
	character.armor += armor_value
	character.speed = max(1, character.speed - int(movement_penalty))
	
	# Apply special properties
	for property in special_properties:
		match property:
			"stealth":
				character.add_combat_modifier(GlobalEnums.CombatModifier.COVER_LIGHT)
			"hazard_protection":
				character.add_combat_modifier(GlobalEnums.CombatModifier.NONE)
			"shield":
				character.add_combat_modifier(GlobalEnums.CombatModifier.COVER_HEAVY)

func remove_modifiers(character: Resource) -> void:
	character.armor -= armor_value
	character.speed = min(character.speed + int(movement_penalty), character.max_speed)
	
	# Remove special properties
	for property in special_properties:
		match property:
			"stealth":
				character.remove_combat_modifier(GlobalEnums.CombatModifier.COVER_LIGHT)
			"hazard_protection":
				character.remove_combat_modifier(GlobalEnums.CombatModifier.NONE)
			"shield":
				character.remove_combat_modifier(GlobalEnums.CombatModifier.COVER_HEAVY)

func get_display_name() -> String:
	return "%s %s (%s)" % [
		GlobalEnums.ArmorType.keys()[armor_type],
		item_name,
		GlobalEnums.ItemRarity.keys()[rarity]
	]

func get_description() -> String:
	var desc := super.get_description()
	desc += "\n\nArmor Type: %s" % GlobalEnums.ArmorType.keys()[armor_type]
	desc += "\nArmor Value: %d" % armor_value
	if movement_penalty > 0:
		desc += "\nMovement Penalty: %.1f" % movement_penalty
	if not special_properties.is_empty():
		desc += "\nSpecial Properties: %s" % ", ".join(special_properties)
	return desc
