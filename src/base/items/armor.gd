@tool
extends Resource
class_name ArmorEquipment

# Update the reference to use the renamed EquipmentBase class
const EquipmentBaseClass = preload("res://src/base/items/BaseEquipment.gd")

# Armor-specific properties
var defense_value: int = 0
var armor_type: int = 0 # Using int to match enum usage
var durability: int = 100
var max_durability: int = 100
var damage_reduction: float = 0.0
var movement_penalty: float = 0.0
var energy_usage: float = 0.0

# Common base equipment properties (duplicated from EquipmentBase)
var id: String
var display_name: String
var description: String
var value: int = 0
var weight: float = 0.0
var rarity: int = 0
var item_type: String = "armor" # Default to armor
var is_equipped: bool = false
var owner_id: String = ""
var modifiers: Dictionary = {}

# Armor classification enum
enum ArmorClass {
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED
}

var armor_class: ArmorClass = ArmorClass.LIGHT

func _init(p_id: String = "", p_name: String = "", p_desc: String = "") -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	item_type = "armor"

# Override base method to apply armor-specific effects
func apply_effects(character_data: Dictionary) -> Dictionary:
	var modified_data = character_data.duplicate()
	
	# Apply armor defense bonus
	if modified_data.has("defense"):
		modified_data["defense"] = modified_data["defense"] + defense_value
	else:
		modified_data["defense"] = defense_value
	
	# Apply damage reduction if supported
	if modified_data.has("damage_reduction"):
		modified_data["damage_reduction"] = modified_data["damage_reduction"] + damage_reduction
	else:
		modified_data["damage_reduction"] = damage_reduction
	
	# Apply movement penalty if supported
	if modified_data.has("movement_speed") and movement_penalty > 0:
		modified_data["movement_speed"] = max(1, modified_data["movement_speed"] - movement_penalty)
	
	# Apply energy usage for powered armor
	if armor_class == ArmorClass.POWERED and modified_data.has("energy"):
		modified_data["energy_usage"] = modified_data.get("energy_usage", 0) + energy_usage
	
	# Apply any additional modifiers
	for stat in modifiers:
		if modified_data.has(stat):
			modified_data[stat] = modified_data[stat] + modifiers[stat]
		else:
			modified_data[stat] = modifiers[stat]
	
	return modified_data

# Override base method to remove armor-specific effects
func remove_effects(character_data: Dictionary) -> Dictionary:
	var modified_data = character_data.duplicate()
	
	# Remove armor defense bonus
	if modified_data.has("defense"):
		modified_data["defense"] = modified_data["defense"] - defense_value
	
	# Remove damage reduction if supported
	if modified_data.has("damage_reduction"):
		modified_data["damage_reduction"] = max(0, modified_data["damage_reduction"] - damage_reduction)
	
	# Remove movement penalty if supported
	if modified_data.has("movement_speed") and movement_penalty > 0:
		modified_data["movement_speed"] = modified_data["movement_speed"] + movement_penalty
	
	# Remove energy usage for powered armor
	if armor_class == ArmorClass.POWERED and modified_data.has("energy_usage"):
		modified_data["energy_usage"] = max(0, modified_data.get("energy_usage", 0) - energy_usage)
	
	# Remove any additional modifiers
	for stat in modifiers:
		if modified_data.has(stat):
			modified_data[stat] = modified_data[stat] - modifiers[stat]
	
	return modified_data

# Method to handle armor damage
func take_damage(amount: int) -> int:
	var actual_damage = min(durability, amount)
	durability -= actual_damage
	
	# Return remaining damage that wasn't absorbed by the armor
	return amount - actual_damage

# Method to repair armor
func repair(amount: int) -> void:
	durability = min(max_durability, durability + amount)

# Create a serializable representation of this equipment
func to_dict() -> Dictionary:
	# Create base dictionary similar to EquipmentBase's to_dict
	var base_dict = {
		"id": id,
		"display_name": display_name,
		"description": description,
		"value": value,
		"weight": weight,
		"rarity": rarity,
		"item_type": item_type,
		"is_equipped": is_equipped,
		"owner_id": owner_id,
		"modifiers": modifiers
	}
	
	# Add armor-specific properties
	base_dict["defense_value"] = defense_value
	base_dict["armor_type"] = armor_type
	base_dict["durability"] = durability
	base_dict["max_durability"] = max_durability
	base_dict["damage_reduction"] = damage_reduction
	base_dict["movement_penalty"] = movement_penalty
	base_dict["energy_usage"] = energy_usage
	base_dict["armor_class"] = armor_class
	
	return base_dict

# Load equipment data from a dictionary
func from_dict(data: Dictionary) -> ArmorEquipment:
	# Set base equipment properties
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	value = data.get("value", 0)
	weight = data.get("weight", 0.0)
	rarity = data.get("rarity", 0)
	item_type = data.get("item_type", "armor")
	is_equipped = data.get("is_equipped", false)
	owner_id = data.get("owner_id", "")
	modifiers = data.get("modifiers", {})
	
	# Load armor-specific properties
	defense_value = data.get("defense_value", 0)
	# Handle both string and int armor_type for backwards compatibility
	if data.has("armor_type"):
		if data["armor_type"] is String:
			# Convert string to enum value if needed
			var type_str = data["armor_type"].to_upper()
			if GameEnums.ArmorType.has(type_str):
				armor_type = GameEnums.ArmorType[type_str]
			else:
				armor_type = 0
		else:
			armor_type = data["armor_type"]
	durability = data.get("durability", 100)
	max_durability = data.get("max_durability", 100)
	damage_reduction = data.get("damage_reduction", 0.0)
	movement_penalty = data.get("movement_penalty", 0.0)
	energy_usage = data.get("energy_usage", 0.0)
	
	# Use the local ArmorClass enum instead of the GameEnums version
	armor_class = data.get("armor_class", ArmorClass.LIGHT)
	
	return self

# Constants should be at the top of the file
const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
@export var armor_save: int = 0
@export var armor_bonus: int = 0

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
	var armor_type_name = "Unknown"
	
	# Get the armor type name from the enum if possible
	if armor_type is int and armor_type >= 0 and GameEnums.ArmorType.size() > armor_type:
		armor_type_name = GameEnums.ArmorType.keys()[armor_type]
	
	var rarity_name = "Common"
	if rarity is int and rarity >= 0 and rarity < GameEnums.ItemRarity.size():
		rarity_name = GameEnums.ItemRarity.keys()[rarity]
		
	return "%s %s (%s)" % [
		armor_type_name,
		display_name,
		rarity_name
	]

func get_description() -> String:
	var desc = description
	
	var armor_type_name = "Unknown"
	# Get the armor type name from the enum if possible
	if armor_type is int and armor_type >= 0 and GameEnums.ArmorType.size() > armor_type:
		armor_type_name = GameEnums.ArmorType.keys()[armor_type]
		
	desc += "\n\nArmor Type: %s" % armor_type_name
	desc += "\nArmor Save: %d+" % armor_save if armor_save > 0 else ""
	desc += "\nArmor Bonus: +%d" % armor_bonus if armor_bonus > 0 else ""
	return desc