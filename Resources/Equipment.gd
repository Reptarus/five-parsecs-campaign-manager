class_name Equipment
extends Resource

enum Type { WEAPON, ARMOR, GEAR, SHIP_COMPONENT }

@export var name: String
@export var type: Type
@export var value: int
@export var is_damaged: bool = false

func _init(_name: String = "", _type: Type = Type.GEAR, _value: int = 0) -> void:
	name = _name
	type = _type
	value = _value

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true

func get_effectiveness() -> int:
	return value if not is_damaged else value / 2

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": type,
		"value": value,
		"is_damaged": is_damaged,
	}

static func deserialize(data: Dictionary) -> Equipment:
	if not data.has_all(["name", "type", "value", "is_damaged"]):
		push_error("Invalid equipment data for deserialization")
		return null
	var equipment = Equipment.new(data["name"], data["type"], data["value"])
	equipment.is_damaged = data["is_damaged"]
	return equipment
