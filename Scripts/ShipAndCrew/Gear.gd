class_name Gear
extends Equipment

enum GearType {
	MEDICAL,
	TECH,
	SURVIVAL,
	UTILITY
}

@export var gear_type: GearType
@export var weight: float = 1.0

func _init(p_name: String = "", p_description: String = "", p_gear_type: GearType = GearType.UTILITY, p_level: int = 1, p_weight: float = 1.0):
	super._init(p_name, GlobalEnums.ItemType.GEAR, p_level)
	description = p_description
	gear_type = p_gear_type
	weight = p_weight

func serialize() -> Dictionary:
	var data = super.serialize()
	data["gear_type"] = GearType.keys()[gear_type]
	data["description"] = description
	data["weight"] = weight
	return data

static func deserialize(data: Dictionary) -> Gear:
	var gear = Gear.new(
		data["name"],
		data["description"],
		GearType[data["gear_type"]],
		data["level"],
		data["weight"]
	)
	gear.value = data["value"]
	gear.is_damaged = data["is_damaged"]
	return gear

func get_gear_type_string() -> String:
	return GearType.keys()[gear_type]

func apply_effect(character: Character) -> void:
	# Implement gear-specific effects here
	pass

func can_use(character: Character) -> bool:
	# Implement usage conditions here
	return true
