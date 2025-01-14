class_name EquipmentData
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var type: int = GlobalEnums.ItemType.MISC
@export var level: int = 1
@export var value: int = 0
@export var requirements: Dictionary = {}
@export var bonuses: Dictionary = {}

func _init(item_name: String = "", item_description: String = "", item_type: int = GlobalEnums.ItemType.MISC, item_level: int = 1) -> void:
	name = item_name
	description = item_description
	type = item_type
	level = item_level
	id = name.to_lower().replace(" ", "_")

func get_requirements() -> Dictionary:
	return requirements

func set_requirement(requirement_type: String, value) -> void:
	requirements[requirement_type] = value

func get_bonuses() -> Dictionary:
	return bonuses

func set_bonus(stat_name: String, value: int) -> void:
	bonuses[stat_name] = value

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"level": level,
		"value": value,
		"requirements": requirements.duplicate(),
		"bonuses": bonuses.duplicate()
	}

func deserialize(data: Dictionary) -> EquipmentData:
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	type = data.get("type", GlobalEnums.ItemType.MISC)
	level = data.get("level", 1)
	value = data.get("value", 0)
	requirements = data.get("requirements", {}).duplicate()
	bonuses = data.get("bonuses", {}).duplicate()
	return self