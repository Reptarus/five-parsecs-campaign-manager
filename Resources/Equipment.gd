class_name Equipment
extends Resource

enum Type { WEAPON, ARMOR, GEAR, SHIP_COMPONENT, CONSUMABLE, IMPLANT, COMPONENT }

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

func create_copy():
	var copy = get_script().new()
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
	var equipment_type = Type.GEAR  # Default to GEAR
	var equipment_value = 0
	var item_description = ""

	if "type" in json_data:
		match json_data["type"].to_lower():
			"military", "high-tech", "melee", "heavy":
				equipment_type = Type.WEAPON
			"light", "medium", "heavy":
				equipment_type = Type.ARMOR
			"utility", "tech", "mobility", "medical":
				equipment_type = Type.GEAR
			"explosive":
				equipment_type = Type.CONSUMABLE
			"defensive", "combat":
				equipment_type = Type.IMPLANT

	if "damage" in json_data:
		equipment_value = json_data["damage"]
	elif "defense" in json_data:
		equipment_value = json_data["defense"]
	elif "effect" in json_data:
		item_description = json_data["effect"]

	if "traits" in json_data:
		item_description += " Traits: " + ", ".join(json_data["traits"])

	var equipment = Equipment.new(
		json_data["name"],
		equipment_type,
		equipment_value,
		item_description,
		false
	)

	if "range" in json_data:
		equipment.effects.append({"range": json_data["range"]})
	if "shots" in json_data:
		equipment.effects.append({"shots": json_data["shots"]})
	if "uses" in json_data:
		equipment.effects.append({"uses": json_data["uses"]})

	return equipment
