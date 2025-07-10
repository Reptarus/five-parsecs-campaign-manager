@tool
extends Resource
class_name BaseArmor

const FiveParsecsCharacter = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var armor_type: int = 0 # GlobalEnums.ArmorType.NONE
@export var item_type: int = 0 # GlobalEnums.ItemType.ARMOR
@export var armor_save: int = 0
@export var armor_bonus: int = 0
@export var item_name: String = ""
@export var rarity: int = 0
@export var description: String = ""

func _init() -> void:
	item_type = GlobalEnums.ItemType.ARMOR

## Safe Property Access Methods
func _get_character_property(character: FiveParsecsCharacter, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return default_value

	return character.get(property)

func _set_character_property(character: FiveParsecsCharacter, property: String, _value: Variant) -> void:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, _value)

func can_be_equipped_by(character: FiveParsecsCharacter) -> bool:
	if not character:
		return false

	var char_class = _get_character_property(character, "character_class", GlobalEnums.CharacterClass.NONE)

	# Only Engineer class can use powered armor
	match armor_type:
		GlobalEnums.ArmorType.POWERED:
			return char_class == GlobalEnums.CharacterClass.ENGINEER
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
		GlobalEnums.ArmorType.LIGHT:
			if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(GlobalEnums.CombatModifier.COVER_LIGHT)
		GlobalEnums.ArmorType.MEDIUM:
			if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(GlobalEnums.CombatModifier.NONE)
		GlobalEnums.ArmorType.HEAVY:
			if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(GlobalEnums.CombatModifier.COVER_HEAVY)

func remove_modifiers(character: FiveParsecsCharacter) -> void:
	if not character:
		return

	# Remove armor save and any other modifiers
	_set_character_property(character, "armor_save", 0)
	_set_character_property(character, "armor_bonus", 0)

	# Remove cover modifiers based on armor type
	match armor_type:
		GlobalEnums.ArmorType.LIGHT:
			if character and character.has_method("remove_combat_modifier"): character.remove_combat_modifier(GlobalEnums.CombatModifier.COVER_LIGHT)
		GlobalEnums.ArmorType.MEDIUM:
			if character and character.has_method("remove_combat_modifier"): character.remove_combat_modifier(GlobalEnums.CombatModifier.NONE)
		GlobalEnums.ArmorType.HEAVY:
			if character and character.has_method("remove_combat_modifier"): character.remove_combat_modifier(GlobalEnums.CombatModifier.COVER_HEAVY)

func get_display_name() -> String:
	return "%s %s (%s)" % [
		GlobalEnums.ArmorType.keys()[armor_type],
		item_name,
		GlobalEnums.ItemRarity.keys()[rarity]
	]

func get_description() -> String:
	var desc = description
	desc += "\n\nArmor Type: %s" % GlobalEnums.ArmorType.keys()[armor_type]
	desc += "\nArmor Save: %d+" % armor_save if armor_save > 0 else ""
	desc += "\nArmor Bonus: +%d" % armor_bonus if armor_bonus > 0 else ""
	return desc

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null