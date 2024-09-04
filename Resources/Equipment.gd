class_name Equipment
extends Resource

enum Type { WEAPON, ARMOR, GEAR, SHIP_COMPONENT }

@export var name: String
@export var type: Type
@export var value: int
@export var is_damaged: bool = false
@export var description: String

func _init(_name: String = "", _type: Type = Type.GEAR, _value: int = 0, _description: String = "") -> void:
	name = _name
	type = _type
	value = _value
	description = _description

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true

func get_effectiveness() -> int:
	return value if not is_damaged else value / 2

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": Type.keys()[type],
		"value": value,
		"is_damaged": is_damaged,
		"description": description
	}

static func deserialize(data: Dictionary) -> Equipment:
	var equipment = Equipment.new(
		data["name"],
		Type[data["type"]],
		data["value"],
		data["description"]
	)
	equipment.is_damaged = data["is_damaged"]
	return equipment
