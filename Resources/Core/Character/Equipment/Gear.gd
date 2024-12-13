extends Equipment
class_name Gear

@export var gear_type: int = GlobalEnums.ItemType.TOOL  # Fixed type hint

func _init(p_name: String = "", p_description: String = "", p_gear_type: int = GlobalEnums.ItemType.TOOL, p_level: int = 1, p_weight: float = 1.0) -> void:
	super._init(p_name, p_gear_type, 0)  # Set initial value to 0
	description = p_description
	weight = p_weight
	is_damaged = false  # Initialize is_damaged

func serialize() -> Dictionary:
	var data = super.serialize()
	data["gear_type"] = GlobalEnums.ItemType.keys()[gear_type]
	data["description"] = description
	data["weight"] = weight
	data["is_damaged"] = is_damaged
	return data

static func deserialize(data: Dictionary) -> Gear:
	var gear = Gear.new(
		data["name"],
		data["description"],
		GlobalEnums.ItemType[data["gear_type"]],
		data["level"],
		data["weight"]
	)
	gear.value = data.get("value", 0)
	gear.is_damaged = data.get("is_damaged", false)
	return gear

func get_gear_type_string() -> String:
	return GlobalEnums.ItemType.keys()[gear_type]

func apply_effect(_character: Character) -> void:
	# Implement gear-specific effects here
	pass

func can_use(_character: Character) -> bool:
	# Check if gear can be used
	return not is_damaged  # Damaged gear cannot be used

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true
