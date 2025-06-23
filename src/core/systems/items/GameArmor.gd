@tool
extends Resource
class_name GameArmor

## Game Armor class for Five Parsecs
## Provides armor protection and characteristics

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var armor_id: String = ""
@export var armor_name: String = ""
@export var description: String = ""
@export var protection_value: int = 1
@export var weight: float = 1.0
@export var armor_type: String = "basic"
@export var durability: int = 100

func _init() -> void:
	armor_id = "armor_" + str(randi())

func get_protection() -> int:
	return protection_value

func get_armor_name() -> String:
	return armor_name

func get_weight() -> float:
	return weight

func serialize() -> Dictionary:
	return {
		"armor_id": armor_id,
		"armor_name": armor_name,
		"description": description,
		"protection_value": protection_value,
		"weight": weight,
		"armor_type": armor_type,
		"durability": durability
	}

func deserialize(data: Dictionary) -> void:
	armor_id = data.get("armor_id", "")
	armor_name = data.get("armor_name", "")
	description = data.get("description", "")
	protection_value = data.get("protection_value", 1)
	weight = data.get("weight", 1.0)
	armor_type = data.get("armor_type", "basic")
	durability = data.get("durability", 100)
