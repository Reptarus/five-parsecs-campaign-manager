@tool
class_name FiveParsecsArmor
extends "res://src/core/character/Equipment/Equipment.gd"

@export var armor_type: GameEnums.ArmorType = GameEnums.ArmorType.NONE
@export var armor_save: int = 0
@export var armor_bonus: int = 0

func _init() -> void:
	item_type = GameEnums.ItemType.ARMOR

func can_be_equipped_by(character: FiveParsecsCharacter) -> bool:
	# Only Engineer class can use powered armor
	match armor_type:
		GameEnums.ArmorType.POWERED:
			return character.character_class == GameEnums.CharacterClass.ENGINEER
		_:
			return true

func apply_modifiers(character: FiveParsecsCharacter) -> void:
	# Apply armor save and any other modifiers
	character.armor_save = armor_save
	character.armor_bonus = armor_bonus
	
	# Apply cover modifiers based on armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			character.add_combat_modifier(GameEnums.CombatModifier.COVER_LIGHT)
		GameEnums.ArmorType.MEDIUM:
			character.add_combat_modifier(GameEnums.CombatModifier.NONE)
		GameEnums.ArmorType.HEAVY:
			character.add_combat_modifier(GameEnums.CombatModifier.COVER_HEAVY)

func remove_modifiers(character: FiveParsecsCharacter) -> void:
	# Remove armor save and any other modifiers
	character.armor_save = 0
	character.armor_bonus = 0
	
	# Remove cover modifiers based on armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			character.remove_combat_modifier(GameEnums.CombatModifier.COVER_LIGHT)
		GameEnums.ArmorType.MEDIUM:
			character.remove_combat_modifier(GameEnums.CombatModifier.NONE)
		GameEnums.ArmorType.HEAVY:
			character.remove_combat_modifier(GameEnums.CombatModifier.COVER_HEAVY)

func get_display_name() -> String:
	return "%s %s (%s)" % [
		GameEnums.ArmorType.keys()[armor_type],
		item_name,
		GameEnums.ItemRarity.keys()[rarity]
	]

func get_description() -> String:
	var desc = description
	desc += "\n\nArmor Type: %s" % GameEnums.ArmorType.keys()[armor_type]
	desc += "\nArmor Save: %d+" % armor_save if armor_save > 0 else ""
	desc += "\nArmor Bonus: +%d" % armor_bonus if armor_bonus > 0 else ""
	return desc
