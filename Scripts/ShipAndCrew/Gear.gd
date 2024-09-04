class_name Gear
extends Equipment

var gear_type: String
var description: String

func _init(p_name: String = "", p_description: String = "", p_gear_type: String = "", p_level: int = 1):
	super._init(p_name, Equipment.Type.GEAR, p_level)
	description = p_description
	gear_type = p_gear_type

func serialize() -> Dictionary:
	var data = super.serialize()
	data["gear_type"] = gear_type
	data["description"] = description
	return data

static func deserialize(data: Dictionary) -> Gear:
	var gear = Gear.new(
		data["name"],
		data["description"],
		data["gear_type"],
		data["level"]
	)
	gear.value = data["value"]
	gear.is_damaged = data["is_damaged"]
	return gear
