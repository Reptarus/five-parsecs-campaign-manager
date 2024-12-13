class_name Equipment
extends Resource

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

@export var name: String = ""
@export var type: int = GlobalEnums.ItemType.TOOL
@export var value: int = 0
@export var description: String = ""
@export var weight: float = 1.0
@export var is_damaged: bool = false
@export var rarity: int = GlobalEnums.ItemRarity.COMMON
@export var quantity: int = 1
var roll_result: int = 0

func _init(_name: String = "", _type: int = GlobalEnums.ItemType.TOOL, _value: int = 0, _description: String = "") -> void:
	name = _name
	type = _type
	value = _value
	description = _description
	is_damaged = false
	rarity = GlobalEnums.ItemRarity.COMMON
	roll_result = 0
	quantity = 1

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": GlobalEnums.ItemType.keys()[type],
		"value": value,
		"description": description,
		"weight": weight,
		"is_damaged": is_damaged,
		"rarity": GlobalEnums.ItemRarity.keys()[rarity],
		"roll_result": roll_result,
		"quantity": quantity
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
	equipment.is_damaged = data.get("is_damaged", false)
	equipment.rarity = GlobalEnums.ItemRarity[data.get("rarity", "COMMON")]
	equipment.roll_result = data.get("roll_result", 0)
	equipment.quantity = data.get("quantity", 1)
	return equipment

static func from_json(json_data: Dictionary) -> Equipment:
	# Convert JSON format to our internal format
	var data := {
		"name": json_data.get("name", "Unknown Item"),
		"type": json_data.get("type", "TOOL"),
		"value": json_data.get("value", 0),
		"description": json_data.get("description", ""),
		"weight": json_data.get("weight", 1.0),
		"is_damaged": json_data.get("is_damaged", false),
		"rarity": json_data.get("rarity", "COMMON"),
		"roll_result": json_data.get("roll_result", 0),
		"quantity": json_data.get("quantity", 1)
	}
	return deserialize(data)

func get_effectiveness() -> int:
	return value if not is_damaged else value / 2  # Damaged equipment is less effective

func create_copy() -> Equipment:
	var copy := Equipment.new()
	copy.name = name
	copy.type = type
	copy.value = value
	copy.description = description
	copy.weight = weight
	copy.rarity = rarity
	copy.roll_result = roll_result
	copy.quantity = quantity
	copy.is_damaged = is_damaged
	return copy

func is_special() -> bool:
	return type == GlobalEnums.ItemType.SPECIAL

func is_gear() -> bool:
	return type == GlobalEnums.ItemType.GEAR

func get_type_string() -> String:
	return GlobalEnums.ItemType.keys()[type]

func get_rarity_string() -> String:
	return GlobalEnums.ItemRarity.keys()[rarity]
