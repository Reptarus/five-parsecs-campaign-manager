class_name HullComponent
extends ShipComponent

@export var armor: int

func _init(p_name: String, p_power_usage: int, p_health: int, p_is_damaged: bool, p_armor: int, p_weight: float) -> void:
	super._init(p_name, "Hull component", GlobalEnums.ComponentType.HULL, p_power_usage, p_health, p_weight)
	armor = p_armor
	is_damaged = p_is_damaged

func take_damage(amount: int) -> void:
	var damage_after_armor = max(0, amount - armor)
	super.take_damage(damage_after_armor)

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"type": GlobalEnums.ComponentType.HULL,
		"armor": armor
	})
	return data

static func deserialize(data: Dictionary) -> HullComponent:
	var component = HullComponent.new(
		data["name"],
		data["power_usage"],
		data["health"],
		data["is_damaged"],
		data["armor"],
		data["weight"]
	)
	return component
