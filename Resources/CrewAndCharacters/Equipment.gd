class_name Equipment
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var name: String
@export var type: int  # GlobalEnums.ItemType
@export var value: int
@export var description: String
@export var is_damaged: bool = false
@export var effects: Array[Dictionary] = []
@export var stats: Dictionary = {}
@export var traits: Array[String] = []

func _init(_name: String = "", _type: int = GlobalEnums.ItemType.GEAR, _value: int = 0, _description: String = "", _is_damaged: bool = false) -> void:
	name = _name
	type = _type
	value = _value
	description = _description
	is_damaged = _is_damaged

func create_copy() -> Equipment:
	var copy = Equipment.new()
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(property.name, get(property.name))
	return copy

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true

func get_effectiveness() -> int:
	return value if not is_damaged else int(float(value) / 2.0)

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": GlobalEnums.ItemType.keys()[type],
		"value": value,
		"description": description,
		"is_damaged": is_damaged,
		"stats": stats,
		"traits": traits
	}

static func deserialize(data: Dictionary) -> Equipment:
	var equipment_type = GlobalEnums.ItemType[data["type"]] if data["type"] in GlobalEnums.ItemType else GlobalEnums.ItemType.GEAR
	var equipment = Equipment.new(
		data["name"],
		equipment_type,
		data["value"],
		data["description"],
		data.get("is_damaged", false)
	)
	equipment.stats = data.get("stats", {})
	equipment.traits = data.get("traits", [])
	return equipment

static func from_json(json_data: Dictionary) -> Equipment:
	var equipment_type = GlobalEnums.ItemType.GEAR  # Default to GEAR
	var equipment_value = 0
	var item_description = ""

	if "type" in json_data:
		match json_data["type"].to_lower():
			"weapon":
				equipment_type = GlobalEnums.ItemType.WEAPON
			"armor":
				equipment_type = GlobalEnums.ItemType.ARMOR
			"gear":
				equipment_type = GlobalEnums.ItemType.GEAR
			"consumable":
				equipment_type = GlobalEnums.ItemType.CONSUMABLE

	if "damage" in json_data:
		equipment_value = json_data["damage"]
	elif "defense" in json_data:
		equipment_value = json_data["defense"]
	elif "effect" in json_data:
		item_description = json_data["effect"]

	var equipment = Equipment.new(
		json_data["name"],
		equipment_type,
		equipment_value,
		item_description,
		false
	)

	if "range" in json_data:
		equipment.stats["range"] = json_data["range"]
	if "shots" in json_data:
		equipment.stats["shots"] = json_data["shots"]
	if "uses" in json_data:
		equipment.stats["uses"] = json_data["uses"]
	if "traits" in json_data:
		equipment.traits = json_data["traits"]

	return equipment
