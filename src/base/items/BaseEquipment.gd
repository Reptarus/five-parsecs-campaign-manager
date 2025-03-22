@tool
extends Resource
# Renamed from BaseEquipment to avoid global class name conflict
class_name EquipmentBase

# This class serves as the base for all equipment items in the game
# It defines common properties and methods that all equipment should have

# Basic properties all equipment should have
var id: String
var display_name: String
var description: String
var value: int = 0
var weight: float = 0.0
var rarity: int = 0
var item_type: String = "equipment"
var is_equipped: bool = false
var owner_id: String = ""

# Optional modifiers that equipment might provide
var modifiers: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_desc: String = "") -> void:
	id = p_id
	display_name = p_name
	description = p_desc

# Base method to apply equipment effects
func apply_effects(character_data: Dictionary) -> Dictionary:
	# Base implementation does nothing
	# This should be overridden by child classes
	return character_data

# Base method to remove equipment effects
func remove_effects(character_data: Dictionary) -> Dictionary:
	# Base implementation does nothing
	# This should be overridden by child classes
	return character_data

# Equip this item to a character
func equip(character_id: String) -> void:
	owner_id = character_id
	is_equipped = true

# Unequip this item from a character
func unequip() -> void:
	owner_id = ""
	is_equipped = false

# Create a serializable representation of this equipment
func to_dict() -> Dictionary:
	return {
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

# Load equipment data from a dictionary
func from_dict(data: Dictionary) -> EquipmentBase:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	value = data.get("value", 0)
	weight = data.get("weight", 0.0)
	rarity = data.get("rarity", 0)
	item_type = data.get("item_type", "equipment")
	is_equipped = data.get("is_equipped", false)
	owner_id = data.get("owner_id", "")
	modifiers = data.get("modifiers", {})
	return self