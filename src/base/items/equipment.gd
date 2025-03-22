@tool
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
# Define a self-reference for this base class
const EquipmentBase = preload("res://src/base/items/equipment.gd")

@export var item_name: String = ""
@export var item_type: GameEnums.ItemType = GameEnums.ItemType.NONE
@export var rarity: GameEnums.ItemRarity = GameEnums.ItemRarity.COMMON
@export var description: String = ""
@export var cost: int = 0
@export var weight: int = 0

func _init() -> void:
	pass

## Returns the rarity level of this equipment
func get_rarity() -> int:
	return rarity

## Sets the rarity level of this equipment
func set_rarity(new_rarity: int) -> void:
	rarity = new_rarity

## Returns the display name of this equipment
## This method can be overridden by child classes
func get_display_name() -> String:
	return item_name
	
## Returns the description of this equipment
## This method can be overridden by child classes
func get_description() -> String:
	return description

## Initialize equipment from data dictionary
func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	item_name = data.get("name", "")
	
	# Handle item type
	if data.has("type"):
		if data.type is int:
			item_type = data.type
		elif data.type is String:
			# Try to match the string to known enum values
			match data.type.to_upper():
				"NONE": item_type = GameEnums.ItemType.NONE
				"WEAPON": item_type = GameEnums.ItemType.WEAPON
				"ARMOR": item_type = GameEnums.ItemType.ARMOR
				"CONSUMABLE": item_type = GameEnums.ItemType.CONSUMABLE
				"MISC": item_type = GameEnums.ItemType.MISC
				_: item_type = GameEnums.ItemType.MISC # Default
	
	# Handle rarity
	if data.has("rarity"):
		if data.rarity is int:
			rarity = data.rarity
		elif data.rarity is String:
			# Try to match the string to known enum values
			match data.rarity.to_upper():
				"COMMON": rarity = GameEnums.ItemRarity.COMMON
				"UNCOMMON": rarity = GameEnums.ItemRarity.UNCOMMON
				"RARE": rarity = GameEnums.ItemRarity.RARE
				"VERY_RARE", "VERY RARE": rarity = GameEnums.ItemRarity.RARE
				"LEGENDARY": rarity = GameEnums.ItemRarity.LEGENDARY
				_: rarity = GameEnums.ItemRarity.COMMON # Default
	
	description = data.get("description", "")
	cost = data.get("cost", 0)
	weight = data.get("weight", 0)
	
	return true
