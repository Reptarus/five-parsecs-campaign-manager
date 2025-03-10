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
