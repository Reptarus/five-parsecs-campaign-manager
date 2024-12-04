class_name Equipment
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var name: String
@export var type: int  # GlobalEnums.ItemType
@export var value: int
@export var description: String
@export var weight: float = 1.0

func _init(_name: String = "", _type: int = GlobalEnums.ItemType.TOOL, _value: int = 0, _description: String = "") -> void:
	name = _name
	type = _type
	value = _value
	description = _description

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": GlobalEnums.ItemType.keys()[type],
		"value": value,
		"description": description,
		"weight": weight
	}

static func deserialize(data: Dictionary) -> Equipment:
	var equipment_type = GlobalEnums.ItemType[data["type"]] if data["type"] in GlobalEnums.ItemType else GlobalEnums.ItemType.TOOL
	var equipment = Equipment.new(
		data["name"],
		equipment_type,
		data["value"],
		data["description"]
	)
	equipment.weight = data.get("weight", 1.0)
	return equipment

static func from_json(json_data: Dictionary) -> Equipment:
	# Convert JSON format to our internal format
	var data := {
		"name": json_data.get("name", "Unknown Item"),
		"type": json_data.get("type", "TOOL"),
		"value": json_data.get("value", 0),
		"description": json_data.get("description", ""),
		"weight": json_data.get("weight", 1.0)
	}
	return deserialize(data)

func get_effectiveness() -> int:
	return value

func create_copy() -> Equipment:
	var copy := Equipment.new()
	copy.name = name
	copy.type = type
	copy.value = value
	copy.description = description
	copy.weight = weight
	return copy
