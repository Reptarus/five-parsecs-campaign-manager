class_name ArmorData
extends EquipmentData

@export var defense: int = 1
@export var armor_type: int = GlobalEnums.ArmorType.LIGHT
@export var characteristics: Array[int] = [] # Array of GlobalEnums.ArmorCharacteristic
@export var durability: int = 100
@export var current_durability: int = 100

func _init(armor_name: String = "", armor_description: String = "", armor_defense: int = 1) -> void:
	super(armor_name, armor_description, GlobalEnums.ItemType.ARMOR)
	defense = armor_defense

func get_defense() -> int:
	return defense

func get_armor_type() -> int:
	return armor_type

func set_armor_type(type: int) -> void:
	armor_type = type

func get_durability() -> int:
	return durability

func get_current_durability() -> int:
	return current_durability

func set_durability(value: int) -> void:
	durability = value
	current_durability = mini(current_durability, durability)

func repair(amount: int) -> void:
	current_durability = mini(current_durability + amount, durability)

func take_damage(amount: int) -> void:
	current_durability = maxi(0, current_durability - amount)

func is_broken() -> bool:
	return current_durability <= 0

func get_characteristics() -> Array[int]:
	return characteristics

func has_characteristic(characteristic: int) -> bool:
	return characteristic in characteristics

func add_characteristic(characteristic: int) -> void:
	if not has_characteristic(characteristic):
		characteristics.append(characteristic)

func remove_characteristic(characteristic: int) -> void:
	characteristics.erase(characteristic)

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"defense": defense,
		"armor_type": armor_type,
		"characteristics": characteristics.duplicate(),
		"durability": durability,
		"current_durability": current_durability
	})
	return data

func deserialize(data: Dictionary) -> ArmorData:
	super.deserialize(data)
	defense = data.get("defense", 1)
	armor_type = data.get("armor_type", GlobalEnums.ArmorType.LIGHT)
	characteristics = data.get("characteristics", [])
	durability = data.get("durability", 100)
	current_durability = data.get("current_durability", durability)
	return self