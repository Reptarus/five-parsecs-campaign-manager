class_name HullComponent
extends ShipComponent

@export var armor: int

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_armor: int) -> void:
	super._init(p_name, p_description, ComponentType.HULL, p_power_usage, p_health)
	armor = p_armor

func take_damage(amount: int) -> void:
	var damage_after_armor = max(0, amount - armor)
	super.take_damage(damage_after_armor)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["armor"] = armor
	return data

static func deserialize(data: Dictionary) -> HullComponent:
	var component = HullComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["max_health"],
		data["armor"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	return component