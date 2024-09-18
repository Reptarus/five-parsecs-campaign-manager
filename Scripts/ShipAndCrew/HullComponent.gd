class_name HullComponent
extends ShipComponent

@export var armor: int

func _init(p_name: String, p_type: ComponentType, p_power_usage: int, p_durability: int, p_armor: int) -> void:
	super._init(p_name, p_type, p_power_usage, p_durability)
	armor = p_armor

func take_damage(amount: int) -> void:
	var damage_after_armor = max(0, amount - armor)
	durability = max(0, durability - damage_after_armor)
	is_damaged = durability == 0

func serialize() -> Dictionary:
	var data = super.serialize()
	data["armor"] = armor
	return data

static func deserialize(data: Dictionary) -> HullComponent:
	var component = HullComponent.new(
		data["name"],
		ComponentType[data["type"]],
		data["power_usage"],
		data["durability"],
		data["armor"]
	)
	component.is_damaged = data["is_damaged"]
	return component
