class_name Equipment
extends Resource

enum Type { WEAPON, ARMOR, GEAR, SHIP_COMPONENT, CONSUMABLE }

@export var name: String
@export var type: Type
@export var value: int
@export var description: String
@export var is_damaged: bool = false
@export var effects: Array[Dictionary] = []

func _init(_name: String = "", _type: Type = Type.GEAR, _value: int = 0, _description: String = "", _is_damaged: bool = false) -> void:
	name = _name
	type = _type
	value = _value
	description = _description
	is_damaged = _is_damaged

func duplicate() -> Equipment:
	var new_equipment = Equipment.new(name, type, value, description, is_damaged)
	new_equipment.effects = effects.duplicate()
	return new_equipment

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true

func get_effectiveness() -> int:
	return value if not is_damaged else int(float(value) / 2.0)

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": Type.keys()[type],
		"value": value,
		"description": description,
		"is_damaged": is_damaged
	}

static func deserialize(data: Dictionary) -> Equipment:
	var equipment_type = Type[data["type"]] if data["type"] in Type else Type.GEAR
	return Equipment.new(
		data["name"],
		equipment_type,
		data["value"],
		data["description"],
		data.get("is_damaged", false)
	)

static func from_json(json_data: Dictionary) -> Equipment:
	var equipment_type = Type[json_data["type"]] if json_data["type"] in Type else Type.GEAR
	return Equipment.new(
		json_data["name"],
		equipment_type,
		json_data["value"],
		json_data["description"],
		false  # Assuming new equipment from JSON is not damaged by default
	)
