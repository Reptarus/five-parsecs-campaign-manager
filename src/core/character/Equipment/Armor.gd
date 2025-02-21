@tool
class_name FiveParsecsArmor
extends "res://src/core/character/Equipment/Equipment.gd"

@export var armor_type: GameEnums.ArmorType = GameEnums.ArmorType.NONE
@export var armor_save: int = 0
@export var armor_bonus: int = 0

func _init() -> void:
	item_type = GameEnums.ItemType.ARMOR

## Safe Property Access Methods
func _get_character_property(character: FiveParsecsCharacter, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return default_value
	return character.get(property)

func _set_character_property(character: FiveParsecsCharacter, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, value)

func can_be_equipped_by(character: FiveParsecsCharacter) -> bool:
	if not character:
		return false
		
	var char_class = _get_character_property(character, "character_class", GameEnums.CharacterClass.NONE)
	
	# Only Engineer class can use powered armor
	match armor_type:
		GameEnums.ArmorType.POWERED:
			return char_class == GameEnums.CharacterClass.ENGINEER
		_:
			return true

func apply_modifiers(character: FiveParsecsCharacter) -> void:
	if not character:
		return
		
	# Apply armor save and any other modifiers
	_set_character_property(character, "armor_save", armor_save)
	_set_character_property(character, "armor_bonus", armor_bonus)
	
	# Apply cover modifiers based on armor type
	match armor_type:
		GameEnums.ArmorType.LIGHT:
			character.add_combat_modifier(GameEnums.CombatModifier.COVER_LIGHT)
		GameEnums.ArmorType.MEDIUM:
			character.add_combat_modifier(GameEnums.CombatModifier.NONE)
		GameEnums.ArmorType.HEAVY:
			character.add_combat_modifier(GameEnums.CombatModifier.COVER_HEAVY)

func remove_modifiers(character: FiveParsecsCharacter) -> void:
	if not character:
		return
		
	# Remove armor save and any other modifiers
	_set_character_property(character, "armor_save", 0)
	_set_character_property(character, "armor_bonus", 0)
	
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
